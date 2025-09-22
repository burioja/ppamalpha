import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// OSM 기반 Fog of War 서비스
class OSMFogService {
  static const double _fogRadius = 1000.0; // 1km 반경

  /// 현재 위치를 기반으로 포그 폴리곤 생성
  static Polygon createFogPolygon(LatLng position) {
    return Polygon(
      points: _generateCirclePoints(position, _fogRadius),
      color: Colors.black.withOpacity(1.0), // 완전히 검게 (opacity 1.0)
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 여러 위치를 기반으로 구멍이 있는 포그 폴리곤 생성
  static Polygon createFogPolygonWithMultipleHoles(List<LatLng> positions) {
    // 전체 맵을 덮는 큰 사각형
    List<LatLng> outerPoints = [
      LatLng(-90, -180),
      LatLng(-90, 180),
      LatLng(90, 180),
      LatLng(90, -180),
    ];

    // 각 위치 주변에 구멍 생성
    List<List<LatLng>> holes = positions
        .map((pos) => _generateCirclePoints(pos, _fogRadius))
        .toList();

    return Polygon(
      points: outerPoints,
      holePointsList: holes,
      color: Colors.black.withOpacity(1.0), // 완전히 검게 (opacity 1.0)
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }


  /// 여러 위치를 기반으로 개별 원형 폴리곤들 생성 (겹침 처리용)
  static List<Polygon> createIndividualCirclePolygons(List<LatLng> positions) {
    List<Polygon> polygons = [];
    
    for (final pos in positions) {
      // 각 위치마다 개별 원형 폴리곤 생성
      Polygon circlePolygon = Polygon(
        points: _generateCirclePoints(pos, _fogRadius),
        color: Colors.transparent, // 투명하게 설정
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      );
      polygons.add(circlePolygon);
    }
    
    return polygons;
  }

  /// 링 원 생성 (반투명 원형 표시)
  static CircleMarker createRingCircle(LatLng position) {
    return CircleMarker(
      point: position,
      radius: _fogRadius,
      color: Colors.blue.withOpacity(0.1),
      borderColor: Colors.blue.withOpacity(0.3),
      borderStrokeWidth: 2.0,
    );
  }

  /// 방문한 지역의 회색 영역 생성
  static List<Polygon> createGrayAreas(List<LatLng> visitedPositions) {
    return visitedPositions.map((position) {
      return Polygon(
        points: _generateCirclePoints(position, _fogRadius), // 1km 반경으로 통일
        color: Colors.grey.withOpacity(0.3),
        borderColor: Colors.grey.withOpacity(0.5),
        borderStrokeWidth: 1.0,
      );
    }).toList();
  }

  /// 원형 포인트 생성 헬퍼 메서드
  static List<LatLng> _generateCirclePoints(LatLng center, double radiusInMeters) {
    const int numberOfPoints = 64;
    final List<LatLng> points = [];

    const Distance distance = Distance();

    for (int i = 0; i < numberOfPoints; i++) {
      final double angle = (i * 360 / numberOfPoints) * (pi / 180);
      final LatLng point = distance.offset(center, radiusInMeters, angle * 180 / pi);
      points.add(point);
    }

    return points;
  }

  /// 두 지점 간 거리 계산
  static double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  /// 위치가 포그 내부에 있는지 확인
  static bool isInsideFogRadius(LatLng center, LatLng target, {double? customRadius}) {
    final double radius = customRadius ?? _fogRadius;
    return calculateDistance(center, target) <= radius;
  }

  /// 포그 오브 워 업데이트 (사용자 위치 기반)
  Future<void> updateFogOfWar(LatLng currentPosition) async {
    // 현재 위치 기반으로 포그 상태 업데이트
    // 실제 구현에서는 방문한 타일 정보를 업데이트하고
    // 필요시 서버에 동기화
    try {
      // 타일 방문 정보 업데이트는 VisitTileService에서 처리
      print('포그 오브 워 업데이트 완료: ${currentPosition.latitude}, ${currentPosition.longitude}');
    } catch (e) {
      print('포그 오브 워 업데이트 오류: $e');
    }
  }
}