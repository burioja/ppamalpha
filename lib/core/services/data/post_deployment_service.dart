import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/post/post_model.dart';

/// 포스트 배포 관련 서비스
class PostDeploymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 포스트 배포
  Future<void> deployPost({
    required String postId,
    required int quantity,
    required List<Map<String, dynamic>> locations,
    required int radiusInMeters,
    required DateTime expiresAt,
  }) async {
    try {
      debugPrint('🚀 deployPost 시작: postId=$postId, quantity=$quantity');

      // 1. 포스트 존재 확인
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      // 2. 포스트 상태를 배포됨으로 변경
      await _firestore.collection('posts').doc(postId).update({
        'status': 'deployed',
        'deployedAt': FieldValue.serverTimestamp(),
        'deployedQuantity': quantity,
        'deployedLocations': locations,
        'deployedRadius': radiusInMeters,
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. 마커 생성
      await _createMarkers(postId, quantity, locations, radiusInMeters, expiresAt);

      debugPrint('✅ deployPost 완료');
    } catch (e) {
      debugPrint('❌ deployPost 에러: $e');
      rethrow;
    }
  }

  // 마커 생성
  Future<void> _createMarkers(
    String postId,
    int quantity,
    List<Map<String, dynamic>> locations,
    int radiusInMeters,
    DateTime expiresAt,
  ) async {
    try {
      final batch = _firestore.batch();
      final markersPerLocation = (quantity / locations.length).ceil();

      for (int i = 0; i < locations.length; i++) {
        final location = locations[i];
        final markersAtThisLocation = i == locations.length - 1
            ? quantity - (markersPerLocation * (locations.length - 1))
            : markersPerLocation;

        for (int j = 0; j < markersAtThisLocation; j++) {
          final markerRef = _firestore.collection('markers').doc();
          batch.set(markerRef, {
            'postId': postId,
            'markerId': markerRef.id,
            'location': GeoPoint(
              location['latitude'] as double,
              location['longitude'] as double,
            ),
            'radius': radiusInMeters,
            'quantity': 1,
            'expiresAt': Timestamp.fromDate(expiresAt),
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'active',
          });
        }
      }

      await batch.commit();
      debugPrint('✅ 마커 생성 완료: ${quantity}개');
    } catch (e) {
      debugPrint('❌ 마커 생성 실패: $e');
      rethrow;
    }
  }

  // 포스트 상태 업데이트
  Future<void> updatePostStatus(String postId, PostStatus status) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ 포스트 상태 업데이트: $postId -> ${status.name}');
    } catch (e) {
      debugPrint('❌ 포스트 상태 업데이트 실패: $e');
      rethrow;
    }
  }

  // 포스트를 배포됨으로 표시
  Future<void> markPostAsDeployed({
    required String postId,
    required int quantity,
    required List<Map<String, dynamic>> locations,
    required int radiusInMeters,
    required DateTime expiresAt,
  }) async {
    await deployPost(
      postId: postId,
      quantity: quantity,
      locations: locations,
      radiusInMeters: radiusInMeters,
      expiresAt: expiresAt,
    );
  }

  // 포스트를 만료됨으로 표시
  Future<void> markPostAsExpired(String postId) async {
    await updatePostStatus(postId, PostStatus.DELETED);
  }

  // 포스트를 삭제됨으로 표시
  Future<void> markPostAsDeleted(String postId) async {
    await updatePostStatus(postId, PostStatus.DELETED);
  }

  // 포스트 회수
  Future<void> recallPost(String postId) async {
    try {
      debugPrint('🔄 recallPost 시작: postId=$postId');

      // 1. 포스트 상태를 회수됨으로 변경
      await _firestore.collection('posts').doc(postId).update({
        'status': 'recalled',
        'recalledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. 관련 마커들 비활성화
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final doc in markersQuery.docs) {
        batch.update(doc.reference, {
          'status': 'inactive',
          'recalledAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ 포스트 회수 완료');
    } catch (e) {
      debugPrint('❌ 포스트 회수 실패: $e');
      rethrow;
    }
  }

  // 포스트 하드 삭제
  Future<void> deletePostHard(String postId) async {
    try {
      debugPrint('🗑️ deletePostHard 시작: postId=$postId');

      // 1. 포스트 삭제
      await _firestore.collection('posts').doc(postId).delete();

      // 2. 관련 마커들 삭제
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final batch = _firestore.batch();
      for (final doc in markersQuery.docs) {
        batch.delete(doc.reference);
      }

      // 3. 수집 기록들 삭제
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      for (final doc in collectionsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('✅ 포스트 하드 삭제 완료');
    } catch (e) {
      debugPrint('❌ 포스트 하드 삭제 실패: $e');
      rethrow;
    }
  }

  // 배포된 포스트 목록 조회
  Future<List<PostModel>> getDeployedPosts(String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .where('status', isEqualTo: 'deployed')
          .orderBy('deployedAt', descending: true)
          .get();

      final posts = <PostModel>[];
      for (final doc in query.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          posts.add(post);
        } catch (e) {
          debugPrint('⚠️ 포스트 파싱 실패: ${doc.id} - $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('❌ 배포된 포스트 조회 실패: $e');
      return [];
    }
  }

  // 만료된 포스트 목록 조회
  Future<List<PostModel>> getExpiredPosts(String userId) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .where('status', isEqualTo: 'expired')
          .orderBy('expiresAt', descending: true)
          .get();

      final posts = <PostModel>[];
      for (final doc in query.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          posts.add(post);
        } catch (e) {
          debugPrint('⚠️ 포스트 파싱 실패: ${doc.id} - $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('❌ 만료된 포스트 조회 실패: $e');
      return [];
    }
  }

  // 만료된 포스트 정리
  Future<void> cleanupExpiredPosts() async {
    try {
      debugPrint('🧹 만료된 포스트 정리 시작');

      final now = Timestamp.now();
      final expiredQuery = await _firestore
          .collection('posts')
          .where('expiresAt', isLessThan: now)
          .where('status', isEqualTo: 'deployed')
          .get();

      final batch = _firestore.batch();
      for (final doc in expiredQuery.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ 만료된 포스트 정리 완료: ${expiredQuery.docs.length}개');
    } catch (e) {
      debugPrint('❌ 만료된 포스트 정리 실패: $e');
    }
  }
}

