import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// OSM 기반 Fog of War 서비스
class OSMFogService {
  // 전세계 커버용 큰 사각형(경위도)
  static const List<LatLng> _worldCoverRect = [
    LatLng(85, -180),
    LatLng(85, 180),
    LatLng(-85, 180),
    LatLng(-85, -180),
  ];

  /// 1km 원형 홀 생성
  static List<LatLng> makeCircleHole(LatLng center, double radiusMeters, {int sides = 180}) {
    const earth = 6378137.0; // 지구 반지름 (미터)
    final d = radiusMeters / earth;
    final lat = center.latitude * pi / 180;
    final lng = center.longitude * pi / 180;
    final result = <LatLng>[];
    
    for (int i = 0; i < sides; i++) {
      final brng = 2 * pi * i / sides;
      final lat2 = asin(sin(lat) * cos(d) + cos(lat) * sin(d) * cos(brng));
      final lng2 = lng + atan2(sin(brng) * sin(d) * cos(lat), cos(d) - sin(lat) * sin(lat2));
      result.add(LatLng(lat2 * 180 / pi, lng2 * 180 / pi));
    }
    return result;
  }

  /// Fog of War 폴리곤 생성 (단일 위치)
  static Polygon createFogPolygon(LatLng currentPosition) {
    final circleHole = makeCircleHole(currentPosition, 1000); // 1km
    
    return Polygon(
      points: _worldCoverRect,
      holePointsList: [circleHole], // 원형 홀
      isFilled: true,
      color: Colors.black.withOpacity(1.0), // 완전 검정
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// Fog of War 폴리곤 생성 (여러 위치)
  static Polygon createFogPolygonWithMultipleHoles(List<LatLng> positions) {
    final circleHoles = positions.map((pos) => makeCircleHole(pos, 1000)).toList();
    
    return Polygon(
      points: _worldCoverRect,
      holePointsList: circleHoles, // 여러 원형 홀
      isFilled: true,
      color: Colors.black.withOpacity(1.0), // 완전 검정
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 1km 경계선 원 생성
  static CircleMarker createRingCircle(LatLng currentPosition) {
    return CircleMarker(
      point: currentPosition,
      radius: 1000, // 미터 단위
      useRadiusInMeter: true, // 미터 반경 사용
      color: Colors.transparent,
      borderStrokeWidth: 2,
      borderColor: Colors.white.withOpacity(0.9),
    );
  }

  /// 줌 레벨에 따른 그리드 간격 계산 (미터)
  static double gridMetersForZoom(double zoom) {
    if (zoom >= 16) return 100;
    if (zoom >= 14) return 250;
    if (zoom >= 12) return 500;
    return 1000;
  }

  /// 1km 반경 내에서 그리드 기반 샘플링
  static List<LatLng> samplePointsInRadius(
    LatLng center, 
    double gridMeters, 
    List<LatLng> allPoints
  ) {
    final sampledPoints = <LatLng>[];
    final gridSize = gridMeters / 111320; // 미터를 도 단위로 변환 (대략적)
    
    for (final point in allPoints) {
      // 1km 반경 내 확인
      final distance = Distance().as(LengthUnit.Meter, center, point);
      if (distance > 1000) continue;
      
      // 그리드 스냅핑
      final snappedLat = (point.latitude / gridSize).round() * gridSize;
      final snappedLng = (point.longitude / gridSize).round() * gridSize;
      final snappedPoint = LatLng(snappedLat, snappedLng);
      
      // 중복 제거
      if (!sampledPoints.any((p) => 
          (p.latitude - snappedPoint.latitude).abs() < 0.0001 &&
          (p.longitude - snappedPoint.longitude).abs() < 0.0001)) {
        sampledPoints.add(snappedPoint);
      }
    }
    
    return sampledPoints;
  }
}
