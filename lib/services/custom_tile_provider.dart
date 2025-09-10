import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/visit_tile_service.dart';
import '../utils/tile_utils.dart';

/// Fog of War를 위한 Custom TileProvider
/// - 기본: 검은 타일
/// - 방문 영역: OSM 타일
class CustomTileProvider extends TileProvider {
  final String baseUrl;
  final Map<String, int> _tileFogLevels = {};
  bool _isLoading = false;

  CustomTileProvider({
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
    final sinh = (math.exp(math.pi * (1 - 2 * y / n)) - math.exp(-math.pi * (1 - 2 * y / n))) / 2;
    return math.atan(sinh) * 180 / math.pi;
  }

  /// OSM 타일 X 좌표를 경도로 변환
  double _tileXToLng(int x, int z) {
    final n = 1 << z;
    return (x / n) * 360.0 - 180.0;
  }

  /// OSM 타일 URL 생성
  String _getTileUrl(TileCoordinates coordinates) {
    return baseUrl
        .replaceAll('{s}', _getSubdomain(coordinates))
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
  }

  /// 서브도메인 선택 (로드 밸런싱)
  String _getSubdomain(TileCoordinates coordinates) {
    final subdomains = ['a', 'b', 'c', 'd'];
    final index = (coordinates.x + coordinates.y) % subdomains.length;
    return subdomains[index];
  }

  /// 검은 타일 ImageProvider 생성
  ImageProvider _createBlackTileProvider() {
    return _BlackTileProvider();
  }

  /// 타일 Fog Level 업데이트
  Future<void> updateTileFogLevels(double latitude, double longitude) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final fogLevels = await VisitTileService.getSurroundingTilesFogLevel(
        latitude, 
        longitude
      );
      _tileFogLevels.clear();
      _tileFogLevels.addAll(fogLevels);
      print('타일 Fog Level 업데이트: ${fogLevels.length}개 타일');
    } catch (e) {
      print('타일 Fog Level 업데이트 실패: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 특정 타일의 Fog Level 조회
  int getTileFogLevel(String tileId) {
    return _tileFogLevels[tileId] ?? 3;
  }
}

/// 검은 타일을 생성하는 ImageProvider
class _BlackTileProvider extends ImageProvider<_BlackTileProvider> {
  @override
  ImageStreamCompleter loadImage(_BlackTileProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _createBlackImageCodec(),
      scale: 1.0,
    );
  }

  @override
  Future<_BlackTileProvider> obtainKey(ImageConfiguration configuration) async {
    return this;
  }

  @override
  bool operator ==(Object other) => other is _BlackTileProvider;

  @override
  int get hashCode => 0;

  /// 검은 이미지 코덱 생성
  Future<ui.Codec> _createBlackImageCodec() async {
    final image = await _createBlackImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return await ui.instantiateImageCodec(byteData!.buffer.asUint8List());
  }

  /// 256x256 검은 이미지 생성
  Future<ui.Image> _createBlackImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 검은 배경
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()..color = Colors.black,
    );
    
    final picture = recorder.endRecording();
    return await picture.toImage(256, 256);
  }
}