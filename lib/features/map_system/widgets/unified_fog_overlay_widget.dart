import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 통합 포그 오버레이
/// - 3단계(검정): 전체 화면 덮기
/// - 1단계(L1: GPS/집/일터) ∪ 2단계(L2: 30일 이내 방문): 먼저 clear로 '펀칭' → 지도가 보임
/// - 2단계(L2 - L1): 지도 위에 반투명 회색을 차집합으로 칠함 (L1 우선권 보장)
class UnifiedFogOverlayWidget extends StatefulWidget {
  final MapController mapController;      // non-null
  final List<LatLng> level1Centers;       // 현위치, 집, 일터
  final List<LatLng> level2CentersRaw;    // 방문(30일 이내) 타일 중심들 (필요시 많을 수 있음)
  final double radiusMeters;              // 보통 1000m
  final Color fogColor;                   // 3단계 색 (검정)
  final Color grayColor;                  // 2단계 색 (회색, 알파 포함 권장)

  const UnifiedFogOverlayWidget({
    super.key,
    required this.mapController,
    required this.level1Centers,
    required this.level2CentersRaw,
    this.radiusMeters = 1000.0,
    this.fogColor = const Color(0xFF000000),
    this.grayColor = const Color(0x4D9E9E9E), // 약 30% 회색
  });

  @override
  State<UnifiedFogOverlayWidget> createState() => _UnifiedFogOverlayWidgetState();
}

class _UnifiedFogOverlayWidgetState extends State<UnifiedFogOverlayWidget> {
  late final StreamSubscription<MapEvent> _sub;

  @override
  void initState() {
    super.initState();
    // 맵 이동/줌 시 리페인트 (좌표 투영만 달라짐)
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
        painter: _UnifiedFogPainter(
          mapController: widget.mapController,
          level1Centers: widget.level1Centers,
          level2Centers: widget.level2CentersRaw, // 원본 L2를 그대로 전달
          radiusMeters: widget.radiusMeters,
          fogColor: widget.fogColor,
          grayColor: widget.grayColor,
        ),
      ),
    );
  }
}

class _UnifiedFogPainter extends CustomPainter {
  final MapController mapController;
  final List<LatLng> level1Centers;
  final List<LatLng> level2Centers;  // 원본 L2 전체
  final double radiusMeters;
  final Color fogColor;
  final Color grayColor;

  _UnifiedFogPainter({
    required this.mapController,
    required this.level1Centers,
    required this.level2Centers,
    required this.radiusMeters,
    required this.fogColor,
    required this.grayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final camera = mapController.camera;
    if (camera == null) {
      debugPrint('🔥 paint: camera is null!');
      return;
    }

    debugPrint('🎨 paint 호출: L1=${level1Centers.length}, L2=${level2Centers.length}');

    final layerBounds = Offset.zero & size;

    // L1 Path 생성 (현위치, 집, 일터)
    final l1Path = ui.Path();
    for (final c in level1Centers) {
      final cp = _toScreen(c, camera);
      final r = _pixelsRadiusAt(c.latitude, radiusMeters, camera.zoom);
      l1Path.addOval(ui.Rect.fromCircle(center: cp, radius: r));
      debugPrint('  L1: center=$c, screen=$cp, radius=${r.toStringAsFixed(1)}px');
    }

    // L2 Path 생성 (visited30Days 타일들)
    final l2Path = ui.Path();
    for (final c in level2Centers) {
      final cp = _toScreen(c, camera);
      final r = _pixelsRadiusAt(c.latitude, radiusMeters, camera.zoom);
      l2Path.addOval(ui.Rect.fromCircle(center: cp, radius: r));
      debugPrint('  L2: center=$c, screen=$cp, radius=${r.toStringAsFixed(1)}px');
    }

    debugPrint('🎨 Path 생성 완료');

    // ========== 10월 15일 방식: 하나의 saveLayer 안에서 모든 작업 ==========
    canvas.saveLayer(layerBounds, Paint());

    // 1) 전체 포그(검정) 칠하기
    final fog = Paint()
      ..color = fogColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRect(layerBounds, fog);
    debugPrint('  ✅ 1단계: 전체 검정 칠함');

    // 2) (L1 ∪ L2) 펀칭 → 지도 보이게
    final punch = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    final unionClear = ui.Path()
      ..addPath(l1Path, Offset.zero)
      ..addPath(l2Path, Offset.zero);
    canvas.drawPath(unionClear, punch);
    debugPrint('  ✅ 2단계: (L1 ∪ L2) 펀칭');

    // 3) 회색은 (L2 - L1)만 지도 위에 얹기 → L1 우선권 보장
    if (level2Centers.isNotEmpty) {
      final grayMinusL1 = ui.Path.combine(ui.PathOperation.difference, l2Path, l1Path);
      final grayPaint = Paint()
        ..color = grayColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(grayMinusL1, grayPaint);
      debugPrint('  ✅ 3단계: L2-L1 회색 레이어');
    }

    canvas.restore();
    
    debugPrint('🎨 paint 완료!');
  }

  // Web Mercator: LatLng → 월드픽셀 → 화면픽셀
  Offset _toScreen(LatLng ll, MapCamera camera) {
    final z = camera.zoom;
    final worldScale = 256.0 * math.pow(2.0, z).toDouble();

    final x = (ll.longitude + 180.0) / 360.0 * worldScale;

    final latClamped = ll.latitude.clamp(-85.05112878, 85.05112878);
    final latRad = latClamped * math.pi / 180.0;
    final y = (0.5 - (math.log((1 + math.sin(latRad)) / (1 - math.sin(latRad))) / (4 * math.pi))) * worldScale;

    final topLeft = camera.pixelOrigin; // Point<double>
    return Offset(x - topLeft.dx, y - topLeft.dy);
  }

  // pan 영향 X: 위도/줌 기반 meters-per-pixel
  double _pixelsRadiusAt(double latDeg, double meters, double zoom) {
    const R = 6378137.0;
    final scale = 256.0 * math.pow(2.0, zoom).toDouble();
    final mpp = (math.cos(latDeg * math.pi / 180.0) * 2 * math.pi * R) / scale;
    return meters / mpp;
  }

  @override
  bool shouldRepaint(covariant _UnifiedFogPainter old) {
    if (old.radiusMeters != radiusMeters ||
        old.fogColor != fogColor ||
        old.grayColor != grayColor ||
        old.level1Centers.length != level1Centers.length ||
        old.level2Centers.length != level2Centers.length) {
      return true;
    }
    // 간단 비교
    for (int i = 0; i < level1Centers.length; i++) {
      if (level1Centers[i] != old.level1Centers[i]) return true;
    }
    for (int i = 0; i < level2Centers.length; i++) {
      if (level2Centers[i] != old.level2Centers[i]) return true;
    }
    return false;
  }
}
