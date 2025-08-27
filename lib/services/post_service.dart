import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 전단지 생성 (Firestore + Meilisearch)
  Future<String> createFlyer({
    required String creatorId,
    required String creatorName,
    required GeoPoint location,
    required int radius,
    required int reward,
    required List<int> targetAge,
    required String targetGender,
    required List<String> targetInterest,
    required List<String> targetPurchaseHistory,
    required List<String> mediaType,
    required List<String> mediaUrl,
    required String title,
    required String description,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    required bool canUse,
    required DateTime expiresAt,
  }) async {
    try {
      final flyer = PostModel(
        flyerId: '',
        creatorId: creatorId,
        creatorName: creatorName,
        location: location,
        radius: radius,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        reward: reward,
        targetAge: targetAge,
        targetGender: targetGender,
        targetInterest: targetInterest,
        targetPurchaseHistory: targetPurchaseHistory,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        title: title,
        description: description,
        canRespond: canRespond,
        canForward: canForward,
        canRequestReward: canRequestReward,
        canUse: canUse,
      );

      // Firestore에 저장
      final docRef = await _firestore.collection('posts').add(flyer.toFirestore());
      
      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(flyer.copyWith(flyerId: docRef.id));
      
      return docRef.id;
    } catch (e) {
      throw Exception('전단지 생성 실패: $e');
    }
  }

  // 포스트 생성 (PostModel 사용)
  Future<String> createPost(PostModel post) async {
    try {
      // Firestore에 저장
      final docRef = await _firestore.collection('posts').add(post.toFirestore());
      
      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(post.copyWith(flyerId: docRef.id));
      
      return docRef.id;
    } catch (e) {
      throw Exception('포스트 생성 실패: $e');
    }
  }

  // 포스트 업데이트
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      debugPrint('🔄 PostService.updatePost 호출:');
      debugPrint('  - postId: $postId');
      debugPrint('  - targetAge: ${updates['targetAge']}');
      debugPrint('  - targetGender: ${updates['targetGender']}');
      
      await _firestore.collection('posts').doc(postId).update(updates);
      
      debugPrint('✅ 포스트 업데이트 완료');
      
      // Meilisearch 업데이트 (실제 구현 시)
      // await _updateMeilisearch(postId, updates);
    } catch (e) {
      debugPrint('❌ 포스트 업데이트 실패: $e');
      throw Exception('포스트 업데이트 실패: $e');
    }
  }

  // 포스트 ID로 단일 포스트 조회
  Future<PostModel?> getPostById(String postId) async {
    try {
      debugPrint('🔍 PostService.getPostById 호출: $postId');
      
      final doc = await _firestore.collection('posts').doc(postId).get();
      
      if (!doc.exists) {
        debugPrint('❌ 포스트를 찾을 수 없음: $postId');
        return null;
      }
      
      final post = PostModel.fromFirestore(doc);
      debugPrint('✅ 포스트 조회 완료: targetAge=${post.targetAge}');
      
      return post;
    } catch (e) {
      debugPrint('❌ 포스트 조회 실패: $e');
      throw Exception('포스트 조회 실패: $e');
    }
  }

  // 포스트 배포 (한번 배포하면 수정 불가)
  Future<void> distributePost(String postId) async {
    try {
      final updates = <String, dynamic>{
        'isDistributed': true,
        'distributedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      };
      
      await _firestore.collection('posts').doc(postId).update(updates);
      
      // Meilisearch 업데이트 (실제 구현 시)
      // await _updateMeilisearch(postId, updates);
    } catch (e) {
      throw Exception('포스트 배포 실패: $e');
    }
  }

  // Meilisearch 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
  Future<void> _indexToMeilisearch(PostModel flyer) async {
    try {
      // TODO: Meilisearch 클라이언트 구현
      // await meilisearchClient.index('flyers').addDocuments([flyer.toMeilisearch()]);
      debugPrint('Meilisearch 인덱싱: ${flyer.flyerId}');
    } catch (e) {
      debugPrint('Meilisearch 인덱싱 실패: $e');
    }
  }

  // 위치 기반 전단지 조회 (GeoFlutterFire 사용)
  Future<List<PostModel>> getFlyersNearLocation({
    required GeoPoint location,
    required double radiusInKm,
    String? userGender,
    int? userAge,
    List<String>? userInterests,
    List<String>? userPurchaseHistory,
  }) async {
    try {
      // 1단계: 위치 기반 필터링 (GeoFlutterFire)
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();

      List<PostModel> flyers = [];
      for (var doc in querySnapshot.docs) {
        final flyer = PostModel.fromFirestore(doc);
        
        // 만료 확인
        if (flyer.isExpired()) continue;
        
        // 거리 확인 (반경을 km로 변환)
        final distance = _calculateDistance(
          location.latitude, location.longitude,
          flyer.location.latitude, flyer.location.longitude,
        );
        if (distance > radiusInKm * 1000) continue;
        
        // 2단계: 타겟 조건 필터링 (임시로 비활성화하여 모든 flyer 표시)
        // if (userAge != null && userGender != null && userInterests != null && userPurchaseHistory != null) {
        //   if (!flyer.matchesTargetConditions(
        //     userAge: userAge,
        //     userGender: userGender,
        //     userInterests: userInterests,
        //     userPurchaseHistory: userPurchaseHistory,
        //   )) continue;
        // }
        
        flyers.add(flyer);
      }

      return flyers;
    } catch (e) {
      throw Exception('전단지 조회 실패: $e');
    }
  }

  // 거리 계산 헬퍼 메서드
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(_degreesToRadians(lat1)) * math.sin(_degreesToRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Meilisearch를 통한 고급 필터링 (실제 구현 시)
  Future<List<PostModel>> searchFlyersWithMeilisearch({
    required GeoPoint location,
    required double radiusInKm,
    String? targetGender,
    List<int>? targetAge,
    List<String>? targetInterest,
    int? minReward,
    int? maxReward,
  }) async {
    try {
      // TODO: Meilisearch 검색 구현
      // final searchResult = await meilisearchClient.index('posts').search(
      //   '',
      //   filter: _buildMeilisearchFilter(
      //     location, radiusInKm, targetGender, targetAge, targetInterest, minReward, maxReward
      //   ),
      // );
      
      // 임시로 Firestore에서 조회
      return await getFlyersNearLocation(
        location: location,
        radiusInKm: radiusInKm,
      );
    } catch (e) {
      throw Exception('Meilisearch 검색 실패: $e');
    }
  }

  // 전단지 회수 (발행자만 가능)
  Future<void> collectFlyer({
    required String flyerId,
    required String userId,
  }) async {
    try {
      // 발행자 확인
      final flyerDoc = await _firestore.collection('posts').doc(flyerId).get();
      if (!flyerDoc.exists) {
        throw Exception('전단지를 찾을 수 없습니다.');
      }
      
      final flyer = PostModel.fromFirestore(flyerDoc);
      if (flyer.creatorId != userId) {
        throw Exception('발행자만 전단지를 회수할 수 있습니다.');
      }
      
      // 회수 처리
      await _firestore.collection('posts').doc(flyerId).update({
        'isCollected': true,
        'collectedBy': userId,
        'collectedAt': Timestamp.now(),
      });
      
      // Meilisearch에서 제거
      await _removeFromMeilisearch(flyerId);
    } catch (e) {
      throw Exception('전단지 회수 실패: $e');
    }
  }

  // Meilisearch에서 제거
  Future<void> _removeFromMeilisearch(String flyerId) async {
    try {
      // TODO: Meilisearch 클라이언트 구현
      // await meilisearchClient.index('posts').deleteDocument(flyerId);
      debugPrint('Meilisearch에서 제거: $flyerId');
    } catch (e) {
      debugPrint('Meilisearch 제거 실패: $e');
    }
  }

  // 사용자가 회수한 전단지 조회 (주운 포스트 탭용)
  Future<List<PostModel>> getCollectedFlyers(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('collectedBy', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      // 인덱스 빌드 전(failed-precondition) 임시 우회: 서버 정렬 없이 가져와 클라이언트에서 정렬
      if (e.code == 'failed-precondition') {
        final fallbackSnapshot = await _firestore
            .collection('posts')
            .where('collectedBy', isEqualTo: userId)
            .get();
        final items = fallbackSnapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .toList();
        items.sort((a, b) {
          final aTime = a.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.collectedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime); // DESC
        });
        return items;
      }
      rethrow;
    } catch (e) {
      throw Exception('주운 전단지 조회 실패: $e');
    }
  }

  // 주운 포스트의 사용 상태 조회 (향후 확장용)
  Future<Map<String, bool>> getCollectedPostUsageStatus(String userId) async {
    try {
      final collectedFlyers = await getCollectedFlyers(userId);
      final Map<String, bool> usageStatus = {};
      
      for (final flyer in collectedFlyers) {
        // TODO: 향후 PostClaim 모델 구현 시 실제 사용 상태 확인
        // 현재는 collectedAt이 있으면 수집된 것으로 간주
        usageStatus[flyer.flyerId] = flyer.collectedAt != null;
      }
      
      return usageStatus;
    } catch (e) {
      throw Exception('주운 포스트 사용 상태 조회 실패: $e');
    }
  }



  // 사용자가 생성한 포스트 조회 (posts 컬렉션)
  Future<List<PostModel>> getUserPosts(String userId, {int limit = 20, DocumentSnapshot? lastDocument}) async {
    try {
      debugPrint('🔍 getUserPosts 호출: userId = $userId, limit = $limit');

      Query query = _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final querySnapshot = await query.get();
      
      debugPrint('📊 getUserPosts 결과: ${querySnapshot.docs.length}개 문서');

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // 디버깅을 위한 로그
      for (final post in posts) {
        debugPrint('📝 Post: ${post.title} (${post.flyerId}) - 생성일: ${post.createdAt}');
      }

      return posts;
    } on FirebaseException catch (e) {
      debugPrint('⚠️ FirebaseException: ${e.code} - ${e.message}');
      if (e.code == 'failed-precondition') {
        debugPrint('🔄 폴백 처리: 인덱스 없이 조회 후 클라이언트 정렬');
        Query fallbackQuery = _firestore
            .collection('posts')
            .where('creatorId', isEqualTo: userId)
            .limit(limit);

        if (lastDocument != null) {
          fallbackQuery = fallbackQuery.startAfterDocument(lastDocument);
        }

        final fallbackSnapshot = await fallbackQuery.get();
        final items = fallbackSnapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      }
      rethrow;
    } catch (e) {
      debugPrint('❌ getUserPosts 에러: $e');
      throw Exception('사용자 포스트 조회 실패: $e');
    }
  }

  // 사용자가 생성한 모든 포스트 조회 (posts 컬렉션만 사용)
  Future<List<PostModel>> getUserAllMyPosts(String userId, {int limitPerCollection = 100}) async {
    try {
      final posts = await getUserPosts(userId, limit: limitPerCollection);
      return posts;
    } catch (e) {
      throw Exception('사용자 전체 포스트 조회 실패: $e');
    }
  }

  // 사용자가 배포한 활성 전단지 조회 (배포한 포스트 탭용)
  Future<List<PostModel>> getDistributedFlyers(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('flyers')
          .where('creatorId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // 인덱스가 없을 경우 클라이언트에서 필터링
        final fallbackSnapshot = await _firestore
            .collection('flyers')
            .where('creatorId', isEqualTo: userId)
            .get();
        final items = fallbackSnapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((flyer) => flyer.isActive) // 클라이언트에서 활성 상태 필터링
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // DESC
        return items;
      }
      rethrow;
    } catch (e) {
      throw Exception('배포한 전단지 조회 실패: $e');
    }
  }

  // 전단지 상세 정보 조회 (Lazy Load)
  Future<PostModel?> getFlyerDetail(String flyerId) async {
    try {
      final doc = await _firestore.collection('flyers').doc(flyerId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('전단지 상세 조회 실패: $e');
    }
  }

  // 전단지 ID로 조회 (MarkerItem 변환용)
  Future<PostModel?> getFlyerById(String flyerId) async {
    try {
      final doc = await _firestore.collection('flyers').doc(flyerId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('전단지 조회 실패: $e');
    }
  }

  // 만료된 전단지 정리 (배치 작업용)
  Future<void> cleanupExpiredFlyers() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('flyers')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('만료 전단지 정리 실패: $e');
    }
  }
} 