import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/user/user_model.dart';
import '../providers/map_filter_provider.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart' as core_marker;
import '../../../core/services/data/user_service.dart';
import '../../../core/constants/app_constants.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import '../widgets/marker_layer_widget.dart';
import '../widgets/map_marker_detail_widget.dart';
import '../widgets/map_longpress_menu_widget.dart';
import '../widgets/map_filter_bar_widget.dart';
import '../widgets/map_user_location_markers_widget.dart';
import '../widgets/map_location_buttons_widget.dart';
import '../utils/client_cluster.dart';
import '../widgets/cluster_widgets.dart';
import '../../post_system/controllers/post_deployment_controller.dart';
import '../../../core/services/osm_geocoding_service.dart';
import '../../post_system/widgets/address_search_dialog.dart';
import '../services/external/osm_fog_service.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../widgets/unified_fog_overlay_widget.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/location/location_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/models/map/fog_level.dart';
import '../models/receipt_item.dart';
import '../widgets/receive_carousel.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart' as audio;

// ✨ 리팩토링된 Controller & State
import '../controllers/fog_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/marker_controller.dart';
import '../controllers/post_controller.dart' as map_post;
import '../state/map_state.dart';
import '../widgets/map_filter_dialog.dart';
import '../models/marker_item.dart';

/// 리팩토링된 MapScreen - Clean Architecture 적용
/// 
/// 기존 4,939줄 → 목표 500줄 이하
class MapScreen extends StatefulWidget {
  final Function(String)? onAddressChanged;
  final VoidCallback? onNavigateToInbox;
  
  const MapScreen({
    super.key,
    this.onAddressChanged,
    this.onNavigateToInbox,
  });
  
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ✨ 상태 관리 객체
  late final MapState _state;
  
  // 리스너 구독
  StreamSubscription<DocumentSnapshot>? _workplaceSubscription;
  
  @override
  void initState() {
    super.initState();
    _state = MapState();
    _state.mapController = MapController();
    
    _initializeApp();
  }
  
  /// 앱 초기화
  Future<void> _initializeApp() async {
    await _loadCustomMarker();
    await _initializeLocation();
    _setupUserDataListener();
    _setupMarkerListener();
    _updateReceivablePosts();
  }

  @override
  void dispose() {
    _state.dispose();
    _workplaceSubscription?.cancel();
    super.dispose();
  }

  // ==================== 초기화 ====================
  
  Future<void> _initializeLocation() async {
    final permission = await LocationController.checkAndRequestPermission();
    
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _state.errorMessage = LocationController.getPermissionErrorMessage(permission);
        });
      }
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationController.getCurrentLocation(
      isMockMode: _state.isMockModeEnabled,
      mockPosition: _state.mockPosition,
    );
    
    if (position == null) {
      if (mounted) {
        setState(() {
          _state.errorMessage = '현재 위치를 가져올 수 없습니다';
        });
      }
      return;
    }

    final previousPosition = _state.currentPosition;

    if (mounted) {
      setState(() {
        _state.currentPosition = position;
        _state.errorMessage = null;
      });
    }

    // Fog of War 재구성
    _rebuildFogWithUserLocations(position);
    
    // 주소 업데이트
    await _updateCurrentAddress();
    
    // 타일 방문 기록
    final tileId = await LocationController.updateTileVisit(position);
    _state.addFogLevel1Tile(tileId);
    
    // 회색 영역 업데이트
    await _updateGrayAreasWithPreviousPosition(previousPosition);
    
    // 프리미엄 상태 확인
    await _checkPremiumStatus();
    
    // 포스트 스트림 설정
    _setupPostStreamListener();
    
    // 마커 조회
    await _updatePostsBasedOnFogLevel();
    
    // 현재 위치 마커
    _createCurrentLocationMarker(position);
    
    // 지도 중심 이동
    _state.mapController?.move(position, _state.currentZoom);
  }

  void _createCurrentLocationMarker(LatLng position) {
    final marker = LocationController.createCurrentLocationMarker(position);
    if (mounted) {
      setState(() {
        _state.currentMarkers = [marker];
      });
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_state.currentPosition == null) return;
    
    final address = await LocationController.getAddressFromLatLng(
      _state.currentPosition!,
    );
    
    if (mounted) {
      setState(() {
        _state.currentAddress = address;
      });
    }
    
    widget.onAddressChanged?.call(address);
  }

  // ==================== Fog of War ====================
  
  void _rebuildFogWithUserLocations(LatLng currentPosition) {
    final result = FogController.rebuildFogWithUserLocations(
      currentPosition: currentPosition,
      homeLocation: _state.homeLocation,
      workLocations: _state.workLocations,
    );
    
    if (mounted) {
      setState(() {
        _state.ringCircles = result.$2;
      });
    }
  }

  Future<void> _loadUserLocations() async {
    final result = await FogController.loadUserLocations();
    
    if (mounted) {
      setState(() {
        _state.homeLocation = result.$1;
        _state.workLocations = result.$2;
      });
    }

    await _loadVisitedLocations();

    if (_state.currentPosition != null) {
      _rebuildFogWithUserLocations(_state.currentPosition!);
    }
  }

  Future<void> _loadVisitedLocations() async {
    final grayPolygons = await FogController.loadVisitedLocations();
    
    if (mounted) {
      setState(() {
        _state.grayPolygons = grayPolygons;
      });
    }
  }

  Future<void> _updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
    final grayPolygons = await FogController.updateGrayAreasWithPreviousPosition(
      previousPosition,
    );
    
    if (mounted) {
      setState(() {
        _state.grayPolygons = grayPolygons;
      });
    }
  }

  // ==================== 사용자 데이터 리스너 ====================
  
  void _setupUserDataListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final userModel = UserModel.fromFirestore(snapshot);
        if (mounted) {
          setState(() {
            _state.updatePremiumStatus(
              userModel.userType == UserType.superSite,
              userModel.userType,
            );
          });
        }
        
        final data = snapshot.data();
        final workplaceId = data?['workplaceId'] as String?;
        if (workplaceId != null && workplaceId.isNotEmpty) {
          _setupWorkplaceListener(workplaceId);
        }
        
        _loadUserLocations();
      }
    });
  }

  void _setupWorkplaceListener(String workplaceId) {
    _workplaceSubscription?.cancel();
    
    _workplaceSubscription = FirebaseFirestore.instance
        .collection('places')
        .doc(workplaceId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        _loadUserLocations();
      }
    });
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final isPremium = userData?['isPremium'] ?? false;

        if (mounted) {
          setState(() {
            _state.updatePremiumStatus(
              isPremium,
              UserType.normal, // TODO: userType 확인
            );
          });
        }
      }
    } catch (e) {
      debugPrint('프리미엄 상태 확인 실패: $e');
    }
  }

  // ==================== 마커 관련 ====================
  
  void _setupMarkerListener() {
    if (_state.currentPosition == null) return;
    debugPrint('마커 리스너 설정 완료');
  }

  void _setupPostStreamListener() {
    if (_state.currentPosition == null) return;
    // TODO: 실시간 마커 스트림 구현
  }

  void _updateMarkers() {
    _state.visibleMarkerModels = MarkerController.convertToClusterModels(_state.markers);
    _rebuildClusters();
    _updateReceivablePosts();
  }

  void _rebuildClusters() {
    final clusteredMarkers = MarkerController.buildClusteredMarkers(
      markers: _state.markers,
      visibleMarkerModels: _state.visibleMarkerModels,
      mapCenter: _state.mapCenter,
      mapZoom: _state.mapZoom,
      viewSize: _state.lastMapSize,
      onTapSingle: _onTapSingleMarker,
      onTapCluster: _zoomIntoCluster,
    );
    
    if (mounted) {
      setState(() {
        _state.clusteredMarkers = clusteredMarkers;
      });
    }
  }

  void _onTapSingleMarker(ClusterMarkerModel marker) {
    final originalMarker = MarkerController.findOriginalMarker(marker, _state.markers);
    if (originalMarker != null) {
      _showMarkerDetails(originalMarker);
    }
  }

  void _zoomIntoCluster(ClusterOrMarker cluster) {
    final targetZoom = MarkerController.calculateClusterZoomTarget(_state.mapZoom);
    _state.mapController?.move(cluster.representative!.position, targetZoom);
  }

  void _showMarkerDetails(MarkerModel marker) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MapMarkerDetailWidget(
        marker: marker,
        currentPosition: _state.currentPosition ?? const LatLng(0, 0),
        currentUserId: currentUserId,
        onCollect: () {
          Navigator.pop(context);
          _collectMarker(marker);
        },
        onRemove: () {
          Navigator.pop(context);
          _removeMarker(marker);
        },
      ),
    );
  }

  Future<void> _collectMarker(MarkerModel marker) async {
    // TODO: PostService.collectPost 구현
    debugPrint('마커 수집: ${marker.title}');
  }

  Future<void> _removeMarker(MarkerModel marker) async {
    // TODO: PostService.recallMarker 구현
    debugPrint('마커 회수: ${marker.markerId}');
  }

  // ==================== UI 빌드 ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          if (_state.isLoading) _buildLoadingOverlay(),
          if (_state.errorMessage != null) _buildErrorMessage(),
          _buildFilterBar(),
          _buildLocationButtons(),
          _buildMockController(),
        ],
      ),
      floatingActionButton: _buildReceiveFab(),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _state.mapController,
      options: MapOptions(
        initialCenter: _state.mapCenter,
        initialZoom: _state.currentZoom,
        onMapEvent: _onMapMoved,
        onLongPress: (_, point) => _onMapLongPress(point),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.ppamalpha.app',
        ),
        
        // Fog Overlay
        if (_state.mapController != null)
        UnifiedFogOverlayWidget(
          mapController: _state.mapController!,
          level1Centers: [
            if (_state.currentPosition != null) _state.currentPosition!,
            if (_state.homeLocation != null) _state.homeLocation!,
            ..._state.workLocations,
          ],
          level2CentersRaw: _state.grayPolygons.isNotEmpty 
            ? _state.grayPolygons.map((polygon) {
                if (polygon.points.isEmpty) return const LatLng(0, 0);
                double sumLat = 0, sumLng = 0;
                for (final point in polygon.points) {
                  sumLat += point.latitude;
                  sumLng += point.longitude;
                }
                return LatLng(
                  sumLat / polygon.points.length,
                  sumLng / polygon.points.length,
                );
              }).toList()
            : [],
          radiusMeters: 1000.0,
          fogColor: Colors.black.withOpacity(1.0),
          grayColor: Colors.grey.withOpacity(0.33),
        ),
        
        // 집/일터 마커 레이어
        MapUserLocationMarkersWidget(
          homeLocation: _state.homeLocation,
          workLocations: _state.workLocations,
        ),
        
        // 마커 레이어
        MarkerLayer(markers: _state.clusteredMarkers),
        
        // 현재 위치 마커
        MarkerLayer(markers: _state.currentMarkers),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.red[100],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _state.errorMessage!,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.blue[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 위치 정보
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _state.currentAddress ?? '위치를 확인하는 중...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 포인트 정보
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_state.userPoints ?? 0}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 검색 버튼
                IconButton(
                  onPressed: () {
                    // TODO: 검색 기능 구현
                  },
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                // DEBUG 라벨 (개발 모드에서만)
                if (kDebugMode)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Consumer<MapFilterProvider>(
      builder: (context, filterProvider, child) {
            return Row(
              children: [
                // 필터 아이콘
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: IconButton(
                    onPressed: _showFilterDialog,
                    icon: const Icon(Icons.filter_list, color: Colors.grey),
                    iconSize: 20,
                  ),
                ),
                // 필터 버튼들
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          icon: Icons.person,
                          label: '내 포스트',
                          isSelected: _state.showMyPostsOnly,
                          onTap: () {
            setState(() {
                              _state.showMyPostsOnly = !_state.showMyPostsOnly;
                              if (_state.showMyPostsOnly) {
                _state.showCouponsOnly = false;
                filterProvider.setUrgentOnly(false);
              }
            });
            _updateMarkers();
          },
                        ),
                        _buildFilterChip(
                          icon: Icons.card_giftcard,
                          label: '쿠폰',
                          isSelected: _state.showCouponsOnly,
                          onTap: () {
            setState(() {
                              _state.showCouponsOnly = !_state.showCouponsOnly;
                              if (_state.showCouponsOnly) {
                _state.showMyPostsOnly = false;
                filterProvider.setUrgentOnly(false);
              }
            });
            _updateMarkers();
          },
                        ),
                        _buildFilterChip(
                          icon: Icons.access_time,
                          label: '마감임박',
                          isSelected: filterProvider.showUrgentOnly,
                          onTap: () {
                            filterProvider.setUrgentOnly(!filterProvider.showUrgentOnly);
                            if (filterProvider.showUrgentOnly) {
              setState(() {
                _state.showMyPostsOnly = false;
                _state.showCouponsOnly = false;
              });
            }
            _updateMarkers();
          },
                        ),
                        _buildFilterChip(
                          icon: Icons.verified,
                          label: '인증',
                          isSelected: filterProvider.showVerifiedOnly,
                          onTap: () {
                            filterProvider.setVerifiedOnly(!filterProvider.showVerifiedOnly);
            _updateMarkers();
          },
                        ),
                        _buildFilterChip(
                          icon: Icons.work_outline,
                          label: '미인증',
                          isSelected: filterProvider.showUnverifiedOnly,
                          onTap: () {
                            filterProvider.setUnverifiedOnly(!filterProvider.showUnverifiedOnly);
            _updateMarkers();
          },
                        ),
                      ],
                    ),
                  ),
                ),
                // 추가 옵션 버튼
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: 추가 옵션 구현
                    },
                    icon: Icon(
                      Icons.more_horiz,
                      color: Colors.purple[600],
                    ),
                    iconSize: 20,
                  ),
                ),
                // 필터 초기화 버튼
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    iconSize: 18,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected 
            ? Border.all(color: Colors.blue[300]!, width: 1)
            : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButtons() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: Column(
        children: [
          // 집 버튼
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _state.homeLocation != null ? _moveToHome : null,
              icon: Icon(
                Icons.home, 
                color: _state.homeLocation != null ? Colors.green : Colors.grey,
              ),
              iconSize: 24,
            ),
          ),
          // 일터 버튼
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _state.workLocations.isNotEmpty ? _moveToWorkplace : null,
              icon: Icon(
                Icons.work, 
                color: _state.workLocations.isNotEmpty ? Colors.orange : Colors.grey,
              ),
              iconSize: 24,
            ),
          ),
          // 현재 위치 버튼
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _moveToCurrentLocation,
              icon: const Icon(Icons.my_location, color: Colors.blue),
              iconSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockController() {
    if (!_state.isMockControllerVisible) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      left: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목과 닫기 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_searching, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Mock 위치',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _state.isMockControllerVisible = false;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            // 화살표 컨트롤러
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // 위쪽 화살표
                  GestureDetector(
                    onTap: () => _moveMockPosition('up'),
                    child: Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 좌우 화살표
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _moveMockPosition('left'),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Icon(Icons.keyboard_arrow_left, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // 중앙 위치 표시
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.purple, size: 16),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => _moveMockPosition('right'),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 아래쪽 화살표
                  GestureDetector(
                    onTap: () => _moveMockPosition('down'),
                    child: Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            // 현재 위치 정보
            if (_state.mockPosition != null)
              GestureDetector(
                onTap: _showMockPositionInputDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '위도: ${_state.mockPosition!.latitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 10, color: Colors.grey),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '경도: ${_state.mockPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 10, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.map,
                label: 'Map',
                isSelected: true,
                onTap: () {
                  // 현재 화면이므로 아무것도 하지 않음
                },
              ),
              _buildNavItem(
                icon: Icons.inbox,
                label: 'Inbox',
                isSelected: false,
                onTap: () {
                  widget.onNavigateToInbox?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveFab() {
    if (_state.receivablePostCount == 0) return const SizedBox.shrink();
    
    return FloatingActionButton.extended(
      onPressed: _handleReceivePosts,
      icon: const Icon(Icons.card_giftcard),
      label: Text('수령하기 (${_state.receivablePostCount})'),
      backgroundColor: Colors.green,
    );
  }

  // ==================== 이벤트 핸들러 ====================
  
  void _onMapMoved(MapEvent event) {
    _updateMapState();
    
    if (event is MapEventMove || event is MapEventMoveStart) {
      _state.mapMoveTimer?.cancel();
      _state.mapMoveTimer = Timer(
        const Duration(milliseconds: 500),
        _handleMapMoveComplete,
      );
      
      _updateReceivablePosts();
    }
  }

  void _updateMapState() {
    if (_state.mapController != null) {
      final camera = _state.mapController!.camera;
      setState(() {
        _state.mapCenter = camera.center;
        _state.mapZoom = camera.zoom;
        _state.lastMapSize = MediaQuery.of(context).size;
      });
      
      _state.clusterDebounceTimer?.cancel();
      _state.clusterDebounceTimer = Timer(
        const Duration(milliseconds: 32),
        _rebuildClusters,
      );
    }
  }

  Future<void> _handleMapMoveComplete() async {
    if (_state.isUpdatingPosts) return;
    
    final currentCenter = _state.mapController?.camera.center;
    if (currentCenter == null) return;
    
    // TODO: 캐시 로직 추가
    
    setState(() => _state.isUpdatingPosts = true);
    
    try {
      await _updatePostsBasedOnFogLevel();
      _updateReceivablePosts();
      _state.lastMapCenter = currentCenter;
    } catch (e) {
      debugPrint('마커 업데이트 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _state.isUpdatingPosts = false);
      }
    }
  }

  void _onMapLongPress(LatLng point) {
    setState(() {
      _state.longPressedLatLng = point;
    });
    _showLongPressMenu();
  }

  void _showLongPressMenu() {
    showMapLongPressMenu(
      context: context,
      onDeployHere: _navigateToPostPlace,
      onDeployAddress: _navigateToPostAddress,
    );
  }

  void _navigateToPostPlace() {
    if (_state.longPressedLatLng != null) {
      Navigator.pushNamed(
        context,
        '/post-deploy',
        arguments: {
          'location': _state.longPressedLatLng,
          'type': 'location',
        },
      );
    }
  }

  void _navigateToPostAddress() {
    if (_state.longPressedLatLng != null) {
      Navigator.pushNamed(
        context,
        '/post-deploy',
        arguments: {
          'location': _state.longPressedLatLng,
          'type': 'address',
        },
      );
    }
  }

  // ==================== 액션 ====================
  
  void _resetFilters() {
    final filterProvider = context.read<MapFilterProvider>();
    filterProvider.resetFilters();
    setState(() {
      _state.showMyPostsOnly = false;
      _state.showCouponsOnly = false;
    });
    _updateMarkers();
  }
  
  void _showFilterDialog() {
    final filterProvider = context.read<MapFilterProvider>();
    
    MapFilterDialog.show(
      context: context,
      selectedCategory: filterProvider.selectedCategory,
      maxDistance: filterProvider.maxDistance,
      minReward: filterProvider.minReward,
      isPremiumUser: _state.isPremiumUser,
      onReset: () {
        filterProvider.resetFilters();
        _updateMarkers();
      },
      onApply: () {
        _updateMarkers();
        Navigator.pop(context);
      },
      onCategoryChanged: (category) {
        filterProvider.setCategory(category);
      },
      onMinRewardChanged: (reward) {
        filterProvider.setMinReward(reward);
      },
    );
  }

  void _moveToHome() {
    if (_state.homeLocation != null && _state.mapController != null) {
      _state.mapController!.move(_state.homeLocation!, _state.currentZoom);
    }
  }

  void _moveToWorkplace() {
    if (_state.workLocations.isNotEmpty && _state.mapController != null) {
      final targetLocation = _state.workLocations[_state.currentWorkplaceIndex];
      _state.mapController!.move(targetLocation, _state.currentZoom);
      
      // 다음 일터로 순환
      setState(() {
        _state.currentWorkplaceIndex = 
            (_state.currentWorkplaceIndex + 1) % _state.workLocations.length;
      });
    }
  }

  void _moveToCurrentLocation() {
    if (_state.currentPosition != null && _state.mapController != null) {
      _state.mapController!.move(_state.currentPosition!, 14.0);
    }
  }

  void _toggleMockMode() {
    setState(() {
      _state.isMockModeEnabled = !_state.isMockModeEnabled;
      _state.isMockControllerVisible = _state.isMockModeEnabled;
    });
  }

  void _moveMockPosition(String direction) {
    if (_state.mockPosition == null) return;
    
    const double step = 0.001; // 약 100m 정도
    double newLat = _state.mockPosition!.latitude;
    double newLng = _state.mockPosition!.longitude;
    
    switch (direction) {
      case 'up':
        newLat += step;
        break;
      case 'down':
        newLat -= step;
        break;
      case 'left':
        newLng -= step;
        break;
      case 'right':
        newLng += step;
        break;
    }
    
    setState(() {
      _state.mockPosition = LatLng(newLat, newLng);
    });
    
    // TODO: Mock 위치 업데이트 로직
  }

  void _showMockPositionInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mock 위치 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '위도',
                hintText: '37.5665',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                // TODO: 위도 입력 처리
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '경도',
                hintText: '126.9780',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                // TODO: 경도 입력 처리
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Mock 위치 적용
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReceivePosts() async {
    // TODO: 수령 로직 구현
    debugPrint('포스트 수령: ${_state.receivablePostCount}개');
  }

  // ==================== 헬퍼 메서드 ====================
  
  Future<void> _loadCustomMarker() async {
    // TODO: 커스텀 마커 로드
  }

  Future<void> _updatePostsBasedOnFogLevel() async {
    // TODO: Fog 레벨 기반 포스트 업데이트
    if (mounted) {
      setState(() => _state.isLoading = false);
    }
  }

  void _updateReceivablePosts() {
    // TODO: 수령 가능 포스트 계산
    setState(() => _state.receivablePostCount = 0);
  }

  double _calculateDistance(LatLng from, LatLng to) {
    return LocationController.calculateDistance(from, to);
  }
}


