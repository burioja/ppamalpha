import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 타일 이미지 생성 유틸리티
/// 
/// 256x256 PNG 타일 이미지들을 생성합니다.
class TileImageGenerator {
  static const int tileSize = 256;
  
  /// 단색 타일 이미지 생성
  static Future<Uint8List> createColorTile(Color color) async {
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
  
  /// 검은색 타일 생성
  static Future<Uint8List> createBlackTile() async {
    return createColorTile(Colors.black.withOpacity(0.8));
  }
  
  /// 회색 타일 생성
  static Future<Uint8List> createGrayTile() async {
    return createColorTile(Colors.grey.withOpacity(0.5));
  }
  
  /// 투명 타일 생성
  static Future<Uint8List> createTransparentTile() async {
    return createColorTile(Colors.transparent);
  }
  
  /// 테스트용 패턴 타일 생성 (격자 무늬)
  static Future<Uint8List> createTestTile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // 배경
    final bgPaint = Paint()..color = Colors.blue.withOpacity(0.3);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, tileSize.toDouble(), tileSize.toDouble()),
      bgPaint,
    );
    
    // 격자 그리기
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    
    const gridSize = 32;
    for (int i = 0; i <= tileSize; i += gridSize) {
      // 세로선
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), tileSize.toDouble()),
        gridPaint,
      );
      // 가로선
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(tileSize.toDouble(), i.toDouble()),
        gridPaint,
      );
    }
    
    // 중앙에 텍스트 (타일 좌표 표시용)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TEST',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (tileSize - textPainter.width) / 2,
        (tileSize - textPainter.height) / 2,
      ),
    );
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(tileSize, tileSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
  
  /// 기본 타일 이미지들을 메모리에서 생성 (개발용)
  static Future<Map<String, Uint8List>> generateBasicTiles() async {
    debugPrint('🎨 기본 타일 이미지 생성 시작...');
    
    try {
      final result = <String, Uint8List>{};
      
      result['black'] = await createBlackTile();
      result['gray'] = await createGrayTile();
      result['transparent'] = await createTransparentTile();
      result['test'] = await createTestTile();
      
      debugPrint('✅ 기본 타일 이미지 생성 완료: ${result.keys.join(', ')}');
      return result;
      
    } catch (e) {
      debugPrint('❌ 타일 이미지 생성 오류: $e');
      return {};
    }
  }
}
