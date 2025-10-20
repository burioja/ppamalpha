import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/marker/marker_model.dart';
import '../utils/client_cluster.dart';
import '../widgets/cluster_widgets.dart';
import '../../../core/constants/app_constants.dart';

/// 마커 클러스터링 헬퍼 (독립적인 순수 함수들)
class MarkerClusteringHelper {
  /// MarkerModel을 ClusterMarkerModel로 변환
  static List<ClusterMarkerModel> convertToClusterModels(List<MarkerModel> markers) {
    return markers.map((marker) => ClusterMarkerModel(
      markerId: marker.markerId,
      position: marker.position,
    )).toList();
  }

  /// 클러스터링 수행 후 Marker 위젯 리스트 생성
  static List<Marker> buildClusteredMarkers({
    required List<MarkerModel> markers,
    required List<ClusterMarkerModel> visibleMarkerModels,
    required LatLng mapCenter,
    required double mapZoom,
    required Size viewSize,
    required Function(ClusterMarkerModel) onTapSingle,
    required Function(ClusterOrMarker) onTapCluster,
  }) {
    if (visibleMarkerModels.isEmpty) {
      return [];
    }

    // 화면 좌표 변환 함수
    Offset latLngToScreen(LatLng ll) {
      return latLngToScreenWebMercator(
        ll,
        mapCenter: mapCenter,
        zoom: mapZoom,
        viewSize: viewSize,
      );
    }

    // 근접 클러스터링 수행
    final buckets = buildProximityClusters(
      source: visibleMarkerModels,
      toScreen: latLngToScreen,
    );

    final resultMarkers = <Marker>[];

    for (final bucket in buckets) {
      if (!bucket.isCluster) {
        // 단일 마커
        final marker = bucket.single!;
        final isSuper = _isSuperMarker(marker, markers);
        final imagePath = isSuper ? 'assets/images/ppam_super.png' : 'assets/images/ppam_work.png';
        final imageSize = isSuper ? 36.0 : 31.0;

        resultMarkers.add(
          Marker(
            key: ValueKey('single_${marker.markerId}'),
            point: marker.position,
            width: 35,
            height: 35,
            child: GestureDetector(
              onTap: () => onTapSingle(marker),
              child: Image.asset(
                imagePath,
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      color: isSuper ? Colors.orange : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.place, color: Colors.white, size: 20),
                  );
                },
              ),
            ),
          ),
        );
      } else {
        // 클러스터 마커
        final rep = bucket.representative!;
        resultMarkers.add(
          Marker(
            key: ValueKey('cluster_${rep.markerId}_${bucket.items!.length}'),
            point: rep.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => onTapCluster(bucket),
              child: SimpleClusterDot(count: bucket.items!.length),
            ),
          ),
        );
      }
    }

    return resultMarkers;
  }

  /// 슈퍼 마커 여부 확인
  static bool _isSuperMarker(ClusterMarkerModel marker, List<MarkerModel> allMarkers) {
    final originalMarker = allMarkers.firstWhere(
      (m) => m.markerId == marker.markerId,
      orElse: () => throw Exception('Marker not found'),
    );
    final markerReward = originalMarker.reward ?? 0;
    return markerReward >= AppConsts.superRewardThreshold;
  }

  /// 원본 MarkerModel 찾기
  static MarkerModel? findOriginalMarker(
    ClusterMarkerModel clusterMarker,
    List<MarkerModel> allMarkers,
  ) {
    try {
      return allMarkers.firstWhere(
        (m) => m.markerId == clusterMarker.markerId,
      );
    } catch (e) {
      return null;
    }
  }

  /// 클러스터 줌 타겟 계산
  static double calculateClusterZoomTarget(double currentZoom) {
    return (currentZoom + 1.5).clamp(14.0, 16.0);
  }
}

