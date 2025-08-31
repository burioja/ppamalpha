import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Fog of War 타일 제공자
/// 
/// Google Maps의 TileOverlay 시스템을 사용하여
/// 사용자의 방문 기록에 따라 다른 투명도의 타일을 제공합니다.
class FogOfWarTileProvider implements TileProvider {
  static const int tileSize = 256;
  
  // 캐시된 타일 이미지들
  static Uint8List? _blackTile;
  static Uint8List? _grayTile;
  static Uint8List? _transparentTile;
  
  // 타일 캐시 (성능 최적화)
  final Map<String, Tile> _tileCache = {};
  final int _maxCacheSize = 100;

  @override
  Future<Tile> getTile(int x, int y, int zoom) async {
    try {
      final tileId = _getTileId(x, y, zoom);
      
      // 캐시 확인
      if (_tileCache.containsKey(tileId)) {
        debugPrint('🔄 타일 캐시 히트: $tileId');
        return _tileCache[tileId]!;
      }
      
      debugPrint('🎯 타일 로드 요청: x=$x, y=$y, zoom=$zoom');
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      // 타일 이미지 준비
      await _ensureTileImages();
      
      if (userId == null) {
        debugPrint('❌ 사용자 인증 없음 - 검은 타일 반환');
        final tile = Tile(tileSize, tileSize, _blackTile!);
        _cacheTile(tileId, tile);
        return tile;
      }
      
      // Firestore에서 방문 기록 조회
      final fogLevel = await _getFogLevel(userId, tileId);
      final tile = _createTileByLevel(fogLevel);
      
      debugPrint('✅ 타일 생성 완료: $tileId, fogLevel=$fogLevel');
      _cacheTile(tileId, tile);
      
      return tile;
      
    } catch (e) {
      debugPrint('❌ 타일 로드 오류: $e');
      // 오류 시 검은 타일 반환
      await _ensureTileImages();
      return Tile(tileSize, tileSize, _blackTile!);
    }
  }
  
  /// 타일 ID 생성
  String _getTileId(int x, int y, int zoom) => '${zoom}_${x}_${y}';
  
  /// Firestore에서 Fog Level 조회
  Future<int> _getFogLevel(String userId, String tileId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('visits_tiles')
          .doc(userId)
          .collection('visited')
          .doc(tileId)
          .get();
      
      if (!doc.exists) {
        return 3; // 미방문 지역 - 검은 타일
      }
      
      final data = doc.data()!;
      final visitedAt = data['visitedAt'] as Timestamp?;
      final fogLevel = data['fogLevel'] as int? ?? 3;
      
      // 30일 지난 방문 기록은 회색으로 처리
      if (visitedAt != null) {
        final daysSinceVisit = DateTime.now().difference(visitedAt.toDate()).inDays;
        if (daysSinceVisit > 30) {
          return 2; // 오래된 방문 지역 - 회색 타일
        }
      }
      
      return fogLevel;
      
    } catch (e) {
      debugPrint('❌ Fog Level 조회 오류: $e');
      return 3; // 오류 시 검은 타일
    }
  }
  
  /// Fog Level에 따른 타일 생성
  Tile _createTileByLevel(int fogLevel) {
    switch (fogLevel) {
      case 1:
        return Tile(tileSize, tileSize, _transparentTile!); // 현재 위치 - 투명
      case 2:
        return Tile(tileSize, tileSize, _grayTile!); // 방문 지역 - 회색
      default:
        return Tile(tileSize, tileSize, _blackTile!); // 미방문 - 검은색
    }
  }
  
  /// 타일 이미지들을 메모리에 로드 (한 번만 실행)
  Future<void> _ensureTileImages() async {
    if (_blackTile != null && _grayTile != null && _transparentTile != null) {
      return; // 이미 로드됨
    }
    
    debugPrint('🎨 타일 이미지 생성 중...');
    
    _blackTile = await _createColorTile(Colors.black.withOpacity(0.8));
    _grayTile = await _createColorTile(Colors.grey.withOpacity(0.5));
    _transparentTile = await _createColorTile(Colors.transparent);
    
    debugPrint('✅ 타일 이미지 생성 완료');
  }
  
  /// 단색 타일 이미지 생성
  Future<Uint8List> _createColorTile(Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
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
    debugPrint('🗑️ 타일 캐시 클리어됨');
  }
}
