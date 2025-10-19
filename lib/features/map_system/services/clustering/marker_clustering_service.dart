import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/marker/marker_model.dart';
import '../../utils/client_cluster.dart';
export '../../utils/client_cluster.dart' show ClusterMarkerModel, ClusterOrMarker, latLngToScreenWebMercator, buildClusters;

/// 마커 클러스터링 서비스
/// 
/// **책임**: 마커 클러스터링 비즈니스 로직
/// **원칙**:
/// - UI/Provider와 분리
/// - Firebase 호출 없음
/// - 순수 계산 로직만
class MarkerClusteringService {
  /// 줌 레벨에 따른 클러스터 임계값 계산 (픽셀)
  static double clusterThreshold(double zoom) {
    if (zoom >= 16) return 30.0;
    if (zoom >= 14) return 40.0;
    if (zoom >= 12) return 50.0;
    return 60.0;
  }

  /// MarkerModel을 ClusterMarkerModel로 변환
  static List<ClusterMarkerModel> convertToClusterModels(
    List<MarkerModel> markers,
  ) {
    return markers.map((marker) {
      return ClusterMarkerModel(
        markerId: marker.markerId,
        position: marker.position,
      );
    }).toList();
  }

  /// 근접 클러스터링 수행
  /// 
  /// [markers]: 원본 마커 리스트
  /// [mapCenter]: 지도 중심 좌표
  /// [zoom]: 현재 줌 레벨
  /// [viewSize]: 화면 크기
  /// 
  /// Returns: 클러스터링된 그룹 리스트
  static List<ClusterOrMarker> performClustering({
    required List<MarkerModel> markers,
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
  }) {
    if (markers.isEmpty) {
      return [];
    }

    // MarkerModel을 ClusterMarkerModel로 변환
    final clusterModels = convertToClusterModels(markers);
    
    // 임계값 계산
    final thresholdPx = clusterThreshold(zoom);
    
    // LatLng -> 화면 좌표 변환 함수
    Offset latLngToScreen(LatLng ll) {
      return latLngToScreenWebMercator(
        ll,
        mapCenter: mapCenter,
        zoom: zoom,
        viewSize: viewSize,
      );
    }
    
    // 근접 클러스터링 수행
    final clusters = buildClusters(
      source: clusterModels,
      toScreen: latLngToScreen,
      cellPx: thresholdPx,
    );

    debugPrint(
      '🔧 클러스터링 완료: '
      '줌=${zoom.toStringAsFixed(1)}, '
      '임계값=${thresholdPx.toInt()}px, '
      '입력=${markers.length}개, '
      '결과=${clusters.length}개 그룹',
    );

    return clusters;
  }

  /// 클러스터 확대 타겟 줌 계산
  static double calculateClusterZoomTarget(double currentZoom) {
    return (currentZoom + 1.5).clamp(14.0, 18.0);
  }

  /// 슈퍼 마커 여부 확인
  static bool isSuperMarker(MarkerModel marker, int superThreshold) {
    final reward = marker.reward ?? 0;
    return reward >= superThreshold;
  }

  /// 원본 마커 찾기
  static MarkerModel? findOriginalMarker(
    String markerId,
    List<MarkerModel> markers,
  ) {
    try {
      return markers.firstWhere(
        (m) => m.markerId == markerId,
      );
    } catch (e) {
      debugPrint('❌ 원본 마커를 찾을 수 없음: $markerId');
      return null;
    }
  }

  /// 클러스터 내 마커들의 중심 좌표 계산
  static LatLng calculateClusterCenter(List<ClusterMarkerModel> markers) {
    if (markers.isEmpty) {
      return const LatLng(0, 0);
    }

    double sumLat = 0;
    double sumLng = 0;

    for (final marker in markers) {
      sumLat += marker.position.latitude;
      sumLng += marker.position.longitude;
    }

    return LatLng(
      sumLat / markers.length,
      sumLng / markers.length,
    );
  }

  /// 줌 레벨에 따른 클러스터 크기 계산
  static double getClusterSize(double zoom) {
    if (zoom >= 16) return 35;
    if (zoom >= 14) return 40;
    return 45;
  }

  /// 마커 아이콘 경로 가져오기
  static String getMarkerIconPath(bool isSuper) {
    return isSuper 
        ? 'assets/images/ppam_super.png' 
        : 'assets/images/ppam_work.png';
  }

  /// 마커 아이콘 크기 가져오기
  static double getMarkerIconSize(bool isSuper) {
    return isSuper ? 36.0 : 31.0;
  }
}

