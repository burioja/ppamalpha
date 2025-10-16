import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_firestore/firebase_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

// Core imports
import '../../../core/models/marker/marker_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/location/nominatim_service.dart';

// Handler imports
import '../handlers/map_fog_handler.dart';
import '../handlers/map_marker_handler.dart';
import '../handlers/map_post_handler.dart';
import '../handlers/map_location_handler.dart';
import '../handlers/map_filter_handler.dart';
import '../handlers/map_ui_helper.dart';

// Widget imports
import '../widgets/map_filter_dialog_widget.dart';
import '../widgets/map_longpress_menu_widget.dart';
import '../widgets/map_marker_detail_widget.dart';
import '../widgets/map_main_widget.dart';

/// 리팩토링된 지도 화면 (1,200줄 이하)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ==================== 핵심 상태 변수 ====================
  MapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 15.0;
  bool _isLoading = false;
  String? _errorMessage;
  
  // 마커 및 포스트
  List<MarkerModel> _markers = [];
  List<PostModel> _posts = [];
  int _receivablePostCount = 0;
  
  // Fog of War
  List<CircleMarker> _ringCircles = [];
  List<Polygon> _grayPolygons = [];
  LatLng? _homeLocation;
  List<LatLng> _workLocations = [];
  
  // UI 상태
  bool _isPremiumUser = false;
  String _userType = 'free';
  LatLng? _longPressedLatLng;
  bool _isReceiving = false;
  
  // Mock 모드
  bool _isMockModeEnabled = false;
  LatLng? _mockPosition;
  String _mockAddress = '';
  bool _isMockControllerVisible = false;
  LatLng? _originalGpsPosition;
  int _currentWorkplaceIndex = 0;
  
  // 필터
  String _selectedCategory = 'all';
  double _maxDistance = 1000.0;
  int _minReward = 0;
  bool _showCouponsOnly = false;
  bool _showMyPostsOnly = false;
  bool _showUrgentOnly = false;
  bool _showVerifiedOnly = false;
  bool _showUnverifiedOnly = false;
  
  // 타이머
  Timer? _mapMoveTimer;
  Timer? _clusterDebounceTimer;
  
  // ==================== Handler 인스턴스 ====================
  late final MapFogHandler _fogHandler;
  late final MapMarkerHandler _markerHandler;
  late final MapPostHandler _postHandler;
  late final MapLocationHandler _locationHandler;
  late final MapFilterHandler _filterHandler;
  late final MapUIHelper _uiHelper;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Handler 초기화
    _fogHandler = MapFogHandler();
    _markerHandler = MapMarkerHandler();
    _postHandler = MapPostHandler();
    _locationHandler = MapLocationHandler();
    _filterHandler = MapFilterHandler();
    _uiHelper = MapUIHelper();
    
    _initializeLocation();
    _loadCustomMarker();
    _loadUserLocations();
    _setupUserDataListener();
    _setupMarkerListener();
    _updateReceivablePosts();
  }

  @override
  void dispose() {
    _mapMoveTimer?.cancel();
    _clusterDebounceTimer?.cancel();
    super.dispose();
  }

  // ==================== 초기화 메서드들 ====================
  
  Future<void> _initializeLocation() async {
    final error = await _locationHandler.initializeLocation();
    if (error != null && mounted) {
      setState(() => _errorMessage = error);
      return;
    }
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final result = await _locationHandler.getCurrentLocation();
    if (result != null && mounted) {
      final (position, error) = result;
      if (position != null) {
        setState(() {
          _currentPosition = position;
          _errorMessage = null;
        });
        _createCurrentLocationMarker(position);
        _updateCurrentAddress();
        _checkPremiumStatus();
        _setupPostStreamListener();
        _updatePostsBasedOnFogLevel();
      } else if (error != null) {
        setState(() => _errorMessage = error);
      }
    }
  }

  void _createCurrentLocationMarker(LatLng position) {
    // 현재 위치 마커 생성 로직
    _updateMapState();
  }

  void _updateMapState() {
    if (_currentPosition != null) {
      _rebuildFogWithUserLocations(_currentPosition!);
    }
  }

  void _rebuildFogWithUserLocations(LatLng currentPosition) {
    _fogHandler.rebuildFogWithUserLocations(
      currentPosition: currentPosition,
      homeLocation: _homeLocation,
      workLocations: _workLocations,
    );
    
    if (mounted) {
      setState(() {
        _ringCircles = _fogHandler.ringCircles;
      });
    }
  }

  Future<void> _loadUserLocations() async {
    try {
      final (home, work) = await _fogHandler.loadUserLocations();
      
      if (mounted) {
        setState(() {
          _homeLocation = home;
          _workLocations = work;
        });
      }

      await _loadVisitedLocations();

      if (_currentPosition != null) {
        _rebuildFogWithUserLocations(_currentPosition!);
      }
    } catch (e) {
      debugPrint('사용자 위치 로드 실패: $e');
    }
  }

  Future<void> _loadVisitedLocations() async {
    await _fogHandler.loadVisitedLocations();
    
    if (mounted) {
      setState(() {
        _grayPolygons = _fogHandler.grayPolygons;
      });
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentPosition != null) {
      try {
        final address = await NominatimService().reverseGeocode(_currentPosition!);
        // 주소 업데이트 로직
      } catch (e) {
        debugPrint('주소 업데이트 실패: $e');
      }
    }
  }

  void _loadCustomMarker() {
    // 커스텀 마커 로드 로직
  }

  void _setupUserDataListener() {
    // 사용자 데이터 리스너 설정
  }

  void _setupMarkerListener() {
    // 마커 리스너 설정
  }

  Future<void> _checkPremiumStatus() async {
    // 프리미엄 상태 확인
  }

  void _setupPostStreamListener() {
    // 포스트 스트림 리스너 설정
  }

  Future<void> _loadPosts({bool forceRefresh = false}) async {
    // 포스트 로드 로직
  }

  // ==================== 지도 이벤트 처리 ====================

  void _onMapMoved(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveStart || event is MapEventMoveEnd) {
      _mapMoveTimer?.cancel();
      _mapMoveTimer = Timer(const Duration(milliseconds: 500), () {
        _handleMapMoveComplete();
      });
    }
  }

  Future<void> _handleMapMoveComplete() async {
    if (_mapController != null) {
      final center = _mapController!.camera.center;
      final zoom = _mapController!.camera.zoom;
      
      setState(() {
        _currentZoom = zoom;
      });
      
      await _updateFogOfWar();
    }
  }

  Future<void> _updateFogOfWar() async {
    if (_currentPosition != null) {
      await _fogHandler.updateFogOfWar(_currentPosition!);
      
      if (mounted) {
        setState(() {
          _grayPolygons = _fogHandler.grayPolygons;
        });
      }
    }
  }

  void _onMapReady() {
    if (_currentPosition != null) {
      _mapController?.move(_currentPosition!, _currentZoom);
    }
  }

  // ==================== 포스트 관리 ====================

  Future<void> _updatePostsBasedOnFogLevel() async {
    LatLng? effectivePosition;
    if (_isMockModeEnabled && _mockPosition != null) {
      effectivePosition = _mockPosition;
    } else {
      effectivePosition = _currentPosition;
    }
    
    if (effectivePosition == null) {
      MapUIHelper.showLocationPermissionDialog(
        context,
        onRetry: _getCurrentLocation,
      );
      return;
    }
    
    _postHandler.setFilters(
      couponsOnly: _showCouponsOnly,
      myPostsOnly: _showMyPostsOnly,
      minRewardValue: _minReward.toDouble(),
      urgentOnly: _showUrgentOnly,
      verifiedOnly: _showVerifiedOnly,
      unverifiedOnly: _showUnverifiedOnly,
    );
    _postHandler.setUserType(_userType);

    final filteredMarkers = await _postHandler.updatePostsBasedOnFogLevel(
      effectivePosition: effectivePosition,
      homeLocation: _homeLocation,
      workLocations: _workLocations,
    );

    if (mounted) {
      setState(() {
        _markers = filteredMarkers;
        _posts = _postHandler.posts;
        _isLoading = _postHandler.isLoading;
        _errorMessage = _postHandler.errorMessage;
        _updateMarkers();
      });
    }
  }

  void _updateMarkers() {
    _markerHandler.setMarkers(_markers);
    _markerHandler.updateMarkers(onRebuild: _rebuildClusters);
    _updateReceivablePosts();
  }

  void _rebuildClusters() {
    // 클러스터 재구성 로직
  }

  Future<void> _updateReceivablePosts() async {
    final count = await _postHandler.calculateReceivablePosts(_currentPosition, _markers);
    
    if (mounted) {
      setState(() {
        _receivablePostCount = count;
      });
    }
  }

  // ==================== 마커 상호작용 ====================

  void _showMarkerDetails(MarkerModel marker) async {
    debugPrint('[MARKER_TAP] markerId: ${marker.markerId}, postId: ${marker.postId}');

    if (_currentPosition == null) {
      MapUIHelper.showToast(context, '위치 정보를 가져올 수 없습니다');
      return;
    }

    showMapMarkerDetail(
      context: context,
      marker: marker,
      currentPosition: _currentPosition!,
      currentUserId: FirebaseAuth.instance.currentUser?.uid,
      onCollect: () => _collectPostFromMarker(marker),
      onRemove: () => _removeMarker(marker),
    );
  }

  Future<void> _collectPostFromMarker(MarkerModel marker) async {
    final result = await _postHandler.collectPostFromMarker(marker, context);
    
    if (result != null && mounted) {
      final (success, newMarkers) = result;
      if (success) {
        setState(() {
          _markers = newMarkers;
        });
        _updateMarkers();
        _updateReceivablePosts();
      }
    }
  }

  Future<void> _removeMarker(MarkerModel marker) async {
    final success = await _postHandler.removeMarker(marker);
    
    if (success && mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId == marker.markerId);
      });
      _updateMarkers();
      _updateReceivablePosts();
    }
  }

  // ==================== 포스트 수령 ====================

  Future<void> _receiveNearbyPosts() async {
    if (_currentPosition == null) return;
    
    setState(() => _isReceiving = true);
    
    try {
      final results = await _postHandler.receiveNearbyPosts(
        currentPosition: _currentPosition!,
        markers: _markers,
        context: context,
        onReceiveEffects: _playReceiveEffects,
        onShowCarousel: _showPostReceivedCarousel,
      );
      
      if (results != null) {
        final (receivedCount, failedCount) = results;
        
        if (mounted) {
          setState(() {
            _markers = _postHandler.markers;
            _receivablePostCount = _postHandler.receivablePostCount;
          });
          _updateMarkers();
          _updateReceivablePosts();
        }
      }
    } finally {
      setState(() => _isReceiving = false);
    }
  }

  Future<void> _playReceiveEffects(int count) async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }
      // 사운드 재생 로직
    } catch (e) {
      debugPrint('효과음 재생 실패: $e');
    }
  }

  Future<void> _showPostReceivedCarousel(List<PostModel> posts) async {
    // 캐러셀 표시 로직
  }

  // ==================== 필터 관리 ====================

  void _showFilterDialog() {
    showMapFilterDialog(
      context: context,
      selectedCategory: _selectedCategory,
      maxDistance: _maxDistance,
      minReward: _minReward,
      isPremiumUser: _isPremiumUser,
      onCategoryChanged: (value) => setState(() => _selectedCategory = value),
      onMinRewardChanged: (value) => setState(() => _minReward = value),
      onReset: _resetFilters,
      onApply: _updateMarkers,
    );
  }

  void _resetFilters() {
    _filterHandler.resetFilters();
    setState(() {
      _selectedCategory = _filterHandler.selectedCategory;
      _maxDistance = _filterHandler.maxDistance;
      _minReward = _filterHandler.minReward;
      _showCouponsOnly = _filterHandler.showCouponsOnly;
      _showMyPostsOnly = _filterHandler.showMyPostsOnly;
      _showUrgentOnly = _filterHandler.showUrgentOnly;
      _showVerifiedOnly = _filterHandler.showVerifiedOnly;
      _showUnverifiedOnly = _filterHandler.showUnverifiedOnly;
    });
    _updateMarkers();
  }

  // ==================== 위치 이동 ====================

  void _moveToHome() {
    final result = _locationHandler.moveToHome(currentZoom: _currentZoom);
    if (result != null) {
      final (location, zoom) = result;
      _mapController?.move(location, zoom);
    }
  }

  void _moveToWorkplace() {
    final result = _locationHandler.moveToWorkplace(currentZoom: _currentZoom);
    if (result != null) {
      final (location, zoom, newIndex) = result;
      _mapController?.move(location, zoom);
      setState(() {
        _currentWorkplaceIndex = newIndex;
      });
    }
  }

  // ==================== 롱프레스 처리 ====================

  Future<void> _handleLongPress(LatLng point) async {
    LatLng? referencePosition;
    if (_isMockModeEnabled && _mockPosition != null) {
      referencePosition = _mockPosition;
    } else {
      referencePosition = _currentPosition;
    }

    if (referencePosition == null) {
      MapUIHelper.showToast(context, '현재 위치를 확인할 수 없습니다');
      return;
    }

    final canDeploy = await _checkDeploymentPermission(point, referencePosition);
    
    if (canDeploy) {
      setState(() {
        _longPressedLatLng = point;
      });
      _showLongPressMenu();
    } else {
      MapUIHelper.showToast(context, '이 위치에는 포스트를 배포할 수 없습니다');
    }
  }

  Future<bool> _checkDeploymentPermission(LatLng point, LatLng referencePosition) async {
    // 배포 권한 확인 로직
    return true;
  }

  void _showLongPressMenu() {
    showMapLongPressMenu(
      context: context,
      onDeployHere: _navigateToPostPlace,
      onDeployAddress: _navigateToPostAddress,
      onDeployBusiness: null,
    );
  }

  // ==================== 네비게이션 ====================

  Future<void> _navigateToPostPlace() async {
    // 포스트 배포 화면으로 이동
  }

  Future<void> _navigateToPostAddress() async {
    // 주소 기반 포스트 배포 화면으로 이동
  }

  Future<void> _navigateToPostBusiness() async {
    // 업종 기반 포스트 배포 화면으로 이동
  }

  // ==================== Mock 모드 ====================

  void _toggleMockMode() {
    _locationHandler.toggleMockMode(
      onStateChanged: (isEnabled, isVisible) {
        if (mounted) {
          setState(() {
            _isMockModeEnabled = isEnabled;
            _isMockControllerVisible = isVisible;
          });
        }
      },
    );
  }

  Future<void> _setMockPosition(LatLng position) async {
    await _locationHandler.setMockPosition(
      position: position,
      onPositionChanged: (newPosition, address) {
        if (mounted) {
          setState(() {
            _mockPosition = newPosition;
            _mockAddress = address;
            _isMockModeEnabled = true;
            _isMockControllerVisible = true;
          });
        }
      },
    );
  }

  void _moveMockPosition(String direction) async {
    final result = await _locationHandler.moveMockPosition(
      direction: direction,
      currentPosition: _mockPosition,
    );
    
    if (result != null && mounted) {
      final (newPosition, address) = result;
      setState(() {
        _mockPosition = newPosition;
        _mockAddress = address;
      });
    }
  }

  // ==================== 미확인 포스트 ====================

  Future<void> _showUnconfirmedPostsDialog() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    await _uiHelper.showUnconfirmedPostsDialog(
      context: context,
      userId: currentUserId,
      onConfirm: _confirmUnconfirmedPost,
      onDelete: _deleteUnconfirmedPost,
    );
  }

  Future<void> _confirmUnconfirmedPost({
    required String collectionId,
    required String userId,
    required String postId,
    required String creatorId,
    required int reward,
    required String title,
  }) async {
    // 미확인 포스트 확인 로직
  }

  Future<void> _deleteUnconfirmedPost({
    required String collectionId,
    required String userId,
  }) async {
    // 미확인 포스트 삭제 로직
  }

  // ==================== 빌드 메서드 ====================

  @override
  Widget build(BuildContext context) {
    return MapMainWidget(
      mapController: _mapController!,
      currentPosition: _currentPosition,
      currentZoom: _currentZoom,
      markers: _markers,
      posts: _posts,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isPremiumUser: _isPremiumUser,
      userType: _userType,
      longPressedLatLng: _longPressedLatLng,
      isMockModeEnabled: _isMockModeEnabled,
      mockPosition: _mockPosition,
      isMockControllerVisible: _isMockControllerVisible,
      ringCircles: _ringCircles,
      grayPolygons: _grayPolygons,
      homeLocation: _homeLocation,
      workLocations: _workLocations,
      currentWorkplaceIndex: _currentWorkplaceIndex,
      receivablePostCount: _receivablePostCount,
      fogHandler: _fogHandler,
      markerHandler: _markerHandler,
      postHandler: _postHandler,
      locationHandler: _locationHandler,
      filterHandler: _filterHandler,
      onMapReady: _onMapReady,
      onMapMoved: _onMapMoved,
      onTap: (tapPosition, point) {
        setState(() {
          _longPressedLatLng = null;
        });
      },
      onLongPress: (tapPosition, point) => _handleLongPress(point),
      onSecondaryTapDown: (tapPosition, point) {
        setState(() {
          _longPressedLatLng = point;
        });
      },
      onFilterPressed: _showFilterDialog,
      onHomePressed: _moveToHome,
      onWorkplacePressed: _moveToWorkplace,
      onReceivePressed: _receiveNearbyPosts,
      onMockToggle: _toggleMockMode,
      onMockPositionSet: _setMockPosition,
      onMockMove: _moveMockPosition,
    );
  }
}

// Vibration import (필요한 경우)
import 'package:vibration/vibration.dart';
