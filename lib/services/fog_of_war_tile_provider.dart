import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

/// Firebase Storage 기반 Fog of War 타일 제공자
/// 
/// CDN/Firebase Storage에서 사용자별 타일 PNG를 불러와서
/// Google Maps TileOverlay로 Fog of War 효과를 제공합니다.
class FogOfWarTileProvider implements TileProvider {
  final int tileSize;
  final String userId;
  final String baseUrl;
  final http.Client _httpClient = http.Client();
  
  // 타일 캐시 (성능 최적화)
  final Map<String, Tile> _tileCache = {};
  final int _maxCacheSize = 100;

  FogOfWarTileProvider({
    required this.userId,
    required this.baseUrl,
    this.tileSize = 256,
  });

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final actualZoom = zoom ?? 15;
    final tileId = '${actualZoom}_${x}_${y}';
    
    debugPrint('🎯 Fog of War 타일 요청: x=$x, y=$y, zoom=$actualZoom');
    
    // 캐시 확인
    if (_tileCache.containsKey(tileId)) {
      debugPrint('🔄 타일 캐시 히트: $tileId');
      return _tileCache[tileId]!;
    }
    
    try {
      final url = _buildTileUrl(x, y, actualZoom);
      final response = await _httpClient.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        debugPrint('✅ 타일 로드 성공: $url');
        final tile = Tile(tileSize, tileSize, response.bodyBytes);
        _cacheTile(tileId, tile);
        return tile;
      } else {
        debugPrint('⚠️ 타일 로드 실패 (${response.statusCode}): $url');
      }
    } catch (e) {
      debugPrint('❌ 타일 로드 오류: $e');
    }
    
    // 기본 검은 타일 반환
    return await _getDefaultDarkTile();
  }
  
  /// 타일 URL 생성
  String _buildTileUrl(int x, int y, int zoom) {
    // 예시: https://your-cdn.com/tiles/user123/15/12345/67890.png
    return '$baseUrl/tiles/$userId/$zoom/$x/$y.png';
  }
  
  /// 기본 검은 타일 생성 (HTTP 실패 시 사용)
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
    debugPrint('🗑️ 타일 캐시 클리어됨');
  }
  
  /// 리소스 정리
  void dispose() {
    _httpClient.close();
    _tileCache.clear();
  }
}
