import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../features/map_system/utils/tile_utils.dart';
import '../core/models/map/fog_level.dart';

/// 고성능 타일 캐시 관리자
class TileCacheManager {
  static const int _maxCacheSize = 2000; // 최대 2000개 타일 캐시
  static const Duration _cacheExpiry = Duration(days: 30);
  static const int _maxCacheSizeBytes = 100 * 1024 * 1024; // 100MB
  
  late final CacheManager _cacheManager;
  final Map<String, DateTime> _accessTimes = {};
  final Map<String, int> _accessCounts = {};
  
  /// 캐시 매니저 초기화
  Future<void> initialize() async {
    final cacheDir = await getTemporaryDirectory();
    final tileCacheDir = Directory('${cacheDir.path}/fog_tiles');
    
    _cacheManager = CacheManager(
      Config(
        'fogTileCache',
        stalePeriod: _cacheExpiry,
        maxNrOfCacheObjects: _maxCacheSize,
        repo: JsonCacheInfoRepository(databaseName: 'fogTileCache'),
        fileService: HttpFileService(),
      ),
    );
    
    debugPrint('✅ 타일 캐시 매니저 초기화 완료');
  }
  
  /// 타일 캐시에서 가져오기
  Future<File?> getCachedTile(String tileKey) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(tileKey);
      if (fileInfo != null) {
        _recordAccess(tileKey);
        debugPrint('📦 캐시 히트: $tileKey');
        return fileInfo.file;
      }
    } catch (e) {
      debugPrint('❌ 캐시 조회 오류: $e');
    }
    return null;
  }
  
  /// 타일을 캐시에 저장
  Future<void> cacheTile(String tileKey, Uint8List data) async {
    try {
      await _cacheManager.putFile(tileKey, data);
      _recordAccess(tileKey);
      debugPrint('💾 타일 캐시 저장: $tileKey (${data.length} bytes)');
    } catch (e) {
      debugPrint('❌ 캐시 저장 오류: $e');
    }
  }
  
  /// 포그 레벨별 타일 캐시
  Future<void> cacheFogTile(String tileKey, FogLevel level) async {
    final tileData = _generateFogTileData(level);
    await cacheTile(tileKey, tileData);
  }
  
  /// 포그 레벨에 따른 타일 데이터 생성
  Uint8List _generateFogTileData(FogLevel level) {
    // 실제 구현에서는 Canvas를 사용해서 256x256 이미지 생성
    // 여기서는 간단한 색상 데이터 생성
    final bytes = Uint8List(4);
    switch (level) {
      case FogLevel.clear:
        bytes[0] = 0; bytes[1] = 0; bytes[2] = 0; bytes[3] = 0; // 투명
        break;
      case FogLevel.gray:
        bytes[0] = 128; bytes[1] = 128; bytes[2] = 128; bytes[3] = 76; // 회색 반투명
        break;
      case FogLevel.black:
        bytes[0] = 0; bytes[1] = 0; bytes[2] = 0; bytes[3] = 255; // 검정
        break;
    }
    return bytes;
  }
  
  /// 접근 기록 업데이트
  void _recordAccess(String tileKey) {
    _accessTimes[tileKey] = DateTime.now();
    _accessCounts[tileKey] = (_accessCounts[tileKey] ?? 0) + 1;
  }
  
  /// 캐시 크기 관리
  Future<void> cleanupCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      
      if (files.length > _maxCacheSize) {
        // LRU (Least Recently Used) 방식으로 정리
        final sortedFiles = await _getSortedFilesByAccess();
        
        for (int i = 0; i < sortedFiles.length - _maxCacheSize; i++) {
          final file = sortedFiles[i];
          try {
            await file.delete();
            debugPrint('🗑️ 오래된 캐시 삭제: ${file.path}');
          } catch (e) {
            debugPrint('❌ 캐시 삭제 오류: $e');
          }
        }
      }
      
      // 캐시 크기 확인
      final totalSize = await _getCacheSize();
      if (totalSize > _maxCacheSizeBytes) {
        await _cleanupBySize();
      }
      
    } catch (e) {
      debugPrint('❌ 캐시 정리 오류: $e');
    }
  }
  
  /// 접근 시간 기준으로 파일 정렬
  Future<List<FileSystemEntity>> _getSortedFilesByAccess() async {
    final cacheDir = await getTemporaryDirectory();
    final files = cacheDir.listSync();
    
    files.sort((a, b) {
      final aTime = _accessTimes[a.path] ?? DateTime(1970);
      final bTime = _accessTimes[b.path] ?? DateTime(1970);
      return aTime.compareTo(bTime);
    });
    
    return files;
  }
  
  /// 캐시 총 크기 계산
  Future<int> _getCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      
      int totalSize = 0;
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('❌ 캐시 크기 계산 오류: $e');
      return 0;
    }
  }
  
  /// 크기 기준 캐시 정리
  Future<void> _cleanupBySize() async {
    final sortedFiles = await _getSortedFilesByAccess();
    int currentSize = await _getCacheSize();
    
    for (final file in sortedFiles) {
      if (currentSize <= _maxCacheSizeBytes) break;
      
      try {
        if (file is File) {
          final fileSize = await file.length();
          await file.delete();
          currentSize -= fileSize;
          debugPrint('🗑️ 크기 기준 캐시 삭제: ${file.path}');
        }
      } catch (e) {
        debugPrint('❌ 캐시 삭제 오류: $e');
      }
    }
  }
  
  /// 캐시 통계 정보
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      
      int totalSize = 0;
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return {
        'totalFiles': files.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'maxCacheSize': _maxCacheSize,
        'maxCacheSizeMB': (_maxCacheSizeBytes / (1024 * 1024)).toStringAsFixed(2),
        'accessCounts': _accessCounts.length,
      };
    } catch (e) {
      debugPrint('❌ 캐시 통계 오류: $e');
      return {};
    }
  }
  
  /// 캐시 완전 초기화
  Future<void> clearAllCache() async {
    try {
      await _cacheManager.emptyCache();
      _accessTimes.clear();
      _accessCounts.clear();
      debugPrint('🗑️ 모든 캐시 초기화 완료');
    } catch (e) {
      debugPrint('❌ 캐시 초기화 오류: $e');
    }
  }
  
  /// 리소스 정리
  void dispose() {
    _accessTimes.clear();
    _accessCounts.clear();
  }
}
