import 'package:latlong2/latlong.dart';

/// 1km 타일 기반 Fog of War 시스템을 위한 유틸리티
class TileUtils {
  // 1km = 약 0.009도 (위도 기준)
  static const double _tileSize = 0.009;
  
  /// 위도, 경도를 1km 타일 ID로 변환
  static String getTileId(double latitude, double longitude) {
    final tileLat = (latitude / _tileSize).floor();
    final tileLng = (longitude / _tileSize).floor();
    return 'tile_${tileLat}_${tileLng}';
  }
  
  /// 타일 ID를 타일 중심점으로 변환
  static LatLng getTileCenter(String tileId) {
    final parts = tileId.split('_');
    final tileLat = int.parse(parts[1]);
    final tileLng = int.parse(parts[2]);
    return LatLng(
      tileLat * _tileSize + (_tileSize / 2), // 타일 중심
      tileLng * _tileSize + (_tileSize / 2),
    );
  }
  
  /// 현재 위치가 속한 타일과 주변 8개 타일 ID 목록 반환
  static List<String> getSurroundingTiles(double latitude, double longitude) {
    final centerTile = getTileId(latitude, longitude);
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
  
  /// 타일 ID에서 위도, 경도 범위 계산
  static Map<String, double> getTileBounds(String tileId) {
    final parts = tileId.split('_');
    final tileLat = int.parse(parts[1]);
    final tileLng = int.parse(parts[2]);
    
    return {
      'minLat': tileLat * _tileSize,
      'maxLat': (tileLat + 1) * _tileSize,
      'minLng': tileLng * _tileSize,
      'maxLng': (tileLng + 1) * _tileSize,
    };
  }
}

/// 전역 함수로 getTileId 제공 (기존 코드 호환성)
String getTileId(double latitude, double longitude) {
  return TileUtils.getTileId(latitude, longitude);
}

/// 전역 함수로 getTileCenter 제공 (기존 코드 호환성)
LatLng getTileCenter(String tileId) {
  return TileUtils.getTileCenter(tileId);
}

