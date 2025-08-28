import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/post_model.dart';
import 'map_marker_controller.dart';

/// 클러스터링을 담당하는 컨트롤러
class MapClusteringController {
  final MapMarkerController _markerController;
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;
  
  // 클러스터링 설정
  static const double _clusterRadius = 0.01; // 약 1km
  static const double _clusteringZoomThreshold = 12.0;
  
  // Getters
  Set<Marker> get clusteredMarkers => Set.unmodifiable(_clusteredMarkers);
  bool get isClustered => _isClustered;

  MapClusteringController(this._markerController);

  /// 줌 레벨에 따른 클러스터링 업데이트
  void updateClustering(double zoomLevel, {
    bool showCouponsOnly = false,
    bool showMyPostsOnly = false,
    String? currentUserId,
  }) {
    if (zoomLevel < _clusteringZoomThreshold) {
      _clusterMarkers(showCouponsOnly: showCouponsOnly, showMyPostsOnly: showMyPostsOnly, currentUserId: currentUserId);
    } else {
      _showIndividualMarkers(showCouponsOnly: showCouponsOnly, showMyPostsOnly: showMyPostsOnly, currentUserId: currentUserId);
    }
    
    debugPrint('클러스터링 업데이트: 줌=$zoomLevel, 클러스터링=$_isClustered, 마커 수=${_clusteredMarkers.length}');
  }

  /// 마커 클러스터링
  void _clusterMarkers({
    bool showCouponsOnly = false,
    bool showMyPostsOnly = false,
    String? currentUserId,
  }) {
    if (_isClustered) return;
    
    debugPrint('클러스터링 시작: 마커 아이템 ${_markerController.markerItems.length}개, 포스트 ${_markerController.posts.length}개');
    
    final clusters = <String, List<dynamic>>{};
    
    // 마커 아이템들 클러스터링
    for (final item in _markerController.markerItems) {
      if (!_shouldShowMarker(item, showCouponsOnly, showMyPostsOnly, currentUserId)) continue;
      
      _addToCluster(clusters, item);
    }
    
    // 포스트들 클러스터링
    for (final post in _markerController.posts) {
      if (!_shouldShowPost(post, showCouponsOnly, showMyPostsOnly, currentUserId)) continue;
      
      _addToCluster(clusters, post);
    }
    
    _createClusteredMarkers(clusters);
    
    _isClustered = true;
  }

  /// 개별 마커 표시
  void _showIndividualMarkers({
    bool showCouponsOnly = false,
    bool showMyPostsOnly = false,
    String? currentUserId,
  }) {
    debugPrint('개별 마커 표시 시작: 마커 아이템 ${_markerController.markerItems.length}개, 포스트 ${_markerController.posts.length}개');
    
    final Set<Marker> newMarkers = {};
    
    // 마커 아이템들 추가
    for (final item in _markerController.markerItems) {
      if (!_shouldShowMarker(item, showCouponsOnly, showMyPostsOnly, currentUserId)) continue;
      
      newMarkers.add(_markerController.createMarker(item, null));
      debugPrint('마커 추가됨: ${item.title} at ${item.position}');
    }
    
    // 포스트 마커들 추가
    for (final post in _markerController.posts) {
      if (!_shouldShowPost(post, showCouponsOnly, showMyPostsOnly, currentUserId)) continue;
      
      newMarkers.add(_markerController.createPostMarker(post, null));
      debugPrint('포스트 마커 추가됨: ${post.title} at ${post.location}');
    }
    
    _clusteredMarkers.clear();
    _clusteredMarkers.addAll(newMarkers);
    _isClustered = false;
    
    debugPrint('마커 설정 완료: 총 ${newMarkers.length}개 마커');
  }

  /// 마커가 표시되어야 하는지 확인
  bool _shouldShowMarker(MapMarkerItem item, bool showCouponsOnly, bool showMyPostsOnly, String? currentUserId) {
    // 쿠폰만 필터
    if (showCouponsOnly && item.data['type'] != 'post_place') return false;
    
    // 내 포스트만 필터
    if (showMyPostsOnly && item.userId != currentUserId) return false;
    
    return true;
  }

  /// 포스트가 표시되어야 하는지 확인
  bool _shouldShowPost(PostModel post, bool showCouponsOnly, bool showMyPostsOnly, String? currentUserId) {
    // 쿠폰만 필터
    if (showCouponsOnly && !(post.canUse || post.canRequestReward)) return false;
    
    // 내 포스트만 필터
    if (showMyPostsOnly && post.creatorId != currentUserId) return false;
    
    return true;
  }

  /// 클러스터에 아이템 추가
  void _addToCluster(Map<String, List<dynamic>> clusters, dynamic item) {
    bool addedToCluster = false;
    
    for (final clusterKey in clusters.keys) {
      final clusterCenter = _parseLatLng(clusterKey);
      final itemPosition = _getItemPosition(item);
      final distance = _calculateDistance(clusterCenter, itemPosition);
      
      if (distance <= _clusterRadius) {
        clusters[clusterKey]!.add(item);
        addedToCluster = true;
        break;
      }
    }
    
    if (!addedToCluster) {
      final itemPosition = _getItemPosition(item);
      final key = '${itemPosition.latitude},${itemPosition.longitude}';
      clusters[key] = [item];
    }
  }

  /// 아이템의 위치 가져오기
  LatLng _getItemPosition(dynamic item) {
    if (item is MapMarkerItem) {
      return item.position;
    } else if (item is PostModel) {
      return LatLng(item.location.latitude, item.location.longitude);
    }
    throw ArgumentError('지원하지 않는 아이템 타입: ${item.runtimeType}');
  }

  /// 클러스터된 마커들 생성
  void _createClusteredMarkers(Map<String, List<dynamic>> clusters) {
    _clusteredMarkers.clear();
    
    clusters.forEach((key, items) {
      if (items.length == 1) {
        final item = items.first;
        if (item is MapMarkerItem) {
          _clusteredMarkers.add(_markerController.createMarker(item, null));
        } else if (item is PostModel) {
          _clusteredMarkers.add(_markerController.createPostMarker(item, null));
        }
      } else {
        final center = _parseLatLng(key);
        _clusteredMarkers.add(_markerController.createClusterMarker(center, items.length));
      }
    });
  }

  /// 문자열을 LatLng으로 파싱
  LatLng _parseLatLng(String key) {
    final parts = key.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  /// 두 지점 간의 거리 계산 (간단한 유클리드 거리)
  double _calculateDistance(LatLng point1, LatLng point2) {
    return sqrt(pow(point1.latitude - point2.latitude, 2) + 
                pow(point1.longitude - point2.longitude, 2));
  }

  /// 하버사인 공식을 사용한 정확한 거리 계산 (km)
  double _haversineKm(LatLng a, LatLng b) {
    const double R = 6371.0; // 지구 반지름 (km)
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa = 
        sin(dLat/2) * sin(dLat/2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) *
        sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(aa), sqrt(1-aa));
    return R * c;
  }

  /// 도를 라디안으로 변환
  double _deg2rad(double d) => d * (pi / 180.0);

  /// 클러스터링 상태 초기화
  void reset() {
    _clusteredMarkers.clear();
    _isClustered = false;
  }

  /// 리소스 정리
  void dispose() {
    _clusteredMarkers.clear();
  }
}
