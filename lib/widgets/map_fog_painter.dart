import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 원 스펙 클래스
class CircleSpec {
  final LatLng center;
  final double radiusMeters;
  final Color? strokeColor;
  final double strokeWidth;
  
  const CircleSpec({
    required this.center,
    required this.radiusMeters,
    this.strokeColor,
    this.strokeWidth = 0.0,
  });
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CircleSpec &&
        other.center == center &&
        other.radiusMeters == radiusMeters &&
        other.strokeColor == strokeColor &&
        other.strokeWidth == strokeWidth;
  }
  
  @override
  int get hashCode => Object.hash(center, radiusMeters, strokeColor, strokeWidth);
}

/// Fog of War를 그리는 CustomPainter
class FogPainter extends CustomPainter {
  final CameraPosition camera;
  final Size screenSize;
  final List<CircleSpec> recentCircles;
  final CircleSpec? hereCircle;
  final double fogOpacity;
  final Color fogColor;
  final GoogleMapController? mapController;

  const FogPainter({
    required this.camera,
    required this.screenSize,
    required this.recentCircles,
    this.hereCircle,
    this.fogOpacity = 0.6,
    this.fogColor = Colors.black,
    this.mapController,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 전체 화면을 덮는 안개 Path
    final fog = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // 구멍들을 합치는 Path
    final holes = Path();
    
    // 최근 방문 지역들의 구멍
    for (final circle in recentCircles) {
      final hole = _createCircleHole(circle, size);
      if (hole != null) {
        holes.addPath(hole, Offset.zero);
      }
    }
    
    // 현재 위치 구멍
    if (hereCircle != null) {
      final hereHole = _createCircleHole(hereCircle!, size);
      if (hereHole != null) {
        holes.addPath(hereHole, Offset.zero);
      }
    }
    
    // 안개에서 구멍들을 뺀 최종 Path
    final finalFog = Path.combine(PathOperation.difference, fog, holes);
    
    // 안개 그리기
    final fogPaint = Paint()
      ..color = fogColor.withOpacity(fogOpacity)
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(finalFog, fogPaint);
    
    // 현재 위치 테두리 강조 (선택적)
    if (hereCircle != null && hereCircle!.strokeColor != null) {
      _drawCircleStroke(canvas, hereCircle!, size);
    }
  }
  
  /// 원 구멍 생성
  Path? _createCircleHole(CircleSpec circle, Size size) {
    final centerOffset = _projectToScreen(circle.center, size);
    if (centerOffset == null) return null;
    
    final radiusPixels = _metersToPixels(
      circle.radiusMeters, 
      circle.center.latitude, 
      camera.zoom,
    );
    
    // 화면 밖의 원은 제외 (성능 최적화)
    if (!_isCircleVisible(centerOffset, radiusPixels, size)) {
      return null;
    }
    
    final hole = Path();
    hole.addOval(Rect.fromCircle(center: centerOffset, radius: radiusPixels));
    return hole;
  }
  
  /// 원 테두리 그리기
  void _drawCircleStroke(Canvas canvas, CircleSpec circle, Size size) {
    final centerOffset = _projectToScreen(circle.center, size);
    if (centerOffset == null) return;
    
    final radiusPixels = _metersToPixels(
      circle.radiusMeters, 
      circle.center.latitude, 
      camera.zoom,
    );
    
    if (!_isCircleVisible(centerOffset, radiusPixels, size)) return;
    
    final strokePaint = Paint()
      ..color = circle.strokeColor!
      ..style = PaintingStyle.stroke
      ..strokeWidth = circle.strokeWidth;
    
    canvas.drawCircle(centerOffset, radiusPixels, strokePaint);
  }
  
  /// LatLng를 화면 좌표로 변환
  Offset? _projectToScreen(LatLng latLng, Size size) {
    // Web Mercator 투영법 사용
    // Google Maps와 동일한 계산 방식
    
    const webMercatorRange = 256.0;
    final scale = math.pow(2, camera.zoom).toDouble();
    final worldWidth = webMercatorRange * scale;
    
    // 경도를 X 좌표로 변환
    final worldX = (latLng.longitude + 180.0) / 360.0 * worldWidth;
    
    // 위도를 Y 좌표로 변환 (Web Mercator 공식)
    final latRad = latLng.latitude * math.pi / 180.0;
    final worldY = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * worldWidth;
    
    // 카메라 중심 기준으로 계산
    final cameraLatRad = camera.target.latitude * math.pi / 180.0;
    final cameraWorldX = (camera.target.longitude + 180.0) / 360.0 * worldWidth;
    final cameraWorldY = (1.0 - math.log(math.tan(cameraLatRad) + 1.0 / math.cos(cameraLatRad)) / math.pi) / 2.0 * worldWidth;
    
    // 화면 중심을 기준으로 상대 좌표 계산
    final relativeX = worldX - cameraWorldX;
    final relativeY = worldY - cameraWorldY;
    
    // 화면 좌표로 변환
    final screenX = size.width / 2.0 + relativeX;
    final screenY = size.height / 2.0 + relativeY;
    
    return Offset(screenX, screenY);
  }
  
  /// 미터를 픽셀로 변환
  double _metersToPixels(double meters, double latitude, double zoom) {
    // Web Mercator 기준 미터 당 픽셀 계산
    final metersPerPixel = 156543.03392 * 
        math.cos(latitude * math.pi / 180.0) / 
        math.pow(2, zoom);
    
    return meters / metersPerPixel;
  }
  
  /// 원이 화면에 보이는지 확인 (성능 최적화)
  bool _isCircleVisible(Offset center, double radius, Size size) {
    const margin = 100.0; // 여유 마진
    
    return center.dx + radius >= -margin &&
           center.dx - radius <= size.width + margin &&
           center.dy + radius >= -margin &&
           center.dy - radius <= size.height + margin;
  }

  @override
  bool shouldRepaint(covariant FogPainter oldDelegate) {
    return oldDelegate.camera != camera ||
           oldDelegate.screenSize != screenSize ||
           oldDelegate.recentCircles != recentCircles ||
           oldDelegate.hereCircle != hereCircle ||
           oldDelegate.fogOpacity != fogOpacity ||
           oldDelegate.fogColor != fogColor;
  }
}

/// Fog of War 위젯
class MapFogOverlay extends StatelessWidget {
  final CameraPosition camera;
  final List<CircleSpec> recentCircles;
  final CircleSpec? hereCircle;
  final double fogOpacity;
  final Color fogColor;
  final GoogleMapController? mapController;

  const MapFogOverlay({
    super.key,
    required this.camera,
    required this.recentCircles,
    this.hereCircle,
    this.fogOpacity = 0.6,
    this.fogColor = Colors.black,
    this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: FogPainter(
          camera: camera,
          screenSize: MediaQuery.of(context).size,
          recentCircles: recentCircles,
          hereCircle: hereCircle,
          fogOpacity: fogOpacity,
          fogColor: fogColor,
          mapController: mapController,
        ),
        child: Container(), // 전체 화면 커버
      ),
    );
  }
}

/// 위치 클러스터링 유틸리티
class LocationClusterer {
  /// 가까운 위치들을 클러스터링 (성능 최적화)
  static List<LatLng> clusterLocations(
    List<LatLng> locations, 
    double minDistanceMeters,
  ) {
    if (locations.isEmpty) return [];
    
    final clustered = <LatLng>[];
    final visited = <bool>[...List.filled(locations.length, false)];
    
    for (int i = 0; i < locations.length; i++) {
      if (visited[i]) continue;
      
      final cluster = <LatLng>[locations[i]];
      visited[i] = true;
      
      // 같은 클러스터에 속하는 다른 점들 찾기
      for (int j = i + 1; j < locations.length; j++) {
        if (visited[j]) continue;
        
        final distance = _calculateDistance(locations[i], locations[j]);
        if (distance <= minDistanceMeters) {
          cluster.add(locations[j]);
          visited[j] = true;
        }
      }
      
      // 클러스터의 중심점 계산
      clustered.add(_calculateClusterCenter(cluster));
    }
    
    return clustered;
  }
  
  /// 두 지점간 거리 계산 (미터)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000.0; // 지구 반지름 (미터)
    
    final lat1Rad = point1.latitude * math.pi / 180.0;
    final lat2Rad = point2.latitude * math.pi / 180.0;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180.0;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180.0;
    
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// 클러스터 중심점 계산
  static LatLng _calculateClusterCenter(List<LatLng> points) {
    if (points.isEmpty) throw ArgumentError('Points cannot be empty');
    if (points.length == 1) return points.first;
    
    double totalLat = 0.0;
    double totalLng = 0.0;
    
    for (final point in points) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }
    
    return LatLng(
      totalLat / points.length,
      totalLng / points.length,
    );
  }
}
