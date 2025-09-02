import 'dart:math';
import 'package:latlong2/latlong.dart';

/// 타일 관련 유틸리티 클래스
class TileUtils {
  /// 두 점 사이의 거리 계산 (km)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  /// LatLng를 타일 좌표로 변환
  static TileCoordinate latLngToTile(LatLng point, int zoom) {
    final n = pow(2.0, zoom);
    final x = ((point.longitude + 180.0) / 360.0 * n).floor();
    final y = ((1.0 - asinh(tan(point.latitude * pi / 180.0)) / pi) / 2.0 * n).floor();
    return TileCoordinate(zoom, x, y);
  }

  /// 타일 좌표를 LatLng로 변환
  static LatLng tileToLatLng(int z, int x, int y) {
    final n = pow(2.0, z);
    final lonDeg = x / n * 360.0 - 180.0;
    final latRad = atan(sinh(pi * (1 - 2 * y / n)));
    final latDeg = latRad * 180.0 / pi;
    return LatLng(latDeg, lonDeg);
  }

  /// 반경 내의 타일들 계산
  static List<TileCoordinate> getTilesInRadius(LatLng center, double radiusKm, int zoom) {
    final tiles = <TileCoordinate>[];
    
    // 반경을 도 단위로 변환 (대략적)
    final radiusDeg = radiusKm / 111.0; // 1도 ≈ 111km
    
    // 타일 크기 계산
    final tileSize = 360.0 / pow(2, zoom);
    
    // 중심 타일
    final centerTile = latLngToTile(center, zoom);
    
    // 반경 내 타일들 계산
    final tileRadius = (radiusDeg / tileSize).ceil();
    
    for (int dx = -tileRadius; dx <= tileRadius; dx++) {
      for (int dy = -tileRadius; dy <= tileRadius; dy++) {
        final tileX = centerTile.x + dx;
        final tileY = centerTile.y + dy;
        
        // 타일 중심점 계산
        final tileCenter = tileToLatLng(zoom, tileX, tileY);
        
        // 거리 확인
        if (calculateDistance(center, tileCenter) <= radiusKm) {
          tiles.add(TileCoordinate(zoom, tileX, tileY));
        }
      }
    }
    
    return tiles;
  }

  /// 타일 키 생성
  static String generateTileKey(int z, int x, int y) {
    return '${z}_${x}_${y}';
  }

  /// 타일 키 파싱
  static TileCoordinate? parseTileKey(String tileKey) {
    try {
      final parts = tileKey.split('_');
      if (parts.length == 3) {
        final z = int.parse(parts[0]);
        final x = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        return TileCoordinate(z, x, y);
      }
    } catch (e) {
      // 파싱 실패
    }
    return null;
  }

  /// 타일 경계 계산
  static TileBounds getTileBounds(int z, int x, int y) {
    final nw = tileToLatLng(z, x, y);
    final se = tileToLatLng(z, x + 1, y + 1);
    return TileBounds(nw, se);
  }

  /// 타일이 화면에 보이는지 확인
  static bool isTileVisible(TileCoordinate tile, LatLngBounds viewport) {
    final tileBounds = getTileBounds(tile.z, tile.x, tile.y);
    
    // 타일이 뷰포트와 겹치는지 확인
    return !(tileBounds.northwest.longitude > viewport.east ||
             tileBounds.southeast.longitude < viewport.west ||
             tileBounds.southeast.latitude > viewport.north ||
             tileBounds.northwest.latitude < viewport.south);
  }
}

/// 타일 좌표 클래스
class TileCoordinate {
  final int z;
  final int x;
  final int y;

  TileCoordinate(this.z, this.x, this.y);

  @override
  String toString() => 'Tile($z, $x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => z.hashCode ^ x.hashCode ^ y.hashCode;
}

/// 타일 경계 클래스
class TileBounds {
  final LatLng northwest;
  final LatLng southeast;

  TileBounds(this.northwest, this.southeast);

  LatLng get southwest => LatLng(southeast.latitude, northwest.longitude);
  LatLng get northeast => LatLng(northwest.latitude, southeast.longitude);
}