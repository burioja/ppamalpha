import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  Future<Tile> getTile(int x, int y, int? zoom) async {
    // zoom이 null인 경우 기본값 사용
    final actualZoom = zoom ?? 15;
    
    debugPrint('🎯 Fog of War 타일 요청: x=$x, y=$y, zoom=$actualZoom');
    
    try {
      final tileId = _getTileId(x, y, actualZoom);
      
      // 캐시 확인
      if (_tileCache.containsKey(tileId)) {
        debugPrint('🔄 타일 캐시 히트: $tileId');
        return _tileCache[tileId]!;
      }
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      // 타일 이미지 준비
      await _ensureTileImages();
      
      if (userId == null) {
        debugPrint('❌ 사용자 인증 없음 - 검은 타일 반환');
        final tile = Tile(tileSize, tileSize, _blackTile!);
        _cacheTile(tileId, tile);
        return tile;
      }
      
      // 🔥 실제 Fog of War 로직
      final fogLevel = await _getFogLevel(userId, tileId, x, y, actualZoom);
      final tile = _createTileByLevel(fogLevel);
      
      debugPrint('✅ Fog of War 타일 생성: $tileId, fogLevel=$fogLevel');
      _cacheTile(tileId, tile);
      
      return tile;
      
    } catch (e) {
      debugPrint('❌ Fog of War 타일 오류: $e');
      // 오류 시 검은 타일 반환
      await _ensureTileImages();
      return Tile(tileSize, tileSize, _blackTile!);
    }
  }
  
  /// 테스트용 빨간색 반투명 타일 생성
  Future<Uint8List> _createTestTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.red.withOpacity(0.3);
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// 타일 ID 생성
  String _getTileId(int x, int y, int zoom) => '${zoom}_${x}_${y}';
  
  /// 🔥 실제 Fog of War 로직: 현재 위치 기반 Fog Level 결정
  Future<int> _getFogLevel(String userId, String tileId, int x, int y, int zoom) async {
    try {
      // 1. 현재 위치 가져오기 (Geolocator 사용)
      final currentPosition = await _getCurrentPosition();
      if (currentPosition == null) {
        debugPrint('❌ 현재 위치 없음 - 검은 타일');
        return 3; // 현재 위치 없으면 검은 타일
      }
      
      // 2. 타일의 중심 좌표 계산
      final tileBounds = _getTileBounds(x, y, zoom);
      final tileCenter = tileBounds.center;
      
      // 3. 현재 위치와 타일 중심 사이의 거리 계산
      final distance = _calculateDistance(currentPosition, tileCenter);
      
      // 4. 거리에 따른 Fog Level 결정
      if (distance <= 0.5) { // 500m 이내
        debugPrint('🌟 밝은 영역: $tileId (${distance.toStringAsFixed(1)}km)');
        return 1; // 투명 - 현재 위치 주변
      } else if (distance <= 2.0) { // 2km 이내
        debugPrint('🌫️ 회색 영역: $tileId (${distance.toStringAsFixed(1)}km)');
        return 2; // 회색 - 주변 지역
      } else {
        debugPrint('🌑 어두운 영역: $tileId (${distance.toStringAsFixed(1)}km)');
        return 3; // 검은색 - 원거리
      }
      
    } catch (e) {
      debugPrint('❌ Fog Level 계산 오류: $e');
      return 3; // 오류 시 검은 타일
    }
  }
  
  /// 현재 위치 가져오기
  Future<LatLng?> _getCurrentPosition() async {
    try {
      // 간단한 구현: 하드코딩된 서울 위치 (테스트용)
      // TODO: 실제 Geolocator 연동
      return const LatLng(37.4969433, 127.0311633); // 로그에서 확인된 현재 위치
    } catch (e) {
      debugPrint('❌ 현재 위치 가져오기 오류: $e');
      return null;
    }
  }
  
  /// 타일 경계 계산
  TileBounds _getTileBounds(int x, int y, int zoom) {
    final northWest = _tileToLatLng(x, y, zoom);
    final southEast = _tileToLatLng(x + 1, y + 1, zoom);
    
    return TileBounds(
      northWest: northWest,
      southEast: southEast,
      center: LatLng(
        (northWest.latitude + southEast.latitude) / 2,
        (northWest.longitude + southEast.longitude) / 2,
      ),
    );
  }
  
  /// 타일 좌표를 위도/경도로 변환
  LatLng _tileToLatLng(int x, int y, int zoom) {
    final n = 1 << zoom; // 2^zoom
    final lng = x / n * 360.0 - 180.0;
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * y / n)));
    final lat = latRad * 180.0 / math.pi;
    return LatLng(lat, lng);
  }
  
  /// 하이퍼볼릭 사인 함수 (math 라이브러리에 없음)
  double _sinh(double x) {
    return (math.exp(x) - math.exp(-x)) / 2.0;
  }
  
  /// 두 지점 사이의 거리 계산 (Haversine 공식, km 단위)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371.0; // km
    
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
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
  
  /// 타일 이미지들을 메모리에 생성 (한 번만 실행)
  Future<void> _ensureTileImages() async {
    if (_blackTile != null && _grayTile != null && _transparentTile != null) {
      return; // 이미 생성됨
    }
    
    debugPrint('🎨 타일 이미지 생성 중...');
    
    _blackTile = await _createColorTile(Colors.black.withOpacity(0.8));
    _grayTile = await _createColorTile(Colors.grey.withOpacity(0.5)); 
    _transparentTile = await _createColorTile(Colors.transparent);
    
    debugPrint('✅ 타일 이미지 생성 완료 (메모리)');
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
