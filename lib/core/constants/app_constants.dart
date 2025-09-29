// lib/core/constants/app_constants.dart
class AppConsts {
  /// 슈퍼포스트 기준 리워드 (원)
  static const int superRewardThreshold = 1000;

  // 마커 표시 거리 (미터)
  static const int normalUserRadius1km = 1000;  // 일반사용자 1단계 영역
  static const int superSiteUserRadius3km = 3000;  // 수퍼사이트 유료구독 1단계 영역
  static const int normalUserRadius2km = 1000;  // 일반사용자 2단계 영역 (30일 방문 경로)
  static const int superSiteUserRadius2km = 3000;  // 수퍼사이트 유료구독 2단계 영역 (30일 방문 경로)
  static const int superPostRadius5km = 5000;  // 슈퍼포스트 표시 거리
  
  // 마커 배포/수집 거리
  static const int markerDeployRadius = 1000;  // 마커 배포 가능 거리 (1단계 영역에서만)
  static const int markerCollectRadius = 50;   // 마커 수집 가능 거리 (현위치 50m)
}
