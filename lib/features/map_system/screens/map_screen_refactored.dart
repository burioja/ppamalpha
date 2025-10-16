import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/user/user_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart' as core_marker;
import '../../../core/services/data/user_service.dart';
import '../../../core/constants/app_constants.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import '../widgets/marker_layer_widget.dart';
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

  // ==================== UI 빌드 ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          if (_state.isLoading) _buildLoadingOverlay(),
          if (_state.errorMessage != null) _buildErrorMessage(),
          _buildControls(),
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
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        
        // Fog Overlay
        if (_state.grayPolygons.isNotEmpty || _state.ringCircles.isNotEmpty)
          UnifiedFogOverlayWidget(
            grayPolygons: _state.grayPolygons,
            ringCircles: _state.ringCircles,
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

  Widget _buildControls() {
    return Positioned(
      top: 50,
      right: 16,
      child: Column(
        children: [
          _buildFilterButton(),
          const SizedBox(height: 8),
          _buildLocationButton(),
          const SizedBox(height: 8),
          _buildMockModeButton(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return FloatingActionButton(
      heroTag: 'filter',
      mini: true,
      onPressed: _showFilterDialog,
      child: const Icon(Icons.filter_list),
    );
  }

  Widget _buildLocationButton() {
    return FloatingActionButton(
      heroTag: 'location',
      mini: true,
      onPressed: _moveToCurrentLocation,
      child: const Icon(Icons.my_location),
    );
  }

  Widget _buildMockModeButton() {
    if (!kDebugMode) return const SizedBox.shrink();
    
    return FloatingActionButton(
      heroTag: 'mock',
      mini: true,
      onPressed: _toggleMockMode,
      backgroundColor: _state.isMockModeEnabled ? Colors.orange : Colors.grey,
      child: const Icon(Icons.developer_mode),
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

  // ==================== 액션 ====================
  
  void _showFilterDialog() {
    MapFilterDialog.show(
      context: context,
      selectedCategory: _state.selectedCategory,
      maxDistance: _state.maxDistance,
      minReward: _state.minReward,
      isPremiumUser: _state.isPremiumUser,
      onReset: _resetFilters,
      onApply: _updateMarkers,
      onCategoryChanged: (category) {
        setState(() => _state.selectedCategory = category);
      },
      onMinRewardChanged: (reward) {
        setState(() => _state.minReward = reward);
      },
    );
  }

  void _resetFilters() {
    if (mounted) {
      setState(() {
        _state.resetFilters();
      });
    }
    _updateMarkers();
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

  Future<void> _handleReceivePosts() async {
    // TODO: 수령 로직 구현
    debugPrint('포스트 수령: ${_state.receivablePostCount}개');
  }

  void _showLongPressMenu() {
    // TODO: 롱프레스 메뉴 구현
  }

  void _showMarkerDetails(MarkerModel marker) async {
    // TODO: 마커 상세 다이얼로그 구현
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

