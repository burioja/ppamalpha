import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/services/location/nominatim_service.dart';

/// 위치 관련 로직을 관리하는 컨트롤러
class LocationController {
  /// 위치 권한 확인 및 요청
  static Future<LocationPermission> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    return permission;
  }

  /// 현재 위치 가져오기
  /// 
  /// [isMockMode]: Mock 모드 여부
  /// [mockPosition]: Mock 위치 (Mock 모드일 때)
  /// 
  /// Returns: 현재 위치 LatLng 또는 null
  static Future<LatLng?> getCurrentLocation({
    bool isMockMode = false,
    LatLng? mockPosition,
  }) async {
    // Mock 모드가 활성화되어 있으면 GPS 위치 요청하지 않음
    if (isMockMode && mockPosition != null) {
      return mockPosition;
    }
    
    try {
      debugPrint('📍 현재 위치 요청 중...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('✅ 현재 위치 획득 성공: ${position.latitude}, ${position.longitude}');
      debugPrint('   - 정확도: ${position.accuracy}m');
      debugPrint('   - 고도: ${position.altitude}m');
      debugPrint('   - 속도: ${position.speed}m/s');
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('❌ 현재 위치 가져오기 실패: $e');
      return null;
    }
  }

  /// 현재 위치 마커 생성
  static Marker createCurrentLocationMarker(LatLng position) {
    return Marker(
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
  }

  /// 좌표로 주소 가져오기
  static Future<String> getAddressFromLatLng(LatLng position) async {
    try {
      final address = await NominatimService.reverseGeocode(position);
      
      if (address != null && address.isNotEmpty) {
        return address;
      }
      
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } catch (e) {
      debugPrint('❌ 주소 변환 실패: $e');
      return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    }
  }

  /// 타일 방문 기록 업데이트
  static Future<String> updateTileVisit(LatLng position) async {
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    debugPrint('타일 방문 기록 업데이트: $tileId');
    await VisitTileService.updateCurrentTileVisit(tileId);
    return tileId;
  }

  /// 두 위치 간 거리 계산 (미터)
  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// 수집 가능 거리 확인 (200m 이내)
  static bool isWithinCollectionRange(LatLng userPosition, LatLng targetPosition) {
    final distance = calculateDistance(userPosition, targetPosition);
    return distance <= 200.0;
  }

  /// 위치 권한 에러 메시지 반환
  static String getPermissionErrorMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.denied:
        return '위치 권한이 거부되었습니다.';
      case LocationPermission.deniedForever:
        return '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      case LocationPermission.unableToDetermine:
        return '위치 권한을 확인할 수 없습니다.';
      default:
        return '';
    }
  }
}

