import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/marker/marker_model.dart';
import '../widgets/cluster_widgets.dart';
import '../utils/client_cluster.dart' show ClusterMarkerModel, ClusterOrMarker, buildProximityClusters, latLngToScreenWebMercator;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/data/marker_domain_service.dart' as core_marker;

/// 마커 관련 로직을 관리하는 컨트롤러
class MarkerController {
  /// MarkerModel 리스트를 ClusterMarkerModel 리스트로 변환
  static List<ClusterMarkerModel> convertToClusterModels(List<MarkerModel> markers) {
    return markers.map((marker) => ClusterMarkerModel(
      markerId: marker.markerId,
      position: marker.position,
    )).toList();
  }

  /// 클러스터링된 마커 리스트 생성
  /// 
  /// [markers]: 원본 마커 리스트
  /// [visibleMarkerModels]: 화면에 보이는 클usterMarkerModel 리스트
  /// [mapCenter]: 지도 중심 좌표
  /// [mapZoom]: 현재 줌 레벨
  /// [viewSize]: 화면 크기
  /// [onTapSingle]: 단일 마커 탭 콜백
  /// [onTapCluster]: 클러스터 탭 콜백
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
    
    // LatLng -> 화면 좌표 변환 함수
    Offset latLngToScreen(LatLng ll) {
      return latLngToScreenWebMercator(
        ll,
        mapCenter: mapCenter,
        zoom: mapZoom,
        viewSize: viewSize,
      );
    }
    
    // 근접 클러스터링 수행 (고정 임계값 사용)
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
        
        // 원본 MarkerModel에서 creatorId 가져오기
        final originalMarker = markers.firstWhere(
          (m) => m.markerId == marker.markerId,
          orElse: () => throw Exception('Marker not found: ${marker.markerId}'),
        );
        
        resultMarkers.add(
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
              onTap: () => onTapSingle(marker),
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

    debugPrint('🔧 근접 클러스터링 완료 (줌 ${mapZoom.toStringAsFixed(1)}, 임계값 50px): ${buckets.length}개 그룹, ${resultMarkers.length}개 마커');
    return resultMarkers;
  }

  /// 슈퍼 마커인지 확인
  static bool _isSuperMarker(ClusterMarkerModel clusterMarker, List<MarkerModel> markers) {
    // 원본 MarkerModel에서 reward 확인
    final originalMarker = markers.firstWhere(
      (m) => m.markerId == clusterMarker.markerId,
      orElse: () => throw Exception('Marker not found: ${clusterMarker.markerId}'),
    );
    final markerReward = originalMarker.reward ?? 0;
    return markerReward >= AppConsts.superRewardThreshold;
  }

  /// 마커 수집 가능 여부 확인
  static bool canCollectMarker(LatLng userPosition, LatLng markerPosition) {
    return core_marker.MarkerDomainService.canCollectMarker(userPosition, markerPosition);
  }

  /// 마커 회수 (삭제)
  static Future<bool> removeMarker(String markerId, String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != userId) {
        debugPrint('❌ 마커 회수 권한 없음');
        return false;
      }

      // Firestore에서 마커 삭제
      await FirebaseFirestore.instance
          .collection('markers')
          .doc(markerId)
          .delete();

      debugPrint('✅ 마커 회수 완료: $markerId');
      return true;
    } catch (e) {
      debugPrint('❌ 마커 회수 실패: $e');
      return false;
    }
  }

  /// ClusterMarkerModel에서 원본 MarkerModel 찾기
  static MarkerModel? findOriginalMarker(
    ClusterMarkerModel clusterMarker,
    List<MarkerModel> markers,
  ) {
    try {
      return markers.firstWhere(
        (m) => m.markerId == clusterMarker.markerId,
      );
    } catch (e) {
      debugPrint('❌ 원본 마커를 찾을 수 없음: ${clusterMarker.markerId}');
      return null;
    }
  }

  /// 줌 레벨에 따른 클러스터 확대 타겟 줌 계산
  static double calculateClusterZoomTarget(double currentZoom) {
    return (currentZoom + 1.5).clamp(14.0, 16.0);
  }
}

