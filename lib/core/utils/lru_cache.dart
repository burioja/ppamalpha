import 'dart:collection';

/// LRU (Least Recently Used) 캐시
/// 
/// **사용 예시**:
/// ```dart
/// final cache = LRUCache<String, List<MarkerModel>>(maxSize: 50);
/// 
/// // 저장
/// cache.put('tile_123', markers);
/// 
/// // 조회
/// final cached = cache.get('tile_123');
/// if (cached != null) {
///   return cached;
/// }
/// ```
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();
  final Map<K, DateTime> _timestamps = {};

  LRUCache({required this.maxSize});

  /// 값 조회
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      // 재삽입으로 맨 뒤로 이동 (가장 최근 사용)
      _cache[key] = value;
      _timestamps[key] = DateTime.now();
    }
    return value;
  }

  /// 값 저장
  void put(K key, V value) {
    // 이미 있으면 제거 후 재삽입
    _cache.remove(key);
    
    // 맨 뒤에 추가
    _cache[key] = value;
    _timestamps[key] = DateTime.now();

    // 크기 초과 시 가장 오래된 것 제거
    if (_cache.length > maxSize) {
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
      _timestamps.remove(firstKey);
    }
  }

  /// 값 존재 확인
  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  /// 값 제거
  V? remove(K key) {
    _timestamps.remove(key);
    return _cache.remove(key);
  }

  /// 캐시 크기
  int get size => _cache.length;

  /// 캐시 비우기
  void clear() {
    _cache.clear();
    _timestamps.clear();
  }

  /// 모든 키
  Iterable<K> get keys => _cache.keys;

  /// 모든 값
  Iterable<V> get values => _cache.values;
}

/// TTL (Time To Live) 지원 LRU 캐시
/// 
/// **사용 예시**:
/// ```dart
/// final cache = TTLCache<String, List<MarkerModel>>(
///   maxSize: 50,
///   ttl: Duration(minutes: 5),
/// );
/// 
/// cache.put('tile_123', markers);
/// 
/// // 5분 후 자동 만료
/// final cached = cache.get('tile_123'); // null
/// ```
class TTLCache<K, V> extends LRUCache<K, V> {
  final Duration ttl;

  TTLCache({
    required super.maxSize,
    required this.ttl,
  });

  @override
  V? get(K key) {
    // TTL 확인
    final timestamp = _timestamps[key];
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age > ttl) {
        // 만료됨
        remove(key);
        return null;
      }
    }

    return super.get(key);
  }

  /// 캐시가 유효한지 확인
  bool isValid(K key) {
    final timestamp = _timestamps[key];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age <= ttl;
  }

  /// 만료된 항목 모두 제거
  int evictExpired() {
    final now = DateTime.now();
    final expiredKeys = <K>[];

    for (final entry in _timestamps.entries) {
      final age = now.difference(entry.value);
      if (age > ttl) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      remove(key);
    }

    return expiredKeys.length;
  }
}

/// 메모리 제한 캐시
/// 
/// **사용 예시**:
/// ```dart
/// final cache = MemoryLimitedCache<String, Uint8List>(
///   maxMemoryBytes: 10 * 1024 * 1024, // 10MB
///   sizeCalculator: (data) => data.length,
/// );
/// ```
class MemoryLimitedCache<K, V> {
  final int maxMemoryBytes;
  final int Function(V value) sizeCalculator;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();
  final Map<K, int> _sizes = {};
  int _currentMemory = 0;

  MemoryLimitedCache({
    required this.maxMemoryBytes,
    required this.sizeCalculator,
  });

  /// 값 조회
  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  /// 값 저장
  void put(K key, V value) {
    final size = sizeCalculator(value);
    
    // 이미 있으면 제거
    if (_cache.containsKey(key)) {
      _currentMemory -= _sizes[key]!;
      _cache.remove(key);
      _sizes.remove(key);
    }

    // 메모리 초과 시 오래된 것부터 제거
    while (_currentMemory + size > maxMemoryBytes && _cache.isNotEmpty) {
      final firstKey = _cache.keys.first;
      _currentMemory -= _sizes[firstKey]!;
      _cache.remove(firstKey);
      _sizes.remove(firstKey);
    }

    // 새 항목 추가
    if (size <= maxMemoryBytes) {
      _cache[key] = value;
      _sizes[key] = size;
      _currentMemory += size;
    }
  }

  /// 현재 메모리 사용량
  int get currentMemory => _currentMemory;

  /// 캐시 크기
  int get size => _cache.length;

  /// 캐시 비우기
  void clear() {
    _cache.clear();
    _sizes.clear();
    _currentMemory = 0;
  }
}

/// 캐시 통계
class CacheStats {
  int hits = 0;
  int misses = 0;
  int evictions = 0;

  double get hitRate {
    final total = hits + misses;
    return total > 0 ? hits / total : 0.0;
  }

  void reset() {
    hits = 0;
    misses = 0;
    evictions = 0;
  }

  @override
  String toString() {
    return 'CacheStats(hits: $hits, misses: $misses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
  }
}

