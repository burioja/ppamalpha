import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

// 컨트롤러들
import '../../controllers/map_map_controller.dart';
import '../../controllers/map_marker_controller.dart';
import '../../controllers/map_clustering_controller.dart';
import '../../controllers/map_fog_of_war_controller.dart';

// 매니저들
import '../../managers/map_marker_data_manager.dart';

// 서비스들
import '../../services/map_data_service.dart';
import '../../services/map_cache_service.dart';
import '../../services/map_batch_request_service.dart';
import '../../services/map_visit_service.dart';

// 핸들러들
import '../../handlers/map_interaction_handler.dart';
import '../../handlers/map_gesture_handler.dart';
import '../../handlers/map_lifecycle_handler.dart';

// 위젯들
import '../../widgets/map_filter_bar.dart';
import '../../widgets/map_popup_widget.dart';
import '../../widgets/map_info_dialog.dart';

// 프로바이더들
import '../../providers/map_filter_provider.dart';

// 모델들
import '../../models/post_model.dart';

/// 리팩토링된 지도 화면
/// 모든 기능이 분리된 컴포넌트들로 구성되어 유지보수성이 크게 향상됨
class MapScreenRefactored extends StatefulWidget {
  const MapScreenRefactored({super.key});

  @override
  State<MapScreenRefactored> createState() => _MapScreenRefactoredState();
}

class _MapScreenRefactoredState extends State<MapScreenRefactored>
    with WidgetsBindingObserver {
  // 컨트롤러들
  late MapMapController _mapController;
  late MapMarkerController _markerController;
  late MapClusteringController _clusteringController;
  late MapFogOfWarController _fogOfWarController;
  
  // 매니저들
  late MapMarkerDataManager _dataManager;
  
  // 서비스들
  late MapDataService _dataService;
  late MapCacheService _cacheService;
  late MapBatchRequestService _batchService;
  late MapVisitService _visitService;
  
  // 핸들러들
  late MapInteractionHandler _interactionHandler;
  late MapGestureHandler _gestureHandler;
  late MapLifecycleHandler _lifecycleHandler;
  
  // 상태 변수들
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isMapActive = false;
  
  // 필터 상태
  bool _showCouponsOnly = false;
  bool _showMyPostsOnly = false;
  
  // 마커 상태
  Set<Marker> _markers = {};
  
  // Fog of War state
  Set<Circle> _fogOfWarCircles = {};
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeComponents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeComponents();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        _lifecycleHandler.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        _lifecycleHandler.onAppResumed();
        break;
      default:
        break;
    }
  }

  /// 컴포넌트들 초기화
  Future<void> _initializeComponents() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // 1. 컨트롤러들 초기화
      _mapController = MapMapController();
      _markerController = MapMarkerController();
      _clusteringController = MapClusteringController(_markerController);
      _fogOfWarController = MapFogOfWarController();

      // 2. 매니저들 초기화
      _dataManager = MapMarkerDataManager(_markerController);

      // 3. 서비스들 초기화
      _dataService = MapDataService();
      _cacheService = MapCacheService();
      _batchService = MapBatchRequestService();
      _visitService = MapVisitService();
      
      // 방문 서비스 초기화
      await _cacheService.initialize();
      _visitService.initialize();

      // 4. 핸들러들 초기화
      _interactionHandler = MapInteractionHandler(
        markerController: _markerController,
        onNavigateToLocation: _onNavigateToLocation,
        onCollectPost: _onCollectPost,
        onSharePost: _onSharePost,
        onEditPost: _onEditPost,
        onDeletePost: _onDeletePost,
        onShowSnackBar: _onShowSnackBar,
      );

      _gestureHandler = MapGestureHandler(
        mapController: _mapController,
        clusteringController: _clusteringController,
        dataManager: _dataManager,
        onCameraStateChanged: _onCameraStateChanged,
        onVisibleBoundsChanged: _onVisibleBoundsChanged,
        onZoomChanged: _onZoomChanged,
        onUserInteractionStarted: _onUserInteractionStarted,
        onUserInteractionEnded: _onUserInteractionEnded,
      );

      _lifecycleHandler = MapLifecycleHandler(
        mapController: _mapController,
        markerController: _markerController,
        clusteringController: _clusteringController,
        dataManager: _dataManager,
        dataService: _dataService,
        cacheService: _cacheService,
        batchService: _batchService,
        onLoadingStateChanged: _onLoadingStateChanged,
        onErrorStateChanged: _onErrorStateChanged,
        onMapStateChanged: _onMapStateChanged,
        onInitializationComplete: _onInitializationComplete,
        onCleanupRequired: _onCleanupRequired,
      );

      // 5. 생명주기 핸들러 초기화
      await _lifecycleHandler.initialize();
      
      // 6. Fog of War 데이터 로드
      await _fogOfWarController.loadVisitsAndBuildFog();
      _updateFogOfWar();

    } catch (error) {
      setState(() {
        _hasError = true;
        _errorMessage = '초기화 실패: $error';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 컴포넌트들 정리
  void _disposeComponents() {
    _lifecycleHandler.dispose();
    _gestureHandler.dispose();
    _interactionHandler.dispose();
    _visitService.dispose();
    _batchService.dispose();
    _cacheService.dispose();
    _dataService.dispose();
    _dataManager.dispose();
    _clusteringController.dispose();
    _markerController.dispose();
    _mapController.dispose();
    _fogOfWarController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '알 수 없는 오류',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _retryInitialization,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 지도
          _buildMap(),
          
          // 상단 필터 바
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _buildFilterBar(),
          ),
          
          // 현재 위치 버튼
          Positioned(
            bottom: 100,
            right: 16,
            child: _buildCurrentLocationButton(),
          ),
          
          // 팝업 위젯
          if (_interactionHandler.isPopupVisible)
            Positioned(
              bottom: 200,
              left: 16,
              right: 16,
              child: _interactionHandler.buildPopupWidget()!,
            ),
          
          // 다이얼로그 위젯
          if (_interactionHandler.isDialogVisible)
            _interactionHandler.buildDialogWidget()!,
          
          // 로딩 인디케이터
          if (_isLoading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// 지도 위젯 빌드
  Widget _buildMap() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.5665, 126.9780), // 서울 시청
        zoom: 15.0,
      ),
      onMapCreated: _onMapCreated,
      markers: _markers,
      circles: _fogOfWarCircles, // Fog of War 추가
      onCameraMove: _gestureHandler.onCameraMove,
      onCameraIdle: _gestureHandler.onCameraIdle,
      onTap: (_) => _interactionHandler.onMapTap(),
      onLongPress: _interactionHandler.onMapLongPress,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  /// 필터 바 빌드
  Widget _buildFilterBar() {
    return MapFilterBar(
      showCouponsOnly: _showCouponsOnly,
      showMyPostsOnly: _showMyPostsOnly,
      onCouponsOnlyChanged: (value) {
        setState(() {
          _showCouponsOnly = value;
        });
        _updateMarkers();
      },
      onMyPostsOnlyChanged: (value) {
        setState(() {
          _showMyPostsOnly = value;
        });
        _updateMarkers();
      },
      onFilterChanged: _updateMarkers,
    );
  }

  /// 현재 위치 버튼 빌드
  Widget _buildCurrentLocationButton() {
    return FloatingActionButton(
      heroTag: 'current_location',
      onPressed: _goToCurrentLocation,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.my_location,
        color: Colors.blue[600],
      ),
    );
  }

  /// 지도 생성 완료 콜백
  void _onMapCreated(GoogleMapController controller) {
    _mapController.setMapController(controller);
    _updateMarkers();
  }

  /// 마커 업데이트 (방문 지역 기반 필터링 적용)
  void _updateMarkers() {
    if (!mounted) return;
    
    // 방문 가능한 지역의 마커만 표시
    final visibleMarkers = _markerController.getVisibleMarkers(
      _mapController.currentPosition,
      _fogOfWarController.visitedLocations,
    );
    
    final visiblePosts = _markerController.getVisiblePosts(
      _mapController.currentPosition,
      _fogOfWarController.visitedLocations,
    );
    
    // 임시로 원래 마커들을 저장하고 보이는 것들만 설정
    final originalMarkers = _markerController.markerItems;
    final originalPosts = _markerController.posts;
    
    _markerController.setMarkerItems(visibleMarkers);
    _markerController.setPosts(visiblePosts);
    
    // 클러스터링 업데이트
    _clusteringController.updateClustering(
      _mapController.currentZoom,
      showCouponsOnly: _showCouponsOnly,
      showMyPostsOnly: _showMyPostsOnly,
      currentUserId: null,
    );
    
    // 원래 마커들로 복원
    _markerController.setMarkerItems(originalMarkers);
    _markerController.setPosts(originalPosts);
    
    setState(() {
      _markers = _clusteringController.clusteredMarkers;
    });
  }
  
  /// Fog of War 업데이트
  void _updateFogOfWar() {
    if (!mounted) return;
    
    setState(() {
      _fogOfWarCircles = _fogOfWarController.fogOfWarCircles;
    });
  }

  /// 현재 위치로 이동
  Future<void> _goToCurrentLocation() async {
    try {
      await _mapController.goToCurrentLocation();
      
      // 현재 위치 방문 기록 추가
      if (_mapController.currentPosition != null) {
        await _visitService.recordCurrentLocationVisit(_mapController.currentPosition!);
        _fogOfWarController.updateCurrentPosition(_mapController.currentPosition!);
        _updateFogOfWar();
        _updateMarkers();
      }
    } catch (error) {
      _onShowSnackBar('현재 위치를 가져올 수 없습니다: $error');
    }
  }

  // 콜백 함수들

  /// 길찾기 실행
  void _onNavigateToLocation(LatLng position) {
    // TODO: 길찾기 기능 구현
    _onShowSnackBar('길찾기 기능은 준비 중입니다');
  }

  /// 포스트 수집
  void _onCollectPost(PostModel post) {
    // TODO: 포스트 수집 기능 구현
    _onShowSnackBar('포스트가 수집되었습니다');
  }

  /// 포스트 공유
  void _onSharePost(PostModel post) {
    // TODO: 포스트 공유 기능 구현
    _onShowSnackBar('포스트 공유 기능은 준비 중입니다');
  }

  /// 포스트 편집
  void _onEditPost(PostModel post) {
    // TODO: 포스트 편집 기능 구현
    _onShowSnackBar('포스트 편집 기능은 준비 중입니다');
  }

  /// 포스트 삭제
  void _onDeletePost(PostModel post) {
    // TODO: 포스트 삭제 기능 구현
    _onShowSnackBar('포스트가 삭제되었습니다');
  }

  /// 스낵바 표시
  void _onShowSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 카메라 상태 변경
  void _onCameraStateChanged(bool isMoving) {
    // TODO: 카메라 움직임 상태에 따른 UI 업데이트
  }

  /// 가시 영역 변경
  void _onVisibleBoundsChanged(LatLngBounds bounds) {
    // 현재 위치 업데이트 시 Fog of War 갱신
    if (_mapController.currentPosition != null) {
      _fogOfWarController.updateCurrentPosition(_mapController.currentPosition!);
      _updateFogOfWar();
      _updateMarkers(); // 마커도 다시 필터링
    }
  }

  /// 줌 변경
  void _onZoomChanged(double zoom) {
    // 줌 변경시 마커 클러스터링 재계산
    _updateMarkers();
  }

  /// 사용자 상호작용 시작
  void _onUserInteractionStarted() {
    // TODO: 사용자 상호작용 중 UI 상태 업데이트
  }

  /// 사용자 상호작용 종료
  void _onUserInteractionEnded() {
    // TODO: 사용자 상호작용 종료 후 UI 상태 업데이트
  }

  /// 로딩 상태 변경
  void _onLoadingStateChanged(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  /// 에러 상태 변경
  void _onErrorStateChanged(bool hasError, String? message) {
    if (mounted) {
      setState(() {
        _hasError = hasError;
        _errorMessage = message;
      });
    }
  }

  /// 지도 상태 변경
  void _onMapStateChanged(bool isActive) {
    if (mounted) {
      setState(() {
        _isMapActive = isActive;
      });
    }
  }

  /// 초기화 완료
  void _onInitializationComplete() {
    _onShowSnackBar('지도가 준비되었습니다');
  }

  /// 정리 필요
  void _onCleanupRequired() {
    // TODO: 메모리 정리 및 최적화
  }

  /// 초기화 재시도
  Future<void> _retryInitialization() async {
    await _initializeComponents();
  }
}
