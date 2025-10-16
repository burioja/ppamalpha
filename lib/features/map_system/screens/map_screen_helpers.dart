import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/marker/marker_model.dart';
import 'dart:math' as math;

/// MapScreen의 헬퍼 메서드들을 모은 클래스
class MapScreenHelpers {
  /// 두 위치 간 거리 계산 (미터)
  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  /// 롱프레스 가능 위치 확인 (200m 이내)
  static bool canLongPressAtLocation({
    required LatLng point,
    LatLng? currentPosition,
    LatLng? homeLocation,
    List<LatLng> workLocations = const [],
  }) {
    // 현재 위치 주변 (200m)
    if (currentPosition != null) {
      final distance = calculateDistance(currentPosition, point);
      if (distance <= 200) return true;
    }

    // 집 주변 (200m)
    if (homeLocation != null) {
      final distance = calculateDistance(homeLocation, point);
      if (distance <= 200) return true;
    }

    // 일터 주변 (200m)
    for (final workLocation in workLocations) {
      final distance = calculateDistance(workLocation, point);
      if (distance <= 200) return true;
    }

    return false;
  }

  /// 타일 반지름 계산
  static double calculateTileRadiusKm(Map<String, double> tileBounds) {
    final latDiff = tileBounds['north']! - tileBounds['south']!;
    final lngDiff = tileBounds['east']! - tileBounds['west']!;
    final diagonal = math.sqrt(latDiff * latDiff + lngDiff * lngDiff);
    return (diagonal / 2.0) * 111.0; // 대략 111km per degree
  }

  /// 캐시 키 생성
  static String generateCacheKeyForLocation(LatLng location, List<String> surroundingTiles) {
    final currentTileId = 'tile_${location.latitude}_${location.longitude}';
    final tileIds = surroundingTiles.take(9).toList();
    tileIds.sort();
    final tileKey = tileIds.join('_');
    return 'fog_${currentTileId}_${tileKey.hashCode}';
  }

  /// 타일 ID에서 좌표 추출
  static LatLng? extractPositionFromTileId(String tileId) {
    try {
      if (tileId.startsWith('tile_')) {
        final parts = tileId.split('_');
        if (parts.length == 3) {
          final tileLat = int.tryParse(parts[1]);
          final tileLng = int.tryParse(parts[2]);
          if (tileLat != null && tileLng != null) {
            const double tileSize = 0.009;
            return LatLng(
              tileLat * tileSize + (tileSize / 2),
              tileLng * tileSize + (tileSize / 2),
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('타일 ID에서 좌표 추출 실패: $e');
      return null;
    }
  }

  /// 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 수령 가능한 마커 필터링
  static List<MarkerModel> filterReceivableMarkers({
    required List<MarkerModel> markers,
    required LatLng? currentPosition,
    required String userId,
    double maxDistance = 200.0,
  }) {
    if (currentPosition == null) return [];

    return markers.where((marker) {
      final distance = calculateDistance(currentPosition, marker.position);
      return distance <= maxDistance && marker.creatorId != userId;
    }).toList();
  }
}

