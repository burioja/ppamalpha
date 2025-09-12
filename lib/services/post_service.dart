import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/post_model.dart';
import 'visit_tile_service.dart';
import '../utils/tile_utils.dart';

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
      
      final flyer = PostModel(
        postId: '',
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

      // Firestore에 저장
      final docRef = await _firestore.collection('posts').add(flyer.toFirestore());
      final postId = docRef.id;
      
      // Meilisearch에 인덱싱 (실제 구현 시 Meilisearch 클라이언트 사용)
      await _indexToMeilisearch(flyer.copyWith(postId: postId));
      
      return postId;
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
    return await createFlyer(
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
  Future<void> _indexToMeilisearch(PostModel flyer) async {
    try {
      // TODO: Meilisearch 클라이언트 구현
      // await meilisearchClient.index('posts').addDocuments([flyer.toMeilisearch()]);
      debugPrint('Meilisearch 인덱싱: ${flyer.postId}');
    } catch (e) {
      debugPrint('Meilisearch 인덱싱 실패: $e');
    }
  }

  // 위치 기반 전단지 조회 (GeoFlutterFire 사용) - 기존 방식
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

  // 🚀 성능 최적화: 1km 타일 기반 포스트 조회
  Future<List<PostModel>> getFlyersInFogLevel1({
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
      
      List<PostModel> flyers = [];
      
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
          final flyer = PostModel.fromFirestore(doc);
          if (!flyer.isExpired()) {
            flyers.add(flyer);
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
        final flyer = PostModel.fromFirestore(doc);
        if (!flyer.isExpired()) {
          // 거리 확인 (슈퍼포스트는 반경 내에서만)
          final distance = _calculateDistance(
            location.latitude, location.longitude,
            flyer.location.latitude, flyer.location.longitude,
          );
          if (distance <= radiusInKm * 1000) {
            flyers.add(flyer);
          }
        }
      }

      return flyers;
    } catch (e) {
      throw Exception('포그레벨 1단계 전단지 조회 실패: $e');
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
  Stream<List<PostModel>> getFlyersInFogLevel1Stream({
    required GeoPoint location,
    required double radiusInKm,
  }) {
    return Rx.combineLatest2(
      // 1. 일반 포스트: FogLevel 1 타일에서만 조회
      _getNormalPostsStream(location, radiusInKm),
      // 2. 슈퍼포스트: 별도 쿼리로 조회
      _getSuperPostsStream(location, radiusInKm),
      (List<PostModel> normalPosts, List<PostModel> superPosts) {
        // 두 리스트 합치기
        final allPosts = [...normalPosts, ...superPosts];
        
        print('📊 최적화된 포스트 로드:');
        print('  - 일반 포스트: ${normalPosts.length}개');
        print('  - 슈퍼포스트: ${superPosts.length}개');
        print('  - 총 포스트: ${allPosts.length}개');
        
        return allPosts;
      },
    );
  }
  
  // 일반 포스트 스트림 (FogLevel 1 타일만)
  Stream<List<PostModel>> _getNormalPostsStream(GeoPoint location, double radiusInKm) {
    return _getFogLevel1Tiles(location, radiusInKm).asStream().asyncExpand((fogTiles) {
      print('🔍 일반 포스트 쿼리:');
      print('  - FogLevel 1 타일 개수: ${fogTiles.length}개');
      print('  - 타일 목록: $fogTiles');
      
      if (fogTiles.isEmpty) {
        print('  - 타일이 비어있음, 빈 리스트 반환');
        return Stream.value(<PostModel>[]);
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


  // 전단지 ID 생성 헬퍼 메서드
  String _generateFlyerId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(1000);
    return 'flyer_${timestamp}_$random';
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

  // 일반 사용자가 다른 사용자의 포스트를 수령하는 메서드
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
      debugPrint('📝 포스트 정보: ${post.title}, creatorId: ${post.creatorId}');
      
      // 이미 수령된 포스트인지 확인
      if (post.isCollected) {
        debugPrint('❌ 이미 수령된 포스트: $postId');
        throw Exception('이미 수령된 포스트입니다.');
      }
      
      // 자신의 포스트는 수령할 수 없음
      if (post.creatorId == userId) {
        debugPrint('❌ 자신의 포스트는 수령할 수 없음: creatorId=${post.creatorId}, userId=$userId');
        throw Exception('자신의 포스트는 수령할 수 없습니다.');
      }
      
      debugPrint('✅ 수령 조건 확인 완료, 수령 처리 시작');
      
      // 수령 처리
      await _firestore.collection('posts').doc(postId).update({
        'isCollected': true,
        'collectedBy': userId,
        'collectedAt': Timestamp.now(),
      });
      
      debugPrint('✅ 포스트 수령 완료: $postId, 수령자: $userId');
      
      // Meilisearch에서 제거
      await _removeFromMeilisearch(postId);
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

  // 사용자가 수령한 포스트 조회 (받은 포스트 탭용)
  Future<List<PostModel>> getCollectedPosts(String userId) async {
    try {
      debugPrint('🔍 getCollectedPosts 호출: userId=$userId');
      
      final querySnapshot = await _firestore
          .collection('posts')
          .where('collectedBy', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      debugPrint('📊 수령된 포스트 조회 결과: ${querySnapshot.docs.length}개');
      
      final posts = querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
          
      for (final post in posts) {
        debugPrint('📝 수령된 포스트: ${post.title} (${post.postId}) - 수령일: ${post.collectedAt}');
      }

      return posts;
    } on FirebaseException catch (e) {
      debugPrint('⚠️ FirebaseException: ${e.code} - ${e.message}');
      // 인덱스 빌드 전(failed-precondition) 임시 우회: 서버 정렬 없이 가져와 클라이언트에서 정렬
      if (e.code == 'failed-precondition') {
        debugPrint('🔄 폴백 처리: 인덱스 없이 조회 후 클라이언트 정렬');
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
        
        debugPrint('📊 폴백 처리 결과: ${items.length}개');
        return items;
      }
      rethrow;
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
  Future<List<PostModel>> getDistributedFlyers(String userId) async {
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
  Future<void> cleanupExpiredFlyers() async {
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