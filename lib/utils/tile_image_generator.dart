import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 타일 이미지 생성기
class TileImageGenerator {
  static const int tileSize = 256;
  
  /// 투명 타일 생성 (Level 1: Clear)
  static Future<Uint8List> generateClearTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 완전 투명한 타일
    final paint = Paint()..color = Colors.transparent;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(tileSize, tileSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// 회색 반투명 타일 생성 (Level 2: Gray)
  static Future<Uint8List> generateGrayTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 회색 반투명 오버레이
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(tileSize, tileSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// 검정 타일 생성 (Level 3: Black)
  static Future<Uint8List> generateBlackTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 완전 검정 오버레이
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      paint,
    );
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(tileSize, tileSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// 모든 포그 타일 이미지 생성
  static Future<void> generateAllFogTiles() async {
    try {
      // 실제 구현에서는 파일 시스템에 저장
      // 여기서는 메모리에서만 생성
      await generateClearTile();
      await generateGrayTile();
      await generateBlackTile();
    } catch (e) {
      debugPrint('Error generating fog tiles: $e');
    }
  }
}