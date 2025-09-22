import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 포그 오브 워 오버레이 위젯
class FogOverlayWidget extends StatelessWidget {
  final List<Polygon> polygons;
  final List<CircleMarker> ringCircles;

  const FogOverlayWidget({
    super.key,
    required this.polygons,
    required this.ringCircles,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // 포그 폴리곤들만 표시 (링 서클 제거)
          if (polygons.isNotEmpty)
            PolygonLayer(
              polygons: polygons,
            ),
        ],
      ),
    );
  }
}