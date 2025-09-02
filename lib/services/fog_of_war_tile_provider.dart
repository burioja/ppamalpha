import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  final String userId;
  final MapController mapController;
  
  // 캐시 관리
  final Map<String, FogLevel> _tileCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheExpiry = const Duration(minutes: 10);
  
  // 위치 및 반경 설정
  LatLng? _currentPosition;
  double _revealRadius = 1.0; // 1km 반경
  
  // 방문 기록 캐시
  final Map<String, DateTime> _visitedTiles = {};
  final Duration _visitRetention = const Duration(days: 30);
  
  // 디바운스 타이머
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  FogOfWarTileProvider({
    required this.userId,
    required this.mapController,
  });

  /// 현재 위치 설정
  void setCurrentLocation(LatLng position) {
    _currentPosition = position;
    _updateVisitedTiles();
    _clearCache();
  }

  /// 반경 설정 (km)
  void setRevealRadius(double radius) {
    _revealRadius = radius;
    _clearCache();
  }

  /// 캐시 클리어
  void clearCache() {
    _tileCache.clear();
    _cacheTimestamp.clear();
  }

  void _clearCache() {
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

    // 포그 레벨 계산
    final fogLevel = await _calculateFogLevel(z, x, y);
    
    // 캐시에 저장
    _tileCache[tileKey] = fogLevel;
    _cacheTimestamp[tileKey] = DateTime.now();
    
    return fogLevel;
  }

  /// 포그 레벨 계산 로직
  Future<FogLevel> _calculateFogLevel(int z, int x, int y) async {
    // 타일 중심점 계산
    final tileCenter = _tileToLatLng(z, x, y);
    
    // 현재 위치가 없으면 검정
    if (_currentPosition == null) {
      return FogLevel.black;
    }

    // 현재 위치에서의 거리 계산
    final distance = _calculateDistance(_currentPosition!, tileCenter);
    
    // 1단계: 현재 위치 1km 반경 내
    if (distance <= _revealRadius) {
      return FogLevel.clear;
    }

    // 2단계: 방문한 위치 1km 반경 내 (30일간)
    if (await _isVisitedTile(z, x, y)) {
      return FogLevel.gray;
    }

    // 3단계: 미방문 지역
    return FogLevel.black;
  }

  /// 타일 좌표를 LatLng로 변환
  LatLng _tileToLatLng(int z, int x, int y) {
    final n = pow(2.0, z);
    final lonDeg = x / n * 360.0 - 180.0;
    final latRad = atan(sinh(pi * (1 - 2 * y / n)));
    final latDeg = latRad * 180.0 / pi;
    return LatLng(latDeg, lonDeg);
  }

  /// 두 점 사이의 거리 계산 (km)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  /// 방문한 타일인지 확인
  Future<bool> _isVisitedTile(int z, int x, int y) async {
    final tileKey = '${z}_${x}_${y}';
    
    // 로컬 캐시 확인
    if (_visitedTiles.containsKey(tileKey)) {
      final visitTime = _visitedTiles[tileKey]!;
      if (DateTime.now().difference(visitTime) < _visitRetention) {
        return true;
      } else {
        _visitedTiles.remove(tileKey);
      }
    }

    // Firestore에서 확인
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('visited_tiles')
          .doc(tileKey)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final timestamp = (data?['timestamp'] as Timestamp?)?.toDate();
        
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < _visitRetention) {
          _visitedTiles[tileKey] = timestamp;
          return true;
        }
      }
    } catch (e) {
      debugPrint('방문 타일 확인 오류: $e');
    }

    return false;
  }

  /// 방문한 타일 기록 업데이트
  void _updateVisitedTiles() {
    if (_currentPosition == null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () async {
      await _recordCurrentPositionTiles();
    });
  }

  /// 현재 위치 주변 타일들을 방문 기록으로 저장
  Future<void> _recordCurrentPositionTiles() async {
    if (_currentPosition == null) return;

    try {
      // 현재 줌 레벨에서 주변 타일들 계산
      final currentZoom = mapController.camera?.zoom ?? 13;
      final tiles = _getTilesInRadius(_currentPosition!, _revealRadius, currentZoom.toInt());
      
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      for (final tile in tiles) {
        final tileKey = '${tile.z}_${tile.x}_${tile.y}';
        
        // 로컬 캐시 업데이트
        _visitedTiles[tileKey] = now;
        
        // Firestore에 저장
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('visited_tiles')
            .doc(tileKey);
        
        batch.set(docRef, {
          'timestamp': Timestamp.fromDate(now),
          'z': tile.z,
          'x': tile.x,
          'y': tile.y,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('방문 타일 기록 완료: ${tiles.length}개 타일');
    } catch (e) {
      debugPrint('방문 타일 기록 오류: $e');
    }
  }

  /// 반경 내의 타일들 계산
  List<TileCoordinate> _getTilesInRadius(LatLng center, double radiusKm, int zoom) {
    final tiles = <TileCoordinate>[];
    
    // 반경을 도 단위로 변환 (대략적)
    final radiusDeg = radiusKm / 111.0; // 1도 ≈ 111km
    
    // 타일 크기 계산
    final tileSize = 360.0 / pow(2, zoom);
    
    // 중심 타일
    final centerTile = _latLngToTile(center, zoom);
    
    // 반경 내 타일들 계산
    final tileRadius = (radiusDeg / tileSize).ceil();
    
    for (int dx = -tileRadius; dx <= tileRadius; dx++) {
      for (int dy = -tileRadius; dy <= tileRadius; dy++) {
        final tileX = centerTile.x + dx;
        final tileY = centerTile.y + dy;
        
        // 타일 중심점 계산
        final tileCenter = _tileToLatLng(zoom, tileX, tileY);
        
        // 거리 확인
        if (_calculateDistance(center, tileCenter) <= radiusKm) {
          tiles.add(TileCoordinate(zoom, tileX, tileY));
        }
      }
    }
    
    return tiles;
  }

  /// LatLng를 타일 좌표로 변환
  TileCoordinate _latLngToTile(LatLng point, int zoom) {
    final n = pow(2.0, zoom);
    final x = ((point.longitude + 180.0) / 360.0 * n).floor();
    final y = ((1.0 - asinh(tan(point.latitude * pi / 180.0)) / pi) / 2.0 * n).floor();
    return TileCoordinate(zoom, x, y);
  }

  /// 리소스 정리
  void dispose() {
    _debounceTimer?.cancel();
    _tileCache.clear();
    _cacheTimestamp.clear();
    _visitedTiles.clear();
  }
}

/// 타일 좌표 클래스
class TileCoordinate {
  final int z;
  final int x;
  final int y;

  TileCoordinate(this.z, this.x, this.y);

  @override
  String toString() => 'Tile($z, $x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => z.hashCode ^ x.hashCode ^ y.hashCode;
}