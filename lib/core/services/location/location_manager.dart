import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../features/map_system/services/fog_of_war/visit_manager.dart';

/// 위치 관리자
class LocationManager {
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  int _currentZoom = 13;
  
  final VisitManager _visitManager = VisitManager();
  
  // 위치 변경 콜백
  Function(LatLng position)? onPositionChanged;
  Function(LatLng position)? onLocationUpdate;
  
  /// 위치 추적 시작
  Future<void> startLocationTracking() async {
    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied');
      return;
    }
    
    // 위치 서비스 활성화 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return;
    }
    
    // 위치 스트림 시작
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m 이동 시 업데이트
      ),
    ).listen((Position position) {
      _currentPosition = LatLng(position.latitude, position.longitude);
      
      // 콜백 호출
      onPositionChanged?.call(_currentPosition!);
      onLocationUpdate?.call(_currentPosition!);
      
      // 방문 기록 저장
      _recordCurrentLocationVisit();
    });
  }
  
  /// 위치 추적 중지
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
  
  /// 현재 위치 가져오기
  Future<LatLng?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
      return _currentPosition;
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }
  
  /// 현재 위치 반환
  LatLng? get currentPosition => _currentPosition;
  
  /// 현재 줌 레벨 설정
  void setCurrentZoom(int zoom) {
    _currentZoom = zoom;
  }
  
  /// 현재 줌 레벨 반환
  int get currentZoom => _currentZoom;
  
  /// 현재 위치 방문 기록 저장
  Future<void> _recordCurrentLocationVisit() async {
    if (_currentPosition != null) {
      await _visitManager.recordCurrentLocationVisit(_currentPosition!, _currentZoom);
    }
  }
  
  /// 수동으로 방문 기록 저장
  Future<void> recordVisit(LatLng position) async {
    await _visitManager.recordVisit(position, _currentZoom);
  }
  
  /// 배터리 최적화를 위한 위치 업데이트 주기 조절
  void optimizeForBattery(bool isLowBattery) {
    stopLocationTracking();
    
    if (isLowBattery) {
      // 배터리 부족 시 업데이트 주기 늘림
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100, // 100m 이동 시 업데이트
        ),
      ).listen((Position position) {
        _currentPosition = LatLng(position.latitude, position.longitude);
        onPositionChanged?.call(_currentPosition!);
        _recordCurrentLocationVisit();
      });
    } else {
      // 정상 배터리 시 고정밀도 추적
      startLocationTracking();
    }
  }
  
  /// 리소스 정리
  void dispose() {
    stopLocationTracking();
  }
}
