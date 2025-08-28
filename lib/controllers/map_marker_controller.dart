import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/post_model.dart';

/// 마커 아이템 클래스
class MapMarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl;
  final int remainingAmount;
  final DateTime? expiryDate;

  MapMarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
    this.imageUrl,
    required this.remainingAmount,
    this.expiryDate,
  });
}

/// 마커 생성을 담당하는 컨트롤러
class MapMarkerController {
  final List<MapMarkerItem> _markerItems = [];
  final List<PostModel> _posts = [];
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;
  
  // Getters
  List<MapMarkerItem> get markerItems => List.unmodifiable(_markerItems);
  List<PostModel> get posts => List.unmodifiable(_posts);
  Set<Marker> get clusteredMarkers => Set.unmodifiable(_clusteredMarkers);
  bool get isClustered => _isClustered;

  /// 마커 아이템 추가
  void addMarkerItem(MapMarkerItem item) {
    _markerItems.add(item);
    _updateClustering();
  }

  /// 마커 아이템 제거
  void removeMarkerItem(String id) {
    _markerItems.removeWhere((item) => item.id == id);
    _updateClustering();
  }

  /// 포스트 추가
  void addPost(PostModel post) {
    _posts.add(post);
    _updateClustering();
  }

  /// 포스트 제거
  void removePost(String id) {
    _posts.removeWhere((post) => post.flyerId == id);
    _updateClustering();
  }

  /// 모든 마커 아이템 설정
  void setMarkerItems(List<MapMarkerItem> items) {
    _markerItems.clear();
    _markerItems.addAll(items);
    _updateClustering();
  }

  /// 모든 포스트 설정
  void setPosts(List<PostModel> posts) {
    _posts.clear();
    _posts.addAll(posts);
    _updateClustering();
  }

  /// 클러스터링 업데이트
  void _updateClustering() {
    // 클러스터링 로직은 별도 컨트롤러에서 처리
    // 여기서는 기본적인 마커 생성만 담당
  }

  /// 마커 생성
  Marker createMarker(MapMarkerItem item, BitmapDescriptor? customIcon) {
    final isPostPlace = item.data['type'] == 'post_place';
    
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: item.title,
        snippet: isPostPlace 
            ? '${item.price}원 - ${item.data['creatorName'] ?? '알 수 없음'}'
            : '${item.price}원 - ${item.amount}개',
      ),
    );
  }

  /// 포스트 마커 생성
  Marker createPostMarker(PostModel post, BitmapDescriptor? customIcon) {
    return Marker(
      markerId: MarkerId(post.markerId),
      position: LatLng(post.location.latitude, post.location.longitude),
      icon: customIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: post.title,
        snippet: '${post.reward}원 - ${post.creatorName}',
      ),
    );
  }

  /// 클러스터 마커 생성
  Marker createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
      ),
    );
  }

  /// 마커 아이템 찾기
  MapMarkerItem? findMarkerItem(String id) {
    try {
      return _markerItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 포스트 찾기
  PostModel? findPost(String id) {
    try {
      return _posts.firstWhere((post) => post.flyerId == id);
    } catch (e) {
      return null;
    }
  }

  /// 특정 영역 내 마커 필터링
  List<MapMarkerItem> getMarkersInBounds(LatLngBounds bounds) {
    return _markerItems.where((item) {
      return item.position.latitude >= bounds.southwest.latitude &&
             item.position.latitude <= bounds.northeast.latitude &&
             item.position.longitude >= bounds.southwest.longitude &&
             item.position.longitude <= bounds.northeast.longitude;
    }).toList();
  }

  /// 특정 영역 내 포스트 필터링
  List<PostModel> getPostsInBounds(LatLngBounds bounds) {
    return _posts.where((post) {
      return post.location.latitude >= bounds.southwest.latitude &&
             post.location.latitude <= bounds.northeast.latitude &&
             post.location.longitude >= bounds.southwest.longitude &&
             post.location.longitude <= bounds.northeast.longitude;
    }).toList();
  }

  /// 만료된 마커 제거
  void removeExpiredMarkers() {
    final now = DateTime.now();
    _markerItems.removeWhere((item) {
      return item.expiryDate != null && item.expiryDate!.isBefore(now);
    });
    _updateClustering();
  }

  /// 리소스 정리
  void dispose() {
    _markerItems.clear();
    _posts.clear();
    _clusteredMarkers.clear();
  }
}
