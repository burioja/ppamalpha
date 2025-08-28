import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../controllers/map_marker_controller.dart';
import '../../models/post_model.dart';

/// 마커 데이터 관리와 캐싱을 담당하는 매니저
class MapMarkerDataManager {
  final MapMarkerController _markerController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 캐싱 관련
  final Map<String, dynamic> _markerCache = {};
  final Map<String, dynamic> _postCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // 실시간 리스너 관리
  StreamSubscription<QuerySnapshot>? _markersListener;
  bool _isListenerActive = false;
  
  // 데이터 로딩 상태
  bool _isLoadingMarkers = false;
  bool _isLoadingPosts = false;
  
  // Getters
  bool get isLoadingMarkers => _isLoadingMarkers;
  bool get isLoadingPosts => _isLoadingPosts;
  bool get isListenerActive => _isListenerActive;

  MapMarkerDataManager(this._markerController);

  /// 마커 데이터 로드 (캐시 우선)
  Future<void> loadMarkersFromFirestore() async {
    if (_isLoadingMarkers) return;
    
    try {
      _isLoadingMarkers = true;
      
      // 캐시에서 먼저 확인
      final cachedMarkers = _getCachedMarkers();
      if (cachedMarkers.isNotEmpty) {
        _markerController.setMarkerItems(cachedMarkers);
        debugPrint('캐시된 마커 로드: ${cachedMarkers.length}개');
      }
      
      // Firestore에서 최신 데이터 로드
      final QuerySnapshot snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();
      
      final markers = _processMarkersSnapshot(snapshot);
      
      // 캐시 업데이트
      _cacheMarkers(markers);
      
      // 컨트롤러에 설정
      _markerController.setMarkerItems(markers);
      
      debugPrint('마커 로드 완료: ${markers.length}개');
    } catch (e) {
      debugPrint('마커 로드 오류: $e');
    } finally {
      _isLoadingMarkers = false;
    }
  }

  /// 포스트 데이터 로드 (캐시 우선)
  Future<void> loadPostsFromFirestore(LatLng currentPosition) async {
    if (_isLoadingPosts) return;
    
    try {
      _isLoadingPosts = true;
      
      // 캐시에서 먼저 확인
      final cachedPosts = _getCachedPosts();
      if (cachedPosts.isNotEmpty) {
        _markerController.setPosts(cachedPosts);
        debugPrint('캐시된 포스트 로드: ${cachedPosts.length}개');
      }
      
      // PostService를 통한 최신 데이터 로드 (기존 로직 유지)
      // TODO: PostService 의존성 주입으로 변경
      
      debugPrint('포스트 로드 완료');
    } catch (e) {
      debugPrint('포스트 로드 오류: $e');
    } finally {
      _isLoadingPosts = false;
    }
  }

  /// 실시간 리스너 설정
  void setupRealtimeListeners() {
    if (_isListenerActive) return;
    
    _markersListener = _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _processMarkersSnapshot(snapshot);
        });
    
    _isListenerActive = true;
    debugPrint('실시간 마커 리스너 활성화');
  }

  /// 실시간 리스너 비활성화
  void deactivateRealtimeListeners() {
    _markersListener?.cancel();
    _isListenerActive = false;
    debugPrint('실시간 마커 리스너 비활성화');
  }

  /// 마커 스냅샷 처리
  List<MapMarkerItem> _processMarkersSnapshot(QuerySnapshot snapshot) {
    final List<MapMarkerItem> markers = [];
    
    debugPrint('마커 스냅샷 처리 중: ${snapshot.docs.length}개 마커');
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = data['position'] as GeoPoint;
      
      // 만료된 마커는 제외
      if (data['expiryDate'] != null) {
        final expiryDate = data['expiryDate'].toDate() as DateTime;
        if (DateTime.now().isAfter(expiryDate)) {
          debugPrint('만료된 마커 제외: ${doc.id}');
          continue;
        }
      }
      
      final markerItem = MapMarkerItem(
        id: doc.id,
        title: data['title'] ?? '',
        price: data['price']?.toString() ?? '0',
        amount: data['amount']?.toString() ?? '0',
        userId: data['userId'] ?? '',
        data: data,
        position: LatLng(geoPoint.latitude, geoPoint.longitude),
        imageUrl: data['imageUrl'],
        remainingAmount: data['remainingAmount'] ?? 0,
        expiryDate: data['expiryDate']?.toDate(),
      );
      
      markers.add(markerItem);
      debugPrint('마커 로드됨: ${markerItem.title} at ${markerItem.position}, 타입: ${data['type']}');
    }
    
    debugPrint('마커 처리 완료: 총 ${markers.length}개 마커 로드됨');
    return markers;
  }

  /// 마커 캐싱
  void _cacheMarkers(List<MapMarkerItem> markers) {
    final cacheKey = 'markers_${DateTime.now().millisecondsSinceEpoch ~/ 60000}'; // 분 단위로 그룹화
    
    _markerCache[cacheKey] = {
      'data': markers,
      'expiry': DateTime.now().add(_cacheExpiry),
      'timestamp': DateTime.now(),
    };
    
    // 오래된 캐시 정리
    _cleanupOldCache(_markerCache);
  }

  /// 포스트 캐싱
  void _cachePosts(List<PostModel> posts) {
    final cacheKey = 'posts_${DateTime.now().millisecondsSinceEpoch ~/ 60000}';
    
    _postCache[cacheKey] = {
      'data': posts,
      'expiry': DateTime.now().add(_cacheExpiry),
      'timestamp': DateTime.now(),
    };
    
    // 오래된 캐시 정리
    _cleanupOldCache(_postCache);
  }

  /// 캐시된 마커 가져오기
  List<MapMarkerItem> _getCachedMarkers() {
    for (final entry in _markerCache.entries) {
      final cacheData = entry.value as Map<String, dynamic>;
      final expiry = cacheData['expiry'] as DateTime;
      
      if (DateTime.now().isBefore(expiry)) {
        return cacheData['data'] as List<MapMarkerItem>;
      }
    }
    return [];
  }

  /// 캐시된 포스트 가져오기
  List<PostModel> _getCachedPosts() {
    for (final entry in _postCache.entries) {
      final cacheData = entry.value as Map<String, dynamic>;
      final expiry = cacheData['expiry'] as DateTime;
      
      if (DateTime.now().isBefore(expiry)) {
        return cacheData['data'] as List<PostModel>;
      }
    }
    return [];
  }

  /// 오래된 캐시 정리
  void _cleanupOldCache(Map<String, dynamic> cache) {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in cache.entries) {
      final cacheData = entry.value as Map<String, dynamic>;
      final expiry = cacheData['expiry'] as DateTime;
      
      if (now.isAfter(expiry)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      cache.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('오래된 캐시 정리: ${keysToRemove.length}개 항목 제거');
    }
  }

  /// 특정 영역 내 마커만 로드 (성능 최적화)
  Future<List<MapMarkerItem>> loadMarkersInBounds(LatLngBounds bounds) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('position', isGreaterThan: GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude))
          .where('position', isLessThan: GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude))
          .limit(100) // 한 번에 최대 100개만
          .get();
      
      return _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('영역별 마커 로드 오류: $e');
      return [];
    }
  }

  /// 마커 추가
  Future<void> addMarker(MapMarkerItem markerItem) async {
    try {
      // Firestore에 저장
      await _saveMarkerToFirestore(markerItem);
      
      // 로컬에 추가
      _markerController.addMarkerItem(markerItem);
      
      // 캐시 무효화
      _invalidateMarkerCache();
      
      debugPrint('마커 추가 완료: ${markerItem.title}');
    } catch (e) {
      debugPrint('마커 추가 오류: $e');
      rethrow;
    }
  }

  /// Firestore에 마커 저장
  Future<void> _saveMarkerToFirestore(MapMarkerItem markerItem) async {
    try {
      final markerData = {
        'title': markerItem.title,
        'price': int.parse(markerItem.price),
        'amount': int.parse(markerItem.amount),
        'userId': markerItem.userId,
        'position': GeoPoint(markerItem.position.latitude, markerItem.position.longitude),
        'remainingAmount': markerItem.remainingAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': markerItem.expiryDate,
        'isActive': true,
        'isCollected': false,
      };
      
      // 전단지 타입인 경우 추가 정보 저장
      if (markerItem.data['type'] == 'post_place') {
        markerData.addAll({
          'type': 'post_place',
          'flyerId': markerItem.data['flyerId'],
          'creatorName': markerItem.data['creatorName'],
          'description': markerItem.data['description'],
          'targetGender': markerItem.data['targetGender'],
          'targetAge': markerItem.data['targetAge'],
          'canRespond': markerItem.data['canRespond'],
          'canForward': markerItem.data['canForward'],
          'canRequestReward': markerItem.data['canRequestReward'],
          'canUse': markerItem.data['canUse'],
          'address': markerItem.data['address'],
        });
      }
      
      final docRef = await _firestore.collection('markers').add(markerData);
      debugPrint('마커 Firebase 저장 완료: ${docRef.id}');
    } catch (e) {
      debugPrint('마커 저장 오류: $e');
      rethrow;
    }
  }

  /// 마커 캐시 무효화
  void _invalidateMarkerCache() {
    _markerCache.clear();
    debugPrint('마커 캐시 무효화');
  }

  /// 포스트 캐시 무효화
  void _invalidatePostCache() {
    _postCache.clear();
    debugPrint('포스트 캐시 무효화');
  }

  /// 모든 캐시 무효화
  void invalidateAllCache() {
    _markerCache.clear();
    _postCache.clear();
    debugPrint('모든 캐시 무효화');
  }

  /// 리소스 정리
  void dispose() {
    _markersListener?.cancel();
    _markerCache.clear();
    _postCache.clear();
  }
}
