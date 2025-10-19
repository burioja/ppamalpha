import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

/// 위치 도메인 서비스
/// 
/// **책임**: 위치 관련 순수 도메인 로직
/// **원칙**: 계산, 검증, 변환만
class LocationDomainService {
  // ==================== 거리 계산 ====================

  /// 두 좌표 간 거리 계산 (미터)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000;
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// 반경 내에 있는지 확인
  static bool isWithinRadius({
    required LatLng center,
    required LatLng point,
    required double radiusMeters,
  }) {
    return calculateDistance(center, point) <= radiusMeters;
  }

  /// 여러 점 중 가장 가까운 점 찾기
  static LatLng? findNearest({
    required LatLng center,
    required List<LatLng> points,
  }) {
    if (points.isEmpty) return null;

    LatLng? nearest;
    double minDistance = double.infinity;

    for (final point in points) {
      final distance = calculateDistance(center, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = point;
      }
    }

    return nearest;
  }

  // ==================== 좌표 검증 ====================

  /// 한국 영역 내 좌표인지 확인
  static bool isInKorea(LatLng location) {
    return location.latitude >= 33.0 &&
        location.latitude <= 39.0 &&
        location.longitude >= 124.0 &&
        location.longitude <= 132.0;
  }

  /// 서울 영역 내 좌표인지 확인
  static bool isInSeoul(LatLng location) {
    return location.latitude >= 37.4 &&
        location.latitude <= 37.7 &&
        location.longitude >= 126.7 &&
        location.longitude <= 127.2;
  }

  /// 유효한 좌표인지 확인
  static bool isValidCoordinate(LatLng location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  // ==================== 좌표 변환 ====================

  /// Position을 LatLng으로 변환
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }

  /// LatLng을 문자열로 변환
  static String latLngToString(LatLng location, {int precision = 6}) {
    return '${location.latitude.toStringAsFixed(precision)}, ${location.longitude.toStringAsFixed(precision)}';
  }

  /// 문자열을 LatLng으로 파싱
  static LatLng? parseLatLng(String str) {
    try {
      final parts = str.split(',');
      if (parts.length != 2) return null;

      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());

      if (lat == null || lng == null) return null;

      return LatLng(lat, lng);
    } catch (e) {
      return null;
    }
  }

  // ==================== 영역 계산 ====================

  /// 중심점과 반경으로 경계 계산
  static (double north, double south, double east, double west) calculateBounds({
    required LatLng center,
    required double radiusMeters,
  }) {
    const earthRadius = 6371000;
    final latRad = center.latitude * (pi / 180);
    
    final dLat = radiusMeters / earthRadius;
    final dLon = radiusMeters / (earthRadius * cos(latRad));

    return (
      center.latitude + (dLat * 180 / pi),
      center.latitude - (dLat * 180 / pi),
      center.longitude + (dLon * 180 / pi),
      center.longitude - (dLon * 180 / pi),
    );
  }
}

