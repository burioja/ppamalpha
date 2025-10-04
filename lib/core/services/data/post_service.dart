import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/post/post_model.dart';
import '../../../features/map_system/services/fog_of_war/visit_tile_service.dart';
import '../../../utils/tile_utils.dart';
import 'post_search_service.dart';
import 'points_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PointsService _pointsService = PointsService();

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
  }) async {
    try {
      debugPrint('🚀 포스트 템플릿 생성 시작: title="$title", creator=$creatorId');

      final now = DateTime.now();
      final expiresAt = defaultExpiresAt ?? now.add(const Duration(days: 30));

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
      });

      final postId = docRef.id;

      // 🎯 생성된 포스트 ID 로깅
      debugPrint('✅ 포스트 템플릿 생성 완료!');
      debugPrint('📋 Post ID: $postId');
      debugPrint('📝 제목: $title');
      debugPrint('👤 생성자: $creatorName ($creatorId)');
      debugPrint('💰 리워드: ${reward}원');
      debugPrint('🎯 기본 반경: ${defaultRadius}m');
      debugPrint('⏰ 기본 만료일: $expiresAt');
      print('🆔 [POST_TEMPLATE_CREATED] ID: $postId | Title: $title');

      // 생성된 문서 ID를 postId 필드에 업데이트
      await docRef.update({'postId': postId});
      debugPrint('🔄 postId 필드 업데이트 완료: $postId');

      final post = PostModel(
        postId: postId,
        creatorId: creatorId,
        creatorName: creatorName,
        createdAt: now,
        reward: reward,
        defaultRadius: defaultRadius,
        defaultExpiresAt: expiresAt,
        targetAge: targetAge,
        targetGender: targetGender,
        targetInterest: targetInterest,
        targetPurchaseHistory: targetPurchaseHistory,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl ?? [],
        title: title,
        description: description,
        canRespond: canRespond,
        canForward: canForward,
        canRequestReward: canRequestReward,
        canUse: canUse,
      );

      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(post);
      debugPrint('🔍 Meilisearch 인덱싱 완료: $postId');

      // 최종 요약 로그
      print('🎉 [POST_TEMPLATE_SUCCESS] PostID: $postId | "$title" 생성 완료');

      return postId;
    } catch (e) {
      debugPrint('❌ 포스트 템플릿 생성 실패: $e');
      print('💥 [POST_TEMPLATE_FAILED] Error: $e');
      throw Exception('포스트 템플릿 생성 실패: $e');
    }
  }

  // 포스트 생성 (PostModel 사용)
  Future<String> createPostFromModel(PostModel post) async {
    try {
      // Firestore에 저장
      final docRef = await _firestore.collection('posts').add(post.toFirestore());
      
      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(post.copyWith(postId: docRef.id));
      
      return docRef.id;
    } catch (e) {
      throw Exception('포스트 생성 실패: $e');
    }
  }

  // 🚀 슈퍼포스트 생성 메서드
  Future<String> createSuperPost({
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
    return await createPost(
      creatorId: creatorId,
      creatorName: creatorName,
      defaultRadius: radius,
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
      defaultExpiresAt: expiresAt, // TODO: expiresAt -> defaultExpiresAt
      // TODO: isSuperPost 파라미터 제거됨, 필요시 다른 방식으로 구분
    );
  }

  // 포스트 업데이트
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      // postId 검증 강화
      if (postId.isEmpty || postId.trim().isEmpty) {
        throw Exception('포스트 ID가 비어있습니다. postId: "$postId"');
      }

      debugPrint('🔄 포스트 업데이트 시작:');
      debugPrint('📋 Post ID: $postId');
      debugPrint('📝 Updates: $updates');
      print('🔧 [POST_UPDATE_START] ID: $postId');

      // 문서 존재 여부 확인
      final docRef = _firestore.collection('posts').doc(postId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('❌ 포스트를 찾을 수 없음: $postId');
        print('💥 [POST_UPDATE_FAILED] ID: $postId | Reason: Post not found');
        throw Exception('포스트를 찾을 수 없습니다. postId: $postId');
      }

      // 기존 포스트 정보 로깅 (업데이트 전)
      final currentData = docSnapshot.data() as Map<String, dynamic>;
      debugPrint('📄 업데이트 전 포스트 제목: ${currentData['title']}');

      await docRef.update(updates);

      debugPrint('✅ 포스트 업데이트 완료!');
      debugPrint('📋 Post ID: $postId');
      debugPrint('🔄 업데이트된 필드: ${updates.keys.join(', ')}');
      print('🎉 [POST_UPDATE_SUCCESS] ID: $postId | Fields: ${updates.keys.join(', ')}');

      // Meilisearch 업데이트 (실제 구현 시)
      // await _updateMeilisearch(postId, updates);
      debugPrint('🔍 Meilisearch 업데이트 스킵 (미구현): $postId');
    } catch (e) {
      debugPrint('❌ 포스트 업데이트 실패: $e');
      print('💥 [POST_UPDATE_FAILED] ID: $postId | Error: $e');
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
      
      // 원본 Firestore 데이터 로깅
      final data = doc.data() as Map<String, dynamic>;
      debugPrint('=== Firestore에서 불러온 원본 데이터 ===');
      debugPrint('mediaType: ${data['mediaType']}');
      debugPrint('mediaUrl: ${data['mediaUrl']}');
      debugPrint('thumbnailUrl: ${data['thumbnailUrl']}');
      
      final post = PostModel.fromFirestore(doc);
      debugPrint('✅ PostModel 변환 완룼: targetAge=${post.targetAge}');
      debugPrint('파스링된 데이터:');
      debugPrint('  mediaType: ${post.mediaType}');
      debugPrint('  mediaUrl: ${post.mediaUrl}');
      debugPrint('  thumbnailUrl: ${post.thumbnailUrl}');
      
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

  // 포스트 삭제 (하드 삭제 - 기존 메서드)
  Future<void> deletePostHard(String postId) async {
    try {
      debugPrint('🗑️ PostService.deletePostHard 호출: $postId');
      
      await _firestore.collection('posts').doc(postId).delete();
      
      debugPrint('✅ 포스트 하드 삭제 완료: $postId');
      
      // Meilisearch에서도 삭제 (실제 구현 시)
      // await _deleteFromMeilisearch(postId);
    } catch (e) {
      debugPrint('❌ 포스트 하드 삭제 실패: $e');
      throw Exception('포스트 하드 삭제 실패: $e');
    }
  }


  // Meilisearch 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
  Future<void> _indexToMeilisearch(PostModel post) async {
    try {
      // TODO: Meilisearch 클라이언트 구현
      // await meilisearchClient.index('posts').addDocuments([post.toMeilisearch()]);
      debugPrint('Meilisearch 인덱싱: ${post.postId}');
    } catch (e) {
      debugPrint('Meilisearch 인덱싱 실패: $e');
    }
  }

  // 위치 기반 포스트 조회 (GeoFlutterFire 사용) - 기존 방식
  Future<List<PostModel>> getPostsNearLocation({
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

      List<PostModel> posts = [];
      for (var doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // 삭제된 포스트 제외
        if (post.status == PostStatus.DELETED) continue;
        
        // 거리 확인 (반경을 km로 변환)
        // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
        final distance = 0.0; // 임시: 위치 필터링 제거
        if (distance > radiusInKm * 1000) continue;
        
        // 2단계: 타겟 조건 필터링 (임시로 비활성화하여 모든 post 표시)
        // if (userAge != null && userGender != null && userInterests != null && userPurchaseHistory != null) {
        //   if (!post.matchesTargetConditions(
        //     userAge: userAge,
        //     userGender: userGender,
        //     userInterests: userInterests,
        //     userPurchaseHistory: userPurchaseHistory,
        //   )) continue;
        // }
        
        posts.add(post);
      }

      return posts;
    } catch (e) {
      throw Exception('포스트 조회 실패: $e');
    }
  }

  // 🚀 성능 최적화: 1km 타일 기반 포스트 조회
  Future<List<PostModel>> getPostsInFogLevel1({
    required GeoPoint location,
    required double radiusInKm,
    String? userGender,
    int? userAge,
    List<String>? userInterests,
    List<String>? userPurchaseHistory,
  }) async {
    try {
      // 1. 현재 위치 기준으로 포그레벨 1단계 타일들 계산
      final fogLevel1Tiles = await _getFogLevel1Tiles(location, radiusInKm);
      
      List<PostModel> posts = [];
      
      if (fogLevel1Tiles.isNotEmpty) {
        // 2. 포그레벨 1단계 타일에 있는 일반 포스트만 조회 (서버 사이드 필터링)
        final normalPostsQuery = await _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .where('isCollected', isEqualTo: false)
            .where('tileId', whereIn: fogLevel1Tiles) // 타일 ID로 필터링
            .where('reward', isLessThan: 1000) // 일반 포스트만 (1000원 미만)
            .get();

        for (var doc in normalPostsQuery.docs) {
          final post = PostModel.fromFirestore(doc);
          if (post.status != PostStatus.DELETED) {
            posts.add(post);
          }
        }
      }
      
      // 3. 슈퍼포스트 (1000원 이상)는 반경 내에서만 조회
      final superPostsQuery = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('reward', isGreaterThanOrEqualTo: 1000) // 슈퍼포스트만
          .get();

      for (var doc in superPostsQuery.docs) {
        final post = PostModel.fromFirestore(doc);
        if (post.status != PostStatus.DELETED) {
          // 거리 확인 (슈퍼포스트는 반경 내에서만)
          // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
          final distance = 0.0; // 임시: 위치 필터링 제거
          if (distance <= radiusInKm * 1000) {
            posts.add(post);
          }
        }
      }

      return posts;
    } catch (e) {
      throw Exception('포그레벨 1단계 포스트 조회 실패: $e');
    }
  }

  // 포그레벨 1단계 타일들 계산 (캐시 활용)
  Future<List<String>> _getFogLevel1Tiles(GeoPoint location, double radiusInKm) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      // 🚀 캐시된 FogLevel 1 타일 목록 사용
      return await VisitTileService.getFogLevel1TileIdsCached();
    } catch (e) {
      print('포그레벨 1단계 타일 계산 실패: $e');
      return [];
    }
  }

  // 🚀 슈퍼포스트 조회 (모든 영역에서 표시)
  Future<List<PostModel>> getSuperPostsInRadius({
    required GeoPoint location,
    required double radiusInKm,
  }) async {
    try {
      // 슈퍼포스트만 조회 (isSuperPost = true)
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('isSuperPost', isEqualTo: true)
          .get();

      List<PostModel> superPosts = [];
      for (var doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // 삭제된 포스트 제외
        if (post.status == PostStatus.DELETED) continue;
        
        // 거리 확인 (반경을 km로 변환)
        // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
        final distance = 0.0; // 임시: 위치 필터링 제거
        if (distance > radiusInKm * 1000) continue;
        
        superPosts.add(post);
      }

      return superPosts;
    } catch (e) {
      throw Exception('슈퍼포스트 조회 실패: $e');
    }
  }

  // 🚀 최적화된 실시간 포스트 스트림 (서버 사이드 필터링)
  Stream<List<PostModel>> getPostsInFogLevel1Stream({
    required GeoPoint location,
    required double radiusInKm,
  }) {
    // 새로운 서버 사이드 필터링 사용
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      try {
        final result = await PostSearchService.searchPosts(
          centerLat: location.latitude,
          centerLng: location.longitude,
          radiusKm: radiusInKm,
          fogLevel: 1, // 포그레벨 1만
          rewardType: 'all',
          limit: 100,
        );
        
        print('📊 서버 사이드 포스트 로드:');
        print('  - 총 포스트: ${result.posts.length}개');
        print('  - 총 카운트: ${result.totalCount}개');
        
        return result.posts;
      } catch (e) {
        print('❌ 서버 사이드 포스트 로드 실패: $e');
        return <PostModel>[];
      }
    });
  }
  
  // 일반 포스트 스트림 (FogLevel 1 타일만)
  Stream<List<PostModel>> _getNormalPostsStream(GeoPoint location, double radiusInKm) {
    return _getFogLevel1Tiles(location, radiusInKm).asStream().asyncExpand((fogTiles) {
      print('🔍 일반 포스트 쿼리:');
      print('  - FogLevel 1 타일 개수: ${fogTiles.length}개');
      print('  - 타일 목록: $fogTiles');
      
      if (fogTiles.isEmpty) {
        print('  - 타일이 비어있음, 현재 위치 주변에서 직접 조회');
        // 포그레벨 1 타일이 없으면 현재 위치 주변에서 직접 조회
        return _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true)
            .where('isCollected', isEqualTo: false)
            .where('reward', isLessThan: 1000) // 일반 포스트만
            .snapshots()
            .map((snapshot) {
          print('  - 직접 쿼리 결과: ${snapshot.docs.length}개 문서');
          
          final allPosts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
          
          // 거리 기반 필터링 (클라이언트 사이드)
          final filteredPosts = allPosts.where((post) {
            // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
            final distance = 0.0; // 임시: 위치 필터링 제거
            return distance <= radiusInKm;
          }).toList();
          
          print('  - 거리 필터링 후: ${filteredPosts.length}개');
          return filteredPosts;
        });
      }
      
      return _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('tileId', whereIn: fogTiles) // 🚀 서버에서 필터링
          .where('reward', isLessThan: 1000) // 일반 포스트만
          .snapshots()
          .map((snapshot) {
        print('  - Firebase 쿼리 결과: ${snapshot.docs.length}개 문서');
        
        final allPosts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        print('  - 파싱된 포스트: ${allPosts.length}개');
        
        // 만료 상태 상세 확인
        for (final post in allPosts) {
          final now = DateTime.now();
          final isExpired = now.isAfter(post.defaultExpiresAt);
          final timeDiff = post.defaultExpiresAt.difference(now).inMinutes;
          print('  - 포스트: ${post.title} - 만료: $isExpired (${timeDiff}분 남음)');
        }
        
        final posts = allPosts.where((post) => post.status != PostStatus.DELETED).toList();
        print('  - 만료 제외 후: ${posts.length}개 포스트');
        return posts;
      });
    });
  }
  
  // 슈퍼포스트 스트림 (거리 계산만)
  Stream<List<PostModel>> _getSuperPostsStream(GeoPoint location, double radiusInKm) {
    print('🔍 슈퍼포스트 쿼리:');
    print('  - 검색 위치: ${location.latitude}, ${location.longitude}');
    print('  - 검색 반경: ${radiusInKm}km');
    
    return _firestore
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .where('reward', isGreaterThanOrEqualTo: 1000) // 슈퍼포스트만
        .snapshots()
        .map((snapshot) {
      print('  - Firebase 쿼리 결과: ${snapshot.docs.length}개 문서');
      
      final allPosts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      print('  - 파싱된 슈퍼포스트: ${allPosts.length}개');
      
      // 만료 상태 상세 확인
      for (final post in allPosts) {
        final now = DateTime.now();
        final isExpired = now.isAfter(post.defaultExpiresAt);
        final timeDiff = post.defaultExpiresAt.difference(now).inMinutes;
        print('  - 슈퍼포스트: ${post.title} - 만료: $isExpired (${timeDiff}분 남음)');
      }
      
      final posts = allPosts
          .where((post) => post.status != PostStatus.DELETED) // 삭제된 포스트 제외
          .where((post) {
            // 거리 계산 (지정된 반경 이내)
            // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
            final distance = 0.0; // 임시: 위치 필터링 제거
            final isInRange = distance <= radiusInKm * 1000;
            if (isInRange) {
              print('  - 슈퍼포스트: ${post.title} (거리: ${(distance/1000).toStringAsFixed(2)}km)');
            }
            return isInRange;
          })
          .toList();
          
      print('  - 거리 필터링 후: ${posts.length}개 슈퍼포스트');
      return posts;
    });
  }

  // 🚀 실시간 슈퍼포스트 스트림
  Stream<List<PostModel>> getSuperPostsStream({
    required GeoPoint location,
    required double radiusInKm,
  }) {
    return _firestore
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .where('isSuperPost', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      List<PostModel> superPosts = [];
      for (var doc in snapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // 삭제된 포스트 제외
        if (post.status == PostStatus.DELETED) continue;
        
        // 거리 확인 (반경을 km로 변환)
        // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
        final distance = 0.0; // 임시: 위치 필터링 제거
        if (distance <= radiusInKm * 1000) {
          superPosts.add(post);
        }
      }

      return superPosts;
    });
  }

  // 🚀 모든 활성 포스트 조회 (포그레벨 필터링용)
  Future<List<PostModel>> getAllActivePosts({
    required GeoPoint location,
    required double radiusInKm,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();

      List<PostModel> posts = [];
      for (var doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // 삭제된 포스트 제외
        if (post.status == PostStatus.DELETED) continue;
        
        // 거리 확인 (반경을 km로 변환)
        // TODO: 거리 계산 제거됨 - Posts는 템플릿이므로 위치 없음
        final distance = 0.0; // 임시: 위치 필터링 제거
        if (distance <= radiusInKm * 1000) {
          posts.add(post);
        }
      }

      return posts;
    } catch (e) {
      throw Exception('모든 활성 포스트 조회 실패: $e');
    }
  }


  // 포스트 ID 생성 헬퍼 메서드
  String _generatePostId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    return 'post_${timestamp}_$random';
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
  Future<List<PostModel>> searchPostsWithMeilisearch({
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
      return await getPostsNearLocation(
        location: location,
        radiusInKm: radiusInKm,
      );
    } catch (e) {
      throw Exception('Meilisearch 검색 실패: $e');
    }
  }


  // 전단지 회수 (발행자만 가능)
  // 발행자가 자신의 포스트를 회수하는 메서드
  Future<void> collectPostAsCreator({
    required String postId,
    required String userId,
  }) async {
    try {
      // 발행자 확인
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }
      
      final post = PostModel.fromFirestore(postDoc);
      if (post.creatorId != userId) {
        throw Exception('발행자만 포스트를 회수할 수 있습니다.');
      }
      
      // 회수 처리
      await _firestore.collection('posts').doc(postId).update({
        'isCollected': true,
        'collectedBy': userId,
        'collectedAt': Timestamp.now(),
      });
      
      // Meilisearch에서 제거
      await _removeFromMeilisearch(postId);
      
    } catch (e) {
      debugPrint('포스트 회수 중 오류: $e');
      rethrow;
    }
  }

  // 일반 사용자가 다른 사용자의 포스트를 수령하는 메서드 (통합 수령 로직)
  Future<void> collectPost({
    required String postId,
    required String userId,
  }) async {
    try {
      debugPrint('🔄 collectPost 호출: postId=$postId, userId=$userId');

      // 1단계: markers 컬렉션에서 먼저 확인 (배포된 포스트는 마커에서 수령)
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (markersQuery.docs.isNotEmpty) {
        debugPrint('✅ markers 컬렉션에서 관련 마커 발견: $postId');
        final markerDoc = markersQuery.docs.first;
        await _collectFromMarkersCollection(markerDoc, userId, postId);
        return;
      }

      debugPrint('⚠️ markers 컬렉션에서 마커 없음, posts 컬렉션 확인 중: $postId');

      // 2단계: posts 컬렉션에서 포스트 확인 (DRAFT 상태 또는 배포되지 않은 포스트)
      final postDoc = await _firestore.collection('posts').doc(postId).get();

      if (postDoc.exists) {
        final post = PostModel.fromFirestore(postDoc);

        // DEPLOYED 상태인 포스트는 마커에서만 수령 가능
        if (post.status == PostStatus.DEPLOYED) {
          debugPrint('❌ DEPLOYED 상태 포스트는 마커에서만 수령 가능: $postId');
          throw Exception('이 포스트는 이미 배포되었습니다. 지도에서 마커를 통해 수령해주세요.');
        }

        // DRAFT 상태 포스트는 posts 컬렉션에서 수령 (테스트용)
        if (post.status == PostStatus.DRAFT) {
          debugPrint('⚠️ DRAFT 상태 포스트 수령 시도: $postId (테스트 모드)');
          await _collectFromPostsCollection(postDoc, userId);
          return;
        }

        // DELETED 상태 포스트는 수령 불가
        if (post.status == PostStatus.DELETED) {
          debugPrint('❌ DELETED 상태 포스트 수령 불가: $postId');
          throw Exception('삭제된 포스트는 수령할 수 없습니다.');
        }
      }

      // 3단계: 둘 다 없거나 수령할 수 없는 상태
      debugPrint('❌ 수령 가능한 포스트/마커를 찾을 수 없음: $postId');
      debugPrint('💡 가능한 원인:');
      debugPrint('  - 포스트가 완전히 삭제됨');
      debugPrint('  - 잘못된 포스트 ID');
      debugPrint('  - 마커의 수량이 모두 소진됨');
      debugPrint('  - 배포된 포스트인데 마커가 비활성화됨');

      throw Exception('포스트를 찾을 수 없습니다. (ID: $postId)\n\n💡 가능한 원인:\n- 포스트가 완전히 삭제됨\n- 잘못된 포스트 ID\n- 마커의 모든 수량이 소진됨\n- 배포된 포스트인데 마커가 비활성화됨\n\n🔧 해결 방법:\n1. 지도를 새로고침하여 최신 마커 상태 확인\n2. 포스트 목록 새로고침\n3. 마커가 여전히 표시되면 앱 재시작');
    } catch (e) {
      debugPrint('❌ collectPost 실패: $e');

      // 사용자 친화적인 에러 메시지 제공
      if (e.toString().contains('마커에서만 수령 가능') ||
          e.toString().contains('삭제된 포스트')) {
        rethrow; // 이미 친화적인 메시지이므로 그대로 전달
      }

      throw Exception('포스트 수령 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n\n오류 세부사항: ${e.toString()}');
    }
  }

  // posts 컬렉션에서 수령 처리 (기존 로직)
  Future<void> _collectFromPostsCollection(DocumentSnapshot postDoc, String userId) async {
    try {
      final post = PostModel.fromFirestore(postDoc);
      debugPrint('📝 posts 컬렉션 포스트 정보: ${post.title}, creatorId: ${post.creatorId}');
      // TODO: quantity 필드 제거됨, 마커에서 관리

      // TODO: 수량 확인은 이제 마커에서 수행
      // Posts는 템플릿이므로 quantity 필드가 없음
      // if (quantity <= 0) {
      //   throw Exception('수령 가능한 수량이 없습니다.');
      // }

      // 자신의 포스트는 수령할 수 없음
      if (post.creatorId == userId) {
        debugPrint('❌ 자신의 포스트는 수령할 수 없음: creatorId=${post.creatorId}, userId=$userId');
        throw Exception('자신의 포스트는 수령할 수 없습니다.');
      }

      debugPrint('✅ posts 컬렉션 수령 조건 확인 완료, 수령 처리 시작');

      // TODO: 수량 차감 처리는 이제 마커에서 수행
      // Posts는 템플릿이므로 quantity 필드가 없음
      await _firestore.collection('posts').doc(post.postId).update({
        // 'quantity': post.quantity - 1,
        'updatedAt': Timestamp.now(),
      });

      // 수령 기록을 별도 컬렉션에 저장
      await _firestore.collection('post_collections').add({
        'postId': post.postId,
        'userId': userId,
        'collectedAt': Timestamp.now(),
        'postTitle': post.title,
        'postCreatorId': post.creatorId,
      });

      debugPrint('✅ posts 컬렉션 포스트 수령 완료: ${post.postId}, 수령자: $userId');
      // TODO: quantity 필드 제거됨, 마커에서 관리

      // TODO: 수량 확인은 이제 마커에서 수행
      // if (post.quantity - 1 <= 0) {
      //   await _removeFromMeilisearch(post.postId);
      //   debugPrint('📤 수량 소진으로 Meilisearch에서 제거: ${post.postId}');
      // }
    } catch (e) {
      debugPrint('❌ posts 컬렉션 수령 실패: $e');
      rethrow;
    }
  }

  // markers 컬렉션에서 수령 처리 (새로운 로직)
  Future<void> _collectFromMarkersCollection(DocumentSnapshot markerDoc, String userId, String originalPostId) async {
    try {
      final markerData = markerDoc.data() as Map<String, dynamic>;
      final markerId = markerDoc.id;

      // 마커 데이터 검증
      if (markerData.isEmpty) {
        debugPrint('❌ 마커 데이터가 비어있음: markerId=$markerId');
        throw Exception('마커 데이터를 읽을 수 없습니다.');
      }

      final title = markerData['title'] ?? 'Unknown Title';
      final creatorId = markerData['creatorId'] ?? '';
      final isActive = markerData['isActive'] ?? false;
      final quantity = (markerData['quantity'] as num?)?.toInt() ?? 0;
      final remainingQuantity = (markerData['remainingQuantity'] as num?)?.toInt() ?? quantity;
      final collectedBy = List<String>.from(markerData['collectedBy'] ?? []);

      debugPrint('📝 markers 컬렉션 마커 정보:');
      debugPrint('  - 제목: $title');
      debugPrint('  - 생성자: $creatorId');
      debugPrint('  - 활성화: $isActive');
      debugPrint('  - 남은 수량: $remainingQuantity');
      debugPrint('  - 수령자 수: ${collectedBy.length}');

      // 마커가 비활성화된 경우
      if (!isActive) {
        debugPrint('❌ 비활성화된 마커: markerId=$markerId');
        throw Exception('이 마커는 더 이상 활성화되어 있지 않습니다.');
      }

      // 생성자 정보가 없는 경우
      if (creatorId.isEmpty) {
        debugPrint('❌ 마커 생성자 정보 없음: markerId=$markerId');
        throw Exception('마커 생성자 정보를 찾을 수 없습니다.');
      }

      // 이미 수령했는지 확인
      if (collectedBy.contains(userId)) {
        debugPrint('❌ 이미 수령한 마커: markerId=$markerId, userId=$userId');
        throw Exception('이미 수령한 포스트입니다.');
      }

      // 수량이 0인지 확인
      if (remainingQuantity <= 0) {
        debugPrint('❌ 마커 수령 가능한 수량이 없음: remainingQuantity=$remainingQuantity');
        throw Exception('수령 가능한 수량이 없습니다. 다른 사용자가 모두 수령했을 수 있습니다.');
      }

      // 자신의 마커는 수령할 수 없음
      if (creatorId == userId) {
        debugPrint('❌ 자신의 마커는 수령할 수 없음: creatorId=$creatorId, userId=$userId');
        throw Exception('자신의 포스트는 수령할 수 없습니다.');
      }

      debugPrint('✅ markers 컬렉션 수령 조건 확인 완료, 수령 처리 시작');

      // 트랜잭션으로 마커 수량 차감 및 수령자 추가
      await _firestore.runTransaction((transaction) async {
        final newRemainingQuantity = remainingQuantity - 1;
        final newCollectedQuantity = (markerData['collectedQuantity'] as num?)?.toInt() ?? 0;
        final totalQuantity = (markerData['totalQuantity'] as num?)?.toInt() ?? quantity;
        final newCollectionRate = totalQuantity > 0 ? (newCollectedQuantity + 1) / totalQuantity : 0.0;

        collectedBy.add(userId);

        final markerUpdate = {
          'remainingQuantity': newRemainingQuantity,
          'collectedQuantity': newCollectedQuantity + 1,
          'collectionRate': newCollectionRate,
          'collectedBy': collectedBy,
          'quantity': newRemainingQuantity, // 호환성 유지
        };

        if (newRemainingQuantity <= 0) {
          markerUpdate['isActive'] = false;
        }

        transaction.update(_firestore.collection('markers').doc(markerId), markerUpdate);
      });

      // 수령 기록을 별도 컬렉션에 저장
      await _firestore.collection('post_collections').add({
        'postId': originalPostId,
        'userId': userId,
        'collectedAt': Timestamp.now(),
        'postTitle': title,
        'postCreatorId': creatorId,
        'markerId': markerId, // 마커에서 수령했음을 표시
        'source': 'marker', // 수령 소스 표시
      });

      // 포인트 처리 (수집자에게 지급 + 생성자에서 차감)
      try {
        final reward = (markerData['reward'] as num?)?.toInt() ?? 0;
        debugPrint('🔍 포인트 처리 시도:');
        debugPrint('  - 마커 데이터에서 reward 값: ${markerData['reward']}');
        debugPrint('  - 파싱된 reward 값: $reward');
        debugPrint('  - 수집자 ID: $userId');
        debugPrint('  - 포스트 ID: $originalPostId');
        debugPrint('  - 생성자 ID: $creatorId');

        if (reward > 0) {
          // 1. 수집자에게 포인트 지급
          debugPrint('💰 수집자 포인트 지급 중...');
          await _pointsService.rewardPostCollection(
            userId,
            reward,
            originalPostId,
            creatorId,
          );
          debugPrint('✅ 수집자 포인트 지급 완료: $reward 포인트');

          // 2. 생성자에서 포인트 차감
          debugPrint('💳 생성자 포인트 차감 중...');
          final deductionResult = await _pointsService.deductPoints(
            creatorId,
            reward,
            '포스트 수집으로 인한 차감 (PostID: $originalPostId, 수집자: $userId)',
          );

          if (deductionResult != null) {
            debugPrint('✅ 생성자 포인트 차감 완료: $reward 포인트');
          } else {
            debugPrint('⚠️ 생성자 포인트 차감 실패 (수집은 완료됨)');
          }
        } else {
          debugPrint('⚠️ 포인트 보상이 0이거나 없음: $reward');
        }
      } catch (pointsError) {
        debugPrint('❌ 포인트 처리 실패 (수집은 완료됨): $pointsError');
        debugPrint('스택 트레이스: $pointsError');
      }

      debugPrint('✅ markers 컬렉션 포스트 수령 완료: markerId=$markerId, 수령자: $userId, 남은 수량: ${remainingQuantity - 1}');
    } catch (e) {
      debugPrint('❌ markers 컬렉션 수령 실패: $e');

      // 사용자 친화적인 에러 메시지 제공
      if (e.toString().contains('이미 수령한 포스트') ||
          e.toString().contains('수령 가능한 수량이 없습니다') ||
          e.toString().contains('자신의 포스트는 수령할 수 없습니다') ||
          e.toString().contains('마커는 더 이상 활성화') ||
          e.toString().contains('마커 데이터를 읽을 수 없습니다') ||
          e.toString().contains('마커 생성자 정보를 찾을 수 없습니다')) {
        rethrow; // 이미 친화적인 메시지이므로 그대로 전달
      }

      // 알 수 없는 오류의 경우 일반적인 메시지 제공
      throw Exception('마커에서 포스트 수령 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.\n\n오류 세부사항: ${e.toString()}');
    }
  }

  // Meilisearch에서 제거
  Future<void> _removeFromMeilisearch(String postId) async {
    try {
      // TODO: Meilisearch 클라이언트 구현
      // await meilisearchClient.index('posts').deleteDocument(postId);
      debugPrint('Meilisearch에서 제거: $postId');
    } catch (e) {
      debugPrint('Meilisearch 제거 실패: $e');
    }
  }

  // 사용자가 수령한 포스트 조회 (받은 포스트 탭용) - 새로운 수령 기록 시스템
  Future<List<PostModel>> getCollectedPosts(String userId) async {
    try {
      debugPrint('🔍 getCollectedPosts 호출: userId=$userId');
      
      // post_collections 컬렉션에서 수령 기록 조회
      // Firebase 인덱스 오류 방지를 위해 임시로 정렬 제거
      final collectionSnapshot = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .get();

      debugPrint('📊 수령 기록 조회 결과: ${collectionSnapshot.docs.length}개');

      // 메모리에서 정렬 수행
      final sortedDocs = collectionSnapshot.docs.toList();
      sortedDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aTime = aData['collectedAt'] as Timestamp?;
        final bTime = bData['collectedAt'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // 내림차순 정렬
      });

      final posts = <PostModel>[];

      // 각 수령 기록에 대해 원본 포스트 정보 조회
      for (final collectionDoc in sortedDocs) {
        try {
          final collectionData = collectionDoc.data();
          final postId = collectionData['postId'] as String;
          
          // 원본 포스트 조회
          final postDoc = await _firestore.collection('posts').doc(postId).get();
          if (postDoc.exists) {
            final post = PostModel.fromFirestore(postDoc);
            posts.add(post);
            debugPrint('📝 수령된 포스트: ${post.title} (${post.postId})');
          } else {
            debugPrint('⚠️ 수령한 포스트가 삭제됨: $postId');
          }
        } catch (e) {
          debugPrint('❌ 포스트 조회 실패: $e');
          continue;
        }
      }

      debugPrint('📊 최종 수령한 포스트: ${posts.length}개');
      return posts;
    } catch (e) {
      debugPrint('❌ getCollectedPosts 에러: $e');
      throw Exception('수령한 포스트 조회 실패: $e');
    }
  }

  // 수령한 포스트의 사용 상태 조회 (향후 확장용)
  Future<Map<String, bool>> getCollectedPostUsageStatus(String userId) async {
    try {
      final collectedPosts = await getCollectedPosts(userId);
      final Map<String, bool> usageStatus = {};
      
      for (final post in collectedPosts) {
        // TODO: 향후 PostClaim 모델 구현 시 실제 사용 상태 확인
        // 현재는 collectedAt이 있으면 수집된 것으로 간주
        // TODO: collectedAt 필드 제거됨, 쿼리에서 확인 필요
        usageStatus[post.postId] = false; // 임시: 쿼리에서 확인해야 함
      }
      
      return usageStatus;
    } catch (e) {
      throw Exception('수령한 포스트 사용 상태 조회 실패: $e');
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
        debugPrint('📝 Post: ${post.title} (${post.postId}) - 생성일: ${post.createdAt}');
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

  // 사용자가 배포한 활성 포스트 조회 (배포한 포스트 탭용)
  Future<List<PostModel>> getDistributedPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
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
            .collection('posts')
            .where('creatorId', isEqualTo: userId)
            .get();
        final items = fallbackSnapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.status != PostStatus.DELETED) // TODO: isActive 필드 제거됨, status로 대체
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // DESC
        return items;
      }
      rethrow;
    } catch (e) {
      throw Exception('배포한 포스트 조회 실패: $e');
    }
  }

  // 전단지 상세 정보 조회 (Lazy Load)
  Future<PostModel?> getPostDetail(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('전단지 상세 조회 실패: $e');
    }
  }



  // 만료된 포스트 정리 (배치 작업용)
  Future<void> cleanupExpiredPosts() async {
    try {
      final now = DateTime.now();
      final querySnapshot = await _firestore
          .collection('posts')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('만료된 포스트 정리 실패: $e');
    }
  }

  // ==================== 포스트 사용 관련 기능 ====================

  /// 포스트 사용 처리
  Future<bool> usePost(String postId, String userId) async {
    try {
      if (kDebugMode) {
        print('포스트 사용 시작: postId=$postId, userId=$userId');
      }

      // 포스트 정보 조회
      final postDoc = await _firestore.collection('flyers').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      final post = PostModel.fromFirestore(postDoc);

      // 사용 가능 여부 확인
      if (!post.canUse) {
        throw Exception('사용할 수 없는 포스트입니다.');
      }

      if (post.status == PostStatus.DELETED) {
        throw Exception('삭제된 포스트입니다.');
      }

      // 이미 사용했는지 확인
      final usageQuery = await _firestore
          .collection('post_usage')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .get();

      if (usageQuery.docs.isNotEmpty) {
        throw Exception('이미 사용한 포스트입니다.');
      }

      final now = DateTime.now();
      final batch = _firestore.batch();

      // 포스트 사용 기록 저장
      final usageRef = _firestore.collection('post_usage').doc();
      batch.set(usageRef, {
        'id': usageRef.id,
        'postId': postId,
        'userId': userId,
        'creatorId': post.creatorId,
        'title': post.title,
        'reward': post.reward,
        'usedAt': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
      });

      // 사용자 포인트 증가
      await _addUserPoints(userId, post.reward, batch);

      // 배치 실행
      await batch.commit();

      if (kDebugMode) {
        print('포스트 사용 완료: +${post.reward}포인트');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('포스트 사용 실패: $e');
      }
      throw Exception('포스트 사용 실패: $e');
    }
  }

  /// 사용자 포인트 증가 (내부 메서드)
  Future<void> _addUserPoints(String userId, int points, WriteBatch batch) async {
    final userPointsRef = _firestore.collection('user_points').doc(userId);
    final userPointsDoc = await userPointsRef.get();

    if (userPointsDoc.exists) {
      final currentPoints = userPointsDoc.data()?['totalPoints'] ?? 0;
      batch.update(userPointsRef, {
        'totalPoints': currentPoints + points,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      batch.set(userPointsRef, {
        'userId': userId,
        'totalPoints': points,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// 사용자 포인트 조회
  Future<int> getUserPoints(String userId) async {
    try {
      final doc = await _firestore.collection('user_points').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['totalPoints'] ?? 0;
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('포인트 조회 실패: $e');
      }
      return 0;
    }
  }

  /// 포스트 사용 이력 조회
  Future<List<Map<String, dynamic>>> getPostUsageHistory(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('post_usage')
          .where('userId', isEqualTo: userId)
          .orderBy('usedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('사용 이력 조회 실패: $e');
      }
      return [];
    }
  }

  /// 특정 포스트의 사용 여부 확인
  Future<bool> isPostUsedByUser(String postId, String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('post_usage')
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('포스트 사용 여부 확인 실패: $e');
      }
      return false;
    }
  }

  /// 사용자별 포인트 통계
  Future<Map<String, int>> getUserPointsStats(String userId) async {
    try {
      final usageSnapshot = await _firestore
          .collection('post_usage')
          .where('userId', isEqualTo: userId)
          .get();

      final totalEarned = usageSnapshot.docs.fold<int>(
        0,
        (sum, doc) => sum + (doc.data()['reward'] as int? ?? 0),
      );

      final totalUsed = usageSnapshot.docs.length;
      final currentPoints = await getUserPoints(userId);

      return {
        'totalEarned': totalEarned,
        'totalUsed': totalUsed,
        'currentPoints': currentPoints,
      };
    } catch (e) {
      if (kDebugMode) {
        print('포인트 통계 조회 실패: $e');
      }
      return {
        'totalEarned': 0,
        'totalUsed': 0,
        'currentPoints': 0,
      };
    }
  }

  // ==================== 새로운 포스트 상태 관리 기능 ====================

  /// 상태별 포스트 조회
  Future<List<PostModel>> getPostsByStatus(String userId, PostStatus status) async {
    try {
      debugPrint('🔍 getPostsByStatus 호출: userId=$userId, status=${status.value}');

      Query query = _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .where('status', isEqualTo: status.value)
          .orderBy('createdAt', descending: true);

      final querySnapshot = await query.get();

      debugPrint('📊 쿼리 결과: ${querySnapshot.docs.length}개 문서 조회됨');

      // 디버그: 각 문서의 status 값 출력
      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        debugPrint('  - postId: ${doc.id}, status in DB: "${data['status']}", title: ${data['title']}');
      }

      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      debugPrint('✅ 상태별 포스트 조회 완료: ${posts.length}개');
      return posts;
    } catch (e) {
      debugPrint('❌ getPostsByStatus 에러: $e');
      throw Exception('상태별 포스트 조회 실패: $e');
    }
  }

  /// 배포 대기 중인 포스트 조회 (DRAFT 상태)
  Future<List<PostModel>> getDraftPosts(String userId) async {
    return await getPostsByStatus(userId, PostStatus.DRAFT);
  }

  /// 배포된 포스트 조회 (DEPLOYED 상태)
  Future<List<PostModel>> getDeployedPosts(String userId) async {
    try {
      debugPrint('🔍 getDeployedPosts 호출: userId=$userId');

      // 먼저 모든 포스트를 조회해서 실제 status 값 확인
      final allPostsQuery = _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      final allSnapshot = await allPostsQuery.get();

      debugPrint('📊 사용자의 전체 포스트: ${allSnapshot.docs.length}개');

      // 모든 포스트의 status 값 출력
      final Map<String, int> statusCounts = {};
      for (var doc in allSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'null';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        debugPrint('  📄 postId: ${doc.id}, status: "$status", title: ${data['title']}');
      }

      debugPrint('📊 Status 분포:');
      statusCounts.forEach((status, count) {
        debugPrint('  - "$status": $count개');
      });

      // 배포된 포스트만 필터링 (대소문자 무관)
      final deployedPosts = allSnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString().toLowerCase();
        return status == 'deployed';
      }).toList();

      debugPrint('✅ 배포된 포스트 (필터링 후): ${deployedPosts.length}개');

      final posts = deployedPosts
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      return posts;
    } catch (e) {
      debugPrint('❌ getDeployedPosts 에러: $e');
      throw Exception('배포된 포스트 조회 실패: $e');
    }
  }

  /// 만료된 포스트 조회 (삭제됨 상태로 변경됨)
  Future<List<PostModel>> getExpiredPosts(String userId) async {
    return await getPostsByStatus(userId, PostStatus.DELETED);
  }

  /// 포스트 배포 (Map에서 호출)
  Future<void> deployPost(
    String postId, {
    required int quantity,
    required GeoPoint location,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('🚀 deployPost 시작: postId=$postId, quantity=$quantity');

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      final post = PostModel.fromFirestore(postDoc);

      // 배포 가능 여부 확인
      if (!post.canDeploy) {
        throw Exception('배포할 수 없는 포스트입니다. 현재 상태: ${post.status.name}');
      }

      final now = DateTime.now();
      final deployData = {
        'status': PostStatus.DEPLOYED.value,
        'deployQuantity': quantity,
        'deployLocation': location,
        'deployStartDate': Timestamp.fromDate(startDate ?? now),
        'deployEndDate': Timestamp.fromDate(endDate ?? post.defaultExpiresAt),
        'distributedAt': Timestamp.fromDate(now),
        'isDistributed': true,
        'totalDeployed': quantity,
        'updatedAt': Timestamp.fromDate(now),
      };

      await _firestore.collection('posts').doc(postId).update(deployData);

      debugPrint('✅ 포스트 배포 완료: $postId');
    } catch (e) {
      debugPrint('❌ deployPost 에러: $e');
      throw Exception('포스트 배포 실패: $e');
    }
  }

  /// 포스트 상태 업데이트
  Future<void> updatePostStatus(String postId, PostStatus status) async {
    try {
      final updateData = {
        'status': status.value,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      // 상태에 따른 추가 필드 업데이트
      switch (status) {
        case PostStatus.DELETED:
          updateData['isActive'] = false;
          break;
        default:
          break;
      }

      await _firestore.collection('posts').doc(postId).update(updateData);

      debugPrint('✅ 포스트 상태 업데이트 완료: $postId -> ${status.name}');
    } catch (e) {
      debugPrint('❌ updatePostStatus 에러: $e');
      throw Exception('포스트 상태 업데이트 실패: $e');
    }
  }

  /// 포스트를 배포됨 상태로 변경
  Future<void> markPostAsDeployed(
    String postId, {
    required int quantity,
    required GeoPoint location,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await deployPost(
      postId,
      quantity: quantity,
      location: location,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// 포스트를 만료됨 상태로 변경 (삭제됨 상태로 변경)
  Future<void> markPostAsExpired(String postId) async {
    await updatePostStatus(postId, PostStatus.DELETED);
  }

  /// 포스트를 삭제됨 상태로 변경
  Future<void> markPostAsDeleted(String postId) async {
    await updatePostStatus(postId, PostStatus.DELETED);
  }

  /// 만료된 포스트들 자동 상태 업데이트
  Future<void> updateExpiredPostsStatus() async {
    try {
      final now = DateTime.now();

      // 배포되어 만료되었지만 아직 삭제되지 않은 포스트들 조회
      final querySnapshot = await _firestore
          .collection('posts')
          .where('expiresAt', isLessThan: Timestamp.fromDate(now))
          .where('status', isEqualTo: 'deployed') // 배포된 포스트만 대상
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('⏰ 자동 만료 처리할 포스트가 없습니다.');
        return;
      }

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'status': PostStatus.DELETED.value,
          'isActive': false,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
      await batch.commit();

      debugPrint('✅ 만료된 포스트 자동 상태 업데이트 완료: ${querySnapshot.docs.length}개');
    } catch (e) {
      debugPrint('❌ updateExpiredPostsStatus 에러: $e');
      throw Exception('만료된 포스트 상태 업데이트 실패: $e');
    }
  }

  /// 포스트 수정 가능 여부 확인
  Future<bool> canEditPost(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return false;
      }

      final post = PostModel.fromFirestore(postDoc);

      // 작성자가 아니면 수정 불가
      if (post.creatorId != userId) {
        return false;
      }

      // DRAFT 상태에서만 수정 가능
      return post.canEdit;
    } catch (e) {
      debugPrint('❌ canEditPost 에러: $e');
      return false;
    }
  }

  /// 포스트 배포 가능 여부 확인
  Future<bool> canDeployPost(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return false;
      }

      final post = PostModel.fromFirestore(postDoc);

      // 작성자가 아니면 배포 불가
      if (post.creatorId != userId) {
        return false;
      }

      // 배포 가능 조건 확인
      return post.canDeploy;
    } catch (e) {
      debugPrint('❌ canDeployPost 에러: $e');
      return false;
    }
  }

  /// 포스트 삭제 (소프트 삭제)
  Future<void> deletePost(String postId) async {
    try {
      // 포스트 상태를 DELETED로 변경
      await _firestore.collection('posts').doc(postId).update({
        'status': 'DELETED',
        'deletedAt': FieldValue.serverTimestamp(),
      });

      // 관련된 마커들 숨김 처리
      final markers = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      // 배치 작업으로 모든 마커 업데이트
      final batch = _firestore.batch();
      for (var marker in markers.docs) {
        batch.update(marker.reference, {'visible': false});
      }
      await batch.commit();

      debugPrint('✅ 포스트 삭제 완료: $postId');
      debugPrint('📍 ${markers.docs.length}개 마커 숨김 처리');
    } catch (e) {
      debugPrint('❌ 포스트 삭제 실패: $e');
      throw Exception('포스트 삭제 중 오류가 발생했습니다');
    }
  }
}