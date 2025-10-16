import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/models/user/user_model.dart';
import '../utils/client_cluster.dart';

/// MapScreen의 모든 상태를 관리하는 클래스
class MapState {
  // ==================== Fog of War 관련 ====================
  List<Polygon> grayPolygons = [];
  List<CircleMarker> ringCircles = [];
  List<Marker> currentMarkers = [];

  // ==================== 클러스터링 관련 ====================
  List<Marker> clusteredMarkers = [];
  Size lastMapSize = const Size(0, 0);
  LatLng mapCenter = const LatLng(37.5665, 126.9780); // 서울 기본값
  double mapZoom = 10.0;
  Timer? clusterDebounceTimer;
  List<ClusterMarkerModel> visibleMarkerModels = [];
  bool isClustered = false;
  static const double clusterRadius = 50.0;

  // ==================== 사용자 위치 정보 ====================
  LatLng? homeLocation;
  List<LatLng> workLocations = [];

  // ==================== 지도 기본 상태 ====================
  MapController? mapController;
  LatLng? currentPosition;
  double currentZoom = 14.0;
  String currentAddress = '위치 불러오는 중...';
  LatLng? longPressedLatLng;
  Widget? customMarkerIcon;

  // ==================== 포스트 관련 ====================
  List<PostModel> posts = [];
  List<MarkerModel> markers = [];
  bool isLoading = false;
  String? errorMessage;

  // ==================== 필터 관련 ====================
  bool showFilter = false;
  String selectedCategory = 'all';
  double maxDistance = 1000.0; // 기본 1km, 유료회원 3km
  int minReward = 0;
  bool showCouponsOnly = false;
  bool showMyPostsOnly = false;
  bool showUrgentOnly = false;
  bool showVerifiedOnly = false;
  bool showUnverifiedOnly = false;
  bool isPremiumUser = false;
  UserType userType = UserType.normal;

  // ==================== 실시간 업데이트 관련 ====================
  Timer? mapMoveTimer;
  LatLng? lastMapCenter;
  Set<String> lastFogLevel1Tiles = {};
  bool isUpdatingPosts = false;

  // ==================== 포스트 수령 관련 ====================
  int receivablePostCount = 0;
  bool isReceiving = false;
  String? lastCacheKey;

  // ==================== 포그레벨 캐시 관련 ====================
  Set<String> currentFogLevel1TileIds = {};
  DateTime? fogLevel1CacheTimestamp;
  static const Duration fogLevel1CacheExpiry = Duration(minutes: 5);
  Map<String, int> tileFogLevels = {};
  Set<String> visiblePostIds = {};

  // ==================== 위치 이동 관련 ====================
  int currentWorkplaceIndex = 0;

  // ==================== Mock 위치 관련 ====================
  bool isMockModeEnabled = false;
  bool isMockControllerVisible = false;
  LatLng? mockPosition;
  LatLng? originalGpsPosition;
  LatLng? previousMockPosition;
  LatLng? previousGpsPosition;

  // ==================== 리스너 구독 관리 ====================
  StreamSubscription<DocumentSnapshot>? workplaceSubscription;

  /// 리소스 정리
  void dispose() {
    clusterDebounceTimer?.cancel();
    mapMoveTimer?.cancel();
    workplaceSubscription?.cancel();
    mapController?.dispose();
  }

  /// 필터 초기화
  void resetFilters() {
    selectedCategory = 'all';
    maxDistance = isPremiumUser ? 3000.0 : 1000.0;
    minReward = 0;
    showCouponsOnly = false;
    showMyPostsOnly = false;
    showUrgentOnly = false;
    showVerifiedOnly = false;
    showUnverifiedOnly = false;
  }

  /// 프리미엄 상태 업데이트
  void updatePremiumStatus(bool isPremium, UserType type) {
    isPremiumUser = isPremium;
    userType = type;
    maxDistance = isPremium ? 3000.0 : 1000.0;
  }

  /// Fog Level 1 캐시 만료 확인
  bool isFogLevel1CacheExpired() {
    if (fogLevel1CacheTimestamp == null) return true;
    return DateTime.now().difference(fogLevel1CacheTimestamp!) > fogLevel1CacheExpiry;
  }

  /// Fog Level 1 캐시 초기화
  void clearFogLevel1Cache() {
    currentFogLevel1TileIds.clear();
    fogLevel1CacheTimestamp = null;
  }

  /// Fog Level 1 타일 추가
  void addFogLevel1Tile(String tileId) {
    currentFogLevel1TileIds.add(tileId);
    fogLevel1CacheTimestamp = DateTime.now();
  }
}

