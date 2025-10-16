import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post/post_model.dart';
import '../../../features/map_system/services/fog_of_war/visit_tile_service.dart';
import 'post_search_service.dart';
import 'points_service.dart';
import 'post_collection_service.dart';
import 'post_deployment_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PointsService _pointsService = PointsService();
  final PostCollectionService _collectionService = PostCollectionService();
  final PostDeploymentService _deploymentService = PostDeploymentService();

  // 🚀 포스트 템플릿 생성 (위치 정보 제거)
  Future<String> createPost({
    required String creatorId,
    required String creatorName,
    required int reward,
    required List<int> targetAge,
    required String targetGender,
    required List<String> targetInterest,
    required List<String> targetPurchaseHistory,
    required List<String> mediaType,
    required List<String> mediaUrl,
    List<String>? thumbnailUrl,
    required String title,
    required String description,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    required bool canUse,
    int defaultRadius = 1000, // 기본 반경 (m)
    DateTime? defaultExpiresAt, // 기본 만료일
    String? placeId, // 플레이스 ID (선택사항)
    bool isCoupon = false, // 쿠폰 여부 (선택사항)
    String? youtubeUrl, // 유튜브 URL (선택사항)
  }) async {
    try {
      debugPrint('🚀 포스트 템플릿 생성 시작: title="$title", creator=$creatorId');

      final now = DateTime.now();
      final expiresAt = defaultExpiresAt ?? now.add(const Duration(days: 30));

      // 🔍 사용자 인증 상태 확인
      bool isVerified = false;
      try {
        debugPrint('🔍 [POST_CREATE] 사용자 인증 상태 확인 시작: creatorId=$creatorId');
        final userDoc = await _firestore.collection('users').doc(creatorId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final workplaceId = userData?['workplaceId'] as String?;
          debugPrint('🔍 [POST_CREATE] workplaceId: $workplaceId');
          
          if (workplaceId != null && workplaceId.isNotEmpty) {
            // workplaceId가 있으면 해당 Place의 isVerified 확인
            final placeDoc = await _firestore.collection('places').doc(workplaceId).get();
            if (placeDoc.exists) {
              isVerified = placeDoc.data()?['isVerified'] as bool? ?? false;
              debugPrint('✅ [POST_CREATE] Place 인증 상태: $isVerified (workplaceId: $workplaceId)');
            } else {
              debugPrint('⚠️ [POST_CREATE] Place 문서가 존재하지 않음');
            }
          } else {
            debugPrint('⚠️ [POST_CREATE] 일터 미등록 사용자 → 미인증');
          }
        } else {
          debugPrint('⚠️ [POST_CREATE] User 문서가 존재하지 않음');
        }
      } catch (e) {
        debugPrint('❌ [POST_CREATE] 사용자 인증 상태 확인 실패: $e → 기본값 false');
      }
      debugPrint('🔍 [POST_CREATE] 최종 isVerified 값: $isVerified');

      // Firestore에 먼저 저장하여 문서 ID 생성
      final docRef = await _firestore.collection('posts').add({
        'postId': '', // 임시로 빈 문자열, 문서 ID 생성 후 업데이트
        'creatorId': creatorId,
        'creatorName': creatorName,
        'createdAt': now,
        'reward': reward,
        // 🚀 템플릿 기본 설정
        'defaultRadius': defaultRadius,
        'defaultExpiresAt': expiresAt,
        'targetAge': targetAge,
        'targetGender': targetGender,
        'targetInterest': targetInterest,
        'targetPurchaseHistory': targetPurchaseHistory,
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl ?? [],
        'title': title,
        'description': description,
        'canRespond': canRespond,
        'canForward': canForward,
        'canRequestReward': canRequestReward,
        'canUse': canUse,
        'isCoupon': isCoupon, // 쿠폰 여부 추가
        'status': 'draft', // 기본적으로 초안 상태
        'placeId': placeId, // 플레이스 ID 추가
        'youtubeUrl': youtubeUrl, // 유튜브 URL 추가
        'isVerified': isVerified, // 인증 상태 추가
        'totalCollected': 0, // 총 수집 횟수 초기화
        'totalUsed': 0, // 총 사용 횟수 초기화
        'updatedAt': now,
      });

      // 문서 ID를 postId로 업데이트
      await docRef.update({'postId': docRef.id});

      debugPrint('✅ 포스트 템플릿 생성 완료: postId=${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 포스트 템플릿 생성 실패: $e');
      rethrow;
    }
  }

  // PostModel로부터 포스트 생성
  Future<String> createPostFromModel(PostModel post) async {
    return await createPost(
      creatorId: post.creatorId,
      creatorName: post.creatorName,
      reward: post.reward,
      targetAge: post.targetAge,
      targetGender: post.targetGender,
      targetInterest: post.targetInterest,
      targetPurchaseHistory: post.targetPurchaseHistory,
      mediaType: post.mediaType,
      mediaUrl: post.mediaUrl,
      thumbnailUrl: post.thumbnailUrl,
      title: post.title,
      description: post.description,
      canRespond: post.canRespond,
      canForward: post.canForward,
      canRequestReward: post.canRequestReward,
      canUse: post.canUse,
      defaultRadius: post.defaultRadius,
      defaultExpiresAt: post.defaultExpiresAt,
      placeId: post.placeId,
      isCoupon: post.isCoupon,
      youtubeUrl: post.youtubeUrl,
    );
  }

  // 슈퍼 포스트 생성
  Future<String> createSuperPost({
    required String creatorId,
    required String creatorName,
    required int reward,
    required List<int> targetAge,
    required String targetGender,
    required List<String> targetInterest,
    required List<String> targetPurchaseHistory,
    required List<String> mediaType,
    required List<String> mediaUrl,
    List<String>? thumbnailUrl,
    required String title,
    required String description,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    required bool canUse,
    int defaultRadius = 5000, // 슈퍼 포스트는 더 큰 반경
    DateTime? defaultExpiresAt,
    String? placeId,
    bool isCoupon = false,
    String? youtubeUrl,
  }) async {
    return await createPost(
      creatorId: creatorId,
      creatorName: creatorName,
      reward: reward,
      targetAge: targetAge,
      targetGender: targetGender,
      targetInterest: targetInterest,
      targetPurchaseHistory: targetPurchaseHistory,
      mediaType: mediaType,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      title: title,
      description: description,
      canRespond: canRespond,
      canForward: canForward,
      canRequestReward: canRequestReward,
      canUse: canUse,
      defaultRadius: defaultRadius,
      defaultExpiresAt: defaultExpiresAt,
      placeId: placeId,
      isCoupon: isCoupon,
      youtubeUrl: youtubeUrl,
    );
  }

  // 포스트 업데이트
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      debugPrint('📝 포스트 업데이트 시작: postId=$postId');
      
      // 업데이트 시간 추가
      updates['updatedAt'] = DateTime.now();
      
      await _firestore.collection('posts').doc(postId).update(updates);
      
      debugPrint('✅ 포스트 업데이트 완료: postId=$postId');
    } catch (e) {
      debugPrint('❌ 포스트 업데이트 실패: postId=$postId, error=$e');
      rethrow;
    }
  }

  // 포스트 ID로 조회
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ 포스트 조회 실패: postId=$postId, error=$e');
      return null;
    }
  }

  // 포스트 배포
  Future<void> distributePost(String postId) async {
    try {
      debugPrint('🚀 distributePost 시작: postId=$postId');
      
      await _firestore.collection('posts').doc(postId).update({
        'status': 'deployed',
        'deployedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ distributePost 완료: postId=$postId');
    } catch (e) {
      debugPrint('❌ distributePost 실패: postId=$postId, error=$e');
      rethrow;
    }
  }

  // 포스트 하드 삭제
  Future<void> deletePostHard(String postId) async {
    try {
      debugPrint('🗑️ deletePostHard 시작: postId=$postId');
      
      await _firestore.collection('posts').doc(postId).delete();
      
      debugPrint('✅ deletePostHard 완료: postId=$postId');
    } catch (e) {
      debugPrint('❌ deletePostHard 실패: postId=$postId, error=$e');
      rethrow;
    }
  }

  // Meilisearch 인덱싱
  Future<void> _indexToMeilisearch(PostModel post) async {
    try {
      // Meilisearch 인덱싱 로직 (구현 필요)
      debugPrint('🔍 Meilisearch 인덱싱: postId=${post.postId}');
    } catch (e) {
      debugPrint('❌ Meilisearch 인덱싱 실패: $e');
    }
  }

  // 위치 기반 포스트 조회
  Future<List<PostModel>> getPostsNearLocation({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    int limit = 50,
  }) async {
    try {
      debugPrint('📍 위치 기반 포스트 조회: lat=$latitude, lng=$longitude, radius=${radiusInKm}km');

      final center = GeoPoint(latitude, longitude);
      final posts = <PostModel>[];

      // 일반 포스트 조회
      final normalPosts = await _getPostsInRadius(center, radiusInKm, limit: limit ~/ 2);
      posts.addAll(normalPosts);

      // 슈퍼 포스트 조회
      final superPosts = await _getSuperPostsInRadius(center, radiusInKm, limit: limit ~/ 2);
      posts.addAll(superPosts);

      debugPrint('✅ 위치 기반 포스트 조회 완료: ${posts.length}개');
      return posts;
    } catch (e) {
      debugPrint('❌ 위치 기반 포스트 조회 실패: $e');
      return [];
    }
  }

  // 반경 내 포스트 조회
  Future<List<PostModel>> _getPostsInRadius(GeoPoint center, double radiusInKm, {int limit = 25}) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'deployed')
          .limit(limit)
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
      debugPrint('❌ 반경 내 포스트 조회 실패: $e');
      return [];
    }
  }

  // 슈퍼 포스트 조회
  Future<List<PostModel>> _getSuperPostsInRadius(GeoPoint center, double radiusInKm, {int limit = 25}) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('status', isEqualTo: 'deployed')
          .where('isVerified', isEqualTo: true)
          .limit(limit)
          .get();

      final posts = <PostModel>[];
      for (final doc in query.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          posts.add(post);
        } catch (e) {
          debugPrint('⚠️ 슈퍼 포스트 파싱 실패: ${doc.id} - $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('❌ 슈퍼 포스트 조회 실패: $e');
      return [];
    }
  }

  // 포스트 ID 생성
  String _generatePostId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    return 'post_${timestamp}_$random';
  }

  // Meilisearch로 포스트 검색
  Future<List<PostModel>> searchPostsWithMeilisearch({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔍 Meilisearch 포스트 검색: query="$query"');
      
      // Meilisearch 검색 로직 (구현 필요)
      return [];
    } catch (e) {
      debugPrint('❌ Meilisearch 검색 실패: $e');
      return [];
    }
  }

  // 포스트 사용
  Future<bool> usePost(String postId, String userId) async {
    try {
      debugPrint('🎯 포스트 사용: postId=$postId, userId=$userId');

      // 포스트 존재 확인
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      // 이미 사용했는지 확인
      final usageQuery = await _firestore
          .collection('post_usage')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (usageQuery.docs.isNotEmpty) {
        debugPrint('⚠️ 이미 사용한 포스트입니다.');
        return false;
      }

      // 사용 기록 추가
      await _firestore.collection('post_usage').add({
        'postId': postId,
        'userId': userId,
        'usedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 포스트 사용 횟수 증가
      await _firestore.collection('posts').doc(postId).update({
        'totalUsed': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 포스트 사용 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 사용 실패: $e');
      return false;
    }
  }

  // 사용자 포인트 조회
  Future<int> getUserPoints(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['points'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('❌ 사용자 포인트 조회 실패: $e');
      return 0;
    }
  }

  // 포스트 사용 이력 조회
  Future<List<Map<String, dynamic>>> getPostUsageHistory(String userId, {int limit = 50}) async {
    try {
      final query = await _firestore
          .collection('post_usage')
          .where('userId', isEqualTo: userId)
          .orderBy('usedAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ 포스트 사용 이력 조회 실패: $e');
      return [];
    }
  }

  // 포스트 사용 여부 확인
  Future<bool> isPostUsedByUser(String postId, String userId) async {
    try {
      final query = await _firestore
          .collection('post_usage')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('❌ 포스트 사용 여부 확인 실패: $e');
      return false;
    }
  }

  // 사용자 포인트 통계
  Future<Map<String, int>> getUserPointsStats(String userId) async {
    try {
      final points = await getUserPoints(userId);
      final usageHistory = await getPostUsageHistory(userId);
      
      int totalEarned = 0;
      int totalUsed = 0;
      
      for (final usage in usageHistory) {
        // 포인트 관련 로직 (구현 필요)
      }

      return {
        'current': points,
        'totalEarned': totalEarned,
        'totalUsed': totalUsed,
      };
    } catch (e) {
      debugPrint('❌ 사용자 포인트 통계 조회 실패: $e');
      return {'current': 0, 'totalEarned': 0, 'totalUsed': 0};
    }
  }

  // 상태별 포스트 조회
  Future<List<PostModel>> getPostsByStatus(String userId, PostStatus status) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
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
      debugPrint('❌ 상태별 포스트 조회 실패: $e');
      return [];
    }
  }

  // 초안 포스트 조회
  Future<List<PostModel>> getDraftPosts(String userId) async {
    return await getPostsByStatus(userId, PostStatus.DRAFT);
  }

  // 배포된 포스트 조회
  Future<List<PostModel>> getDeployedPosts(String userId) async {
    return await _deploymentService.getDeployedPosts(userId);
  }

  // 만료된 포스트 조회
  Future<List<PostModel>> getExpiredPosts(String userId) async {
    return await _deploymentService.getExpiredPosts(userId);
  }

  // 포스트 배포 (위임)
  Future<void> deployPost({
    required String postId,
    required int quantity,
    required List<Map<String, dynamic>> locations,
    required int radiusInMeters,
    required DateTime expiresAt,
  }) async {
    await _deploymentService.deployPost(
      postId: postId,
      quantity: quantity,
      locations: locations,
      radiusInMeters: radiusInMeters,
      expiresAt: expiresAt,
    );
  }

  // 포스트 상태 업데이트 (위임)
  Future<void> updatePostStatus(String postId, PostStatus status) async {
    await _deploymentService.updatePostStatus(postId, status);
  }

  // 포스트를 배포됨으로 표시 (위임)
  Future<void> markPostAsDeployed({
    required String postId,
    required int quantity,
    required List<Map<String, dynamic>> locations,
    required int radiusInMeters,
    required DateTime expiresAt,
  }) async {
    await _deploymentService.markPostAsDeployed(
      postId: postId,
      quantity: quantity,
      locations: locations,
      radiusInMeters: radiusInMeters,
      expiresAt: expiresAt,
    );
  }

  // 포스트를 만료됨으로 표시 (위임)
  Future<void> markPostAsExpired(String postId) async {
    await _deploymentService.markPostAsExpired(postId);
  }

  // 포스트를 삭제됨으로 표시 (위임)
  Future<void> markPostAsDeleted(String postId) async {
    await _deploymentService.markPostAsDeleted(postId);
  }

  // 포스트 회수 (위임)
  Future<void> recallPost(String postId) async {
    await _deploymentService.recallPost(postId);
  }

  // 포스트 수집 (위임)
  Future<void> collectPost({
    required String postId,
    required String userId,
  }) async {
    await _collectionService.collectPost(postId: postId, userId: userId);
  }

  // 포스트 수집 (크리에이터용) (위임)
  Future<void> collectPostAsCreator({
    required String postId,
    required String userId,
    required String markerId,
    required int quantity,
  }) async {
    await _collectionService.collectPostAsCreator(
      postId: postId,
      userId: userId,
      markerId: markerId,
      quantity: quantity,
    );
  }

  // 수집한 포스트 목록 조회 (위임)
  Future<List<PostModel>> getCollectedPosts(String userId) async {
    return await _collectionService.getCollectedPosts(userId);
  }

  // 수집한 포스트 사용 상태 조회 (위임)
  Future<Map<String, bool>> getCollectedPostUsageStatus(String userId) async {
    return await _collectionService.getCollectedPostUsageStatus(userId);
  }

  // 포스트 확인 처리 (위임)
  Future<void> confirmPost({
    required String postId,
    required String userId,
  }) async {
    await _collectionService.confirmPost(postId: postId, userId: userId);
  }

  // 미확인 포스트 개수 조회 (위임)
  Future<int> getUnconfirmedPostCount(String userId) async {
    return await _collectionService.getUnconfirmedPostCount(userId);
  }

  // 미확인 포스트 개수 스트림 (위임)
  Stream<int> getUnconfirmedPostCountStream(String userId) {
    return _collectionService.getUnconfirmedPostCountStream(userId);
  }

  // 미확인 포스트 목록 조회 (위임)
  Future<List<Map<String, dynamic>>> getUnconfirmedPosts(String userId) async {
    return await _collectionService.getUnconfirmedPosts(userId);
  }

  // 사용자 포스트 조회
  Future<List<PostModel>> getUserPosts(String userId, {int limit = 20, DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      final posts = <PostModel>[];

      for (final doc in querySnapshot.docs) {
        try {
          final post = PostModel.fromFirestore(doc);
          posts.add(post);
        } catch (e) {
          debugPrint('⚠️ 포스트 파싱 실패: ${doc.id} - $e');
        }
      }

      return posts;
    } catch (e) {
      debugPrint('❌ 사용자 포스트 조회 실패: $e');
      return [];
    }
  }

  // 사용자 모든 포스트 조회
  Future<List<PostModel>> getUserAllMyPosts(String userId, {int limitPerCollection = 100}) async {
    try {
      final query = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .limit(limitPerCollection)
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
      debugPrint('❌ 사용자 모든 포스트 조회 실패: $e');
      return [];
    }
  }

  // 배포된 포스트 조회 (사용자별)
  Future<List<PostModel>> getDistributedPosts(String userId) async {
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

  // 포스트 상세 조회
  Future<PostModel?> getPostDetail(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('❌ 포스트 상세 조회 실패: $e');
      return null;
    }
  }

  // 만료된 포스트 정리 (위임)
  Future<void> cleanupExpiredPosts() async {
    await _deploymentService.cleanupExpiredPosts();
  }
}