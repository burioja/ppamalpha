import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../utils/tile_utils.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import 'dart:math';

/// 위치 관리 Handler
/// 
/// GPS, Mock 위치, 집/일터 이동 등 위치 관련 모든 기능
class MapLocationHandler {
  // 위치 상태
  LatLng? currentPosition;
  LatLng? homeLocation;
  List<LatLng> workLocations = [];
  String currentAddress = '위치 불러오는 중...';
  String? errorMessage;

  // Mock 모드
  bool isMockModeEnabled = false;
  LatLng? mockPosition;
  LatLng? originalGpsPosition;
  bool isMockControllerVisible = false;

  // 일터 순환용
  int currentWorkplaceIndex = 0;

  // 마커
  List<Marker> currentMarkers = [];

  /// 위치 초기화
  Future<String?> initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return '위치 권한이 거부되었습니다.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      }

      await getCurrentLocation();
      return null;
    } catch (e) {
      return '위치를 가져오는 중 오류가 발생했습니다: $e';
    }
  }

  /// 현재 GPS 위치 가져오기
  Future<void> getCurrentLocation() async {
    // Mock 모드면 GPS 요청 스킵
    if (isMockModeEnabled && mockPosition != null) {
      debugPrint('🎭 Mock 모드 활성화 - GPS 위치 요청 스킵');
      return;
    }

    try {
      debugPrint('📍 현재 위치 요청 중...');
      
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint('✅ 현재 위치 획득 성공: ${position.latitude}, ${position.longitude}');
      debugPrint('   - 정확도: ${position.accuracy}m');
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
      // 이전 GPS 위치 저장
      final previousGpsPosition = currentPosition;
      currentPosition = newPosition;
      errorMessage = null;

      // 타일 방문 기록
      final tileId = TileUtils.getKm1TileId(newPosition.latitude, newPosition.longitude);
      debugPrint('   - 타일 ID: $tileId');
      await VisitTileService.updateCurrentTileVisit(tileId);

      // 주소 업데이트
      await updateCurrentAddress();
    } catch (e) {
      errorMessage = '현재 위치를 가져올 수 없습니다: $e';
      debugPrint('❌ 위치 가져오기 실패: $e');
    }
  }

  /// 현재 위치 마커 생성
  Marker createCurrentLocationMarker(LatLng position) {
    final marker = Marker(
      point: position,
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
          size: 16,
        ),
      ),
    );

    currentMarkers = [marker];
    return marker;
  }

  /// 주소 업데이트 (GPS 기준)
  Future<String?> updateCurrentAddress() async {
    if (currentPosition == null) return null;

    try {
      final address = await NominatimService.reverseGeocode(currentPosition!);
      currentAddress = address;
      return address;
    } catch (e) {
      currentAddress = '주소 변환 실패';
      debugPrint('❌ 주소 변환 실패: $e');
      return null;
    }
  }

  /// 주소 업데이트 (Mock 위치 기준)
  Future<String?> updateMockAddress(LatLng position) async {
    try {
      final address = await NominatimService.reverseGeocode(position);
      currentAddress = address;
      return address;
    } catch (e) {
      currentAddress = '주소 변환 실패';
      return null;
    }
  }

  /// 집으로 이동
  (LatLng, double)? moveToHome({required double currentZoom}) {
    if (homeLocation != null) {
      return (homeLocation!, currentZoom);
    }
    return null;
  }

  /// 일터로 이동 (순차적)
  (LatLng, double, int)? moveToWorkplace({required double currentZoom}) {
    if (workLocations.isEmpty) return null;

    final targetLocation = workLocations[currentWorkplaceIndex];
    
    // 다음 일터로 인덱스 이동 (순환)
    currentWorkplaceIndex = (currentWorkplaceIndex + 1) % workLocations.length;
    
    return (targetLocation, currentZoom, currentWorkplaceIndex);
  }

  /// Mock 모드 토글
  void toggleMockMode() {
    isMockModeEnabled = !isMockModeEnabled;
    
    if (isMockModeEnabled) {
      isMockControllerVisible = true;
      // 원래 GPS 위치 백업
      originalGpsPosition = currentPosition;
      // Mock 위치가 없으면 현재 GPS 위치를 기본값으로
      if (mockPosition == null && currentPosition != null) {
        mockPosition = currentPosition;
      }
    } else {
      isMockControllerVisible = false;
      // Mock 모드 비활성화 시 원래 GPS 위치로 복원
      if (originalGpsPosition != null) {
        currentPosition = originalGpsPosition;
      }
    }
  }

  /// Mock 위치 설정
  Future<void> setMockPosition(LatLng position) async {
    // 이전 Mock 위치 저장
    final previousPosition = mockPosition;
    
    mockPosition = position;
    
    // Mock 모드에서는 실제 위치도 업데이트
    if (isMockModeEnabled) {
      currentPosition = position;
    }

    // 주소 업데이트
    await updateMockAddress(position);

    // 타일 방문 기록
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    debugPrint('🎭 Mock 위치 타일 방문 기록 업데이트: $tileId');
    await VisitTileService.updateCurrentTileVisit(tileId);
  }

  /// Mock 위치 이동 (화살표)
  Future<void> moveMockPosition(String direction) async {
    if (mockPosition == null) return;

    const double moveDistance = 0.000225; // 약 25m
    LatLng newPosition;

    switch (direction) {
      case 'up':
        newPosition = LatLng(mockPosition!.latitude + moveDistance, mockPosition!.longitude);
        break;
      case 'down':
        newPosition = LatLng(mockPosition!.latitude - moveDistance, mockPosition!.longitude);
        break;
      case 'left':
        newPosition = LatLng(mockPosition!.latitude, mockPosition!.longitude - moveDistance);
        break;
      case 'right':
        newPosition = LatLng(mockPosition!.latitude, mockPosition!.longitude + moveDistance);
        break;
      default:
        return;
    }

    await setMockPosition(newPosition);
  }

  /// Mock 컨트롤러 숨기기
  void hideMockController() {
    isMockControllerVisible = false;
  }

  /// 두 지점 간 거리 계산 (미터)
  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(_degreesToRadians(point1.latitude)) *
            sin(_degreesToRadians(point2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 위치 상태 리셋
  void reset() {
    currentPosition = null;
    homeLocation = null;
    workLocations = [];
    mockPosition = null;
    originalGpsPosition = null;
    isMockModeEnabled = false;
    isMockControllerVisible = false;
    currentWorkplaceIndex = 0;
    currentMarkers = [];
  }

  /// 유효한 위치 반환 (Mock 우선, 없으면 GPS)
  LatLng? get effectivePosition {
    if (isMockModeEnabled && mockPosition != null) {
      return mockPosition;
    }
    return currentPosition;
  }
}

/// Mock 위치 입력 다이얼로그 (UI는 별도 파일로 분리 가능)
Future<LatLng?> showMockPositionInputDialog(BuildContext context, LatLng? currentMockPosition) async {
  final latController = TextEditingController(
    text: currentMockPosition?.latitude.toStringAsFixed(6) ?? '',
  );
  final lngController = TextEditingController(
    text: currentMockPosition?.longitude.toStringAsFixed(6) ?? '',
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Mock 위치 직접 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: latController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: '위도 (Latitude)',
              hintText: '37.5665',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lngController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: '경도 (Longitude)',
              hintText: '126.9780',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '예시: 서울시청 (37.5665, 126.9780)',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
          child: const Text('이동'),
        ),
      ],
    ),
  );

  if (result == true) {
    final lat = double.tryParse(latController.text);
    final lng = double.tryParse(lngController.text);

    if (lat != null && lng != null) {
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return LatLng(lat, lng);
      }
    }
  }

  return null;
}

