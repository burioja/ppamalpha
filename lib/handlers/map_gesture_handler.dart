import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/map_map_controller.dart';
import '../controllers/map_clustering_controller.dart';
import '../managers/map_marker_data_manager.dart';

/// 지도 제스처와 카메라 움직임을 담당하는 핸들러
class MapGestureHandler {
  final MapMapController _mapController;
  final MapClusteringController _clusteringController;
  final MapMarkerDataManager _dataManager;
  
  // 제스처 설정
  static const Duration _cameraMoveDebounce = Duration(milliseconds: 300);
  static const Duration _idleDebounce = Duration(milliseconds: 500);
  static const double _minZoomForClustering = 12.0;
  static const double _maxZoomForClustering = 18.0;
  
  // 타이머들
  Timer? _cameraMoveTimer;
  Timer? _idleTimer;
  
  // 제스처 상태
  bool _isCameraMoving = false;
  bool _isUserInteracting = false;
  LatLngBounds? _lastVisibleBounds;
  
  // 콜백 함수들
  final Function(bool) onCameraStateChanged;
  final Function(LatLngBounds) onVisibleBoundsChanged;
  final Function(double) onZoomChanged;
  final VoidCallback onUserInteractionStarted;
  final VoidCallback onUserInteractionEnded;

  MapGestureHandler({
    required MapMapController mapController,
    required MapClusteringController clusteringController,
    required MapMarkerDataManager dataManager,
    required this.onCameraStateChanged,
    required this.onVisibleBoundsChanged,
    required this.onZoomChanged,
    required this.onUserInteractionStarted,
    required this.onUserInteractionEnded,
  }) : _mapController = mapController,
       _clusteringController = clusteringController,
       _dataManager = dataManager;

  // Getters
  bool get isCameraMoving => _isCameraMoving;
  bool get isUserInteracting => _isUserInteracting;
  LatLngBounds? get lastVisibleBounds => _lastVisibleBounds;

  /// 카메라 움직임 시작 처리
  void onCameraMove(CameraPosition position) {
    _isCameraMoving = true;
    onCameraStateChanged(true);
    
    // 이전 타이머 취소
    _cameraMoveTimer?.cancel();
    
    // 새로운 타이머 시작
    _cameraMoveTimer = Timer(_cameraMoveDebounce, () {
      _onCameraMoveDebounced(position);
    });
  }

  /// 디바운스된 카메라 움직임 처리
  void _onCameraMoveDebounced(CameraPosition position) {
    // 줌 레벨에 따른 클러스터링 업데이트
    _updateClusteringBasedOnZoom(position.zoom);
    
    // 가시 영역 계산
    _calculateVisibleBounds();
    
    // 마커 데이터 로드 (필요한 경우)
    _loadMarkersIfNeeded();
  }

  /// 카메라 정지 처리
  void onCameraIdle() {
    _isCameraMoving = false;
    onCameraStateChanged(false);
    
    // 이전 타이머 취소
    _idleTimer?.cancel();
    
    // 새로운 타이머 시작
    _idleTimer = Timer(_idleDebounce, () {
      _onCameraIdleDebounced();
    });
  }

  /// 디바운스된 카메라 정지 처리
  void _onCameraIdleDebounced() {
    // 최종 가시 영역 업데이트
    _updateFinalVisibleBounds();
    
    // 사용자 상호작용 종료
    if (_isUserInteracting) {
      _isUserInteracting = false;
      onUserInteractionEnded();
    }
  }

  /// 줌 레벨에 따른 클러스터링 업데이트
  void _updateClusteringBasedOnZoom(double zoom) {
    if (zoom < _minZoomForClustering) {
      // 낮은 줌: 클러스터링 활성화
      _clusteringController.updateClustering(zoom);
    } else if (zoom > _maxZoomForClustering) {
      // 높은 줌: 개별 마커 표시
      _clusteringController.updateClustering(zoom);
    }
    
    // 줌 변경 알림
    onZoomChanged(zoom);
  }

  /// 가시 영역 계산
  void _calculateVisibleBounds() {
    final mapController = _mapController.mapController;
    if (mapController != null) {
      mapController.getVisibleRegion().then((bounds) {
        if (bounds != null && _hasBoundsChanged(bounds)) {
          _lastVisibleBounds = bounds;
          onVisibleBoundsChanged(bounds);
        }
      });
    }
  }

  /// 최종 가시 영역 업데이트
  void _updateFinalVisibleBounds() {
    final mapController = _mapController.mapController;
    if (mapController != null) {
      mapController.getVisibleRegion().then((bounds) {
        if (bounds != null) {
          _lastVisibleBounds = bounds;
          onVisibleBoundsChanged(bounds);
          
          // 가시 영역 내 마커 데이터 로드
          _loadMarkersInVisibleBounds(bounds);
        }
      });
    }
  }

  /// 가시 영역 변경 확인
  bool _hasBoundsChanged(LatLngBounds newBounds) {
    if (_lastVisibleBounds == null) return true;
    
    final oldBounds = _lastVisibleBounds!;
    const tolerance = 0.001; // 약 100m
    
    return (newBounds.northeast.latitude - oldBounds.northeast.latitude).abs() > tolerance ||
           (newBounds.northeast.longitude - oldBounds.northeast.longitude).abs() > tolerance ||
           (newBounds.southwest.latitude - oldBounds.southwest.latitude).abs() > tolerance ||
           (newBounds.southwest.longitude - oldBounds.southwest.longitude).abs() > tolerance;
  }

  /// 필요한 경우 마커 데이터 로드
  void _loadMarkersIfNeeded() {
    // 카메라가 빠르게 움직이는 중에는 로드하지 않음
    if (_isCameraMoving) return;
    
    // 마지막 로드로부터 일정 시간이 지났는지 확인
    // TODO: 로드 간격 제어 로직 구현
  }

  /// 가시 영역 내 마커 데이터 로드
  void _loadMarkersInVisibleBounds(LatLngBounds bounds) {
    if (_lastVisibleBounds != null && !_hasBoundsChanged(bounds)) {
      // 가시 영역이 크게 변경되지 않았으면 로드하지 않음
      return;
    }
    
    // 가시 영역 내 마커 데이터 로드
    _dataManager.loadMarkersInBounds(bounds);
  }

  /// 사용자 상호작용 시작
  void onUserInteractionStarted() {
    _isUserInteracting = true;
    onUserInteractionStarted();
    
    // 실시간 리스너 비활성화 (성능 최적화)
    _dataManager.deactivateRealtimeListeners();
  }

  /// 사용자 상호작용 종료
  void onUserInteractionEnded() {
    _isUserInteracting = false;
    onUserInteractionEnded();
    
    // 실시간 리스너 재활성화
    _dataManager.setupRealtimeListeners();
  }

  /// 지도 탭 처리
  void onMapTap(LatLng position) {
    // 사용자 상호작용 시작
    onUserInteractionStarted();
    
    // 탭 위치에서 마커 확인
    _checkMarkerAtPosition(position);
  }

  /// 지도 롱프레스 처리
  void onMapLongPress(LatLng position) {
    // 사용자 상호작용 시작
    onUserInteractionStarted();
    
    // 롱프레스 위치에서 마커 확인
    _checkMarkerAtPosition(position);
  }

  /// 특정 위치에서 마커 확인
  void _checkMarkerAtPosition(LatLng position) {
    // TODO: 해당 위치에 마커가 있는지 확인하는 로직 구현
    // 마커가 있으면 선택, 없으면 새 마커 생성 옵션 제공
  }

  /// 줌 제스처 처리
  void onZoomChanged(double zoom) {
    // 줌 레벨에 따른 클러스터링 업데이트
    _updateClusteringBasedOnZoom(zoom);
    
    // 줌 변경 알림
    onZoomChanged(zoom);
  }

  /// 스크롤 제스처 처리
  void onScroll() {
    // 사용자 상호작용 시작
    onUserInteractionStarted();
    
    // 스크롤 중에는 실시간 업데이트 비활성화
    _dataManager.deactivateRealtimeListeners();
  }

  /// 스크롤 종료 처리
  void onScrollEnd() {
    // 사용자 상호작용 종료
    onUserInteractionEnded();
    
    // 실시간 리스너 재활성화
    _dataManager.setupRealtimeListeners();
  }

  /// 제스처 상태 초기화
  void reset() {
    _isCameraMoving = false;
    _isUserInteracting = false;
    _lastVisibleBounds = null;
    
    _cameraMoveTimer?.cancel();
    _idleTimer?.cancel();
    
    onCameraStateChanged(false);
    onUserInteractionEnded();
  }

  /// 리소스 정리
  void dispose() {
    _cameraMoveTimer?.cancel();
    _idleTimer?.cancel();
  }
}
