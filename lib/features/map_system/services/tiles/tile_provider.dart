import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../utils/tile_utils.dart';

/// 통합 타일 프로바이더
/// - 기존 custom_tile_provider.dart + tile_cache_manager.dart + tile_prefetcher.dart 통합
class UnifiedTileProvider extends TileProvider {
  final String baseUrl;
  final Map<String, int> _tileFogLevels = {};

  // 캐시 관리
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheExpiry = const Duration(hours: 1);
  final int _maxCacheSize = 500;

  // 프리페칭 관리
  final Set<String> _prefetchingTiles = {};
  final Map<String, Completer<ui.Image>> _loadingTiles = {};

  // 검은 타일 캐시
  ui.Image? _blackTileImage;

  bool _isLoading = false;

  UnifiedTileProvider({
    required this.baseUrl,
  });

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final tileId = _getTileIdFromCoordinates(coordinates);
    final fogLevel = _tileFogLevels[tileId] ?? 3; // 기본값: 검은 영역

    if (fogLevel == 3) {
      // 검은 타일 반환
      return _createBlackTileProvider();
    } else {
      // OSM 타일 반환 (밝은 영역 또는 회색 영역)
      final tileKey = '${coordinates.z}_${coordinates.x}_${coordinates.y}';

      // 캐시된 이미지가 있는지 확인
      if (_imageCache.containsKey(tileKey)) {
        final timestamp = _cacheTimestamp[tileKey];
        if (timestamp != null &&
            DateTime.now().difference(timestamp) < _cacheExpiry) {
          return MemoryImage(_imageToBytes(_imageCache[tileKey]!));
        }
      }

      return NetworkImage(_getTileUrl(coordinates));
    }
  }

  /// 타일 좌표를 타일 ID로 변환
  String _getTileIdFromCoordinates(TileCoordinates coords) {
    // OSM 타일 좌표를 위도/경도로 변환
    final lat = _tileYToLat(coords.y, coords.z);
    final lng = _tileXToLng(coords.x, coords.z);
    return TileUtils.getTileId(lat, lng);
  }

  /// OSM 타일 Y 좌표를 위도로 변환
  double _tileYToLat(int y, int z) {
    final n = 1 << z;
    final sinh = (math.exp(math.pi * (1 - 2 * y / n)) -
                  math.exp(-math.pi * (1 - 2 * y / n))) / 2;
    return math.atan(sinh) * 180 / math.pi;
  }

  /// OSM 타일 X 좌표를 경도로 변환
  double _tileXToLng(int x, int z) {
    final n = 1 << z;
    return x / n * 360.0 - 180.0;
  }

  /// 검은 타일 이미지 프로바이더 생성
  MemoryImage _createBlackTileProvider() {
    return MemoryImage(_createBlackTileBytes());
  }

  /// 검은 타일 바이트 데이터 생성
  Uint8List _createBlackTileBytes() {
    // 256x256 검은색 타일 생성
    const int tileSize = 256;
    final bytes = Uint8List(tileSize * tileSize * 4); // RGBA

    for (int i = 0; i < bytes.length; i += 4) {
      bytes[i] = 0;     // R
      bytes[i + 1] = 0; // G
      bytes[i + 2] = 0; // B
      bytes[i + 3] = 255; // A (불투명)
    }

    return bytes;
  }

  /// 타일 URL 생성
  String _getTileUrl(TileCoordinates coords) {
    return baseUrl
        .replaceAll('{z}', coords.z.toString())
        .replaceAll('{x}', coords.x.toString())
        .replaceAll('{y}', coords.y.toString());
  }

  /// 포그 레벨 업데이트
  Future<void> updateFogLevels() async {
    if (_isLoading) return;

    _isLoading = true;
    try {
      // VisitTileService에서 FogLevel 1 타일들을 가져와서 업데이트
      // 실제 구현은 visit_manager.dart와 연동
      await _loadFogLevelsFromFirestore();
    } finally {
      _isLoading = false;
    }
  }

  /// Firestore에서 포그 레벨 로드
  Future<void> _loadFogLevelsFromFirestore() async {
    try {
      // TODO: Firebase에서 방문한 타일들을 조회하여 _tileFogLevels 업데이트
      // 현재는 빈 구현
    } catch (e) {
      debugPrint('❌ 포그 레벨 로드 오류: $e');
    }
  }

  /// 캐시에 이미지 추가
  void _addToCache(String tileKey, ui.Image image) {
    // 캐시 크기 제한
    if (_imageCache.length >= _maxCacheSize) {
      _evictOldestCacheEntry();
    }

    _imageCache[tileKey] = image;
    _cacheTimestamp[tileKey] = DateTime.now();
  }

  /// 가장 오래된 캐시 항목 제거
  void _evictOldestCacheEntry() {
    if (_cacheTimestamp.isEmpty) return;

    String oldestKey = _cacheTimestamp.keys.first;
    DateTime oldestTime = _cacheTimestamp.values.first;

    for (final entry in _cacheTimestamp.entries) {
      if (entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    _imageCache.remove(oldestKey);
    _cacheTimestamp.remove(oldestKey);
  }

  /// 주변 타일들을 프리페치
  Future<void> prefetchSurroundingTiles(
    TileCoordinates center,
    int radius,
    TileLayer options,
  ) async {
    final tilesToPrefetch = <TileCoordinates>[];

    for (int x = center.x - radius; x <= center.x + radius; x++) {
      for (int y = center.y - radius; y <= center.y + radius; y++) {
        if (x >= 0 && y >= 0) {
          tilesToPrefetch.add(TileCoordinates(x, y, center.z));
        }
      }
    }

    await _prefetchTiles(tilesToPrefetch, options);
  }

  /// 타일들을 프리페치
  Future<void> _prefetchTiles(
    List<TileCoordinates> tiles,
    TileLayer options,
  ) async {
    final futures = <Future>[];

    for (final coords in tiles) {
      final tileKey = '${coords.z}_${coords.x}_${coords.y}';

      // 이미 캐시되어 있거나 로딩 중이면 스킵
      if (_imageCache.containsKey(tileKey) ||
          _prefetchingTiles.contains(tileKey)) {
        continue;
      }

      _prefetchingTiles.add(tileKey);

      futures.add(_loadTileImage(coords, options, tileKey));
    }

    await Future.wait(futures);
  }

  /// 타일 이미지 로드
  Future<void> _loadTileImage(
    TileCoordinates coords,
    TileLayer options,
    String tileKey,
  ) async {
    try {
      if (_loadingTiles.containsKey(tileKey)) {
        await _loadingTiles[tileKey]!.future;
        return;
      }

      final completer = Completer<ui.Image>();
      _loadingTiles[tileKey] = completer;

      final imageProvider = getImage(coords, options);
      final imageStream = imageProvider.resolve(const ImageConfiguration());

      imageStream.addListener(ImageStreamListener((info, _) {
        _addToCache(tileKey, info.image);
        completer.complete(info.image);
        _loadingTiles.remove(tileKey);
        _prefetchingTiles.remove(tileKey);
      }, onError: (exception, stackTrace) {
        completer.completeError(exception);
        _loadingTiles.remove(tileKey);
        _prefetchingTiles.remove(tileKey);
      }));

      await completer.future;
    } catch (e) {
      debugPrint('❌ 타일 이미지 로드 실패 ($tileKey): $e');
      _prefetchingTiles.remove(tileKey);
    }
  }

  /// 이미지를 바이트 배열로 변환
  Uint8List _imageToBytes(ui.Image image) {
    // 실제 구현에서는 image.toByteData()를 사용
    // 여기서는 간단히 빈 배열 반환
    return Uint8List(0);
  }

  /// 캐시 클리어
  void clearCache() {
    _imageCache.clear();
    _cacheTimestamp.clear();
    _prefetchingTiles.clear();
    _loadingTiles.clear();
  }

  /// 캐시 통계
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _imageCache.length,
      'maxCacheSize': _maxCacheSize,
      'prefetchingCount': _prefetchingTiles.length,
      'loadingCount': _loadingTiles.length,
    };
  }

  /// 리소스 정리
  void dispose() {
    clearCache();
    _blackTileImage?.dispose();
  }
}