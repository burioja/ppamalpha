import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../../../core/models/marker/marker_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../../core/constants/app_constants.dart';
import '../utils/client_side_cluster.dart';
import '../utils/client_cluster.dart' show clusterThresholdPx;
import '../widgets/cluster_widgets.dart' hide SimpleClusterDot;

/// 마커 & 클러스터링 시스템 Handler
/// 
/// map_screen.dart에서 분리한 마커 관련 모든 기능
class MapMarkerHandler {
  // 마커 상태
  List<MarkerModel> markers = [];
  List<ClusterMarkerModel> visibleMarkerModels = [];
  List<Marker> clusteredMarkers = [];
  Widget? customMarkerIcon;

  // 지도 상태 (외부에서 전달받음)
  LatLng mapCenter = const LatLng(0, 0);
  double mapZoom = 15.0;
  Size lastMapSize = Size.zero;

  /// 커스텀 마커 아이콘 로드
  void loadCustomMarker() {
    customMarkerIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/ppam_work.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 현재 위치 마커 생성
  Marker createCurrentLocationMarker(LatLng position) {
    return Marker(
      point: position,
      width: 100,
      height: 100,
      child: Icon(
        Icons.my_location,
        color: Colors.blue,
        size: 30,
      ),
    );
  }

  /// 마커 업데이트
  void updateMarkers({
    required VoidCallback onRebuild,
  }) {
    debugPrint('🔧 _updateMarkers 호출됨 - _markers 개수: ${markers.length}');

    // MarkerModel을 클러스터링 시스템용으로 변환
    visibleMarkerModels = markers.map((marker) => ClusterMarkerModel(
      markerId: marker.markerId,
      position: marker.position,
    )).toList();

    onRebuild();
  }

  /// 클러스터 재구성
  void rebuildClusters({
    required Function(LatLng) latLngToScreen,
    required Function(ClusterMarkerModel) onTapSingleMarker,
    required Function(ClusterOrMarker) onZoomIntoCluster,
  }) {
    if (visibleMarkerModels.isEmpty) {
      clusteredMarkers = [];
      return;
    }

    // TODO: Implement proper clustering
    // For now, just create individual markers
    final buckets = visibleMarkerModels.map((marker) => 
      ClusterOrMarker.single(marker)).toList();

    final newMarkers = <Marker>[];
    
    for (final bucket in buckets) {
      if (!bucket.isCluster) {
        // 단일 마커
        final marker = bucket.single!;
        final isSuper = _isSuperMarker(marker);
        final imagePath = isSuper ? 'assets/images/ppam_super.png' : 'assets/images/ppam_work.png';
        final imageSize = isSuper ? 36.0 : 31.0;
        
        // 원본 MarkerModel에서 creatorId 가져오기
        final originalMarker = markers.firstWhere(
          (m) => m.markerId == marker.markerId,
          orElse: () => throw Exception('Marker not found'),
        );
        
        newMarkers.add(
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
              onTap: () => onTapSingleMarker(marker),
            ),
          ),
        );
      } else {
        // 클러스터 마커
        final rep = bucket.representative!;
        newMarkers.add(
          Marker(
            key: ValueKey('cluster_${rep.markerId}_${bucket.items!.length}'),
            point: rep.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => onZoomIntoCluster(bucket),
              child: const SimpleClusterDot(count: 1),
            ),
          ),
        );
      }
    }

    clusteredMarkers = newMarkers;
    final threshold = clusterThresholdPx(mapZoom);
    debugPrint('🔧 근접 클러스터링 완료 (줌 ${mapZoom.toStringAsFixed(1)}, 임계값 ${threshold.toInt()}px): ${buckets.length}개 그룹, ${newMarkers.length}개 마커');
  }

  /// 슈퍼 마커 확인
  bool _isSuperMarker(ClusterMarkerModel marker) {
    final originalMarker = markers.firstWhere(
      (m) => m.markerId == marker.markerId,
      orElse: () => throw Exception('Marker not found'),
    );
    final markerReward = originalMarker.reward ?? 0;
    return markerReward >= AppConsts.superRewardThreshold;
  }

  /// 단일 마커 탭 처리
  MarkerModel? onTapSingleMarker(ClusterMarkerModel marker) {
    final originalMarker = markers.firstWhere(
      (m) => m.markerId == marker.markerId,
      orElse: () => throw Exception('Marker not found'),
    );
    return originalMarker;
  }

  /// 클러스터 탭 처리
  (LatLng, double) onZoomIntoCluster(ClusterOrMarker cluster) {
    final rep = cluster.representative!;
    final targetZoom = (mapZoom + 1.5).clamp(14.0, 16.0);
    return (rep.position, targetZoom);
  }

  /// 마커 회수
  Future<bool> removeMarker({
    required MarkerModel marker,
    required String currentUserId,
  }) async {
    try {
      // 배포자 확인
      if (marker.creatorId != currentUserId) {
        return false;
      }

      debugPrint('');
      debugPrint('🟢🟢🟢 [MapMarkerHandler] 마커 회수 시작 🟢🟢🟢');
      debugPrint('🟢 marker.markerId: ${marker.markerId}');
      debugPrint('🟢 marker.postId: ${marker.postId}');
      debugPrint('');

      // 마커 회수
      // TODO: recallMarker 메소드 구현 필요
      // await PostService().recallMarker(marker.markerId);
      
      // 임시로 마커 삭제만 처리
      await MarkerService.deleteMarker(marker.markerId);

      debugPrint('');
      debugPrint('🟢 [MapMarkerHandler] 마커 회수 완료');
      debugPrint('🟢🟢🟢 ========================================== 🟢🟢🟢');
      debugPrint('');

      return true;
    } catch (e) {
      debugPrint('❌ 마커 회수 실패: $e');
      return false;
    }
  }

  /// 포스트로부터 마커 수집
  Future<bool> collectPostFromMarker({
    required MarkerModel marker,
    required String currentUserId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      debugPrint('');
      debugPrint('🟢🟢🟢 [MapMarkerHandler] 포스트 수집 시작 🟢🟢🟢');
      debugPrint('🟢 marker.markerId: ${marker.markerId}');
      debugPrint('🟢 marker.postId: ${marker.postId}');
      debugPrint('');

      // TODO: Implement PostService.collectPost method
      // For now, return false
      final success = false;

      if (success) {
        // 로컬 마커 목록에서 제거
        markers.removeWhere((m) => m.postId == marker.postId);
        debugPrint('🟢 포스트 수집 완료 및 마커 제거');
      }

      return success;
    } catch (e) {
      debugPrint('❌ 포스트 수집 실패: $e');
      return false;
    }
  }

  /// 마커 목록 갱신
  void setMarkers(List<MarkerModel> newMarkers) {
    markers = newMarkers;
    debugPrint('🔧 마커 목록 업데이트: ${markers.length}개');
  }

  /// 지도 상태 업데이트
  void updateMapState({
    required LatLng center,
    required double zoom,
    required Size size,
  }) {
    mapCenter = center;
    mapZoom = zoom;
    lastMapSize = size;
  }

  /// 단일 마커 탭 핸들러
  MarkerModel? onTapSingleMarker(ClusterMarkerModel clusterMarker) {
    try {
      final originalMarker = markers.firstWhere(
        (m) => m.markerId == clusterMarker.markerId,
      );
      return originalMarker;
    } catch (e) {
      debugPrint('❌ 마커를 찾을 수 없습니다: ${clusterMarker.markerId}');
      return null;
    }
  }

  /// 클러스터 탭 시 확대 좌표 반환
  (LatLng, double)? getClusterZoomTarget(ClusterOrMarker cluster, double currentZoom) {
    final rep = cluster.representative;
    if (rep == null) return null;
    
    final targetZoom = (currentZoom + 1.5).clamp(14.0, 16.0);
    return (rep.position, targetZoom);
  }
}

/// LatLng를 Web Mercator 화면 좌표로 변환
Offset latLngToScreenWebMercator(
  LatLng ll, {
  required LatLng mapCenter,
  required double zoom,
  required Size viewSize,
}) {
  // Web Mercator 투영
  final scale = 256.0 * (1 << zoom.floor());
  
  // 타일 좌표 계산
  final centerTileX = (mapCenter.longitude + 180.0) / 360.0 * scale;
  final centerTileY = (1.0 - math.log(math.tan(mapCenter.latitude * math.pi / 180.0) + 
      1.0 / math.cos(mapCenter.latitude * math.pi / 180.0)) / math.pi) / 2.0 * scale;
  
  final pointTileX = (ll.longitude + 180.0) / 360.0 * scale;
  final pointTileY = (1.0 - math.log(math.tan(ll.latitude * math.pi / 180.0) + 
      1.0 / math.cos(ll.latitude * math.pi / 180.0)) / math.pi) / 2.0 * scale;
  
  // 화면 좌표로 변환
  final dx = (pointTileX - centerTileX) + viewSize.width / 2.0;
  final dy = (pointTileY - centerTileY) + viewSize.height / 2.0;
  
  return Offset(dx, dy);
}

