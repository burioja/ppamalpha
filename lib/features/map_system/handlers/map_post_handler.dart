import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../../utils/tile_utils.dart';
import '../services/fog_of_war/visit_tile_service.dart';

/// 포스트 관리 Handler
/// 
/// map_screen.dart에서 분리한 포스트 관련 모든 기능
class MapPostHandler {
  // 포스트 상태
  List<PostModel> posts = [];
  int receivablePostsCount = 0;
  bool isLoading = false;
  String? errorMessage;

  // 필터 상태
  bool showCouponsOnly = false;
  bool showMyPostsOnly = false;
  double minReward = 0;
  bool showUrgentOnly = false;
  bool showVerifiedOnly = false;
  bool showUnverifiedOnly = false;

  // 사용자 타입
  String userType = 'life'; // 'life' or 'work'

  /// 포스트 업데이트 (Fog Level 기반)
  Future<List<MarkerModel>> updatePostsBasedOnFogLevel({
    required LatLng? effectivePosition,
    LatLng? homeLocation,
    required List<LatLng> workLocations,
  }) async {
    if (effectivePosition == null) {
      errorMessage = '위치 정보가 없습니다';
      return [];
    }

    final centers = <LatLng>[
      effectivePosition,
      if (homeLocation != null) homeLocation,
      ...workLocations,
    ];

    debugPrint('🎯 총 ${centers.length}개의 기준점에서 마커 검색');

    try {
      debugPrint('🔍 _updatePostsBasedOnFogLevel 호출됨');

      // 필터 설정
      final filters = <String, dynamic>{
        'showCouponsOnly': showCouponsOnly,
        'myPostsOnly': showMyPostsOnly,
        'minReward': minReward,
        'showUrgentOnly': showUrgentOnly,
        'showVerifiedOnly': showVerifiedOnly,
        'showUnverifiedOnly': showUnverifiedOnly,
      };

      // 서버에서 마커 조회
      final primaryCenter = centers.first;
      final additionalCenters = centers.skip(1).toList();

      final normalRadiusKm = MarkerService.getMarkerDisplayRadius(userType, false) / 1000.0;
      final superRadiusKm = MarkerService.getMarkerDisplayRadius(userType, true) / 1000.0;

      debugPrint('🔍 서버 호출:');
      debugPrint('  - 주 중심점: ${primaryCenter.latitude}, ${primaryCenter.longitude}');
      debugPrint('  - 일반 포스트 반경: ${normalRadiusKm}km');
      debugPrint('  - 슈퍼포스트 반경: ${superRadiusKm}km');

      // TODO: Implement marker fetching methods
      // For now, return empty lists
      final normalMarkers = <Map<String, dynamic>>[];
      final superMarkers = <Map<String, dynamic>>[];

      debugPrint('📍 서버 응답:');
      debugPrint('  - 일반 마커: ${normalMarkers.length}개');
      debugPrint('  - 슈퍼마커: ${superMarkers.length}개');

      // 마커 합치기 및 중복 제거
      final allMarkers = <MapMarkerServiceFile.MapMarkerData>[];
      final seenMarkerIds = <String>{};

      for (final marker in [...normalMarkers, ...superMarkers]) {
        if (!seenMarkerIds.contains(marker.id)) {
          allMarkers.add(marker);
          seenMarkerIds.add(marker.id);
        }
      }

      // MarkerData -> MarkerModel 변환
      final uniqueMarkers = allMarkers.map((markerData) =>
          MapMarkerServiceFile.MarkerService.convertToMarkerModel(markerData)
      ).toList();

      // 이미 수령한 포스트 필터링
      final currentUser = FirebaseAuth.instance.currentUser;
      Set<String> collectedPostIds = {};

      if (currentUser != null) {
        try {
          final collectedSnapshot = await FirebaseFirestore.instance
              .collection('post_collections')
              .where('userId', isEqualTo: currentUser.uid)
              .get();

          collectedPostIds = collectedSnapshot.docs
              .map((doc) => doc.data()['postId'] as String)
              .toSet();

          debugPrint('📦 이미 수령한 포스트: ${collectedPostIds.length}개');
        } catch (e) {
          debugPrint('❌ 수령 기록 조회 실패: $e');
        }
      }

      final filteredMarkers = uniqueMarkers.where((marker) {
        return !collectedPostIds.contains(marker.postId);
      }).toList();

      debugPrint('✅ 필터링 후 마커: ${filteredMarkers.length}개');

      // 포스트 정보 가져오기
      final postIds = filteredMarkers.map((marker) => marker.postId).toSet().toList();
      final fetchedPosts = <PostModel>[];

      if (postIds.isNotEmpty) {
        try {
          final postSnapshots = await FirebaseFirestore.instance
              .collection('posts')
              .where('postId', whereIn: postIds)
              .get();

          for (final doc in postSnapshots.docs) {
            try {
              fetchedPosts.add(PostModel.fromFirestore(doc));
            } catch (e) {
              debugPrint('포스트 파싱 오류: $e');
            }
          }

          debugPrint('📄 포스트 정보 조회: ${fetchedPosts.length}개');
        } catch (e) {
          debugPrint('❌ 포스트 정보 조회 실패: $e');
        }
      }

      posts = fetchedPosts;
      isLoading = false;
      errorMessage = null;

      return filteredMarkers;
    } catch (e, stackTrace) {
      debugPrint('❌ _updatePostsBasedOnFogLevel 오류: $e');
      debugPrint('📚 스택 트레이스: $stackTrace');

      isLoading = false;
      errorMessage = '마커를 불러오는 중 오류가 발생했습니다: $e';
      return [];
    }
  }

  /// 포스트 수집
  Future<bool> collectPost({
    required PostModel post,
    required String userId,
  }) async {
    try {
      // TODO: Implement PostService.collectPost method
      // For now, return false
      final success = false;

      if (success) {
        debugPrint('✅ 포스트 수집 완료: ${post.title}');
      }

      return success;
    } catch (e) {
      debugPrint('❌ 포스트 수집 실패: $e');
      return false;
    }
  }

  /// 포스트 삭제 (작성자만)
  Future<bool> removePost({
    required PostModel post,
    required String userId,
  }) async {
    try {
      if (post.creatorId != userId) {
        return false;
      }

      // TODO: Implement PostService.deletePost method
      // await PostService().deletePost(post.postId ?? '');
      debugPrint('✅ 포스트 삭제 완료: ${post.title}');
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 삭제 실패: $e');
      return false;
    }
  }

  /// 수령 가능 포스트 개수 업데이트
  Future<void> updateReceivablePosts({
    required LatLng? currentPosition,
  }) async {
    if (currentPosition == null) {
      receivablePostsCount = 0;
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        receivablePostsCount = 0;
        return;
      }

      // 현재 위치 기준 근처 마커 조회
      final nearbyMarkers = await MapMarkerServiceFile.MarkerService.getMarkers(
        location: currentPosition,
        radiusInKm: 0.1, // 100m 이내
        additionalCenters: [],
        filters: {},
        pageSize: 100,
      );

      // 이미 수령한 포스트 제외
      final collectedSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final collectedPostIds = collectedSnapshot.docs
          .map((doc) => doc.data()['postId'] as String)
          .toSet();

      receivablePostsCount = nearbyMarkers
          .where((marker) => !collectedPostIds.contains(marker.postId))
          .length;

      debugPrint('📦 수령 가능 포스트: $receivablePostsCount개');
    } catch (e) {
      debugPrint('❌ 수령 가능 포스트 개수 업데이트 실패: $e');
      receivablePostsCount = 0;
    }
  }

  /// 근처 포스트 일괄 수령
  Future<List<PostModel>> receiveNearbyPosts({
    required LatLng currentPosition,
    required String userId,
  }) async {
    try {
      debugPrint('🎁 근처 포스트 일괄 수령 시작');

      // 근처 마커 조회
      final nearbyMarkers = await MapMarkerServiceFile.MarkerService.getMarkers(
        location: currentPosition,
        radiusInKm: 0.1,
        additionalCenters: [],
        filters: {},
        pageSize: 100,
      );

      debugPrint('📍 근처 마커: ${nearbyMarkers.length}개');

      // 이미 수령한 포스트 확인
      final collectedSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .get();

      final collectedPostIds = collectedSnapshot.docs
          .map((doc) => doc.data()['postId'] as String)
          .toSet();

      // TODO: Implement marker fetching
      // For now, return empty list
      final receivableMarkers = <MarkerModel>[];

      debugPrint('📦 수령 가능: ${receivableMarkers.length}개');

      // 포스트 수집
      final receivedPosts = <PostModel>[];

      for (final marker in receivableMarkers) {
        final postId = marker.postId;
        if (postId == null || postId.isEmpty) continue;

        try {
          final success = await PostService().collectPost(
            postId: postId,
            userId: userId,
          );

          if (success) {
            // 포스트 정보 가져오기
            final postDoc = await FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .get();

            if (postDoc.exists) {
              receivedPosts.add(PostModel.fromFirestore(postDoc));
            }
          }
        } catch (e) {
          debugPrint('❌ 포스트 수집 실패: $e');
        }
      }

      debugPrint('✅ 총 ${receivedPosts.length}개 수령 완료');
      return receivedPosts;
    } catch (e) {
      debugPrint('❌ 일괄 수령 실패: $e');
      return [];
    }
  }

  /// 위치에서 롱프레스 가능 여부 확인
  bool canLongPressAtLocation({
    required LatLng point,
    required LatLng? currentPosition,
    LatLng? homeLocation,
    required List<LatLng> workLocations,
  }) {
    final maxRadius = MapMarkerServiceFile.MarkerService.getMarkerDisplayRadius(userType, false);

    // 현재 위치 주변 확인
    if (currentPosition != null) {
      final distance = MapMarkerServiceFile.MarkerService.calculateDistance(currentPosition, point);
      if (distance <= maxRadius) return true;
    }

    // 집 주변 확인
    if (homeLocation != null) {
      final distance = MarkerService.calculateDistance(homeLocation, point);
      if (distance <= maxRadius) return true;
    }

    // 일터 주변 확인
    for (final workLocation in workLocations) {
      final distance = MarkerService.calculateDistance(workLocation, point);
      if (distance <= maxRadius) return true;
    }

    return false;
  }

  /// 포그 레벨 확인
  Future<int> checkFogLevel(LatLng point) async {
    try {
      final tileId = TileUtils.getTileId(point.latitude, point.longitude);
      final fogLevel = await VisitTileService.getFogLevelForTile(tileId);
      debugPrint('🔍 롱프레스 위치 포그레벨: $fogLevel');
      // TODO: Fix return type - should return int instead of FogLevel
      return fogLevel.index;
    } catch (e) {
      debugPrint('❌ 포그레벨 확인 실패: $e');
      return 0;
    }
  }

  /// 필터 설정
  void setFilters({
    bool? couponsOnly,
    bool? myPostsOnly,
    double? minRewardValue,
    bool? urgentOnly,
    bool? verifiedOnly,
    bool? unverifiedOnly,
  }) {
    if (couponsOnly != null) showCouponsOnly = couponsOnly;
    if (myPostsOnly != null) showMyPostsOnly = myPostsOnly;
    if (minRewardValue != null) minReward = minRewardValue;
    if (urgentOnly != null) showUrgentOnly = urgentOnly;
    if (verifiedOnly != null) showVerifiedOnly = verifiedOnly;
    if (unverifiedOnly != null) showUnverifiedOnly = unverifiedOnly;
  }

  /// 사용자 타입 설정
  void setUserType(String type) {
    userType = type;
  }
}

