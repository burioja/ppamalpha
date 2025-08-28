import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// 로컬 캐싱과 스마트 동기화를 담당하는 서비스
class MapCacheService {
  static const String _markerCachePrefix = 'map_markers_';
  static const String _postCachePrefix = 'map_posts_';
  static const String _regionCachePrefix = 'map_region_';
  static const String _userCachePrefix = 'map_user_';
  
  // 캐시 설정
  static const Duration _defaultExpiry = Duration(minutes: 15);
  static const Duration _shortExpiry = Duration(minutes: 5);
  static const Duration _longExpiry = Duration(hours: 1);
  
  // 메모리 캐시 (빠른 접근용)
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _memoryCacheExpiry = {};
  
  // 디스크 캐시 (영구 저장용)
  SharedPreferences? _prefs;
  
  // 캐시 통계
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _cacheWrites = 0;
  
  // Getters
  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  int get cacheWrites => _cacheWrites;
  double get cacheHitRate => _cacheHits / (_cacheHits + _cacheMisses);

  /// 초기화
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('MapCacheService 초기화 완료');
  }

  /// 마커 데이터 캐싱
  Future<void> cacheMarkers(String key, List<dynamic> markers, {Duration? expiry}) async {
    final cacheKey = _markerCachePrefix + _generateHashKey(key);
    final cacheData = {
      'data': markers,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': (expiry ?? _defaultExpiry).inMilliseconds,
      'type': 'markers',
    };
    
    await _setCache(cacheKey, cacheData);
    _cacheWrites++;
    debugPrint('마커 캐시 저장: $key (${markers.length}개)');
  }

  /// 포스트 데이터 캐싱
  Future<void> cachePosts(String key, List<dynamic> posts, {Duration? expiry}) async {
    final cacheKey = _postCachePrefix + _generateHashKey(key);
    final cacheData = {
      'data': posts,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': (expiry ?? _defaultExpiry).inMilliseconds,
      'type': 'posts',
    };
    
    await _setCache(cacheKey, cacheData);
    _cacheWrites++;
    debugPrint('포스트 캐시 저장: $key (${posts.length}개)');
  }

  /// 지역 데이터 캐싱
  Future<void> cacheRegionData(String key, List<dynamic> data, {Duration? expiry}) async {
    final cacheKey = _regionCachePrefix + _generateHashKey(key);
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': (expiry ?? _longExpiry).inMilliseconds,
      'type': 'region',
    };
    
    await _setCache(cacheKey, cacheData);
    _cacheWrites++;
    debugPrint('지역 데이터 캐시 저장: $key (${data.length}개)');
  }

  /// 사용자별 데이터 캐싱
  Future<void> cacheUserData(String userId, String key, dynamic data, {Duration? expiry}) async {
    final cacheKey = _userCachePrefix + _generateHashKey('${userId}_$key');
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': (expiry ?? _shortExpiry).inMilliseconds,
      'type': 'user',
      'userId': userId,
    };
    
    await _setCache(cacheKey, cacheData);
    _cacheWrites++;
    debugPrint('사용자 데이터 캐시 저장: $userId/$key');
  }

  /// 캐시된 마커 데이터 가져오기
  List<dynamic>? getCachedMarkers(String key) {
    final cacheKey = _markerCachePrefix + _generateHashKey(key);
    final cached = _getCache(cacheKey);
    
    if (cached != null) {
      _cacheHits++;
      debugPrint('마커 캐시 히트: $key (${cached.length}개)');
      return cached;
    } else {
      _cacheMisses++;
      debugPrint('마커 캐시 미스: $key');
      return null;
    }
  }

  /// 캐시된 포스트 데이터 가져오기
  List<dynamic>? getCachedPosts(String key) {
    final cacheKey = _postCachePrefix + _generateHashKey(key);
    final cached = _getCache(cacheKey);
    
    if (cached != null) {
      _cacheHits++;
      debugPrint('포스트 캐시 히트: $key (${cached.length}개)');
      return cached;
    } else {
      _cacheMisses++;
      debugPrint('포스트 캐시 미스: $key');
      return null;
    }
  }

  /// 캐시된 지역 데이터 가져오기
  List<dynamic>? getCachedRegionData(String key) {
    final cacheKey = _regionCachePrefix + _generateHashKey(key);
    final cached = _getCache(cacheKey);
    
    if (cached != null) {
      _cacheHits++;
      debugPrint('지역 데이터 캐시 히트: $key (${cached.length}개)');
      return cached;
    } else {
      _cacheMisses++;
      debugPrint('지역 데이터 캐시 미스: $key');
      return null;
    }
  }

  /// 캐시된 사용자 데이터 가져오기
  dynamic getCachedUserData(String userId, String key) {
    final cacheKey = _userCachePrefix + _generateHashKey('${userId}_$key');
    final cached = _getCache(cacheKey);
    
    if (cached != null) {
      _cacheHits++;
      debugPrint('사용자 데이터 캐시 히트: $userId/$key');
      return cached;
    } else {
      _cacheMisses++;
      debugPrint('사용자 데이터 캐시 미스: $userId/$key');
      return null;
    }
  }

  /// 스마트 동기화: 변경된 데이터만 동기화
  Future<List<String>> getChangedKeys(String collection, DateTime since) async {
    try {
      // 마지막 동기화 이후 변경된 키들 반환
      final lastSyncKey = 'last_sync_$collection';
      final lastSync = await _getLastSyncTime(lastSyncKey);
      
      if (lastSync == null || lastSync.isBefore(since)) {
        return [];
      }
      
      // 변경된 키들 계산 (실제로는 Firestore에서 변경사항을 가져와야 함)
      final changedKeys = <String>[];
      
      // TODO: Firestore 변경사항 감지 로직 구현
      
      return changedKeys;
    } catch (e) {
      debugPrint('변경된 키 가져오기 오류: $e');
      return [];
    }
  }

  /// 조건부 캐싱: 필요할 때만 캐시
  Future<void> conditionalCache(String key, dynamic data, {
    required bool shouldCache,
    Duration? expiry,
    String? type,
  }) async {
    if (!shouldCache) return;
    
    final cacheKey = _generateCacheKey(key, type);
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': (expiry ?? _defaultExpiry).inMilliseconds,
      'type': type ?? 'general',
    };
    
    await _setCache(cacheKey, cacheData);
    _cacheWrites++;
    debugPrint('조건부 캐시 저장: $key (타입: $type)');
  }

  /// 캐시 무효화
  Future<void> invalidateCache(String key, {String? type}) async {
    final cacheKey = _generateCacheKey(key, type);
    
    // 메모리 캐시에서 제거
    _memoryCache.remove(cacheKey);
    _memoryCacheExpiry.remove(cacheKey);
    
    // 디스크 캐시에서 제거
    if (_prefs != null) {
      await _prefs!.remove(cacheKey);
    }
    
    debugPrint('캐시 무효화: $key (타입: $type)');
  }

  /// 타입별 캐시 무효화
  Future<void> invalidateCacheByType(String type) async {
    final keysToRemove = <String>[];
    
    // 메모리 캐시에서 타입별 제거
    for (final entry in _memoryCache.entries) {
      if (entry.value is Map && entry.value['type'] == type) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _memoryCacheExpiry.remove(key);
    }
    
    // 디스크 캐시에서 타입별 제거
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('map_') && key.contains(type)) {
          await _prefs!.remove(key);
        }
      }
    }
    
    debugPrint('타입별 캐시 무효화: $type (${keysToRemove.length}개 항목)');
  }

  /// 모든 캐시 무효화
  Future<void> invalidateAllCache() async {
    // 메모리 캐시 클리어
    _memoryCache.clear();
    _memoryCacheExpiry.clear();
    
    // 디스크 캐시 클리어
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('map_')) {
          await _prefs!.remove(key);
        }
      }
    }
    
    debugPrint('모든 캐시 무효화 완료');
  }

  /// 캐시 정리 (오래된 항목 제거)
  Future<void> cleanupExpiredCache() async {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    // 메모리 캐시 정리
    for (final entry in _memoryCacheExpiry.entries) {
      if (now.isAfter(entry.value)) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      _memoryCache.remove(key);
      _memoryCacheExpiry.remove(key);
    }
    
    // 디스크 캐시 정리
    if (_prefs != null) {
      final allKeys = _prefs!.getKeys();
      for (final key in allKeys) {
        if (key.startsWith('map_')) {
          try {
            final cached = _getCacheFromDisk(key);
            if (cached != null) {
              final expiry = DateTime.fromMillisecondsSinceEpoch(cached['expiry']);
              if (now.isAfter(expiry)) {
                await _prefs!.remove(key);
              }
            }
          } catch (e) {
            // 손상된 캐시 데이터 제거
            await _prefs!.remove(key);
          }
        }
      }
    }
    
    if (keysToRemove.isNotEmpty) {
      debugPrint('만료된 캐시 정리: ${keysToRemove.length}개 항목 제거');
    }
  }

  /// 캐시 통계 가져오기
  Map<String, dynamic> getCacheStats() {
    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'writes': _cacheWrites,
      'hitRate': cacheHitRate,
      'memoryCacheSize': _memoryCache.length,
      'memoryCacheExpirySize': _memoryCacheExpiry.length,
    };
  }

  /// 캐시 설정
  Future<void> _setCache(String key, Map<String, dynamic> data) async {
    // 메모리 캐시에 저장
    _memoryCache[key] = data;
    _memoryCacheExpiry[key] = DateTime.now().add(Duration(milliseconds: data['expiry']));
    
    // 디스크 캐시에 저장
    if (_prefs != null) {
      try {
        final jsonString = jsonEncode(data);
        await _prefs!.setString(key, jsonString);
      } catch (e) {
        debugPrint('디스크 캐시 저장 오류: $e');
      }
    }
  }

  /// 캐시 가져오기
  dynamic _getCache(String key) {
    // 메모리 캐시에서 먼저 확인
    if (_memoryCache.containsKey(key)) {
      final expiry = _memoryCacheExpiry[key];
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        return _memoryCache[key]['data'];
      } else {
        // 만료된 메모리 캐시 제거
        _memoryCache.remove(key);
        _memoryCacheExpiry.remove(key);
      }
    }
    
    // 디스크 캐시에서 확인
    return _getCacheFromDisk(key);
  }

  /// 디스크에서 캐시 가져오기
  dynamic _getCacheFromDisk(String key) {
    if (_prefs == null) return null;
    
    try {
      final jsonString = _prefs!.getString(key);
      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final expiry = DateTime.fromMillisecondsSinceEpoch(data['expiry']);
        
        if (DateTime.now().isBefore(expiry)) {
          // 메모리 캐시에 복원
          _memoryCache[key] = data;
          _memoryCacheExpiry[key] = expiry;
          return data['data'];
        } else {
          // 만료된 디스크 캐시 제거
          _prefs!.remove(key);
        }
      }
    } catch (e) {
      debugPrint('디스크 캐시 읽기 오류: $e');
      _prefs!.remove(key);
    }
    
    return null;
  }

  /// 마지막 동기화 시간 가져오기
  Future<DateTime?> _getLastSyncTime(String key) async {
    if (_prefs == null) return null;
    
    try {
      final timestamp = _prefs!.getInt(key);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('마지막 동기화 시간 읽기 오류: $e');
    }
    
    return null;
  }

  /// 캐시 키 생성
  String _generateCacheKey(String key, String? type) {
    if (type != null) {
      return 'map_${type}_' + _generateHashKey(key);
    }
    return 'map_general_' + _generateHashKey(key);
  }

  /// 해시 키 생성
  String _generateHashKey(String key) {
    final bytes = utf8.encode(key);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 리소스 정리
  void dispose() {
    _memoryCache.clear();
    _memoryCacheExpiry.clear();
    _prefs = null;
    debugPrint('MapCacheService 리소스 정리 완료');
  }
}
