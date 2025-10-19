import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user/user_model.dart';
import '../providers/map_filter_provider.dart';
import '../providers/tile_provider.dart' as fog_tile;
import '../providers/mock_location_provider.dart';
import '../providers/marker_provider.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/models/post/post_model.dart';
import '../widgets/map_marker_detail_widget.dart';
import '../widgets/map_longpress_menu_widget.dart';
import '../widgets/map_filter_bar_widget.dart';
import '../widgets/map_user_location_markers_widget.dart';
import '../widgets/map_location_buttons_widget.dart';
import '../widgets/enhanced_mock_location_controller.dart';
import '../utils/client_cluster.dart';
import '../widgets/unified_fog_overlay_widget.dart';
import '../../../utils/tile_utils.dart';

// ✨ 리팩토링된 Controller & State
import '../services/fog/fog_service.dart';
import '../services/markers/marker_app_service.dart';
import '../controllers/location_controller.dart';
import '../controllers/marker_controller.dart';
import '../state/map_state.dart';
import '../widgets/map_filter_dialog.dart';
import '../../../core/services/data/marker_domain_service.dart';
import '../../../core/models/post/post_model.dart';

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

    // 🎯 TileProvider의 핵심 메서드 호출
    // "방문확정 → 레벨1 재계산" 순서 보장
    final tileProvider = context.read<fog_tile.TileProvider>();
    await tileProvider.onLocationUpdate(
      newPosition: position,
      homeLocation: _state.homeLocation,
      workLocations: _state.workLocations,
    );

    // 주소 업데이트
    await _updateCurrentAddress();
    
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
  // 
  // Fog of War는 UnifiedFogOverlayWidget + TileProvider로 자동 관리됨
  // 별도 메서드 불필요

  Future<void> _loadUserLocations() async {
    final result = await FogService.loadUserLocations();
    
    if (mounted) {
      setState(() {
        _state.homeLocation = result.$1;
        _state.workLocations = result.$2;
      });
    }

    // Fog of War는 TileProvider + Consumer가 자동 관리
  }

  // _loadVisitedLocations() - 제거됨 (TileProvider가 자동 처리)
  // _updateGrayAreasWithPreviousPosition() - 제거됨 (TileProvider가 자동 처리)

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
    // MarkerProvider를 통해 Fog 레벨 기반 마커 조회
    final markerProvider = context.read<MarkerProvider>();
    final mockProvider = context.read<MockLocationProvider>();
    
    final effectivePosition = mockProvider.effectivePosition ?? _state.currentPosition;
    
    if (effectivePosition == null) {
      debugPrint('❌ 위치 정보 없음');
      return;
    }
    
    markerProvider.refreshByFogLevel(
      currentPosition: effectivePosition,
      homeLocation: _state.homeLocation,
      workLocations: _state.workLocations,
      userType: _state.userType,
      filters: {
        'showCouponsOnly': _state.showCouponsOnly,
        'myPostsOnly': _state.showMyPostsOnly,
        'minReward': _state.minReward,
        'showUrgentOnly': _state.showUrgentOnly,
        'showVerifiedOnly': _state.showVerifiedOnly,
        'showUnverifiedOnly': _state.showUnverifiedOnly,
      },
    );
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
          MapFilterBarWidget(
            showMyPostsOnly: _state.showMyPostsOnly,
            showCouponsOnly: _state.showCouponsOnly,
            showStampsOnly: _state.showStampsOnly,
            onUpdateMarkers: () {
              _updateMarkers();
            },
            onMyPostsChanged: (value) {
              setState(() {
                _state.showMyPostsOnly = value;
                if (value) {
                  _state.showCouponsOnly = false;
                  _state.showStampsOnly = false;
                }
              });
            },
            onCouponsChanged: (value) {
              setState(() {
                _state.showCouponsOnly = value;
                if (value) {
                  _state.showMyPostsOnly = false;
                  _state.showStampsOnly = false;
                }
              });
            },
            onStampsChanged: (value) {
              setState(() {
                _state.showStampsOnly = value;
                if (value) {
                  _state.showMyPostsOnly = false;
                  _state.showCouponsOnly = false;
                }
              });
            },
          ),
          // Mock 위치 토글 버튼 (필터바 밑)
          Consumer<MockLocationProvider>(
            builder: (context, mockProvider, _) {
              return Positioned(
                top: 75,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: mockProvider.isMockModeEnabled 
                        ? Colors.purple 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      mockProvider.toggleMockMode();
                    },
                    icon: Icon(
                      Icons.location_searching,
                      color: mockProvider.isMockModeEnabled 
                          ? Colors.white 
                          : Colors.purple,
                    ),
                    iconSize: 20,
                  ),
                ),
              );
            },
          ),
          MapLocationButtonsWidget(
            homeLocation: _state.homeLocation,
            workLocations: _state.workLocations,
            onMoveToHome: _moveToHome,
            onMoveToWorkplace: _moveToWorkplace,
            onMoveToCurrentLocation: _moveToCurrentLocation,
          ),
          // Enhanced Mock Location Controller
          Consumer<MockLocationProvider>(
            builder: (context, mockProvider, _) {
              return EnhancedMockLocationController(
                currentPosition: mockProvider.effectivePosition ?? _state.currentPosition,
                isMockModeEnabled: mockProvider.isMockModeEnabled,
                isVisible: mockProvider.isControllerVisible,
                onPositionChanged: (newPosition) async {
                  // Mock 위치 Provider 업데이트
                  mockProvider.setMockPosition(newPosition);
                  
                  // 현재 위치 상태 업데이트
                  setState(() {
                    _state.currentPosition = newPosition;
                  });
                  
                  // 🎯 TileProvider의 핵심 메서드 호출
                  // "방문확정 → 레벨1 재계산" 순서 보장
                  try {
                    debugPrint('🚀 TileProvider.onLocationUpdate 호출 시도...');
                    final tileProvider = context.read<fog_tile.TileProvider>();
                    debugPrint('✅ TileProvider 획득 성공');
                    await tileProvider.onLocationUpdate(
                      newPosition: newPosition,
                      homeLocation: _state.homeLocation,
                      workLocations: _state.workLocations,
                    );
                    debugPrint('✅ onLocationUpdate 완료');
                  } catch (e, stackTrace) {
                    debugPrint('🔥 TileProvider.onLocationUpdate 오류: $e');
                    debugPrint('Stack trace: $stackTrace');
                  }
                  
                  // 1. 현재 위치 마커 업데이트
                  _createCurrentLocationMarker(newPosition);
                  
                  // 2. 지도 중심 이동
                  final currentZoom = _state.mapController?.camera.zoom ?? _state.currentZoom;
                  _state.mapController?.move(newPosition, currentZoom);
                  
                  // 3. 주소 업데이트
                  await _updateCurrentAddress();
                  
                  // 4. 마커 업데이트
                  _updateMarkers();
                  
                  debugPrint('🎭 Mock 위치 업데이트 완료: ${newPosition.latitude}, ${newPosition.longitude}');
                },
                onClose: () {
                  mockProvider.hideController();
                },
              );
            },
          ),
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
        Consumer<fog_tile.TileProvider>(
          builder: (context, tileProvider, _) {
            // visited30Days에서 직접 타일 중심점 계산
            final level2Centers = <LatLng>[];
            for (final tileId in tileProvider.visited30Days) {
              try {
                // 1km 타일 전용 메서드 사용!
                final center = TileUtils.getKm1TileCenter(tileId);
                level2Centers.add(center);
              } catch (e) {
                debugPrint('🔥 타일 중심점 계산 오류: $tileId - $e');
              }
            }
            
            final level1Centers = [
              if (_state.currentPosition != null) _state.currentPosition!,
              if (_state.homeLocation != null) _state.homeLocation!,
              ..._state.workLocations,
            ];
            
            debugPrint('🎯 Level 2 중심점: ${level2Centers.length}개 (visited30Days: ${tileProvider.visited30Days.length}개)');
            debugPrint('🔍 L1 중심점: ${level1Centers.length}개');
            debugPrint('📊 Fog 데이터: L1=${level1Centers.length} L2=${level2Centers.length} visited30Days=${tileProvider.visited30Days.length}');
            
            return UnifiedFogOverlayWidget(
              mapController: _state.mapController!,
              level1Centers: level1Centers,
              level2CentersRaw: level2Centers,
              radiusMeters: 1000.0,
              fogColor: Colors.black.withOpacity(1.0),
              grayColor: Colors.grey.withOpacity(0.33),
            );
          },
        ),
        
        // 집/일터 마커 레이어
        MapUserLocationMarkersWidget(
          homeLocation: _state.homeLocation,
          workLocations: _state.workLocations,
        ),
        
        // 마커 레이어 (Provider에서)
        Consumer<MarkerProvider>(
          builder: (context, markerProvider, _) {
            return MarkerLayer(markers: _state.clusteredMarkers);
          },
        ),
        
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
    // Fog 레벨 체크
    final tileProvider = context.read<fog_tile.TileProvider>();
    
    // Level 1 중심점들 (현재 위치, 집, 일터)
    final level1Centers = <LatLng>[
      if (_state.currentPosition != null) _state.currentPosition!,
      if (_state.homeLocation != null) _state.homeLocation!,
      ..._state.workLocations,
    ];
    
    // 해당 위치의 Fog 레벨 계산
    final fogLevel = FogService.calculateFogLevel(
      position: point,
      level1Centers: level1Centers,
      level2TileIds: tileProvider.visited30Days,
    );
    
    // Level 1에서만 포스트 배포 가능
    if (!FogService.canLongPress(fogLevel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 지역에서는 포스트를 배포할 수 없습니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // 기존 로직
    setState(() {
      _state.longPressedLatLng = point;
    });
    _showLongPressMenu();
  }

  void _showLongPressMenu() {
    _showDeploymentTypeSelectionDialog();
  }

  /// 배포 방식 선택 다이얼로그
  void _showDeploymentTypeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배포 방식 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDeploymentTypeOption(
              icon: Icons.location_on,
              title: '거리배포',
              description: '거리에 마커를 만들고 근접한 사용자가 수령',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _navigateToPostDeploy(DeploymentType.STREET);
              },
            ),
            const SizedBox(height: 12),
            _buildDeploymentTypeOption(
              icon: Icons.mail,
              title: '우편함배포',
              description: '집/일터가 선택 주소인 사용자가 자동 수령',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _navigateToPostDeploy(DeploymentType.MAILBOX);
              },
            ),
            const SizedBox(height: 12),
            _buildDeploymentTypeOption(
              icon: Icons.campaign,
              title: '광고보드배포',
              description: '광고보드 클릭 시 등록된 모든 포스트 수령',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _navigateToPostDeploy(DeploymentType.BILLBOARD);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 배포 방식 옵션 위젯
  Widget _buildDeploymentTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 배포 화면으로 네비게이션
  void _navigateToPostDeploy(DeploymentType deploymentType) {
    if (_state.longPressedLatLng != null) {
      Navigator.pushNamed(
        context,
        '/post-deploy',
        arguments: {
          'location': _state.longPressedLatLng,
          'deploymentType': deploymentType.value,
        },
      );
    }
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

  Future<void> _handleReceivePosts() async {
    // TODO: 수령 로직 구현
    debugPrint('포스트 수령: ${_state.receivablePostCount}개');
  }

  // ==================== 헬퍼 메서드 ====================
  
  Future<void> _loadCustomMarker() async {
    // TODO: 커스텀 마커 로드
  }

  Future<void> _updatePostsBasedOnFogLevel() async {
    _updateMarkers();
  }

  void _updateReceivablePosts() {
    final receivable = _state.markers.where((m) {
      return m.remainingQuantity > 0 && m.isActive;
    }).length;
    
    setState(() {
      _state.receivablePostCount = receivable;
    });
  }
}


