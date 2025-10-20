import 'dart:io';
import 'package:flutter/foundation.dart';

/// 포스트 단가 계산 유틸리티
/// 
/// 파일 크기 기반 최소 단가 자동 계산:
/// - 기본 (1MB까지): 30원
/// - 1MB 초과 시: 300KB당 10원씩 추가
class PostPriceCalculator {
  // 가격 정책 상수
  static const int _baseMB = 1024 * 1024; // 1MB (바이트)
  static const int _basePrice = 30; // 기본 30원
  static const int _additionalKB = 300 * 1024; // 300KB (바이트)
  static const int _additionalPrice = 10; // 10원

  /// 전체 파일 크기 계산 (바이트)
  /// 
  /// [images] 이미지 파일 리스트
  /// [audioFile] 오디오 파일 (옵션)
  /// 
  /// Returns: 총 파일 크기 (바이트)
  static int calculateTotalFileSize({
    required List<File> images,
    File? audioFile,
  }) {
    int totalSize = 0;
    
    // 이미지 파일들
    for (final image in images) {
      try {
        totalSize += image.lengthSync();
      } catch (e) {
        debugPrint('⚠️ 이미지 크기 계산 오류: $e');
      }
    }
    
    // 사운드 파일
    if (audioFile != null) {
      try {
        totalSize += audioFile.lengthSync();
      } catch (e) {
        debugPrint('⚠️ 사운드 파일 크기 계산 오류: $e');
      }
    }
    
    return totalSize;
  }
  
  /// 파일 크기에 따른 최소 단가 계산
  /// 
  /// 가격 정책:
  /// - 1MB까지: 30원 (기본 단가)
  /// - 1MB 초과 시: 300KB당 10원씩 추가
  /// 
  /// [fileSizeBytes] 파일 크기 (바이트)
  /// 
  /// Returns: 최소 단가 (원)
  /// 
  /// 예시:
  /// - 500KB → 30원
  /// - 1.5MB → 30원 + ceil(0.5MB/0.3MB) × 10원 = 30원 + 20원 = 50원
  /// - 3MB → 30원 + ceil(2MB/0.3MB) × 10원 = 30원 + 70원 = 100원
  static int calculateMinPrice(int fileSizeBytes) {
    if (fileSizeBytes <= _baseMB) {
      return _basePrice;
    }
    
    // 1MB 초과분 계산
    final excessBytes = fileSizeBytes - _baseMB;
    final additionalUnits = (excessBytes / _additionalKB).ceil();
    
    return _basePrice + (additionalUnits * _additionalPrice);
  }
  
  /// 파일 리스트로부터 직접 최소 단가 계산
  /// 
  /// [images] 이미지 파일 리스트
  /// [audioFile] 오디오 파일 (옵션)
  /// 
  /// Returns: 최소 단가 (원)
  static int calculateMinPriceFromFiles({
    required List<File> images,
    File? audioFile,
  }) {
    final totalSize = calculateTotalFileSize(
      images: images,
      audioFile: audioFile,
    );
    return calculateMinPrice(totalSize);
  }
  
  /// 파일 크기를 읽기 쉬운 형식으로 변환
  /// 
  /// [bytes] 파일 크기 (바이트)
  /// 
  /// Returns: 포맷된 문자열 (예: "1.5MB", "500KB")
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      final kb = bytes / 1024;
      return '${kb.toStringAsFixed(1)}KB';
    } else {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(2)}MB';
    }
  }
  
  /// 단가가 최소 단가 이상인지 검증
  /// 
  /// [price] 확인할 단가
  /// [minPrice] 최소 단가
  /// 
  /// Returns: 유효하면 true, 아니면 false
  static bool validatePrice(int price, int minPrice) {
    return price >= minPrice;
  }
  
  /// 가격 정책 정보 문자열 생성
  /// 
  /// Returns: 가격 정책 설명 문자열
  static String getPricingPolicyDescription() {
    return '1MB까지: ${_basePrice}원, 이후 ${_additionalKB ~/ 1024}KB당 +${_additionalPrice}원';
  }
  
  /// 디버그용: 상세 계산 정보 출력
  /// 
  /// [images] 이미지 파일 리스트
  /// [audioFile] 오디오 파일 (옵션)
  static void printCalculationDetails({
    required List<File> images,
    File? audioFile,
  }) {
    final totalSize = calculateTotalFileSize(
      images: images,
      audioFile: audioFile,
    );
    final minPrice = calculateMinPrice(totalSize);
    
    debugPrint('═══ 단가 계산 상세 ═══');
    debugPrint('📷 이미지 개수: ${images.length}');
    debugPrint('🎵 오디오 파일: ${audioFile != null ? "있음" : "없음"}');
    debugPrint('📊 총 파일 크기: ${formatFileSize(totalSize)} (${totalSize} bytes)');
    debugPrint('💰 최소 단가: ${minPrice}원');
    debugPrint('📋 정책: ${getPricingPolicyDescription()}');
    debugPrint('═══════════════════');
  }
}

