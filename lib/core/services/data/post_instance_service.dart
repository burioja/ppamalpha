import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/post/post_instance_model_simple.dart';
import '../../models/post/post_model.dart';
import 'points_service.dart';

/// 포스트 인스턴스 서비스
/// 사용자가 마커를 터치해서 수집한 개인 포스트 인스턴스를 관리
class PostInstanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PointsService _pointsService = PointsService();

  /// 포스트 수집 (마커 터치 → post_collections에 기록)
  Future<String> collectPost({
    required String markerId,
    required String userId,
    required GeoPoint userLocation,
  }) async {
    try {
      debugPrint('🎯 PostInstanceService.collectPost 시작: markerId=$markerId, userId=$userId');

      // 1. 마커 정보 조회
      debugPrint('🔍 마커 조회 시도: markerId=$markerId');
      final markerDoc = await _firestore.collection('markers').doc(markerId).get();
      if (!markerDoc.exists) {
        debugPrint('❌ 마커를 찾을 수 없음: $markerId');
        throw Exception('마커를 찾을 수 없습니다.');
      }
      debugPrint('✅ 마커 조회 성공');

      final markerData = markerDoc.data()!;
      final postId = markerData['postId'] as String;
      final remainingQuantity = markerData['remainingQuantity'] as int? ?? 0;
      final endDate = (markerData['endDate'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(days: 7));

      debugPrint('📍 마커 정보:');
      debugPrint('   - postId: $postId');
      debugPrint('   - remainingQuantity: $remainingQuantity');
      debugPrint('   - endDate: $endDate');

      // 2. 수량 체크
      if (remainingQuantity <= 0) {
        throw Exception('이미 모든 포스트가 수집되었습니다.');
      }

      // 3. 중복 수집 체크 (post_collections에서)
      final existingCollection = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingCollection.docs.isNotEmpty) {
        throw Exception('이미 수집한 포스트입니다.');
      }

      // 4. 원본 템플릿 정보 조회 (posts 컬렉션만 사용)
      debugPrint('🔍 포스트 조회 시도: postId=$postId');
      final postDoc = await _firestore.collection('posts').doc(postId).get();

      if (!postDoc.exists) {
        debugPrint('❌ posts 컬렉션에서 포스트를 찾을 수 없음: $postId');
        debugPrint('💡 가능한 원인: 1) 포스트가 삭제됨 2) 마커 데이터 오류 3) posts 컬렉션 없음');
        throw Exception('포스트가 더 이상 존재하지 않습니다. 마커가 만료되었을 가능성이 있습니다.');
      }

      debugPrint('✅ 포스트 조회 성공: ${postDoc.data()?['title']}');

      final postModel = PostModel.fromFirestore(postDoc);

      // 5. 배치 트랜잭션으로 처리
      final batch = _firestore.batch();

      // 5-1. post_collections에 수집 기록 생성 (기존 구조 + 확장 필드)
      final collectionRef = _firestore.collection('post_collections').doc();
      final collectionData = {
        // 기존 필드들
        'postId': postId,
        'userId': userId,
        'collectedAt': Timestamp.now(),
        'postTitle': postModel.title,
        'postCreatorId': postModel.creatorId,

        // 확장 필드들
        'markerId': markerId,
        'collectedLocation': userLocation,
        'status': 'COLLECTED',
        'isActive': true,
        'reward': postModel.reward,
        'canUse': postModel.canUse,
        'isCoupon': postModel.isCoupon,
        'expiresAt': Timestamp.fromDate(endDate),

        // 포스트 상세 정보 (통계 및 표시용)
        'description': postModel.description,
        'mediaType': postModel.mediaType,
        'mediaUrl': postModel.mediaUrl,
        'thumbnailUrl': postModel.thumbnailUrl,
        'placeId': postModel.placeId,
        'couponData': postModel.couponData,
      };

      batch.set(collectionRef, collectionData);

      // 5-2. 마커 수량 감소
      batch.update(markerDoc.reference, {
        'remainingQuantity': FieldValue.increment(-1),
        'collectedQuantity': FieldValue.increment(1),
        'collectionRate': ((markerData['collectedQuantity'] as int) + 1) / (markerData['totalQuantity'] as int),
      });

      // 5-3. 템플릿 통계 업데이트
      batch.update(postDoc.reference, {
        'totalInstances': FieldValue.increment(1),
        'lastCollectedAt': FieldValue.serverTimestamp(),
      });

      // 6. 트랜잭션 실행
      await batch.commit();

      // 7. 포인트 보상 지급 (수집자에게)
      try {
        await _pointsService.rewardPostCollection(
          userId,
          postModel.reward,
          postId,
          postModel.creatorId,
        );
      } catch (pointsError) {
        debugPrint('⚠️ 포인트 보상 지급 실패 (수집은 완료됨): $pointsError');
      }

      debugPrint('✅ 포스트 수집 완료: collectionId=${collectionRef.id}');
      return collectionRef.id;

    } catch (e) {
      debugPrint('❌ PostInstanceService.collectPost 오류: $e');
      rethrow;
    }
  }

  /// 사용자별 수집 포스트 목록 조회 (post_collections 사용)
  Future<List<Map<String, dynamic>>> getUserCollections({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDocument,
    String? statusFilter, // 'COLLECTED', 'USED', 'EXPIRED'
  }) async {
    try {
      debugPrint('🔍 PostInstanceService.getUserCollections 호출: userId=$userId, limit=$limit');

      Query query = _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId);

      // 활성 상태만 조회 (기본적으로)
      if (statusFilter == null) {
        query = query.where('isActive', isEqualTo: true);
      }

      // 상태 필터링
      if (statusFilter != null && statusFilter != 'all') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      // 정렬 및 페이지네이션
      query = query.orderBy('collectedAt', descending: true).limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();

      final collections = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      debugPrint('📊 사용자 수집 기록 조회 결과: ${collections.length}개');

      return collections;
    } catch (e) {
      debugPrint('❌ getUserCollections 오류: $e');
      throw Exception('수집 포스트 조회 실패: $e');
    }
  }

  /// 수집된 포스트 사용 처리 (post_collections 업데이트)
  Future<void> useCollectedPost({
    required String collectionId,
    required String userId,
    GeoPoint? usedLocation,
    String? usedNote,
  }) async {
    try {
      debugPrint('🎯 PostInstanceService.useCollectedPost 시작: collectionId=$collectionId');

      final collectionDoc = await _firestore.collection('post_collections').doc(collectionId).get();
      if (!collectionDoc.exists) {
        throw Exception('수집 기록을 찾을 수 없습니다.');
      }

      final collectionData = collectionDoc.data()!;
      final postId = collectionData['postId'] as String;

      // 사용 권한 및 상태 체크
      if (collectionData['userId'] != userId) {
        throw Exception('사용 권한이 없습니다.');
      }

      if (collectionData['status'] == 'USED') {
        throw Exception('이미 사용된 포스트입니다.');
      }

      final canUse = collectionData['canUse'] as bool? ?? true;
      if (!canUse) {
        throw Exception('사용할 수 없는 포스트입니다.');
      }

      // 만료 체크
      final expiresAt = collectionData['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('만료된 포스트입니다.');
      }

      // 배치 트랜잭션으로 업데이트
      final batch = _firestore.batch();

      // 1. 수집 기록 사용 처리
      batch.update(collectionDoc.reference, {
        'status': 'USED',
        'usedAt': FieldValue.serverTimestamp(),
        'usedLocation': usedLocation,
        'usedNote': usedNote,
      });

      // 2. 포스트 템플릿 통계 업데이트
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'totalUsed': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // 포인트 지급 처리 (사용자에게 추가 보상, 옵션)
      try {
        final isCoupon = collectionData['isCoupon'] as bool? ?? false;
        final reward = collectionData['reward'] as int? ?? 0;
        final placeId = collectionData['placeId'] as String?;

        // 쿠폰 사용 시 추가 보상
        if (isCoupon && reward > 0) {
          await _pointsService.rewardPostUsage(
            userId,
            reward ~/ 2, // 사용 보상은 수집 보상의 절반
            postId,
            placeId: placeId,
          );
        }
      } catch (pointsError) {
        debugPrint('⚠️ 포인트 사용 보상 지급 실패 (사용은 완료됨): $pointsError');
      }

      debugPrint('✅ 포스트 사용 및 통계 업데이트 완료: collectionId=$collectionId');

    } catch (e) {
      debugPrint('❌ PostInstanceService.useCollectedPost 오류: $e');
      rethrow;
    }
  }

  /// 수집 기록 상세 조회
  Future<Map<String, dynamic>?> getCollectionById(String collectionId) async {
    try {
      final doc = await _firestore.collection('post_collections').doc(collectionId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {'id': doc.id, ...data};
      }
      return null;
    } catch (e) {
      debugPrint('❌ getCollectionById 오류: $e');
      return null;
    }
  }

  /// 만료된 수집 기록 정리 (배치 작업)
  Future<void> cleanupExpiredCollections() async {
    try {
      debugPrint('🧹 만료된 수집 기록 정리 시작');

      final now = DateTime.now();
      final expiredQuery = await _firestore
          .collection('post_collections')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('status', isEqualTo: 'COLLECTED')
          .limit(100)
          .get();

      if (expiredQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();

        for (final doc in expiredQuery.docs) {
          batch.update(doc.reference, {
            'status': 'EXPIRED',
            'isActive': false,
          });
        }

        await batch.commit();
        debugPrint('✅ ${expiredQuery.docs.length}개 수집 기록 만료 처리 완료');
      } else {
        debugPrint('📝 만료된 수집 기록 없음');
      }

    } catch (e) {
      debugPrint('❌ cleanupExpiredCollections 오류: $e');
    }
  }

  /// 사용자 수집/사용 통계 조회 (post_collections 기반)
  Future<Map<String, int>> getUserUsageStats(String userId) async {
    try {
      final userCollections = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .get();

      int totalCollected = userCollections.docs.length;
      int totalUsed = 0;
      int totalExpired = 0;

      for (final doc in userCollections.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'COLLECTED';

        if (status == 'USED') {
          totalUsed++;
        } else if (status == 'EXPIRED') {
          totalExpired++;
        }
      }

      return {
        'totalCollected': totalCollected,
        'totalUsed': totalUsed,
        'totalExpired': totalExpired,
        'totalActive': totalCollected - totalUsed - totalExpired,
      };
    } catch (e) {
      debugPrint('❌ getUserUsageStats 오류: $e');
      return {'totalCollected': 0, 'totalUsed': 0, 'totalExpired': 0, 'totalActive': 0};
    }
  }

  /// 특정 포스트로 생성된 모든 수집 기록 조회 (통계용)
  Future<List<Map<String, dynamic>>> getCollectionsByPostId(String postId) async {
    try {
      final querySnapshot = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .orderBy('collectedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('❌ getCollectionsByPostId 오류: $e');
      return [];
    }
  }

  /// 특정 마커로 생성된 모든 수집 기록 조회 (통계용)
  Future<List<Map<String, dynamic>>> getCollectionsByMarkerId(String markerId) async {
    try {
      final querySnapshot = await _firestore
          .collection('post_collections')
          .where('markerId', isEqualTo: markerId)
          .orderBy('collectedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('❌ getCollectionsByMarkerId 오류: $e');
      return [];
    }
  }

  /// 실시간 사용자 수집 기록 스트림
  Stream<List<Map<String, dynamic>>> getUserCollectionsStream(String userId) {
    return _firestore
        .collection('post_collections')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('collectedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList());
  }
}