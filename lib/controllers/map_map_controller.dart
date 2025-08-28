import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';

/// 지도 제어를 담당하는 컨트롤러
class MapMapController {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 15.0;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  
  // 디바운싱을 위한 타이머
  Timer? _debounceTimer;
  
  // 가시 영역 관리
  LatLngBounds? _visibleBounds;
  
  // Getters
  GoogleMapController? get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  double get currentZoom => _currentZoom;
  String? get mapStyle => _mapStyle;
  BitmapDescriptor? get customMarkerIcon => _customMarkerIcon;
  LatLngBounds? get visibleBounds => _visibleBounds;

  /// 지도 컨트롤러 설정
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  /// 초기 위치 설정
  Future<void> setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      _currentPosition = position != null
          ? LatLng(position.latitude, position.longitude)
          : const LatLng(37.495872, 127.025046); // 기본 위치 (강남)
    } catch (_) {
      _currentPosition = const LatLng(37.492894, 127.012469); // 폴백 위치
    }
  }

  /// 지도 스타일 로드
  Future<void> loadMapStyle(BuildContext context) async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      _mapStyle = style;
      
      // 컨트롤러가 이미 설정되어 있다면 스타일 적용
      if (_mapController != null) {
        _mapController!.setMapStyle(_mapStyle);
      }
    } catch (e) {
      debugPrint('지도 스타일 로드 실패: $e');
    }
  }

  /// 커스텀 마커 아이콘 로드
  Future<void> loadCustomMarkerIcon() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/슽.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      const double targetSize = 32.0; // 48 -> 32로 최적화
      
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        drawWidth = targetSize;
        drawHeight = targetSize / imageRatio;
        offsetY = (targetSize - drawHeight) / 2;
      }
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
      
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final ByteData? resizedBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedBytes != null) {
        final Uint8List resizedUint8List = resizedBytes.buffer.asUint8List();
        _customMarkerIcon = BitmapDescriptor.fromBytes(resizedUint8List);
      }
    } catch (e) {
      debugPrint('커스텀 마커 로드 실패: $e');
    }
  }

  /// 카메라 이동 처리 (디바운싱 적용)
  void onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
    
    // 디바운싱으로 과도한 호출 방지
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _calculateVisibleBounds();
    });
  }

  /// 카메라 이동 완료 시 가시 영역 계산
  void onCameraIdle() {
    _debounceTimer?.cancel();
    _calculateVisibleBounds();
  }

  /// 현재 가시 영역 계산
  Future<void> _calculateVisibleBounds() async {
    if (_mapController != null) {
      try {
        final bounds = await _mapController!.getVisibleRegion();
        _visibleBounds = bounds;
        debugPrint('가시 영역 업데이트: ${bounds.northeast}, ${bounds.southwest}');
      } catch (e) {
        debugPrint('가시 영역 계산 실패: $e');
      }
    }
  }

  /// 현재 위치로 이동
  Future<void> goToCurrentLocation() async {
    if (_mapController != null && _currentPosition != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  /// 특정 위치로 이동
  Future<void> goToLocation(LatLng location) async {
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLng(location),
      );
    }
  }

  /// 줌 레벨 변경
  Future<void> setZoom(double zoom) async {
    if (_mapController != null) {
      _currentZoom = zoom;
      await _mapController!.animateCamera(
        CameraUpdate.zoomTo(zoom),
      );
    }
  }

  /// 리소스 정리
  void dispose() {
    _debounceTimer?.cancel();
    _mapController = null;
  }
}
