import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/marker/marker_model.dart';
import '../../../../core/models/post/post_model.dart';
import '../../../../core/models/user/user_model.dart';

/// 필터 서비스
/// 
/// **책임**: 필터 로직 (서버/클라이언트 필터 머지, 조건 검증)
/// **원칙**: 순수 비즈니스 로직만
class FilterService {
  // ==================== 마커 필터링 ====================

  /// 마커 필터링 (클라이언트 사이드)
  /// 
  /// [markers]: 필터링할 마커 리스트
  /// [filter]: 필터 조건
  /// 
  /// Returns: 필터링된 마커 리스트
  static List<MarkerModel> filterMarkers({
    required List<MarkerModel> markers,
    required MarkerFilter filter,
  }) {
    return markers.where((marker) {
      // 내 포스트만
      if (filter.showMyPostsOnly && marker.creatorId != filter.currentUserId) {
        return false;
      }

      // 쿠폰만 - TODO: 마커 모델에 속성 추가 필요
      // if (filter.showCouponsOnly && !(marker.isCoupon ?? false)) {
      //   return false;
      // }

      // 스탬프만 - TODO: 마커 모델에 속성 추가 필요
      // if (filter.showStampsOnly && !(marker.isStamp ?? false)) {
      //   return false;
      // }

      // 인증만 - TODO: 마커 모델에 속성 추가 필요
      // if (filter.showVerifiedOnly && !(marker.isVerified ?? false)) {
      //   return false;
      // }

      // 미인증만 - TODO: 마커 모델에 속성 추가 필요
      // if (filter.showUnverifiedOnly && (marker.isVerified ?? false)) {
      //   return false;
      // }

      // 마감임박 (24시간 이내)
      if (filter.showUrgentOnly) {
        final expiresAt = marker.expiresAt;
        if (expiresAt == null) return false;
        
        final remaining = expiresAt.difference(DateTime.now());
        if (remaining.inHours > 24) return false;
      }

      // 최소 보상
      if (filter.minReward > 0) {
        final reward = marker.reward ?? 0;
        if (reward < filter.minReward) return false;
      }

      // 카테고리 - TODO: 마커 모델에 속성 추가 필요
      // if (filter.category != null && filter.category != 'all') {
      //   if (marker.category != filter.category) return false;
      // }

      return true;
    }).toList();
  }

  /// 포스트 필터링 (클라이언트 사이드)
  static List<PostModel> filterPosts({
    required List<PostModel> posts,
    required PostFilter filter,
  }) {
    return posts.where((post) {
      // 내 포스트만
      if (filter.showMyPostsOnly && post.creatorId != filter.currentUserId) {
        return false;
      }

      // 쿠폰만
      if (filter.showCouponsOnly && !post.isCoupon) {
        return false;
      }

      // 카테고리 - TODO: 포스트 모델 확인 필요
      // if (filter.category != null && filter.category != 'all') {
      //   if (post.category != filter.category) return false;
      // }

      return true;
    }).toList();
  }

  // ==================== 필터 유효성 검증 ====================

  /// 필터 조건 유효성 검증
  /// 
  /// Returns: (isValid, errorMessage)
  static (bool, String?) validateFilter(MarkerFilter filter) {
    // 거리 범위 확인
    if (filter.maxDistance < 0.1 || filter.maxDistance > 5.0) {
      return (false, '거리는 0.1km ~ 5km 사이여야 합니다');
    }

    // 프리미엄 사용자만 5km 가능
    if (filter.maxDistance > 1.0 && !filter.isPremiumUser) {
      return (false, '프리미엄 멤버십이 필요합니다 (1km 초과)');
    }

    // 보상 범위 확인
    if (filter.minReward < 0 || filter.minReward > 100000) {
      return (false, '보상은 0 ~ 100,000원 사이여야 합니다');
    }

    return (true, null);
  }

  // ==================== 필터 머지 ====================

  /// 서버 필터 조건 생성 (Firebase 쿼리용)
  /// 
  /// Returns: Firebase 쿼리에 사용할 조건 맵
  static Map<String, dynamic> buildServerFilterConditions(MarkerFilter filter) {
    final conditions = <String, dynamic>{};

    // 카테고리
    if (filter.category != null && filter.category != 'all') {
      conditions['category'] = filter.category;
    }

    // 수량 있는 것만
    conditions['quantity_greaterThan'] = 0;

    // 만료되지 않은 것만
    conditions['expiresAt_greaterThan'] = DateTime.now();

    return conditions;
  }

  /// 클라이언트 필터가 필요한지 확인
  static bool needsClientSideFiltering(MarkerFilter filter) {
    return filter.showMyPostsOnly ||
        filter.showCouponsOnly ||
        filter.showStampsOnly ||
        filter.showVerifiedOnly ||
        filter.showUnverifiedOnly ||
        filter.showUrgentOnly ||
        filter.minReward > 0;
  }

  // ==================== 거리 필터 ====================

  /// 거리 기반 필터링
  /// 
  /// [markers]: 마커 리스트
  /// [userPosition]: 사용자 현재 위치
  /// [maxDistance]: 최대 거리 (미터)
  static List<MarkerModel> filterByDistance({
    required List<MarkerModel> markers,
    required LatLng userPosition,
    required double maxDistance,
  }) {
    return markers.where((marker) {
      final distance = _calculateDistance(userPosition, marker.position);
      return distance <= maxDistance;
    }).toList();
  }

  /// 거리 계산
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // 미터
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
}

// ==================== 필터 모델 ====================

/// 마커 필터 조건
class MarkerFilter {
  final String? currentUserId;
  final bool showMyPostsOnly;
  final bool showCouponsOnly;
  final bool showStampsOnly;
  final bool showVerifiedOnly;
  final bool showUnverifiedOnly;
  final bool showUrgentOnly;
  final int minReward;
  final String? category;
  final double maxDistance; // km
  final bool isPremiumUser;

  const MarkerFilter({
    this.currentUserId,
    this.showMyPostsOnly = false,
    this.showCouponsOnly = false,
    this.showStampsOnly = false,
    this.showVerifiedOnly = false,
    this.showUnverifiedOnly = false,
    this.showUrgentOnly = false,
    this.minReward = 0,
    this.category,
    this.maxDistance = 1.0,
    this.isPremiumUser = false,
  });

  /// 활성 필터 있는지 확인
  bool get hasActiveFilters {
    return showMyPostsOnly ||
        showCouponsOnly ||
        showStampsOnly ||
        showVerifiedOnly ||
        showUnverifiedOnly ||
        showUrgentOnly ||
        minReward > 0 ||
        (category != null && category != 'all');
  }

  /// 복사본 생성
  MarkerFilter copyWith({
    String? currentUserId,
    bool? showMyPostsOnly,
    bool? showCouponsOnly,
    bool? showStampsOnly,
    bool? showVerifiedOnly,
    bool? showUnverifiedOnly,
    bool? showUrgentOnly,
    int? minReward,
    String? category,
    double? maxDistance,
    bool? isPremiumUser,
  }) {
    return MarkerFilter(
      currentUserId: currentUserId ?? this.currentUserId,
      showMyPostsOnly: showMyPostsOnly ?? this.showMyPostsOnly,
      showCouponsOnly: showCouponsOnly ?? this.showCouponsOnly,
      showStampsOnly: showStampsOnly ?? this.showStampsOnly,
      showVerifiedOnly: showVerifiedOnly ?? this.showVerifiedOnly,
      showUnverifiedOnly: showUnverifiedOnly ?? this.showUnverifiedOnly,
      showUrgentOnly: showUrgentOnly ?? this.showUrgentOnly,
      minReward: minReward ?? this.minReward,
      category: category ?? this.category,
      maxDistance: maxDistance ?? this.maxDistance,
      isPremiumUser: isPremiumUser ?? this.isPremiumUser,
    );
  }
}

/// 포스트 필터 조건
class PostFilter {
  final String? currentUserId;
  final bool showMyPostsOnly;
  final bool showCouponsOnly;
  final String? category;

  const PostFilter({
    this.currentUserId,
    this.showMyPostsOnly = false,
    this.showCouponsOnly = false,
    this.category,
  });
}

