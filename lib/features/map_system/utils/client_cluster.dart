// 근접(픽셀 거리) 클러스터링 엔진
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

// 프로젝트의 모델에 맞게 최소 필드만 사용
class ClusterMarkerModel {
  final String markerId;
  final LatLng position;
  const ClusterMarkerModel({required this.markerId, required this.position});
}

// LatLng -> 화면 좌표 변환 콜백 (맵 상태에서 주입)
typedef ToScreenFn = Offset Function(LatLng);

class ClusterOrMarker {
  final bool isCluster;
  final ClusterMarkerModel? single;
  final List<ClusterMarkerModel>? items;
  final Offset? screenCenter; // 화면좌표 중심(옵션)
  final ClusterMarkerModel? representative; // 대표 마커(지도의 점)

  ClusterOrMarker.single(this.single)
      : isCluster = false, items = null, screenCenter = null, representative = null;

  ClusterOrMarker.cluster({required this.items, required this.screenCenter, required this.representative})
      : isCluster = true, single = null;
}

// 마커 겹침 기반 클러스터링 임계값 (픽셀)
// 마커들이 이 거리 안에 있으면 자동으로 클러스터링됨
double get clusterThresholdPx => 50.0; // 고정값: 50픽셀

/// 근접(화면 픽셀 거리) 기반 클러스터링
List<ClusterOrMarker> buildProximityClusters({
  required List<ClusterMarkerModel> source,
  required ToScreenFn toScreen,
}) {
  // 고정 임계값 사용
  final thresholdPx = clusterThresholdPx;
  
  // thresholdPx가 0이면 클러스터링 하지 않고 모든 마커를 개별로 반환
  if (thresholdPx <= 0) {
    return source.map((m) => ClusterOrMarker.single(m)).toList();
  }

  final cell = thresholdPx; // 그리드 셀 크기 = 임계거리
  final grid = <String, List<int>>{}; // "gx:gy" -> cluster indices
  final items = <_MutCluster>[];

  int _newCluster(ClusterMarkerModel m, Offset sp) {
    items.add(_MutCluster()..add(m, sp));
    return items.length - 1;
  }

  for (final m in source) {
    final sp = toScreen(m.position);
    final gx = (sp.dx / cell).floor();
    final gy = (sp.dy / cell).floor();

    // 후보: 본 셀 + 8개 이웃 셀
    int? bestIdx;
    double bestD2 = 1e18;
    for (int ix = gx - 1; ix <= gx + 1; ix++) {
      for (int iy = gy - 1; iy <= gy + 1; iy++) {
        final key = '$ix:$iy';
        final list = grid[key];
        if (list == null) continue;
        for (final ci in list) {
          final c = items[ci];
          final center = c.screenCenter;
          final dx = center.dx - sp.dx, dy = center.dy - sp.dy;
          final d2 = dx*dx + dy*dy;
          if (d2 <= (thresholdPx * thresholdPx) && d2 < bestD2) {
            bestD2 = d2; bestIdx = ci;
          }
        }
      }
    }

    if (bestIdx == null) {
      final ci = _newCluster(m, sp);
      (grid['$gx:$gy'] ??= <int>[]).add(ci);
    } else {
      items[bestIdx].add(m, sp);
      // 그리드 인덱스 재배치는 생략(근사). 필요하면 업데이트 가능.
    }
  }

  // Out
  return items.map((c) {
    if (c.count == 1) {
      return ClusterOrMarker.single(c.one!);
    } else {
      return ClusterOrMarker.cluster(
        items: List.unmodifiable(c.list),
        screenCenter: c.screenCenter,
        representative: c.list.first, // 대표 하나
      );
    }
  }).toList(growable: false);
}

class _MutCluster {
  final list = <ClusterMarkerModel>[];
  double sx = 0, sy = 0;
  int count = 0;
  void add(ClusterMarkerModel m, Offset sp) { list.add(m); sx += sp.dx; sy += sp.dy; count++; }
  Offset get screenCenter => Offset(sx / count, sy / count);
  ClusterMarkerModel? get one => list.isEmpty ? null : list.first;
}

// ─────────────────────────────────────────────────────────────────────────────
// WebMercator 기반 LatLng→스크린 픽셀 변환 헬퍼
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