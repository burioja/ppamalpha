import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/tile_utils.dart';

/// 타일 경계 정보 클래스
class TileBounds {
  final LatLng northWest;
  final LatLng southEast;
  final LatLng center;
  
  const TileBounds({
    required this.northWest,
    required this.southEast,
    required this.center,
  });
}

/// Firestore 기반 Fog of War 타일 제공자
/// 
/// 현재 위치 주변은 실시간으로 투명하게 만들고,
/// 방문한 지역은 Firestore에서 읽어서 처리합니다.
class FogOfWarTileProvider implements TileProvider {
  final int tileSize;
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 타일 캐시 (성능 최적화)
  final Map<String, Tile> _tileCache = {};
  final int _maxCacheSize = 100;
  
  // 현재 위치 정보 (투명 영역 계산용)
  LatLng? _currentLocation;
  double _revealRadius = 0.3; // 킬로미터 단위
  
  // 방문 기록 캐시
  final Map<String, int> _visitedTilesCache = {};

  FogOfWarTileProvider({
    required this.userId,
    this.tileSize = 256,
  });
  
  /// 현재 위치 설정
  void setCurrentLocation(LatLng location) {
    _currentLocation = location;
    debugPrint('📍 FogOfWarTileProvider 현재 위치 설정: ${location.latitude}, ${location.longitude}');
  }
  
  /// 탐색 반경 설정
  void setRevealRadius(double radiusKm) {
    _revealRadius = radiusKm;
    debugPrint('🎯 FogOfWarTileProvider 탐색 반경 설정: ${radiusKm}km');
  }

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final actualZoom = zoom ?? 15;
    final tileId = '${actualZoom}_${x}_${y}';
    
    // 캐시 확인
    if (_tileCache.containsKey(tileId)) {
      return _tileCache[tileId]!;
    }
    
    // 1. 현재 위치 주변 확인 (가장 우선순위)
    if (_currentLocation != null) {
      final tileCenter = _getTileCenter(x, y, actualZoom);
      final distance = TileUtils.calculateDistance(_currentLocation!, tileCenter);
      
      // 현재 위치 주변 300m는 항상 투명
      if (distance <= _revealRadius) {
        final tile = await _getTransparentTile();
        _cacheTile(tileId, tile);
        return tile;
      }
    }
    
    // 2. 방문 기록 확인 (현재 위치 주변 300m는 제외)
    final fogLevel = await _getTileFogLevel(tileId);
    Tile tile;
    
    switch (fogLevel) {
      case 1: // 완전 밝음 (투명) - 현재는 사용하지 않음
        tile = await _getTransparentTile();
        break;
      case 2: // 회색 (반투명) - 방문한 지역
        tile = await _getGrayTile();
        break;
      default: // 3 또는 없음 - 완전 어둠 (검은색)
        tile = await _getDefaultDarkTile();
        break;
    }
    
    _cacheTile(tileId, tile);
    return tile;
  }
  
  /// 타일의 Fog Level 가져오기 (Firestore에서)
  Future<int> _getTileFogLevel(String tileId) async {
    // 캐시 확인
    if (_visitedTilesCache.containsKey(tileId)) {
      return _visitedTilesCache[tileId]!;
    }
    
    // 현재 위치가 없으면 완전 어둠
    if (_currentLocation == null) {
      _visitedTilesCache[tileId] = 3;
      return 3;
    }
    
    try {
      final doc = await _firestore
          .collection('visits_tiles')
          .doc(userId)
          .collection('visited')
          .doc(tileId)
          .get();
      
      if (doc.exists) {
        final fogLevel = doc.data()?['fogLevel'] as int? ?? 3;
        _visitedTilesCache[tileId] = fogLevel;
        return fogLevel;
      }
    } catch (e) {
      debugPrint('❌ Firestore 읽기 오류: $e');
    }
    
    // 기본값: 완전 어둠
    _visitedTilesCache[tileId] = 3;
    return 3;
  }
  
  /// 타일 중심점 계산
  LatLng _getTileCenter(int x, int y, int zoom) {
    final n = 1 << zoom;
    final lonDeg = x / n * 360.0 - 180.0;
    final latRad = atan((pow(e, pi * (1 - 2 * y / n)) - pow(e, -pi * (1 - 2 * y / n))) / 2);
    final latDeg = latRad * 180.0 / pi;
    return LatLng(latDeg, lonDeg);
  }
  

  

  
  /// 투명 타일 생성 (지도가 보이는 영역)
  Future<Tile> _getTransparentTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 투명한 배경 (지도가 그대로 보임)
    final paint = Paint()..color = Colors.transparent;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return Tile(tileSize, tileSize, byteData!.buffer.asUint8List());
  }
  
  /// 회색 타일 생성 (방문한 지역 - 반투명)
  Future<Tile> _getGrayTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 반투명 회색 배경 (지도가 흐리게 보임)
    final paint = Paint()..color = Colors.grey.withOpacity(0.5);
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return Tile(tileSize, tileSize, byteData!.buffer.asUint8List());
  }
  
  /// 기본 검은 타일 생성 (지도가 안 보이는 영역)
  Future<Tile> _getDefaultDarkTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.black; // 완전 불투명
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return Tile(tileSize, tileSize, byteData!.buffer.asUint8List());
  }
  
  /// 타일 캐시 저장
  void _cacheTile(String tileId, Tile tile) {
    if (_tileCache.length >= _maxCacheSize) {
      // 캐시 크기 제한 - 가장 오래된 항목 제거
      final oldestKey = _tileCache.keys.first;
      _tileCache.remove(oldestKey);
    }
    
    _tileCache[tileId] = tile;
  }
  
  /// 캐시 클리어
  void clearCache() {
    _tileCache.clear();
    _visitedTilesCache.clear();
    debugPrint('🗑️ 타일 캐시 및 방문 기록 캐시 클리어됨');
  }
  
  /// 리소스 정리
  void dispose() {
    _tileCache.clear();
    _visitedTilesCache.clear();
  }
}
