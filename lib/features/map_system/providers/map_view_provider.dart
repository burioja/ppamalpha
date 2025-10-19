import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 지도 뷰 상태 관리 Provider
/// 
/// **책임**: 카메라 위치/줌, 선택된 마커, 보이는 영역(Bounds)만 관리
/// **금지**: Firebase 호출, 복잡한 로직, IO 작업
class MapViewProvider with ChangeNotifier {
  // ==================== 상태 ====================
  
  /// 지도 중심 좌표
  LatLng _center = const LatLng(37.5665, 126.9780); // 서울 기본 위치
  
  /// 현재 줌 레벨
  double _zoom = 15.0;
  
  /// 현재 보이는 지도 영역
  LatLngBounds? _bounds;
  
  /// 선택된 마커 ID
  String? _selectedMarkerId;
  
  /// 지도 컨트롤러 (외부에서 주입)
  MapController? _mapController;

  // ==================== Getters ====================
  
  LatLng get center => _center;
  double get zoom => _zoom;
  LatLngBounds? get bounds => _bounds;
  String? get selectedMarkerId => _selectedMarkerId;
  MapController? get mapController => _mapController;

  // ==================== 액션 ====================
  
  /// 지도 컨트롤러 설정
  void setMapController(MapController controller) {
    _mapController = controller;
  }
  
  /// 카메라를 특정 위치로 이동
  void moveCamera(LatLng newCenter, {double? newZoom}) {
    _center = newCenter;
    if (newZoom != null) {
      _zoom = newZoom;
    }
    _mapController?.move(_center, _zoom);
    notifyListeners();
  }
  
  /// 줌 레벨만 변경
  void setZoom(double newZoom) {
    _zoom = newZoom.clamp(10.0, 18.0);
    _mapController?.move(_center, _zoom);
    notifyListeners();
  }
  
  /// 현재 보이는 영역 업데이트
  void setBounds(LatLngBounds newBounds) {
    _bounds = newBounds;
    notifyListeners();
  }
  
  /// 지도 상태 업데이트 (중심 + 줌)
  void updateMapState(LatLng newCenter, double newZoom) {
    _center = newCenter;
    _zoom = newZoom.clamp(10.0, 18.0);
    notifyListeners();
  }
  
  /// 마커 선택
  void selectMarker(String? markerId) {
    _selectedMarkerId = markerId;
    notifyListeners();
  }
  
  /// 마커 선택 해제
  void clearSelection() {
    _selectedMarkerId = null;
    notifyListeners();
  }
  
  /// 특정 위치로 애니메이션 이동
  void animateToLocation(LatLng location, {double? targetZoom}) {
    final zoom = targetZoom ?? _zoom;
    moveCamera(location, newZoom: zoom);
  }
  
  /// 줌 인
  void zoomIn() {
    setZoom(_zoom + 1);
  }
  
  /// 줌 아웃
  void zoomOut() {
    setZoom(_zoom - 1);
  }
  
  /// 초기 위치로 리셋
  void reset() {
    _center = const LatLng(37.5665, 126.9780);
    _zoom = 15.0;
    _bounds = null;
    _selectedMarkerId = null;
    notifyListeners();
  }
  
  /// 디버그 정보
  Map<String, dynamic> getDebugInfo() {
    return {
      'center': '${_center.latitude}, ${_center.longitude}',
      'zoom': _zoom,
      'hasBounds': _bounds != null,
      'selectedMarker': _selectedMarkerId,
    };
  }
}

