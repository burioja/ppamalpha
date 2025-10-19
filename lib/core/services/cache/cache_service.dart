import '../../utils/lru_cache.dart';
import '../../utils/async_utils.dart';

/// 통합 캐시 서비스
/// 
/// **책임**: 앱 전역 캐시 관리
/// **원칙**: 
/// - LRU + TTL 기반
/// - 메모리 제한
/// - 통계 수집
class CacheService {
  // ==================== 마커 캐시 ====================

  static final _markerCache = TTLCache<String, dynamic>(
    maxSize: 50,
    ttl: const Duration(minutes: 5),
  );

  /// 마커 캐시 저장
  static void putMarkers(String key, dynamic markers) {
    _markerCache.put(key, markers);
  }

  /// 마커 캐시 조회
  static dynamic getMarkers(String key) {
    return _markerCache.get(key);
  }

  /// 마커 캐시 초기화
  static void clearMarkers() {
    _markerCache.clear();
  }

  // ==================== 포스트 캐시 ====================

  static final _postCache = TTLCache<String, dynamic>(
    maxSize: 30,
    ttl: const Duration(minutes: 10),
  );

  /// 포스트 캐시 저장
  static void putPosts(String key, dynamic posts) {
    _postCache.put(key, posts);
  }

  /// 포스트 캐시 조회
  static dynamic getPosts(String key) {
    return _postCache.get(key);
  }

  /// 포스트 캐시 초기화
  static void clearPosts() {
    _postCache.clear();
  }

  // ==================== 장소 캐시 ====================

  static final _placeCache = TTLCache<String, dynamic>(
    maxSize: 20,
    ttl: const Duration(minutes: 15),
  );

  /// 장소 캐시 저장
  static void putPlaces(String key, dynamic places) {
    _placeCache.put(key, places);
  }

  /// 장소 캐시 조회
  static dynamic getPlaces(String key) {
    return _placeCache.get(key);
  }

  /// 장소 캐시 초기화
  static void clearPlaces() {
    _placeCache.clear();
  }

  // ==================== 타일 이미지 캐시 ====================

  static final _tileImageCache = LRUCache<String, dynamic>(
    maxSize: 500,
  );

  /// 타일 이미지 캐시 저장
  static void putTileImage(String key, dynamic image) {
    _tileImageCache.put(key, image);
  }

  /// 타일 이미지 캐시 조회
  static dynamic getTileImage(String key) {
    return _tileImageCache.get(key);
  }

  /// 타일 이미지 캐시 초기화
  static void clearTileImages() {
    _tileImageCache.clear();
  }

  // ==================== 전체 관리 ====================

  /// 모든 캐시 초기화
  static void clearAll() {
    _markerCache.clear();
    _postCache.clear();
    _placeCache.clear();
    _tileImageCache.clear();
  }

  /// 만료된 항목 정리
  static int evictExpired() {
    int count = 0;
    
    count += _markerCache.evictExpired();
    count += _postCache.evictExpired();
    count += _placeCache.evictExpired();
    
    return count;
  }

  /// 캐시 통계
  static Map<String, dynamic> getStats() {
    return {
      'markers': {
        'size': _markerCache.size,
      },
      'posts': {
        'size': _postCache.size,
      },
      'places': {
        'size': _placeCache.size,
      },
      'tileImages': {
        'size': _tileImageCache.size,
      },
      'totalItems': _markerCache.size +
          _postCache.size +
          _placeCache.size +
          _tileImageCache.size,
    };
  }

  /// 캐시 키 생성 헬퍼
  static String buildKey(String prefix, List<String> parts) {
    return '$prefix:${parts.join(':')}';
  }

  /// 타일 기반 키 생성
  static String buildTileKey(String prefix, List<String> tileIds) {
    tileIds.sort();
    return buildKey(prefix, tileIds);
  }
}

