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

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 포스트 생성 (Firestore + Meilisearch)
  Future<String> createPost({
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
    List<String>? thumbnailUrl,
    required String title,
    required String description,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    required bool canUse,
    required DateTime expiresAt,
    bool isSuperPost = false, // 슈퍼포스트 여부
  }) async {
    try {
      // 타일 ID 자동 계산
      final tileId = TileUtils.getTileId(location.latitude, location.longitude);
      
      // Firestore에 먼저 저장하여 문서 ID 생성
      final docRef = await _firestore.collection('posts').add({
        'postId': '', // 임시로 빈 문자열, 문서 ID 생성 후 업데이트
        'creatorId': creatorId,
        'creatorName': creatorName,
        'location': location,
        'radius': radius,
        'createdAt': DateTime.now(),
        'expiresAt': expiresAt,
        'reward': reward,
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
        'tileId': tileId, // 타일 ID 자동 설정
        'isSuperPost': isSuperPost, // 슈퍼포스트 여부
        'isActive': true,
        'isCollected': false,
        'collectedBy': null,
        'collectedAt': null,
      });
      
      final postId = docRef.id;
      
      // 생성된 문서 ID를 postId 필드에 업데이트
      await docRef.update({'postId': postId});
      
      // S2 타일 ID 자동 설정
      await PostSearchService.updatePostS2Tiles(postId);
      
      final post = PostModel(
        postId: postId,
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
        thumbnailUrl: thumbnailUrl ?? [],
        title: title,
        description: description,
        canRespond: canRespond,
        canForward: canForward,
        canRequestReward: canRequestReward,
        canUse: canUse,
        tileId: tileId, // 타일 ID 자동 설정
        isSuperPost: isSuperPost, // 슈퍼포스트 여부
      );

      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(post);
      
      return postId;
    } catch (e) {
      throw Exception('포스트 생성 실패: $e');
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
      location: location,
      radius: radius,
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
      expiresAt: expiresAt,
      isSuperPost: true, // 슈퍼포스트로 생성
    );
  }

  // 포스트 업데이트
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      // postId 검증 강화
      if (postId.isEmpty || postId.trim().isEmpty) {
        throw Exception('포스트 ID가 비어있습니다. postId: "$postId"');
      }
      
      debugPrint('🔄 PostService.updatePost 호출:');
      debugPrint('  - postId: $postId');
      debugPrint('  - updates: $updates');
      
      // 문서 존재 여부 확인
      final docRef = _firestore.collection('posts').doc(postId);
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        throw Exception('포스트를 찾을 수 없습니다. postId: $postId');
      }
      
      await docRef.update(updates);
      
      debugPrint('✅ 포스트 업데이트 완료: $postId');
      
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

  // 포스트 삭제
  Future<void> deletePost(String postId) async {
    try {
      debugPrint('🗑️ PostService.deletePost 호출: $postId');
      
      await _firestore.collection('posts').doc(postId).delete();
      
      debugPrint('✅ 포스트 삭제 완료: $postId');
      
      // Meilisearch에서도 삭제 (실제 구현 시)
      // await _deleteFromMeilisearch(postId);
    } catch (e) {
      debugPrint('❌ 포스트 삭제 실패: $e');
      throw Exception('포스트 삭제 실패: $e');
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
        
        // 만료 확인
        if (post.isExpired()) continue;
        
        // 거리 확인 (반경을 km로 변환)
        final distance = _calculateDistance(
          location.latitude, location.longitude,
          post.location.latitude, post.location.longitude,
        );
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
          if (!post.isExpired()) {
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
        if (!post.isExpired()) {
          // 거리 확인 (슈퍼포스트는 반경 내에서만)
          final distance = _calculateDistance(
            location.latitude, location.longitude,
            post.location.latitude, post.location.longitude,
          );
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
      return await VisitTileService.getFogLevel1TileIdsCached(user.uid);
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
        
        // 만료 확인
        if (post.isExpired()) continue;
        
        // 거리 확인 (반경을 km로 변환)
        final distance = _calculateDistance(
          location.latitude, location.longitude,
          post.location.latitude, post.location.longitude,
        );
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
            final distance = _calculateDistance(
              location.latitude, location.longitude,
              post.location.latitude, post.location.longitude,
            );
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
          final isExpired = now.isAfter(post.expiresAt);
          final timeDiff = post.expiresAt.difference(now).inMinutes;
          print('  - 포스트: ${post.title} - 만료: $isExpired (${timeDiff}분 남음)');
        }
        
        final posts = allPosts.where((post) => !post.isExpired()).toList();
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
        final isExpired = now.isAfter(post.expiresAt);
        final timeDiff = post.expiresAt.difference(now).inMinutes;
        print('  - 슈퍼포스트: ${post.title} - 만료: $isExpired (${timeDiff}분 남음)');
      }
      
      final posts = allPosts
          .where((post) => !post.isExpired()) // 만료 확인
          .where((post) {
            // 거리 계산 (지정된 반경 이내)
            final distance = _calculateDistance(
              location.latitude, location.longitude,
              post.location.latitude, post.location.longitude,
            );
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
        
        // 만료 확인
        if (post.isExpired()) continue;
        
        // 거리 확인 (반경을 km로 변환)
        final distance = _calculateDistance(
          location.latitude, location.longitude,
          post.location.latitude, post.location.longitude,
        );
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
        
        // 만료 확인
        if (post.isExpired()) continue;
        
        // 거리 확인 (반경을 km로 변환)
        final distance = _calculateDistance(
          location.latitude, location.longitude,
          post.location.latitude, post.location.longitude,
        );
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

  // 일반 사용자가 다른 사용자의 포스트를 수령하는 메서드 (수량 차감 방식)
  Future<void> collectPost({
    required String postId,
    required String userId,
  }) async {
    try {
      debugPrint('🔄 collectPost 호출: postId=$postId, userId=$userId');
      
      // 포스트 존재 확인
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        debugPrint('❌ 포스트를 찾을 수 없음: $postId');
        throw Exception('포스트를 찾을 수 없습니다.');
      }
      
      final post = PostModel.fromFirestore(postDoc);
      debugPrint('📝 포스트 정보: ${post.title}, creatorId: ${post.creatorId}, quantity: ${post.quantity}');
      
      // 수량이 0인지 확인
      if (post.quantity <= 0) {
        debugPrint('❌ 수령 가능한 수량이 없음: quantity=${post.quantity}');
        throw Exception('수령 가능한 수량이 없습니다.');
      }
      
      // 자신의 포스트는 수령할 수 없음
      if (post.creatorId == userId) {
        debugPrint('❌ 자신의 포스트는 수령할 수 없음: creatorId=${post.creatorId}, userId=$userId');
        throw Exception('자신의 포스트는 수령할 수 없습니다.');
      }
      
      debugPrint('✅ 수령 조건 확인 완료, 수령 처리 시작');
      
      // 수량 차감 처리
      await _firestore.collection('posts').doc(postId).update({
        'quantity': post.quantity - 1,
        'updatedAt': Timestamp.now(),
      });
      
      // 수령 기록을 별도 컬렉션에 저장
      await _firestore.collection('post_collections').add({
        'postId': postId,
        'userId': userId,
        'collectedAt': Timestamp.now(),
        'postTitle': post.title,
        'postCreatorId': post.creatorId,
      });
      
      debugPrint('✅ 포스트 수령 완료: $postId, 수령자: $userId, 남은 수량: ${post.quantity - 1}');
      
      // 수량이 0이 되면 Meilisearch에서 제거
      if (post.quantity - 1 <= 0) {
        await _removeFromMeilisearch(postId);
        debugPrint('📤 수량 소진으로 Meilisearch에서 제거: $postId');
      }
    } catch (e) {
      debugPrint('❌ collectPost 실패: $e');
      throw Exception('포스트 수령 실패: $e');
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
      final collectionSnapshot = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      debugPrint('📊 수령 기록 조회 결과: ${collectionSnapshot.docs.length}개');
      
      final posts = <PostModel>[];
      
      // 각 수령 기록에 대해 원본 포스트 정보 조회
      for (final collectionDoc in collectionSnapshot.docs) {
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
        usageStatus[post.postId] = post.collectedAt != null;
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
            .where((post) => post.isActive) // 클라이언트에서 활성 상태 필터링
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

      if (post.isExpired()) {
        throw Exception('만료된 포스트입니다.');
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
} 