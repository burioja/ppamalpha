import 'dart:math';
import 'package:latlong2/latlong.dart';

/// 타일 관련 유틸리티 클래스
class TileUtils {
  static const int _zoomLevel = 18; // 기본 줌 레벨
  static const double _tileSize = 256.0; // 타일 크기 (픽셀)

  /// 위도/경도를 기반으로 타일 ID 생성
  static String getTileId(double latitude, double longitude) {
    final tileX = _longitudeToTileX(longitude, _zoomLevel);
    final tileY = _latitudeToTileY(latitude, _zoomLevel);
    return '${tileX}_${tileY}_$_zoomLevel';
  }

  /// 특정 위치 주변의 타일들 가져오기
  static List<String> getSurroundingTiles(double latitude, double longitude, {int radius = 1}) {
    final centerTileX = _longitudeToTileX(longitude, _zoomLevel);
    final centerTileY = _latitudeToTileY(latitude, _zoomLevel);

    final List<String> tiles = [];

    for (int x = centerTileX - radius; x <= centerTileX + radius; x++) {
      for (int y = centerTileY - radius; y <= centerTileY + radius; y++) {
        tiles.add('${x}_${y}_$_zoomLevel');
      }
    }

    return tiles;
  }

  /// 타일 ID에서 중심 좌표 가져오기
  static Map<String, double> getTileCenter(String tileId) {
    final parts = tileId.split('_');
    if (parts.length != 3) {
      throw ArgumentError('잘못된 타일 ID 형식: $tileId');
    }

    final tileX = int.parse(parts[0]);
    final tileY = int.parse(parts[1]);
    final zoomLevel = int.parse(parts[2]);

    final latitude = _tileYToLatitude(tileY, zoomLevel);
    final longitude = _tileXToLongitude(tileX, zoomLevel);

    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// 타일의 경계 좌표 가져오기
  static Map<String, double> getTileBounds(String tileId) {
    final parts = tileId.split('_');
    if (parts.length != 3) {
      throw ArgumentError('잘못된 타일 ID 형식: $tileId');
    }

    final tileX = int.parse(parts[0]);
    final tileY = int.parse(parts[1]);
    final zoomLevel = int.parse(parts[2]);

    final northLat = _tileYToLatitude(tileY, zoomLevel);
    final southLat = _tileYToLatitude(tileY + 1, zoomLevel);
    final westLng = _tileXToLongitude(tileX, zoomLevel);
    final eastLng = _tileXToLongitude(tileX + 1, zoomLevel);

    return {
      'north': northLat,
      'south': southLat,
      'west': westLng,
      'east': eastLng,
    };
  }

  /// 두 타일 간 거리 계산 (킬로미터)
  static double calculateTileDistance(String tileId1, String tileId2) {
    final center1 = getTileCenter(tileId1);
    final center2 = getTileCenter(tileId2);

    return _calculateDistance(
      center1['latitude']!,
      center1['longitude']!,
      center2['latitude']!,
      center2['longitude']!,
    );
  }

  /// 특정 반경 내의 타일들 가져오기
  static List<String> getTilesInRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) {
    final centerTileX = _longitudeToTileX(centerLng, _zoomLevel);
    final centerTileY = _latitudeToTileY(centerLat, _zoomLevel);

    // 반경을 타일 단위로 변환 (대략적)
    final tileRadius = (radiusKm * 1000 / _getMetersPerTile(centerLat)).ceil();

    final List<String> tiles = [];

    for (int x = centerTileX - tileRadius; x <= centerTileX + tileRadius; x++) {
      for (int y = centerTileY - tileRadius; y <= centerTileY + tileRadius; y++) {
        final tileId = '${x}_${y}_$_zoomLevel';
        final tileCenter = getTileCenter(tileId);

        final distance = _calculateDistance(
          centerLat,
          centerLng,
          tileCenter['latitude']!,
          tileCenter['longitude']!,
        );

        if (distance <= radiusKm) {
          tiles.add(tileId);
        }
      }
    }

    return tiles;
  }

  /// 경도를 타일 X 좌표로 변환
  static int _longitudeToTileX(double longitude, int zoomLevel) {
    return ((longitude + 180.0) / 360.0 * pow(2.0, zoomLevel)).floor();
  }

  /// 위도를 타일 Y 좌표로 변환 (Web Mercator)
  static int _latitudeToTileY(double latitude, int zoomLevel) {
    // 위도 범위 제한 (-85.0511도 ~ 85.0511도)
    final clampedLat = latitude.clamp(-85.0511, 85.0511);
    final latRad = clampedLat * pi / 180.0;
    
    // Web Mercator 투영법
    final y = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0;
    return (y * pow(2.0, zoomLevel)).floor();
  }

  /// 타일 X 좌표를 경도로 변환
  static double _tileXToLongitude(int tileX, int zoomLevel) {
    return tileX / pow(2.0, zoomLevel) * 360.0 - 180.0;
  }

  /// 타일 Y 좌표를 위도로 변환 (Web Mercator)
  static double _tileYToLatitude(int tileY, int zoomLevel) {
    final n = pi - 2.0 * pi * tileY / pow(2.0, zoomLevel);
    final latitude = 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
    
    // 위도 범위 제한
    return latitude.clamp(-85.0511, 85.0511);
  }

  // ===== 1km 근사 그리드 시스템 =====
  static const double _km1TileSize = 0.009; // 1km = 약 0.009도

  /// 위도, 경도를 1km 타일 ID로 변환 (Fog of War용)
  static String getKm1TileId(double latitude, double longitude) {
    final tileLat = (latitude / _km1TileSize).floor();
    final tileLng = (longitude / _km1TileSize).floor();
    return 'tile_${tileLat}_${tileLng}';
  }

  /// 1km 타일 ID를 타일 중심점으로 변환
  static LatLng getKm1TileCenter(String tileId) {
    final parts = tileId.split('_');
    final tileLat = int.parse(parts[1]);
    final tileLng = int.parse(parts[2]);
    return LatLng(
      tileLat * _km1TileSize + (_km1TileSize / 2),
      tileLng * _km1TileSize + (_km1TileSize / 2),
    );
  }

  /// 1km 타일 ID에서 위도, 경도 범위 계산
  static Map<String, double> getKm1TileBounds(String tileId) {
    final parts = tileId.split('_');
    final tileLat = int.parse(parts[1]);
    final tileLng = int.parse(parts[2]);
    
    return {
      'minLat': tileLat * _km1TileSize,
      'maxLat': (tileLat + 1) * _km1TileSize,
      'minLng': tileLng * _km1TileSize,
      'maxLng': (tileLng + 1) * _km1TileSize,
    };
  }

  /// 현재 위치가 속한 1km 타일과 주변 8개 타일 ID 목록 반환
  static List<String> getKm1SurroundingTiles(double latitude, double longitude) {
    final centerTile = getKm1TileId(latitude, longitude);
    final parts = centerTile.split('_');
    final centerLat = int.parse(parts[1]);
    final centerLng = int.parse(parts[2]);
    
    final tiles = <String>[];
    for (int latOffset = -1; latOffset <= 1; latOffset++) {
      for (int lngOffset = -1; lngOffset <= 1; lngOffset++) {
        final tileLat = centerLat + latOffset;
        final tileLng = centerLng + lngOffset;
        tiles.add('tile_${tileLat}_${tileLng}');
      }
    }
    return tiles;
  }

  /// 특정 위도에서 타일당 미터 수 계산
  static double _getMetersPerTile(double latitude) {
    const double earthCircumference = 40075017.0; // 지구 둘레 (미터)
    final double latRad = latitude * pi / 180.0;
    return earthCircumference * cos(latRad) / pow(2.0, _zoomLevel);
  }

  /// 두 지점 간 거리 계산 (킬로미터)
  static double _calculateDistance(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const double earthRadius = 6371; // km

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 타일 ID가 유효한지 확인
  static bool isValidTileId(String tileId) {
    final parts = tileId.split('_');
    if (parts.length != 3) return false;

    try {
      int.parse(parts[0]); // tileX
      int.parse(parts[1]); // tileY
      int.parse(parts[2]); // zoomLevel
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 줌 레벨에 따른 타일 개수 계산
  static int getTileCount(int zoomLevel) {
    return pow(2, zoomLevel).toInt();
  }

  /// 특정 줌 레벨에서 타일 크기 (미터) 계산
  static double getTileSizeInMeters(double latitude, int zoomLevel) {
    const double earthCircumference = 40075017.0;
    final double latRad = latitude * pi / 180.0;
    return earthCircumference * cos(latRad) / pow(2.0, zoomLevel);
  }
}