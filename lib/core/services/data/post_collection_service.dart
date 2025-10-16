import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post/post_model.dart';
import '../../../features/map_system/services/fog_of_war/visit_tile_service.dart';
import 'points_service.dart';

/// 포스트 수집 관련 서비스
class PostCollectionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PointsService _pointsService = PointsService();

  // 포스트 수집 (크리에이터용)
  Future<void> collectPostAsCreator({
    required String postId,
    required String userId,
    required String markerId,
    required int quantity,
  }) async {
    try {
      debugPrint('🎯 collectPostAsCreator 호출: postId=$postId, userId=$userId, markerId=$markerId, quantity=$quantity');

      // 1. 포스트 문서 가져오기
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      // 2. 마커 문서 가져오기
      final markerDoc = await _firestore.collection('markers').doc(markerId).get();
      if (!markerDoc.exists) {
        throw Exception('마커를 찾을 수 없습니다.');
      }

      // 3. 배치 작업으로 수집 처리
      final batch = _firestore.batch();

      // 3-1. 포스트 컬렉션에서 수집
      await _collectFromPostsCollection(postDoc, userId);

      // 3-2. 마커 컬렉션에서 수집
      await _collectFromMarkersCollection(markerDoc, userId, postId);

      // 3-3. 포인트 추가
      final postData = postDoc.data()!;
      final reward = postData['reward'] as int? ?? 0;
      final totalPoints = reward * quantity;
      await _addUserPoints(userId, totalPoints, batch);

      // 3-4. 배치 커밋
      await batch.commit();

      debugPrint('✅ collectPostAsCreator 완료: ${totalPoints}포인트 추가');
    } catch (e) {
      debugPrint('❌ collectPostAsCreator 실패: $e');
      rethrow;
    }
  }

  // 포스트 수집 (일반 사용자용)
  Future<void> collectPost({
    required String postId,
    required String userId,
  }) async {
    try {
      debugPrint('🔄 collectPost 호출: postId=$postId, userId=$userId');

      // 1. 포스트 문서 가져오기
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      // 2. 마커 문서 가져오기 (postId로 검색)
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .limit(1)
          .get();

      if (markersQuery.docs.isEmpty) {
        throw Exception('해당 포스트의 마커를 찾을 수 없습니다.');
      }

      final markerDoc = markersQuery.docs.first;

      // 3. 배치 작업으로 수집 처리
      final batch = _firestore.batch();

      // 3-1. 포스트 컬렉션에서 수집
      await _collectFromPostsCollection(postDoc, userId);

      // 3-2. 마커 컬렉션에서 수집
      await _collectFromMarkersCollection(markerDoc, userId, postId);

      // 3-3. 포인트 추가
      final postData = postDoc.data()!;
      final reward = postData['reward'] as int? ?? 0;
      await _addUserPoints(userId, reward, batch);

      // 3-4. 배치 커밋
      await batch.commit();

      debugPrint('✅ collectPost 완료: ${reward}포인트 추가');
    } catch (e) {
      debugPrint('❌ collectPost 실패: $e');
      rethrow;
    }
  }

  // 포스트 컬렉션에서 수집
  Future<void> _collectFromPostsCollection(DocumentSnapshot postDoc, String userId) async {
    try {
      final batch = _firestore.batch();
      final postId = postDoc.id;

      // 1. post_collections에 수집 기록 추가
      final collectionRef = _firestore.collection('post_collections').doc();
      batch.set(collectionRef, {
        'postId': postId,
        'userId': userId,
        'collectedAt': FieldValue.serverTimestamp(),
        'status': 'unconfirmed', // 미확인 상태로 시작
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. 포스트의 총 수집 횟수 증가
      batch.update(postDoc.reference, {
        'totalCollected': FieldValue.increment(1),
        'lastCollectedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('✅ 포스트 컬렉션에서 수집 완료');
    } catch (e) {
      debugPrint('❌ 포스트 컬렉션 수집 실패: $e');
      rethrow;
    }
  }

  // 마커 컬렉션에서 수집
  Future<void> _collectFromMarkersCollection(DocumentSnapshot markerDoc, String userId, String originalPostId) async {
    try {
      final batch = _firestore.batch();
      final markerId = markerDoc.id;
      final markerData = markerDoc.data() as Map<String, dynamic>;

      // 1. 마커 수집 기록 추가
      final markerCollectionRef = _firestore.collection('marker_collections').doc();
      batch.set(markerCollectionRef, {
        'markerId': markerId,
        'postId': originalPostId,
        'userId': userId,
        'collectedAt': FieldValue.serverTimestamp(),
        'status': 'unconfirmed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. 마커의 수량 감소
      final currentQuantity = markerData['quantity'] as int? ?? 1;
      if (currentQuantity > 1) {
        batch.update(markerDoc.reference, {
          'quantity': FieldValue.increment(-1),
          'lastCollectedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // 수량이 1이면 마커 삭제
        batch.delete(markerDoc.reference);
      }

      await batch.commit();
      debugPrint('✅ 마커 컬렉션에서 수집 완료');
    } catch (e) {
      debugPrint('❌ 마커 컬렉션 수집 실패: $e');
      rethrow;
    }
  }

  // 사용자 포인트 추가
  Future<void> _addUserPoints(String userId, int points, WriteBatch batch) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // 사용자 포인트 증가
      batch.update(userRef, {
        'points': FieldValue.increment(points),
        'lastPointsUpdate': FieldValue.serverTimestamp(),
      });

      // 포인트 히스토리 추가
      final historyRef = _firestore.collection('point_history').doc();
      batch.set(historyRef, {
        'userId': userId,
        'points': points,
        'type': 'earned',
        'source': 'post_collection',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 포인트 추가 준비 완료: ${points}포인트');
    } catch (e) {
      debugPrint('❌ 포인트 추가 실패: $e');
      rethrow;
    }
  }

  // 수집한 포스트 목록 조회
  Future<List<PostModel>> getCollectedPosts(String userId) async {
    try {
      debugPrint('🔍 getCollectedPosts 호출: userId=$userId');

      // 1. 수집 기록 조회
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      if (collectionsQuery.docs.isEmpty) {
        debugPrint('📭 수집한 포스트가 없습니다.');
        return [];
      }

      // 2. 포스트 ID 목록 추출
      final postIds = collectionsQuery.docs
          .map((doc) => doc.data()['postId'] as String)
          .toList();

      debugPrint('📦 수집한 포스트 ID 목록: ${postIds.length}개');

      // 3. 포스트 상세 정보 조회
      final posts = <PostModel>[];
      for (final postId in postIds) {
        try {
          final postDoc = await _firestore.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            final postData = postDoc.data()!;
            final post = PostModel.fromFirestore(postDoc);
            posts.add(post);
          }
        } catch (e) {
          debugPrint('⚠️ 포스트 로드 실패: $postId - $e');
        }
      }

      debugPrint('✅ 수집한 포스트 로드 완료: ${posts.length}개');
      return posts;
    } catch (e) {
      debugPrint('❌ getCollectedPosts 에러: $e');
      return [];
    }
  }

  // 수집한 포스트 사용 상태 조회
  Future<Map<String, bool>> getCollectedPostUsageStatus(String userId) async {
    try {
      final collectedPosts = await getCollectedPosts(userId);
      final usageStatus = <String, bool>{};

      for (final post in collectedPosts) {
        final usageQuery = await _firestore
            .collection('post_usage')
            .where('postId', isEqualTo: post.postId)
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

        usageStatus[post.postId] = usageQuery.docs.isNotEmpty;
      }

      return usageStatus;
    } catch (e) {
      debugPrint('❌ 사용 상태 조회 실패: $e');
      return {};
    }
  }

  // 포스트 확인 처리
  Future<void> confirmPost({
    required String postId,
    required String userId,
  }) async {
    try {
      debugPrint('✅ confirmPost 호출: postId=$postId, userId=$userId');

      // 1. 수집 기록 상태 업데이트
      final collectionQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (collectionQuery.docs.isNotEmpty) {
        final collectionDoc = collectionQuery.docs.first;
        await collectionDoc.reference.update({
          'status': 'confirmed',
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. 마커 수집 기록도 확인 처리
      final markerCollectionQuery = await _firestore
          .collection('marker_collections')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      for (final doc in markerCollectionQuery.docs) {
        batch.update(doc.reference, {
          'status': 'confirmed',
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      debugPrint('✅ 포스트 확인 처리 완료');
    } catch (e) {
      debugPrint('❌ 포스트 확인 처리 실패: $e');
      rethrow;
    }
  }

  // 미확인 포스트 개수 조회
  Future<int> getUnconfirmedPostCount(String userId) async {
    try {
      final query = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'unconfirmed')
          .get();

      return query.docs.length;
    } catch (e) {
      debugPrint('❌ 미확인 포스트 개수 조회 실패: $e');
      return 0;
    }
  }

  // 미확인 포스트 개수 스트림
  Stream<int> getUnconfirmedPostCountStream(String userId) {
    return _firestore
        .collection('post_collections')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'unconfirmed')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // 미확인 포스트 목록 조회
  Future<List<Map<String, dynamic>>> getUnconfirmedPosts(String userId) async {
    try {
      final query = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'unconfirmed')
          .orderBy('collectedAt', descending: true)
          .get();

      final unconfirmedPosts = <Map<String, dynamic>>[];
      for (final doc in query.docs) {
        final data = doc.data();
        data['collectionId'] = doc.id;
        unconfirmedPosts.add(data);
      }

      return unconfirmedPosts;
    } catch (e) {
      debugPrint('❌ 미확인 포스트 목록 조회 실패: $e');
      return [];
    }
  }
}

