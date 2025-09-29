// 클라이언트 클러스터링 (의존성 최소):
// - flutter_map의 Marker 위젯만 사용
// - plugin_api 사용 안 함 (버전 독립)
// - 화면 픽셀 그리드 기반 O(N) 클러스터링

import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- 프로젝트의 MarkerModel에 맞게 position, markerId만 쓰는 걸 가정 ---
class ClusterMarkerModel {
  final String markerId;
  final LatLng position;
  const ClusterMarkerModel({required this.markerId, required this.position});
}

// 화면 좌표 변환 콜백 (맵 상태에서 주입해 사용)
typedef ToScreenFn = Offset Function(LatLng);

// ─────────────────────────────────────────────────────────────────────────────
// 1) 클러스터 엔진
class _ClusterBucket {
  final List<ClusterMarkerModel> items = [];
  double sx = 0, sy = 0;
  void add(ClusterMarkerModel m, Offset sp) { items.add(m); sx += sp.dx; sy += sp.dy; }
  Offset get screenCenter => Offset(sx / items.length, sy / items.length);
}

class ClusterOrMarker {
  final bool isCluster;
  final ClusterMarkerModel? single;
  final List<ClusterMarkerModel>? items;
  final Offset? screenCenter;
  final ClusterMarkerModel? representative;

  ClusterOrMarker.single(this.single)
      : isCluster = false, items = null, screenCenter = null, representative = null;

  ClusterOrMarker.cluster({
    required this.items,
    required this.screenCenter,
    required this.representative,
  })  : isCluster = true, single = null;
}

/// 픽셀 그리드 기반 클러스터링 (cellPx: 같은 셀에 들어오면 한 클러스터)
List<ClusterOrMarker> buildClusters({
  required List<ClusterMarkerModel> source,
  required ToScreenFn toScreen,
  double cellPx = 60, // 줌 낮을수록 80~100, 높을수록 40 권장
}) {
  final buckets = <String, _ClusterBucket>{};

  for (final m in source) {
    final sp = toScreen(m.position);
    final gx = (sp.dx / cellPx).floor();
    final gy = (sp.dy / cellPx).floor();
    final key = '$gx:$gy';
    (buckets[key] ??= _ClusterBucket()).add(m, sp);
  }

  final out = <ClusterOrMarker>[];
  buckets.forEach((_, b) {
    if (b.items.length == 1) {
      out.add(ClusterOrMarker.single(b.items.first));
    } else {
      final rep = b.items.first; // 대표 1개 (간단/빠름)
      out.add(ClusterOrMarker.cluster(
        items: b.items,
        screenCenter: b.screenCenter,
        representative: rep,
      ));
    }
  });
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2) FlutterMap Marker로 변환 (대표 아이템 위치 사용)
typedef SingleMarkerBuilder = Widget Function(ClusterMarkerModel model);
typedef ClusterMarkerBuilder = Widget Function(int count, ClusterMarkerModel representative);

List<Marker> clustersToFlutterMarkers({
  required List<ClusterOrMarker> buckets,
  required SingleMarkerBuilder buildSingle,
  required ClusterMarkerBuilder buildCluster,
  double singleSize = 35,
  double clusterSize = 36,
}) {
  final markers = <Marker>[];
  for (final b in buckets) {
    if (!b.isCluster) {
      final m = b.single!;
      markers.add(
        Marker(
          key: ValueKey('m_${m.markerId}'),
          point: m.position,
          width: singleSize,
          height: singleSize,
          child: buildSingle(m),
        ),
      );
    } else {
      final rep = b.representative!;
      markers.add(
        Marker(
          key: ValueKey('c_${rep.markerId}_${b.items!.length}'),
          point: rep.position, // 대표 아이템 위치 사용 (실무적으로 충분)
          width: clusterSize,
          height: clusterSize,
          child: buildCluster(b.items!.length, rep),
        ),
      );
    }
  }
  return markers;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3) (선택) 간단한 클러스터 도트 위젯
class SimpleClusterDot extends StatelessWidget {
  const SimpleClusterDot({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xAA000000),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4) (옵션) WebMercator 기반 LatLng→스크린 픽셀 변환 헬퍼
// plugin_api 없이도 사용 가능. mapCenter/zoom/뷰 사이즈만 넘겨주면 됨.
Offset latLngToScreenWebMercator(
  LatLng ll, {
  required LatLng mapCenter,
  required double zoom,
  required Size viewSize,
}) {
  const tileSize = 256.0;
  const pi = math.pi;

  double worldX(LatLng p) => (p.longitude + 180.0) / 360.0 * tileSize * math.pow(2.0, zoom);
  double worldY(LatLng p) {
    final latRad = p.latitude * pi / 180.0;
    return (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / pi) / 2 * tileSize * math.pow(2.0, zoom);
  }

  final cx = worldX(mapCenter), cy = worldY(mapCenter);
  final x  = worldX(ll)       , y  = worldY(ll);
  final dx = x - cx, dy = y - cy;
  return Offset(viewSize.width / 2 + dx, viewSize.height / 2 + dy);
}
