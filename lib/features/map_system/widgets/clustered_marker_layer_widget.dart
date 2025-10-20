import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';
import '../providers/marker_provider.dart';

/// 클러스터링된 마커 레이어 위젯
/// 
/// map_screen.dart에서 전달받은 클러스터링 마커 렌더링
class ClusteredMarkerLayerWidget extends StatelessWidget {
  final List<Marker> clusteredMarkers;

  const ClusteredMarkerLayerWidget({
    super.key,
    required this.clusteredMarkers,
  });

  @override
  Widget build(BuildContext context) {
    // clusteredMarkers가 비어있으면 빈 레이어 반환
    if (clusteredMarkers.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 클러스터링된 마커 렌더링
    return MarkerLayer(markers: clusteredMarkers);
  }
}

