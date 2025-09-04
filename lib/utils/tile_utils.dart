import 'dart:math';
import 'package:latlong2/latlong.dart';

/// 타일 좌표 클래스
class Coords {
  final int x;
  final int y;
  
  const Coords(this.x, this.y);
  
  @override
  String toString() => 'Coords($x, $y)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coords && runtimeType == other.runtimeType && x == other.x && y == other.y;
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// 타일 관련 유틸리티 클래스
class TileUtils {
  /// Slippy Map Tile System (Z/X/Y) 기반 타일 키 생성
  static String generateTileKey(int z, int x, int y) {
    return '${z}_${x}_$y';
  }
  
  /// GPS 좌표를 타일 좌표로 변환
  static Coords latLngToTile(LatLng latLng, int zoom) {
    final x = ((latLng.longitude + 180) / 360 * pow(2, zoom)).floor();
    final y = ((1 - log(tan(latLng.latitude * pi / 180) + 
        1 / cos(latLng.latitude * pi / 180)) / pi) / 2 * pow(2, zoom)).floor();
    return Coords(x, y);
  }
  
  /// 타일 좌표를 GPS 좌표로 변환
  static LatLng tileToLatLng(Coords coords, int zoom) {
    final n = pow(2, zoom);
    final lonDeg = coords.x / n * 360.0 - 180.0;
    // sinh 대신 다른 방법 사용
    final latRad = atan((exp(pi * (1 - 2 * coords.y / n)) - exp(-pi * (1 - 2 * coords.y / n))) / 2);
    final latDeg = latRad * 180.0 / pi;
    return LatLng(latDeg, lonDeg);
  }
  
  /// 1km 반경 내 타일들 계산
  static List<Coords> getTilesInRadius(LatLng center, int zoom, double radiusKm) {
    final tiles = <Coords>[];
    final centerTile = latLngToTile(center, zoom);
    
    // 반경 내 타일들 계산 (간단한 사각형 근사)
    // 1도 ≈ 111.32km
    final tileRadius = (radiusKm / 111.32 * pow(2, zoom)).ceil();
    
    for (int dx = -tileRadius; dx <= tileRadius; dx++) {
      for (int dy = -tileRadius; dy <= tileRadius; dy++) {
        final tile = Coords(centerTile.x + dx, centerTile.y + dy);
        
        // 실제 거리 체크 (정확한 원형 반경)
        final tileCenter = tileToLatLng(tile, zoom);
        final distance = Distance().as(LengthUnit.Kilometer, center, tileCenter);
        
        if (distance <= radiusKm) {
          tiles.add(tile);
        }
      }
    }
    
    return tiles;
  }
  
  /// 두 GPS 좌표 간의 거리 계산 (km)
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Distance().as(LengthUnit.Kilometer, point1, point2);
  }
  
  /// 타일이 특정 반경 내에 있는지 확인
  static bool isTileInRadius(Coords tile, LatLng center, int zoom, double radiusKm) {
    final tileCenter = tileToLatLng(tile, zoom);
    final distance = calculateDistance(center, tileCenter);
    return distance <= radiusKm;
  }
}