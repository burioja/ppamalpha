import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../utils/tile_utils.dart';
import '../models/fog_level.dart';
import 'tile_cache_manager.dart';

/// 타일 Prefetching 전략 관리자
class TilePrefetcher {
  static const int _prefetchRadius = 3; // 3x3 타일 영역
  static const double _prefetchDistance = 0.5; // 500m
  static const int _maxPrefetchTiles = 25; // 최대 25개 타일
  
  final TileCacheManager _cacheManager;
  final Map<String, bool> _prefetchedTiles = {};
  final List<LatLng> _positionHistory = [];
  static const int _maxHistorySize = 10;
  
  // 이동 방향 계산을 위한 변수들
  double? _lastBearing;
  LatLng? _lastPosition;
  DateTime? _lastUpdateTime;
  
  TilePrefetcher(this._cacheManager);
  
  /// 위치 업데이트 시 Prefetching 실행
  Future<void> updatePosition(LatLng position, int zoom) async {
    final now = DateTime.now();
    
    // 위치 히스토리 업데이트
    _positionHistory.add(position);
    if (_positionHistory.length > _maxHistorySize) {
      _positionHistory.removeAt(0);
    }
    
    // 이동 방향 계산
    final bearing = _calculateBearing();
    final speed = _calculateSpeed();
    
    // Prefetching 실행
    if (bearing != null && speed != null && speed > 0.5) { // 0.5m/s 이상 이동 시
      await _prefetchTilesInDirection(position, bearing, zoom, speed);
    }
    
    // 현재 위치 주변 타일도 Prefetch
    await _prefetchTilesAroundPosition(position, zoom);
    
    _lastPosition = position;
    _lastBearing = bearing;
    _lastUpdateTime = now;
  }
  
  /// 이동 방향 계산
  double? _calculateBearing() {
    if (_positionHistory.length < 2) return null;
    
    final current = _positionHistory.last;
    final previous = _positionHistory[_positionHistory.length - 2];
    
    return _calculateBearingBetweenPoints(previous, current);
  }
  
  /// 두 점 간의 방향 계산
  double _calculateBearingBetweenPoints(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final deltaLng = (to.longitude - from.longitude) * pi / 180;
    
    final y = sin(deltaLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng);
    
    final bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360; // 0-360도 범위로 정규화
  }
  
  /// 이동 속도 계산 (m/s)
  double? _calculateSpeed() {
    if (_positionHistory.length < 2 || _lastUpdateTime == null) return null;
    
    final current = _positionHistory.last;
    final previous = _positionHistory[_positionHistory.length - 2];
    final now = DateTime.now();
    
    final distance = TileUtils.calculateDistance(previous, current) * 1000; // km to m
    final timeDiff = now.difference(_lastUpdateTime!).inSeconds;
    
    if (timeDiff == 0) return null;
    
    return distance / timeDiff;
  }
  
  /// 이동 방향 기준 타일 Prefetch
  Future<void> _prefetchTilesInDirection(LatLng position, double bearing, int zoom, double speed) async {
    try {
      // 속도에 따른 Prefetch 거리 조절
      final prefetchDistance = _prefetchDistance * (speed / 5.0).clamp(0.5, 2.0);
      
      // 이동 방향으로 예상 위치 계산
      final predictedPosition = _calculatePositionInDirection(position, bearing, prefetchDistance);
      
      // 예상 위치 주변 타일들 계산
      final tiles = TileUtils.getTilesInRadius(predictedPosition, zoom, 0.3);
      
      // Prefetch 실행
      int prefetchCount = 0;
      for (final tile in tiles) {
        if (prefetchCount >= _maxPrefetchTiles) break;
        
        final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
        
        if (!_prefetchedTiles.containsKey(tileKey)) {
          await _prefetchTile(tile, zoom);
          _prefetchedTiles[tileKey] = true;
          prefetchCount++;
        }
      }
      
      debugPrint('🚀 방향 기반 Prefetch: $prefetchCount개 타일 (방향: ${bearing.toStringAsFixed(1)}°)');
      
    } catch (e) {
      debugPrint('❌ 방향 기반 Prefetch 오류: $e');
    }
  }
  
  /// 현재 위치 주변 타일 Prefetch
  Future<void> _prefetchTilesAroundPosition(LatLng position, int zoom) async {
    try {
      final centerTile = TileUtils.latLngToTile(position, zoom);
      
      int prefetchCount = 0;
      for (int dx = -_prefetchRadius; dx <= _prefetchRadius; dx++) {
        for (int dy = -_prefetchRadius; dy <= _prefetchRadius; dy++) {
          if (prefetchCount >= _maxPrefetchTiles) break;
          
          final tile = Coords(centerTile.x + dx, centerTile.y + dy);
          final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
          
          if (!_prefetchedTiles.containsKey(tileKey)) {
            await _prefetchTile(tile, zoom);
            _prefetchedTiles[tileKey] = true;
            prefetchCount++;
          }
        }
      }
      
      debugPrint('📍 위치 기반 Prefetch: $prefetchCount개 타일');
      
    } catch (e) {
      debugPrint('❌ 위치 기반 Prefetch 오류: $e');
    }
  }
  
  /// 방향과 거리로 다음 위치 계산
  LatLng _calculatePositionInDirection(LatLng start, double bearing, double distance) {
    final lat1 = start.latitude * pi / 180;
    final lng1 = start.longitude * pi / 180;
    final bearingRad = bearing * pi / 180;
    
    final lat2 = asin(sin(lat1) * cos(distance / 6371000) + 
                     cos(lat1) * sin(distance / 6371000) * cos(bearingRad));
    
    final lng2 = lng1 + atan2(sin(bearingRad) * sin(distance / 6371000) * cos(lat1),
                              cos(distance / 6371000) - sin(lat1) * sin(lat2));
    
    return LatLng(lat2 * 180 / pi, lng2 * 180 / pi);
  }
  
  /// 개별 타일 Prefetch
  Future<void> _prefetchTile(Coords tile, int zoom) async {
    try {
      final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
      
      // 캐시에서 이미 존재하는지 확인
      final cachedFile = await _cacheManager.getCachedTile(tileKey);
      if (cachedFile != null) {
        return; // 이미 캐시됨
      }
      
      // 포그 레벨 결정 (간단한 구현)
      final fogLevel = _determineFogLevel(tile, zoom);
      
      // 포그 타일 캐시
      await _cacheManager.cacheFogTile(tileKey, fogLevel);
      
    } catch (e) {
      debugPrint('❌ 타일 Prefetch 오류: $e');
    }
  }
  
  /// 타일의 포그 레벨 결정 (간단한 구현)
  FogLevel _determineFogLevel(Coords tile, int zoom) {
    // 실제 구현에서는 사용자 위치와 방문 기록을 고려
    // 여기서는 간단한 패턴으로 구현
    final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
    final hash = tileKey.hashCode;
    
    if (hash % 3 == 0) {
      return FogLevel.clear;
    } else if (hash % 3 == 1) {
      return FogLevel.gray;
    } else {
      return FogLevel.black;
    }
  }
  
  /// Prefetch 통계 정보
  Map<String, dynamic> getPrefetchStats() {
    return {
      'prefetchedTiles': _prefetchedTiles.length,
      'positionHistory': _positionHistory.length,
      'lastBearing': _lastBearing,
      'lastPosition': _lastPosition?.toString(),
      'lastUpdateTime': _lastUpdateTime?.toString(),
    };
  }
  
  /// Prefetch 히스토리 초기화
  void clearHistory() {
    _positionHistory.clear();
    _prefetchedTiles.clear();
    _lastBearing = null;
    _lastPosition = null;
    _lastUpdateTime = null;
  }
  
  /// 리소스 정리
  void dispose() {
    clearHistory();
  }
}
