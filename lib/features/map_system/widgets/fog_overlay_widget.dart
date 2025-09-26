import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;

/// 포그(레벨3)를 화면 전체에 칠하고,
/// [holeCenters] 주변을 radiusMeters 원으로 '펀칭(투명)'하는 오버레이.
/// - 겹치는 홀에서도 항상 투명
/// - 순서/시계·반시계/홀 교차/다중 폴리곤 이슈 없음
/// - 반드시 flutter_map 위에서 사용 (project + pixelOrigin 활용)
class FogOverlayWidget extends StatelessWidget {
  final List<LatLng> holeCenters;   // 현위치, 집, 일터 등
  final double radiusMeters;        // 기본 1000m
  final Color fogColor;             // 레벨3 컬러(기본: 완전 검정)
  final double? featherSigma;       // 가장자리 부드럽게(픽셀 단위 sigma). null이면 선명하게

  const FogOverlayWidget({
    super.key,
    required this.holeCenters,
    this.radiusMeters = 1000.0,
    this.fogColor = const Color(0xFF000000),
    this.featherSigma,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _FogPunchPainter(
            holeCenters: holeCenters,
            radiusMeters: radiusMeters,
            fogColor: fogColor,
            featherSigma: featherSigma,
            context: context,
          ),
        ),
      ),
    );
  }
}

class _FogPunchPainter extends CustomPainter {
  final List<LatLng> holeCenters;
  final double radiusMeters;
  final Color fogColor;
  final double? featherSigma;
  final BuildContext context;

  _FogPunchPainter({
    required this.holeCenters,
    required this.radiusMeters,
    required this.fogColor,
    required this.context,
    this.featherSigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (holeCenters.isEmpty) {
      // 구멍이 없어도 전체 검정은 칠해줘야 포그가 적용됨
      final paint = Paint()
        ..color = fogColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final mapState = FlutterMapState.maybeOf(context);
    if (mapState == null) return;

    final bounds = Offset.zero & size;

    // 1) 레이어 시작 (clear 펀칭을 적용하려면 saveLayer 필요)
    canvas.saveLayer(bounds, Paint());

    // 2) 화면 전체 포그 채우기
    final fogPaint = Paint()
      ..color = fogColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRect(bounds, fogPaint);

    // 3) 구멍은 clear로 '펀칭'
    final punch = Paint()
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    // feather(가장자리 부드럽게) 원할 경우
    if (featherSigma != null && featherSigma! > 0) {
      punch.maskFilter = MaskFilter.blur(BlurStyle.normal, featherSigma!);
    }

    // 미터 → 화면 픽셀 반경
    for (final c in holeCenters) {
      final centerPx = mapState.project(c);
      final cx = (centerPx.x - mapState.pixelOrigin.x).toDouble();
      final cy = (centerPx.y - mapState.pixelOrigin.y).toDouble();

      final rPx = _metersToScreenPixels(c, radiusMeters, mapState);

      final holePath = ui.Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: rPx));

      canvas.drawPath(holePath, punch);
    }

    // 4) 레이어 종료(펀칭 결과 적용)
    canvas.restore();
  }

  // 위도에 따른 미터→픽셀 변환 (줌/투영 반영)
  // - 위도 1도 ≈ 111320m를 활용해 북쪽으로 meters만큼 이동한 점의 픽셀 차이를 사용
  double _metersToScreenPixels(LatLng center, double meters, FlutterMapState mapState) {
    const metersPerDegLat = 111320.0; // 위도 1도당 미터
    final dLat = meters / metersPerDegLat;

    final a = mapState.project(center);
    final b = mapState.project(LatLng(center.latitude + dLat, center.longitude));

    final ay = (a.y - mapState.pixelOrigin.y).toDouble();
    final by = (b.y - mapState.pixelOrigin.y).toDouble();

    final pxPerMeter = (by - ay).abs() / meters;
    // 안전 가드: 너무 작은/큰 값 방지
    final r = (meters * pxPerMeter).clamp(2.0, 5000.0);
    return r;
  }

  @override
  bool shouldRepaint(covariant _FogPunchPainter old) {
    if (old.radiusMeters != radiusMeters ||
        old.fogColor != fogColor ||
        old.featherSigma != featherSigma ||
        old.pixelOrigin != pixelOrigin ||
        old.holeCenters.length != holeCenters.length) {
      return true;
    }
    // 간단 비교(필요시 딥 이퀄 구현)
    for (int i = 0; i < holeCenters.length; i++) {
      if (holeCenters[i] != old.holeCenters[i]) return true;
    }
    return false;
  }
}