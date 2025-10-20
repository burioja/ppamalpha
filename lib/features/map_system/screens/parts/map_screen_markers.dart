part of '../map_screen.dart';

// ==================== 마커 및 클러스터링 관련 메서드들 ====================

/// 마커 업데이트
void _updateMarkers() {
  // MarkerModel을 새로운 클러스터링 시스템용으로 변환
  _visibleMarkerModels = _markers.map((marker) => ClusterMarkerModel(
    markerId: marker.markerId,
    position: marker.position,
  )).toList();

  // 새로운 클러스터링 시스템 적용
  _rebuildClusters();
  
  // 마커 업데이트 시 수령 가능 개수도 업데이트
  _updateReceivablePosts();
}

/// LatLng -> 화면 좌표 변환 함수
Offset _latLngToScreen(LatLng ll) {
  return latLngToScreenWebMercator(
    ll, 
    mapCenter: _mapCenter, 
    zoom: _mapZoom, 
    viewSize: _lastMapSize,
  );
}

/// 클러스터링 재구성
void _rebuildClusters() {
  if (_visibleMarkerModels.isEmpty) {
    setState(() {
      _clusteredMarkers = [];
    });
    return;
  }

  // 근접 클러스터링 수행 (고정 임계값 사용)
  final buckets = buildProximityClusters(
    source: _visibleMarkerModels,
    toScreen: _latLngToScreen,
  );

  final markers = <Marker>[];
  
  for (final bucket in buckets) {
    if (!bucket.isCluster) {
      // 단일 마커
      final marker = bucket.single!;
      final isSuper = _isSuperMarker(marker);
      final imagePath = isSuper ? 'assets/images/ppam_super.png' : 'assets/images/ppam_work.png';
      final imageSize = isSuper ? 36.0 : 31.0;
      
      // 원본 MarkerModel에서 creatorId 가져오기
      final originalMarker = _markers.firstWhere(
        (m) => m.markerId == marker.markerId,
        orElse: () => throw Exception('Marker not found'),
      );
      
    markers.add(
      Marker(
          key: ValueKey('single_${marker.markerId}'),
        point: marker.position,
        width: 35,
        height: 35,
          child: SingleMarkerWidget(
            imagePath: imagePath,
            size: imageSize,
            isSuper: isSuper,
            userId: originalMarker.creatorId,
            onTap: () => _onTapSingleMarker(marker),
          ),
        ),
      );
    } else {
      // 클러스터 마커
      final rep = bucket.representative!;
      markers.add(
        Marker(
          key: ValueKey('cluster_${rep.markerId}_${bucket.items!.length}'),
          point: rep.position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _zoomIntoCluster(bucket),
            child: SimpleClusterDot(count: bucket.items!.length),
        ),
      ),
    );
    }
  }

  setState(() {
    _clusteredMarkers = markers;
  });
}

/// 슈퍼 마커인지 확인
bool _isSuperMarker(ClusterMarkerModel marker) {
  // 원본 MarkerModel에서 reward 확인
  final originalMarker = _markers.firstWhere(
    (m) => m.markerId == marker.markerId,
    orElse: () => throw Exception('Marker not found'),
  );
  final markerReward = originalMarker.reward ?? 0;
  return markerReward >= AppConsts.superRewardThreshold;
}

/// 단일 마커 탭 처리
void _onTapSingleMarker(ClusterMarkerModel marker) {
  // 기존 MarkerModel을 찾아서 상세 정보 표시
  final originalMarker = _markers.firstWhere(
    (m) => m.markerId == marker.markerId,
    orElse: () => throw Exception('Marker not found'),
  );
  _showMarkerDetails(originalMarker);
}

/// 클러스터 탭 시 확대
void _zoomIntoCluster(ClusterOrMarker cluster) {
  final rep = cluster.representative!;
  final targetZoom = (_mapZoom + 1.5).clamp(14.0, 16.0); // 앱의 줌 범위 내에서
  _mapController?.move(rep.position, targetZoom);
}

