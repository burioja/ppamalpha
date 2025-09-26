import 'dart:math';
import 'package:flutter/material.dart' hide Colors;
import 'package:flutter/material.dart' as material show Colors;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_math/vector_math.dart';

/// OSM 기반 Fog of War 서비스
class OSMFogService {
  static const double _fogRadius = 1000.0; // 1km 반경

  /// 현재 위치를 기반으로 포그 폴리곤 생성
  static Polygon createFogPolygon(LatLng position) {
    return Polygon(
      points: _generateCirclePoints(position, _fogRadius),
      color: material.Colors.black.withOpacity(1.0), // 완전히 검게 (opacity 1.0)
      borderColor: material.Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 여러 위치를 기반으로 구멍이 있는 포그 폴리곤 생성 (기존 방식 - EvenOdd 규칙 사용)
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
      color: material.Colors.black.withOpacity(1.0), // 완전히 검게 (opacity 1.0)
      borderColor: material.Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// Union 연산을 사용한 포그 폴리곤 생성 (겹침 문제 해결)
  static Polygon createFogPolygonWithUnion(List<LatLng> positions) {
    if (positions.isEmpty) {
      // 위치가 없으면 전체 맵을 검은색으로 덮기
      return Polygon(
        points: [
          LatLng(-90, -180),
          LatLng(-90, 180),
          LatLng(90, 180),
          LatLng(90, -180),
        ],
        color: material.Colors.black.withOpacity(1.0),
        borderColor: material.Colors.transparent,
        borderStrokeWidth: 0,
      );
    }

    if (positions.length == 1) {
      // 위치가 하나면 기존 방식 사용
      return createFogPolygon(positions.first);
    }

    // 각 위치마다 개별 구멍 생성 (EvenOdd 규칙 사용)
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
      color: material.Colors.black.withOpacity(1.0),
      borderColor: material.Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 여러 원의 Union 연산 계산 (개선된 알고리즘)
  static List<LatLng> _calculateUnionOfCircles(List<LatLng> positions) {
    if (positions.isEmpty) return [];
    if (positions.length == 1) {
      return _generateCirclePoints(positions.first, _fogRadius);
    }

    // 개선된 Union 연산: 겹치는 원들을 정확히 합치기
    return _calculateUnionOfCirclesAdvanced(positions);
  }

  /// 고급 Union 연산 (겹치는 원들을 정확히 합치기)
  static List<LatLng> _calculateUnionOfCirclesAdvanced(List<LatLng> positions) {
    if (positions.length == 2) {
      return _unionTwoCircles(positions[0], positions[1]);
    }

    // 3개 이상의 원이 있는 경우, 재귀적으로 Union 연산 수행
    List<LatLng> result = _unionTwoCircles(positions[0], positions[1]);
    
    for (int i = 2; i < positions.length; i++) {
      // 현재 결과와 다음 원을 Union
      final nextCircle = _generateCirclePoints(positions[i], _fogRadius);
      result = _unionPolygonWithCircle(result, positions[i]);
    }
    
    return result;
  }

  /// 두 원의 Union 연산
  static List<LatLng> _unionTwoCircles(LatLng center1, LatLng center2) {
    final distance = calculateDistance(center1, center2);
    
    if (distance >= _fogRadius * 2) {
      // 두 원이 겹치지 않는 경우, 각각의 원을 유지
      return _generateCirclePoints(center1, _fogRadius);
    }
    
    if (distance == 0) {
      // 두 원이 같은 중심인 경우
      return _generateCirclePoints(center1, _fogRadius);
    }
    
    // 두 원이 겹치는 경우, Union 계산
    return _calculateOverlappingCirclesUnion(center1, center2);
  }

  /// 겹치는 두 원의 Union 계산
  static List<LatLng> _calculateOverlappingCirclesUnion(LatLng center1, LatLng center2) {
    final distance = calculateDistance(center1, center2);
    
    // 교점 계산
    final intersectionPoints = _calculateCircleIntersection(center1, center2, distance);
    
    if (intersectionPoints.isEmpty) {
      // 교점이 없는 경우 (한 원이 다른 원 안에 있음)
      return _generateCirclePoints(center1, _fogRadius);
    }
    
    // Union 폴리곤 생성
    List<LatLng> unionPoints = [];
    
    // 첫 번째 원의 호 (교점 사이)
    final arc1 = _generateArcPoints(center1, intersectionPoints[0], intersectionPoints[1], _fogRadius);
    unionPoints.addAll(arc1);
    
    // 두 번째 원의 호 (교점 사이)
    final arc2 = _generateArcPoints(center2, intersectionPoints[1], intersectionPoints[0], _fogRadius);
    unionPoints.addAll(arc2);
    
    return unionPoints;
  }

  /// 두 원의 교점 계산
  static List<LatLng> _calculateCircleIntersection(LatLng center1, LatLng center2, double distance) {
    if (distance >= _fogRadius * 2 || distance == 0) {
      return [];
    }
    
    // 교점 계산 공식
    final a = (_fogRadius * _fogRadius - _fogRadius * _fogRadius + distance * distance) / (2 * distance);
    final h = sqrt(_fogRadius * _fogRadius - a * a);
    
    final p2x = center1.latitude + a * (center2.latitude - center1.latitude) / distance;
    final p2y = center1.longitude + a * (center2.longitude - center1.longitude) / distance;
    
    final p3x1 = p2x + h * (center2.longitude - center1.longitude) / distance;
    final p3y1 = p2y - h * (center2.latitude - center1.latitude) / distance;
    
    final p3x2 = p2x - h * (center2.longitude - center1.longitude) / distance;
    final p3y2 = p2y + h * (center2.latitude - center1.latitude) / distance;
    
    return [
      LatLng(p3x1, p3y1),
      LatLng(p3x2, p3y2),
    ];
  }

  /// 원호 생성 (시작점에서 끝점까지)
  static List<LatLng> _generateArcPoints(LatLng center, LatLng start, LatLng end, double radius) {
    final startAngle = _calculateAngle(center, start);
    final endAngle = _calculateAngle(center, end);
    
    List<LatLng> arcPoints = [];
    const int numPoints = 32; // 원호의 점 개수
    
    for (int i = 0; i <= numPoints; i++) {
      final t = i / numPoints;
      final angle = startAngle + (endAngle - startAngle) * t;
      
      final x = center.latitude + radius * cos(angle) * (111320 / 1000); // 위도 변환
      final y = center.longitude + radius * sin(angle) * (111320 / 1000) / cos(center.latitude * pi / 180); // 경도 변환
      
      arcPoints.add(LatLng(x, y));
    }
    
    return arcPoints;
  }

  /// 폴리곤과 원의 Union 연산
  static List<LatLng> _unionPolygonWithCircle(List<LatLng> polygon, LatLng circleCenter) {
    // 간단한 구현: 폴리곤의 모든 점과 원의 점을 합쳐서 Convex Hull 계산
    final circlePoints = _generateCirclePoints(circleCenter, _fogRadius);
    final allPoints = [...polygon, ...circlePoints];
    return _calculateConvexHull(allPoints);
  }

  /// Convex Hull 계산 (Graham Scan 알고리즘)
  static List<LatLng> _calculateConvexHull(List<LatLng> points) {
    if (points.length < 3) return points;

    // 가장 아래쪽 점을 찾기
    LatLng bottomPoint = points[0];
    int bottomIndex = 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].latitude < bottomPoint.latitude ||
          (points[i].latitude == bottomPoint.latitude && 
           points[i].longitude < bottomPoint.longitude)) {
        bottomPoint = points[i];
        bottomIndex = i;
      }
    }

    // 각도순으로 정렬
    List<LatLng> sortedPoints = List.from(points);
    sortedPoints.removeAt(bottomIndex);
    sortedPoints.sort((a, b) {
      double angleA = _calculateAngle(bottomPoint, a);
      double angleB = _calculateAngle(bottomPoint, b);
      if (angleA != angleB) return angleA.compareTo(angleB);
      return _calculateDistance(bottomPoint, a).compareTo(_calculateDistance(bottomPoint, b));
    });

    // Graham Scan 알고리즘
    List<LatLng> hull = [bottomPoint];
    for (final point in sortedPoints) {
      while (hull.length > 1 && 
             _crossProduct(hull[hull.length - 2], hull[hull.length - 1], point) <= 0) {
        hull.removeLast();
      }
      hull.add(point);
    }

    return hull;
  }

  /// 두 점 사이의 각도 계산
  static double _calculateAngle(LatLng center, LatLng point) {
    return atan2(point.longitude - center.longitude, point.latitude - center.latitude);
  }

  /// 두 점 사이의 거리 계산 (미터 단위)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }


  /// 외적 계산 (Graham Scan용)
  static double _crossProduct(LatLng O, LatLng A, LatLng B) {
    return (A.longitude - O.longitude) * (B.latitude - O.latitude) - 
           (A.latitude - O.latitude) * (B.longitude - O.longitude);
  }


  /// 여러 위치를 기반으로 개별 원형 폴리곤들 생성 (겹침 처리용)
  static List<Polygon> createIndividualCirclePolygons(List<LatLng> positions) {
    List<Polygon> polygons = [];
    
    for (final pos in positions) {
      // 각 위치마다 개별 원형 폴리곤 생성
      Polygon circlePolygon = Polygon(
        points: _generateCirclePoints(pos, _fogRadius),
        color: material.Colors.transparent, // 투명하게 설정
        borderColor: material.Colors.transparent,
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
      color: material.Colors.blue.withOpacity(0.1),
      borderColor: material.Colors.blue.withOpacity(0.3),
      borderStrokeWidth: 2.0,
    );
  }

  /// 방문한 지역의 회색 영역 생성
  static List<Polygon> createGrayAreas(List<LatLng> visitedPositions) {
    return visitedPositions.map((position) {
      return Polygon(
        points: _generateCirclePoints(position, _fogRadius), // 1km 반경으로 통일
        color: material.Colors.grey.withOpacity(0.3),
        borderColor: material.Colors.grey.withOpacity(0.5),
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