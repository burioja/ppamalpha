import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 수학 유틸리티 함수들
class MathUtils {
  /// 하이퍼볼릭 사인 함수 (Dart math 라이브러리에 없음)
  static double sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2.0;
  }
  
  /// 하이퍼볼릭 코사인 함수
  static double cosh(double x) {
    return (math.exp(x) + math.exp(-x)) / 2.0;
  }
  
  /// 하이퍼볼릭 탄젠트 함수
  static double tanh(double x) {
    return sinh(x) / cosh(x);
  }
}

/// 타일 좌표 계산 유틸리티
class TileUtils {
  /// 위도/경도를 타일 좌표로 변환
  /// 
  /// Google Maps 타일 시스템:
  /// - 줌 레벨 0: 전 세계 = 1x1 타일
  /// - 줌 레벨 n: 2^n x 2^n 타일로 분할
  static TileCoordinate latLngToTile(double lat, double lng, int zoom) {
    final double latRad = lat * (math.pi / 180.0);
    final double n = math.pow(2.0, zoom).toDouble();
    
    final int x = ((lng + 180.0) / 360.0 * n).floor();
    final int y = ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n).floor();
    
    return TileCoordinate(x: x, y: y, zoom: zoom);
  }
  
  /// 타일 좌표를 위도/경도로 변환
  static LatLng tileToLatLng(int x, int y, int zoom) {
    final double n = math.pow(2.0, zoom).toDouble();
    
    final double lng = x / n * 360.0 - 180.0;
    final double latRad = math.atan(MathUtils.sinh(math.pi * (1 - 2 * y / n)));
    final double lat = latRad * (180.0 / math.pi);
    
    return LatLng(lat, lng);
  }
  
  /// 타일의 경계 좌표 계산
  static TileBounds getTileBounds(int x, int y, int zoom) {
    final northWest = tileToLatLng(x, y, zoom);
    final southEast = tileToLatLng(x + 1, y + 1, zoom);
    
    return TileBounds(
      northWest: northWest,
      southEast: southEast,
      northEast: LatLng(northWest.latitude, southEast.longitude),
      southWest: LatLng(southEast.latitude, northWest.longitude),
    );
  }
  
  /// 현재 위치 주변의 타일들 계산
  static List<TileCoordinate> getTilesAroundLocation(
    LatLng center,
    int zoom,
    double radiusKm,
  ) {
    final centerTile = latLngToTile(center.latitude, center.longitude, zoom);
    
    // 반경을 타일 단위로 변환 (대략적)
    final tilesPerDegree = math.pow(2, zoom) / 360.0;
    final kmPerDegree = 111.32; // 지구 둘레 / 360도
    final tilesRadius = (radiusKm / kmPerDegree * tilesPerDegree).ceil();
    
    final tiles = <TileCoordinate>[];
    
    for (int dx = -tilesRadius; dx <= tilesRadius; dx++) {
      for (int dy = -tilesRadius; dy <= tilesRadius; dy++) {
        final x = centerTile.x + dx;
        final y = centerTile.y + dy;
        
        // 타일 좌표 유효성 검사
        if (x >= 0 && x < math.pow(2, zoom) && y >= 0 && y < math.pow(2, zoom)) {
          tiles.add(TileCoordinate(x: x, y: y, zoom: zoom));
        }
      }
    }
    
    return tiles;
  }
  
  /// 두 지점 사이의 거리 계산 (Haversine 공식)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    
    final double lat1Rad = point1.latitude * (math.pi / 180);
    final double lat2Rad = point2.latitude * (math.pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (math.pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (math.pi / 180);
    
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// 타일 ID 문자열 생성
  static String getTileId(int x, int y, int zoom) => '${zoom}_${x}_${y}';
  
  /// 타일 ID 문자열 파싱
  static TileCoordinate? parseTileId(String tileId) {
    final parts = tileId.split('_');
    if (parts.length != 3) return null;
    
    try {
      return TileCoordinate(
        zoom: int.parse(parts[0]),
        x: int.parse(parts[1]),
        y: int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }
}

/// 타일 좌표 클래스
class TileCoordinate {
  final int x;
  final int y;
  final int zoom;
  
  const TileCoordinate({
    required this.x,
    required this.y,
    required this.zoom,
  });
  
  String get id => TileUtils.getTileId(x, y, zoom);
  
  @override
  String toString() => 'TileCoordinate(x: $x, y: $y, zoom: $zoom)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          zoom == other.zoom;
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ zoom.hashCode;
}

/// 타일 경계 좌표 클래스
class TileBounds {
  final LatLng northWest;
  final LatLng northEast;
  final LatLng southWest;
  final LatLng southEast;
  
  const TileBounds({
    required this.northWest,
    required this.northEast,
    required this.southWest,
    required this.southEast,
  });
  
  /// 타일의 중심점 계산
  LatLng get center => LatLng(
    (northWest.latitude + southEast.latitude) / 2,
    (northWest.longitude + southEast.longitude) / 2,
  );
  
  /// 점이 타일 경계 내에 있는지 확인
  bool contains(LatLng point) {
    return point.latitude >= southEast.latitude &&
           point.latitude <= northWest.latitude &&
           point.longitude >= northWest.longitude &&
           point.longitude <= southEast.longitude;
  }
  
  @override
  String toString() => 'TileBounds(NW: $northWest, SE: $southEast)';
}
