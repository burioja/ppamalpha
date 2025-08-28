import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../controllers/map_marker_controller.dart';
import '../../models/post_model.dart';

/// Firestore 데이터 쿼리를 최적화하는 서비스
class MapDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 쿼리 최적화 설정
  static const int _maxBatchSize = 100; // 한 번에 최대 100개
  static const int _maxConcurrentQueries = 3; // 동시 쿼리 수 제한
  
  // 쿼리 제한자
  final StreamController<int> _queryLimiter = StreamController<int>.broadcast();
  int _activeQueries = 0;
  
  // 지역 기반 쿼리 캐시
  final Map<String, List<dynamic>> _regionCache = {};
  static const Duration _regionCacheExpiry = Duration(minutes: 10);
  
  // Getters
  int get activeQueries => _activeQueries;
  bool get hasActiveQueries => _activeQueries > 0;

  /// 지역 기반 마커 로드 (최적화된 쿼리)
  Future<List<MapMarkerItem>> loadMarkersInRegion(LatLng center, double radiusKm) async {
    final cacheKey = _generateRegionCacheKey(center, radiusKm);
    
    // 캐시 확인
    final cached = _getCachedRegionData(cacheKey);
    if (cached.isNotEmpty) {
      debugPrint('지역 캐시에서 마커 로드: ${cached.length}개');
      return cached;
    }
    
    // 쿼리 제한 확인
    if (_activeQueries >= _maxConcurrentQueries) {
      debugPrint('쿼리 제한에 도달, 대기 중...');
      await _waitForQuerySlot();
    }
    
    try {
      _activeQueries++;
      debugPrint('지역 기반 마커 쿼리 시작: 중심점=$center, 반경=${radiusKm}km');
      
      // 지역 경계 계산
      final bounds = _calculateBoundingBox(center, radiusKm);
      
      // 최적화된 쿼리 실행
      final markers = await _executeOptimizedMarkerQuery(bounds);
      
      // 캐시 저장
      _cacheRegionData(cacheKey, markers);
      
      debugPrint('지역 기반 마커 로드 완료: ${markers.length}개');
      return markers;
    } finally {
      _activeQueries--;
      _queryLimiter.add(_activeQueries);
    }
  }

  /// 최적화된 마커 쿼리 실행
  Future<List<MapMarkerItem>> _executeOptimizedMarkerQuery(LatLngBounds bounds) async {
    try {
      // 복합 인덱스를 활용한 최적화된 쿼리
      final QuerySnapshot snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('position', isGreaterThan: GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude))
          .where('position', isLessThan: GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude))
          .orderBy('position') // 인덱스 활용
          .limit(_maxBatchSize)
          .get();
      
      return _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('최적화된 마커 쿼리 오류: $e');
      
      // 폴백: 기본 쿼리 사용
      return _executeFallbackMarkerQuery();
    }
  }

  /// 폴백 마커 쿼리 (기본 방식)
  Future<List<MapMarkerItem>> _executeFallbackMarkerQuery() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .limit(_maxBatchSize)
          .get();
      
      return _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('폴백 마커 쿼리 오류: $e');
      return [];
    }
  }

  /// 지역 기반 포스트 로드 (최적화된 쿼리)
  Future<List<PostModel>> loadPostsInRegion(LatLng center, double radiusKm) async {
    final cacheKey = 'posts_${_generateRegionCacheKey(center, radiusKm)}';
    
    // 캐시 확인
    final cached = _getCachedRegionData(cacheKey);
    if (cached.isNotEmpty) {
      debugPrint('지역 캐시에서 포스트 로드: ${cached.length}개');
      return cached.cast<PostModel>();
    }
    
    // 쿼리 제한 확인
    if (_activeQueries >= _maxConcurrentQueries) {
      await _waitForQuerySlot();
    }
    
    try {
      _activeQueries++;
      debugPrint('지역 기반 포스트 쿼리 시작: 중심점=$center, 반경=${radiusKm}km');
      
      // 지역 경계 계산
      final bounds = _calculateBoundingBox(center, radiusKm);
      
      // 최적화된 쿼리 실행
      final posts = await _executeOptimizedPostQuery(bounds);
      
      // 캐시 저장
      _cacheRegionData(cacheKey, posts);
      
      debugPrint('지역 기반 포스트 로드 완료: ${posts.length}개');
      return posts;
    } finally {
      _activeQueries--;
      _queryLimiter.add(_activeQueries);
    }
  }

  /// 최적화된 포스트 쿼리 실행
  Future<List<PostModel>> _executeOptimizedPostQuery(LatLngBounds bounds) async {
    try {
      // 복합 인덱스를 활용한 최적화된 쿼리
      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('location', isGreaterThan: GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude))
          .where('location', isLessThan: GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude))
          .orderBy('location') // 인덱스 활용
          .limit(_maxBatchSize)
          .get();
      
      return _processPostsSnapshot(snapshot);
    } catch (e) {
      debugPrint('최적화된 포스트 쿼리 오류: $e');
      
      // 폴백: 기본 쿼리 사용
      return _executeFallbackPostQuery();
    }
  }

  /// 폴백 포스트 쿼리 (기본 방식)
  Future<List<PostModel>> _executeFallbackPostQuery() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .limit(_maxBatchSize)
          .get();
      
      return _processPostsSnapshot(snapshot);
    } catch (e) {
      debugPrint('폴백 포스트 쿼리 오류: $e');
      return [];
    }
  }

  /// 페이지네이션을 사용한 대량 데이터 로드
  Future<List<MapMarkerItem>> loadMarkersWithPagination({
    required LatLngBounds bounds,
    DocumentSnapshot? lastDocument,
    int pageSize = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('position', isGreaterThan: GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude))
          .where('position', isLessThan: GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude))
          .orderBy('position')
          .limit(pageSize);
      
      // 페이지네이션 적용
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final QuerySnapshot snapshot = await query.get();
      return _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('페이지네이션 마커 로드 오류: $e');
      return [];
    }
  }

  /// 실시간 업데이트 리스너 (최적화된)
  Stream<List<MapMarkerItem>> getMarkersStream(LatLngBounds bounds) {
    return _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .where('position', isGreaterThan: GeoPoint(bounds.southwest.latitude, bounds.southwest.longitude))
        .where('position', isLessThan: GeoPoint(bounds.northeast.latitude, bounds.northeast.longitude))
        .orderBy('position')
        .limit(_maxBatchSize)
        .snapshots()
        .map((snapshot) => _processMarkersSnapshot(snapshot))
        .handleError((error) {
          debugPrint('마커 스트림 오류: $error');
          return <MapMarkerItem>[];
        });
  }

  /// 지역 경계 계산
  LatLngBounds _calculateBoundingBox(LatLng center, double radiusKm) {
    // 위도 1도 ≈ 111km, 경도 1도 ≈ 111km * cos(위도)
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * (center.latitude * 3.14159 / 180.0).cos());
    
    return LatLngBounds(
      southwest: LatLng(center.latitude - latDelta, center.longitude - lngDelta),
      northeast: LatLng(center.latitude + latDelta, center.longitude + lngDelta),
    );
  }

  /// 지역 캐시 키 생성
  String _generateRegionCacheKey(LatLng center, double radius) {
    return '${(center.latitude * 1000).round()}_${(center.longitude * 1000).round()}_${radius.round()}';
  }

  /// 지역 데이터 캐싱
  void _cacheRegionData(String key, List<dynamic> data) {
    _regionCache[key] = data;
    
    // 오래된 캐시 정리
    _cleanupOldRegionCache();
  }

  /// 캐시된 지역 데이터 가져오기
  List<dynamic> _getCachedRegionData(String key) {
    final cached = _regionCache[key];
    if (cached != null) {
      return cached;
    }
    return [];
  }

  /// 오래된 지역 캐시 정리
  void _cleanupOldRegionCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    for (final entry in _regionCache.entries) {
      // 간단한 캐시 만료 (10분)
      if (now.millisecondsSinceEpoch - entry.key.hashCode % 600000 > 600000) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _regionCache.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('오래된 지역 캐시 정리: ${keysToRemove.length}개 항목 제거');
    }
  }

  /// 쿼리 슬롯 대기
  Future<void> _waitForQuerySlot() async {
    await for (final activeQueries in _queryLimiter.stream) {
      if (activeQueries < _maxConcurrentQueries) {
        break;
      }
    }
  }

  /// 마커 스냅샷 처리
  List<MapMarkerItem> _processMarkersSnapshot(QuerySnapshot snapshot) {
    final List<MapMarkerItem> markers = [];
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = data['position'] as GeoPoint;
      
      // 만료된 마커는 제외
      if (data['expiryDate'] != null) {
        final expiryDate = data['expiryDate'].toDate() as DateTime;
        if (DateTime.now().isAfter(expiryDate)) {
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
    }
    
    return markers;
  }

  /// 포스트 스냅샷 처리
  List<PostModel> _processPostsSnapshot(QuerySnapshot snapshot) {
    final List<PostModel> posts = [];
    
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final post = PostModel.fromMap(data, doc.id);
        posts.add(post);
      } catch (e) {
        debugPrint('포스트 데이터 처리 오류: $e');
        continue;
      }
    }
    
    return posts;
  }

  /// 모든 지역 캐시 무효화
  void invalidateRegionCache() {
    _regionCache.clear();
    debugPrint('지역 캐시 무효화');
  }

  /// 특정 지역 캐시 무효화
  void invalidateRegionCacheFor(LatLng center, double radius) {
    final key = _generateRegionCacheKey(center, radius);
    _regionCache.remove(key);
    debugPrint('지역 캐시 무효화: $key');
  }

  /// 리소스 정리
  void dispose() {
    _queryLimiter.close();
    _regionCache.clear();
  }
}
