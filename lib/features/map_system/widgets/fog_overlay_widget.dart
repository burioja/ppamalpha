import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 화면 전체를 포그색으로 덮고,
/// [holeCenters] (GPS/집/일터) 주변을 반경 [radiusMeters]만큼 '투명'으로 펀칭.
/// - 맵 드래그/줌 시에도 지도 좌표에 고정
/// - 맵 센터는 사용하지 않음(밝게 표시 X)
/// - flutter_map 8.2.x 호환, 내부 CRS 의존 없음(Web Mercator 직접 계산)
class FogOverlayWidget extends StatefulWidget {
  final MapController mapController;     // non-null
  final List<LatLng> holeCenters;        // GPS, 집, 일터만!
  final double radiusMeters;             // 보통 1000m
  final Color fogColor;                  // 레벨3(검정)

  const FogOverlayWidget({
    super.key,
    required this.mapController,
    required this.holeCenters,
    this.radiusMeters = 1000.0,
    this.fogColor = const Color(0xFF000000),
  });

  @override
  State<FogOverlayWidget> createState() => _FogOverlayWidgetState();
}

class _FogOverlayWidgetState extends State<FogOverlayWidget> {
  late final StreamSubscription<MapEvent> _sub;

  @override
  void initState() {
    super.initState();
    // 맵 이동/줌 이벤트마다 리페인트(구멍 좌표는 건드리지 않음)
    _sub = widget.mapController.mapEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FogPunchPainter(
          mapController: widget.mapController,
          holeCenters: widget.holeCenters,   // ✅ GPS/집/일터만
          radiusMeters: widget.radiusMeters,
          fogColor: widget.fogColor,
        ),
      ),
    );
  }
}

class _FogPunchPainter extends CustomPainter {
  final MapController mapController;
  final List<LatLng> holeCenters;
  final double radiusMeters;
  final Color fogColor;

  _FogPunchPainter({
    required this.mapController,
    required this.holeCenters,
    required this.radiusMeters,
    required this.fogColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final camera = mapController.camera;
    if (camera == null) return;

    final layerBounds = Offset.zero & size;
    canvas.saveLayer(layerBounds, Paint()); // 새 레이어

    // 전체 화면 포그(검정) 칠하기
    final fog = Paint()
      ..color = fogColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRect(layerBounds, fog);

    // 구멍은 clear로 '펀칭' → 겹쳐도 항상 투명
    final punch = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    for (final center in holeCenters) {
      final c = _toScreen(center, camera);                                  // 중심 픽셀
      final rPx = _pixelsRadiusAt(center.latitude, radiusMeters, camera.zoom); // 반경 픽셀(zoom/lat만)

      final hole = ui.Path()
        ..addOval(ui.Rect.fromCircle(center: c, radius: rPx));
      canvas.drawPath(hole, punch);
    }

    canvas.restore();
  }

  // Web Mercator: LatLng → 월드픽셀 → 화면픽셀 (pixelOrigin 보정)
  Offset _toScreen(LatLng ll, MapCamera camera) {
    final z = camera.zoom;
    final worldScale = 256.0 * math.pow(2.0, z).toDouble();

    final x = (ll.longitude + 180.0) / 360.0 * worldScale;

    final latClamped = ll.latitude.clamp(-85.05112878, 85.05112878);
    final latRad = latClamped * math.pi / 180.0;
    final y = (0.5 - (math.log((1 + math.sin(latRad)) / (1 - math.sin(latRad))) / (4 * math.pi))) * worldScale;

    final topLeft = camera.pixelOrigin; // Offset(dx, dy)
    return Offset(x - topLeft.dx, y - topLeft.dy);
  }

  /// pan 영향 X. 위도/줌 기반 meters-per-pixel로 반경 픽셀 구함.
  double _pixelsRadiusAt(double latDeg, double meters, double zoom) {
    const R = 6378137.0; // Web Mercator sphere radius
    final scale = 256.0 * math.pow(2.0, zoom).toDouble();
    final metersPerPixel = (math.cos(latDeg * math.pi / 180.0) * 2 * math.pi * R) / scale;
    return meters / metersPerPixel;
  }

  @override
  bool shouldRepaint(covariant _FogPunchPainter old) {
    if (old.radiusMeters != radiusMeters ||
        old.fogColor != fogColor ||
        old.holeCenters.length != holeCenters.length) {
      return true;
    }
    for (int i = 0; i < holeCenters.length; i++) {
      if (holeCenters[i] != old.holeCenters[i]) return true;
    }
    return false;
  }
}