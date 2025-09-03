import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// 포그 오브 워 타일 레벨 정의
enum FogLevel {
  clear(1),    // 완전 노출 (현재 위치 1km)
  gray(2),     // 회색 반투명 (방문한 위치 1km, 30일간)
  black(3);    // 검정 (미방문 지역)

  const FogLevel(this.level);
  final int level;
}

/// OSM 기반 포그 오브 워 타일 프로바이더
class FogOfWarTileProvider {
  final FogOfWarManager fogManager;
  
  // 캐시 관리
  final Map<String, FogLevel> _tileCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheExpiry = const Duration(minutes: 10);
  
  // 방문 기록 캐시
  final Map<String, DateTime> _visitedTiles = {};
  final Duration _visitRetention = const Duration(days: 30);
  
  // 디바운스 타이머
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  FogOfWarTileProvider(this.fogManager);

  /// 캐시 클리어
  void clearCache() {
    _tileCache.clear();
    _cacheTimestamp.clear();
  }

  /// 타일의 포그 레벨 계산
  Future<FogLevel> getFogLevelForTile(int z, int x, int y) async {
    final tileKey = '${z}_${x}_${y}';
    
    // 캐시 확인
    if (_tileCache.containsKey(tileKey)) {
      final timestamp = _cacheTimestamp[tileKey];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _tileCache[tileKey]!;
      }
    }
    
    // 간단한 포그 레벨 계산 (현재는 모든 타일을 clear로 설정)
    final fogLevel = FogLevel.clear;
    
    // 캐시에 저장
    _tileCache[tileKey] = fogLevel;
    _cacheTimestamp[tileKey] = DateTime.now();
    
    return fogLevel;
  }

  /// 리소스 정리
  void dispose() {
    _debounceTimer?.cancel();
    _tileCache.clear();
    _cacheTimestamp.clear();
    _visitedTiles.clear();
  }
}