import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import 'fog_of_war_tile_provider.dart';

/// 포그 오브 워 타일 프로바이더 (실제 구현)
class FogTileProvider extends TileProvider {
  final String userId;
  final MapController mapController;
  
  // 포그 오브 워 매니저
  final FogOfWarTileProvider _fogManager;
  
  // 캐시 관리
  final Map<String, Uint8List> _tileCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheExpiry = const Duration(minutes: 10);
  
  // 타일 크기
  static const int tileSize = 256;

  FogTileProvider({
    required this.userId,
    required this.mapController,
  }) : _fogManager = FogOfWarTileProvider(
          userId: userId,
          mapController: mapController,
        );

  @override
  ImageProvider getImage(Coords coords, TileLayerOptions options) {
    return _FogTileImage(
      coords: coords,
      fogManager: _fogManager,
      cache: _tileCache,
      cacheTimestamp: _cacheTimestamp,
      cacheExpiry: _cacheExpiry,
    );
  }

  /// 현재 위치 설정
  void setCurrentLocation(LatLng position) {
    _fogManager.setCurrentLocation(position);
  }

  /// 반경 설정 (km)
  void setRevealRadius(double radius) {
    _fogManager.setRevealRadius(radius);
  }

  /// 캐시 클리어
  void clearCache() {
    _fogManager.clearCache();
    _tileCache.clear();
    _cacheTimestamp.clear();
  }

  @override
  void dispose() {
    _fogManager.dispose();
    _tileCache.clear();
    _cacheTimestamp.clear();
    super.dispose();
  }
}

/// 포그 타일 이미지 클래스
class _FogTileImage extends ImageProvider<_FogTileImage> {
  final Coords coords;
  final FogOfWarTileProvider fogManager;
  final Map<String, Uint8List> cache;
  final Map<String, DateTime> cacheTimestamp;
  final Duration cacheExpiry;

  _FogTileImage({
    required this.coords,
    required this.fogManager,
    required this.cache,
    required this.cacheTimestamp,
    required this.cacheExpiry,
  });

  @override
  ImageStreamCompleter loadImage(_FogTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadTile(key),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadTile(_FogTileImage key) async {
    final tileKey = '${coords.z}_${coords.x}_${coords.y}';
    
    // 캐시 확인
    if (cache.containsKey(tileKey)) {
      final timestamp = cacheTimestamp[tileKey];
      if (timestamp != null && 
          DateTime.now().difference(timestamp) < cacheExpiry) {
        final bytes = cache[tileKey]!;
        return await ui.instantiateImageCodec(bytes);
      }
    }

    // 포그 레벨 계산
    final fogLevel = await fogManager.getFogLevelForTile(
      coords.z, coords.x, coords.y
    );

    // 포그 타일 생성
    final bytes = await _generateFogTile(fogLevel);
    
    // 캐시에 저장
    cache[tileKey] = bytes;
    cacheTimestamp[tileKey] = DateTime.now();
    
    return await ui.instantiateImageCodec(bytes);
  }

  /// 포그 타일 생성
  Future<Uint8List> _generateFogTile(FogLevel fogLevel) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(256, 256);

    switch (fogLevel) {
      case FogLevel.clear:
        // 완전 투명 (지도 보임)
        canvas.drawColor(Colors.transparent, BlendMode.clear);
        break;
        
      case FogLevel.gray:
        // 회색 반투명
        canvas.drawColor(Colors.grey.withOpacity(0.3), BlendMode.srcOver);
        break;
        
      case FogLevel.black:
        // 검정 (완전 가림)
        canvas.drawColor(Colors.black.withOpacity(0.8), BlendMode.srcOver);
        break;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  @override
  Future<_FogTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FogTileImage &&
          runtimeType == other.runtimeType &&
          coords == other.coords;

  @override
  int get hashCode => coords.hashCode;
}
