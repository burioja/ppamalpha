import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/map_map_controller.dart';
import '../controllers/map_marker_controller.dart';
import '../controllers/map_clustering_controller.dart';
import '../managers/map_marker_data_manager.dart';
import '../services/map_data_service.dart';
import '../services/map_cache_service.dart';
import '../services/map_batch_request_service.dart';

/// 지도 생명주기와 상태 관리를 담당하는 핸들러
class MapLifecycleHandler {
  final MapMapController _mapController;
  final MapMarkerController _markerController;
  final MapClusteringController _clusteringController;
  final MapMarkerDataManager _dataManager;
  final MapDataService _dataService;
  final MapCacheService _cacheService;
  final MapBatchRequestService _batchService;
  
  // 생명주기 상태
  bool _isInitialized = false;
  bool _isActive = false;
  bool _isVisible = false;
  bool _isInBackground = false;
  
  // 상태 관리
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // 타이머들
  Timer? _backgroundTimer;
  Timer? _refreshTimer;
  
  // 콜백 함수들
  final Function(bool) onLoadingStateChanged;
  final Function(bool, String?) onErrorStateChanged;
  final Function(bool) onMapStateChanged;
  final VoidCallback onInitializationComplete;
  final VoidCallback onCleanupRequired;

  MapLifecycleHandler({
    required MapMapController mapController,
    required MapMarkerController markerController,
    required MapClusteringController clusteringController,
    required MapMarkerDataManager dataManager,
    required MapDataService dataService,
    required MapCacheService cacheService,
    required MapBatchRequestService batchService,
    required this.onLoadingStateChanged,
    required this.onErrorStateChanged,
    required this.onMapStateChanged,
    required this.onInitializationComplete,
    required this.onCleanupRequired,
  }) : _mapController = mapController,
       _markerController = markerController,
       _clusteringController = clusteringController,
       _dataManager = dataManager,
       _dataService = dataService,
       _cacheService = cacheService,
       _batchService = batchService;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isActive => _isActive;
  bool get isVisible => _isVisible;
  bool get isInBackground => _isInBackground;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  /// 지도 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _setLoadingState(true);
      _clearErrorState();
      
      // 1. 지도 컨트롤러 초기화
      await _initializeMapController();
      
      // 2. 마커 컨트롤러 초기화
      await _initializeMarkerController();
      
      // 3. 클러스터링 컨트롤러 초기화
      await _initializeClusteringController();
      
      // 4. 데이터 매니저 초기화
      await _initializeDataManager();
      
      // 5. 서비스들 초기화
      await _initializeServices();
      
      // 6. 초기 데이터 로드
      await _loadInitialData();
      
      _isInitialized = true;
      _isActive = true;
      _onInitializationComplete();
      
    } catch (error) {
      _setErrorState(true, '지도 초기화 실패: $error');
    } finally {
      _setLoadingState(false);
    }
  }

  /// 지도 컨트롤러 초기화
  Future<void> _initializeMapController() async {
    // 지도 스타일 로드
    await _mapController.loadMapStyle(null); // TODO: BuildContext 전달
    
    // 커스텀 마커 아이콘 로드
    await _mapController.loadCustomMarkerIcon();
    
    // 초기 위치 설정
    await _mapController.setInitialLocation();
  }

  /// 마커 컨트롤러 초기화
  Future<void> _initializeMarkerController() async {
    // 기존 마커 정리
    _markerController.dispose();
    
    // 캐시된 마커 데이터 로드
    final cachedMarkers = _cacheService.getCachedMarkers();
    if (cachedMarkers.isNotEmpty) {
      _markerController.setMarkerItems(cachedMarkers);
    }
  }

  /// 클러스터링 컨트롤러 초기화
  Future<void> _initializeClusteringController() async {
    // 클러스터링 상태 초기화
    _clusteringController.reset();
  }

  /// 데이터 매니저 초기화
  Future<void> _initializeDataManager() async {
    // 실시간 리스너 설정
    _dataManager.setupRealtimeListeners();
    
    // 캐시 서비스 연결
    _cacheService.initialize();
  }

  /// 서비스들 초기화
  Future<void> _initializeServices() async {
    // 배치 서비스 초기화
    _batchService.initialize();
    
    // 데이터 서비스 초기화
    await _dataService.initialize();
  }

  /// 초기 데이터 로드
  Future<void> _loadInitialData() async {
    // 현재 위치 기반으로 주변 마커 로드
    final currentPosition = _mapController.currentPosition;
    if (currentPosition != null) {
      await _dataManager.loadMarkersFromFirestore();
      await _dataManager.loadPostsFromFirestore(currentPosition);
    }
  }

  /// 지도 활성화
  void activate() {
    if (!_isActive) {
      _isActive = true;
      _onMapStateChanged();
      
      // 실시간 리스너 재활성화
      _dataManager.setupRealtimeListeners();
      
      // 배치 서비스 재활성화
      _batchService.resume();
      
      // 주기적 새로고침 시작
      _startRefreshTimer();
    }
  }

  /// 지도 비활성화
  void deactivate() {
    if (_isActive) {
      _isActive = false;
      _onMapStateChanged();
      
      // 실시간 리스너 비활성화
      _dataManager.deactivateRealtimeListeners();
      
      // 배치 서비스 일시정지
      _batchService.pause();
      
      // 주기적 새로고침 중지
      _stopRefreshTimer();
    }
  }

  /// 지도 가시성 변경
  void onVisibilityChanged(bool isVisible) {
    _isVisible = isVisible;
    
    if (isVisible) {
      _onMapBecameVisible();
    } else {
      _onMapBecameHidden();
    }
  }

  /// 지도가 보이게 됨
  void _onMapBecameVisible() {
    if (_isActive) {
      // 실시간 리스너 재활성화
      _dataManager.setupRealtimeListeners();
      
      // 캐시 무효화 및 데이터 새로고침
      _refreshDataIfNeeded();
    }
  }

  /// 지도가 숨겨짐
  void _onMapBecameHidden() {
    // 실시간 리스너 비활성화 (배터리 절약)
    _dataManager.deactivateRealtimeListeners();
    
    // 백그라운드 타이머 시작
    _startBackgroundTimer();
  }

  /// 앱이 백그라운드로 이동
  void onAppPaused() {
    _isInBackground = true;
    
    // 실시간 리스너 비활성화
    _dataManager.deactivateRealtimeListeners();
    
    // 배치 서비스 일시정지
    _batchService.pause();
    
    // 백그라운드 타이머 시작
    _startBackgroundTimer();
  }

  /// 앱이 포그라운드로 복귀
  void onAppResumed() {
    _isInBackground = false;
    
    // 백그라운드 타이머 중지
    _stopBackgroundTimer();
    
    if (_isActive && _isVisible) {
      // 실시간 리스너 재활성화
      _dataManager.setupRealtimeListeners();
      
      // 배치 서비스 재활성화
      _batchService.resume();
      
      // 데이터 새로고침
      _refreshDataIfNeeded();
    }
  }

  /// 데이터 새로고침 (필요한 경우)
  void _refreshDataIfNeeded() {
    // 마지막 업데이트로부터 일정 시간이 지났는지 확인
    final lastUpdate = _cacheService.getLastUpdateTime();
    final now = DateTime.now();
    
    if (lastUpdate == null || now.difference(lastUpdate).inMinutes > 5) {
      _refreshData();
    }
  }

  /// 데이터 새로고침
  Future<void> _refreshData() async {
    try {
      _setLoadingState(true);
      
      // 캐시 무효화
      _cacheService.invalidateAllCache();
      
      // 새로운 데이터 로드
      final currentPosition = _mapController.currentPosition;
      if (currentPosition != null) {
        await _dataManager.loadMarkersFromFirestore();
        await _dataManager.loadPostsFromFirestore(currentPosition);
      }
      
      // 에러 상태 초기화
      _clearErrorState();
      
    } catch (error) {
      _setErrorState(true, '데이터 새로고침 실패: $error');
    } finally {
      _setLoadingState(false);
    }
  }

  /// 주기적 새로고침 타이머 시작
  void _startRefreshTimer() {
    _stopRefreshTimer();
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_isActive && _isVisible && !_isInBackground) {
        _refreshData();
      }
    });
  }

  /// 주기적 새로고침 타이머 중지
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// 백그라운드 타이머 시작
  void _startBackgroundTimer() {
    _stopBackgroundTimer();
    _backgroundTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (_isInBackground) {
        _onCleanupRequired();
      }
    });
  }

  /// 백그라운드 타이머 중지
  void _stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  /// 로딩 상태 설정
  void _setLoadingState(bool isLoading) {
    _isLoading = isLoading;
    onLoadingStateChanged(isLoading);
  }

  /// 에러 상태 설정
  void _setErrorState(bool hasError, String? message) {
    _hasError = hasError;
    _errorMessage = message;
    onErrorStateChanged(hasError, message);
  }

  /// 에러 상태 초기화
  void _clearErrorState() {
    _setErrorState(false, null);
  }

  /// 초기화 완료 콜백
  void _onInitializationComplete() {
    onInitializationComplete();
  }

  /// 정리 필요 콜백
  void _onCleanupRequired() {
    onCleanupRequired();
  }

  /// 지도 상태 변경 콜백
  void _onMapStateChanged() {
    onMapStateChanged(_isActive);
  }

  /// 에러 복구 시도
  Future<void> retryOnError() async {
    if (_hasError) {
      await _refreshData();
    }
  }

  /// 지도 정리
  void cleanup() {
    // 모든 타이머 중지
    _stopRefreshTimer();
    _stopBackgroundTimer();
    
    // 실시간 리스너 비활성화
    _dataManager.deactivateRealtimeListeners();
    
    // 배치 서비스 정리
    _batchService.dispose();
    
    // 캐시 서비스 정리
    _cacheService.dispose();
    
    // 컨트롤러들 정리
    _mapController.dispose();
    _markerController.dispose();
    _clusteringController.dispose();
    _dataManager.dispose();
    
    // 상태 초기화
    _isInitialized = false;
    _isActive = false;
    _isVisible = false;
    _isInBackground = false;
    _clearErrorState();
  }

  /// 리소스 정리
  void dispose() {
    cleanup();
  }
}
