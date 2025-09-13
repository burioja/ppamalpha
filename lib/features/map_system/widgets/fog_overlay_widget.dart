import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/fog_of_war/fog_tile_service.dart';

/// Fog of War 오버레이 위젯
class FogOverlayWidget extends StatefulWidget {
  final LatLng? currentPosition;
  final List<LatLng> visitedPositions;
  final bool isVisible;
  final VoidCallback? onFogUpdate;

  const FogOverlayWidget({
    super.key,
    this.currentPosition,
    this.visitedPositions = const [],
    this.isVisible = true,
    this.onFogUpdate,
  });

  @override
  State<FogOverlayWidget> createState() => _FogOverlayWidgetState();
}

class _FogOverlayWidgetState extends State<FogOverlayWidget> {
  final FogTileService _fogService = FogTileService();
  List<Polygon> _fogPolygons = [];
  List<Polygon> _grayPolygons = [];

  @override
  void initState() {
    super.initState();
    _updateFogPolygons();
  }

  @override
  void didUpdateWidget(FogOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.visitedPositions != widget.visitedPositions) {
      _updateFogPolygons();
    }
  }

  void _updateFogPolygons() {
    if (!widget.isVisible) {
      setState(() {
        _fogPolygons = [];
        _grayPolygons = [];
      });
      return;
    }

    // 현재 위치 기반 포그 폴리곤 생성
    if (widget.currentPosition != null) {
      final currentFog = FogTileService.createFogPolygon(widget.currentPosition!);

      // 방문한 위치들 기반 회색 폴리곤 생성
      final grayFog = widget.visitedPositions.isNotEmpty
          ? FogTileService.createGrayFogPolygon(widget.visitedPositions)
          : null;

      setState(() {
        _fogPolygons = [currentFog];
        _grayPolygons = grayFog != null ? [grayFog] : [];
      });

      widget.onFogUpdate?.call();
    }
  }

  /// Fog를 토글합니다
  void toggleFog() {
    setState(() {
      if (_fogPolygons.isNotEmpty || _grayPolygons.isNotEmpty) {
        _fogPolygons = [];
        _grayPolygons = [];
      } else {
        _updateFogPolygons();
      }
    });
  }

  /// Fog를 새로고침합니다
  void refreshFog() {
    _updateFogPolygons();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible ||
        (_fogPolygons.isEmpty && _grayPolygons.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // 회색 폴리곤 (과거 방문 위치)
        if (_grayPolygons.isNotEmpty)
          IgnorePointer(
            child: Container(
              child: CustomPaint(
                painter: PolygonPainter(_grayPolygons),
                size: Size.infinite,
              ),
            ),
          ),

        // 검은 포그 폴리곤 (미방문 영역)
        if (_fogPolygons.isNotEmpty)
          IgnorePointer(
            child: Container(
              child: CustomPaint(
                painter: PolygonPainter(_fogPolygons),
                size: Size.infinite,
              ),
            ),
          ),

        // Fog 컨트롤 버튼
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: "fog_toggle",
                onPressed: toggleFog,
                backgroundColor: Colors.black87,
                child: Icon(
                  _fogPolygons.isNotEmpty || _grayPolygons.isNotEmpty
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: "fog_refresh",
                onPressed: refreshFog,
                backgroundColor: Colors.black87,
                child: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fogService.dispose();
    super.dispose();
  }
}

/// 폴리곤을 그리는 커스텀 페인터
class PolygonPainter extends CustomPainter {
  final List<Polygon> polygons;

  PolygonPainter(this.polygons);

  @override
  void paint(Canvas canvas, Size size) {
    for (final polygon in polygons) {
      final paint = Paint()
        ..color = polygon.color ?? Colors.black
        ..style = PaintingStyle.fill;

      final path = Path();

      // 메인 폴리곤 경로
      if (polygon.points.isNotEmpty) {
        final firstPoint = polygon.points.first;
        path.moveTo(firstPoint.longitude, firstPoint.latitude);

        for (int i = 1; i < polygon.points.length; i++) {
          final point = polygon.points[i];
          path.lineTo(point.longitude, point.latitude);
        }
        path.close();
      }

      // 홀 경로들 (역방향)
      for (final hole in polygon.holePointsList ?? []) {
        if (hole.isNotEmpty) {
          final firstHole = hole.first;
          path.moveTo(firstHole.longitude, firstHole.latitude);

          for (int i = hole.length - 1; i >= 0; i--) {
            final point = hole[i];
            path.lineTo(point.longitude, point.latitude);
          }
          path.close();
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}