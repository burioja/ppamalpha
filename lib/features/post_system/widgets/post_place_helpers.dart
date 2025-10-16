import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';

/// 포스트 생성 화면의 헬퍼 함수들
class PostPlaceHelpers {
  // 이미지 선택
  static Future<List<File>> pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      return images.map((image) => File(image.path)).toList();
    } catch (e) {
      debugPrint('이미지 선택 실패: $e');
      return [];
    }
  }

  // 오디오 파일 선택
  static Future<File?> pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        return File(result.files.first.path!);
      }
      return null;
    } catch (e) {
      debugPrint('오디오 파일 선택 실패: $e');
      return null;
    }
  }

  // 이미지 크기 계산
  static Future<Map<String, double>> calculateImageSize(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      return {
        'width': image.width.toDouble(),
        'height': image.height.toDouble(),
        'sizeKB': bytes.length / 1024,
      };
    } catch (e) {
      debugPrint('이미지 크기 계산 실패: $e');
      return {'width': 0, 'height': 0, 'sizeKB': 0};
    }
  }

  // 오디오 파일 크기 계산
  static Future<double> calculateAudioSize(File audioFile) async {
    try {
      final bytes = await audioFile.readAsBytes();
      return bytes.length / 1024; // KB
    } catch (e) {
      debugPrint('오디오 파일 크기 계산 실패: $e');
      return 0;
    }
  }

  // 미디어 타입 결정
  static List<String> determineMediaTypes(List<File> images, File? audioFile) {
    final types = <String>[];
    
    if (images.isNotEmpty) {
      types.add('image');
    }
    
    if (audioFile != null) {
      types.add('audio');
    }
    
    return types;
  }

  // 미디어 URL 생성 (실제로는 업로드 후 반환)
  static Future<List<String>> generateMediaUrls(List<File> images, File? audioFile) async {
    final urls = <String>[];
    
    // 이미지 URL 생성 (실제로는 Firebase Storage에 업로드)
    for (final image in images) {
      urls.add('https://example.com/image_${DateTime.now().millisecondsSinceEpoch}.jpg');
    }
    
    // 오디오 URL 생성 (실제로는 Firebase Storage에 업로드)
    if (audioFile != null) {
      urls.add('https://example.com/audio_${DateTime.now().millisecondsSinceEpoch}.mp3');
    }
    
    return urls;
  }

  // 썸네일 URL 생성
  static Future<List<String>> generateThumbnailUrls(List<File> images) async {
    final urls = <String>[];
    
    for (final image in images) {
      urls.add('https://example.com/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
    }
    
    return urls;
  }

  // 포스트 생성
  static Future<String?> createPost({
    required String creatorId,
    required String creatorName,
    required int reward,
    required List<int> targetAge,
    required String targetGender,
    required List<String> targetInterest,
    required List<String> targetPurchaseHistory,
    required List<String> mediaType,
    required List<String> mediaUrl,
    List<String>? thumbnailUrl,
    required String title,
    required String description,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    required bool canUse,
    int defaultRadius = 1000,
    DateTime? defaultExpiresAt,
    String? placeId,
    bool isCoupon = false,
    String? youtubeUrl,
  }) async {
    try {
      final postService = PostService();
      
      return await postService.createPost(
        creatorId: creatorId,
        creatorName: creatorName,
        reward: reward,
        targetAge: targetAge,
        targetGender: targetGender,
        targetInterest: targetInterest,
        targetPurchaseHistory: targetPurchaseHistory,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        canRespond: canRespond,
        canForward: canForward,
        canRequestReward: canRequestReward,
        canUse: canUse,
        defaultRadius: defaultRadius,
        defaultExpiresAt: defaultExpiresAt,
        placeId: placeId,
        isCoupon: isCoupon,
        youtubeUrl: youtubeUrl,
      );
    } catch (e) {
      debugPrint('포스트 생성 실패: $e');
      return null;
    }
  }

  // 폼 유효성 검사
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '제목을 입력해주세요';
    }
    if (value.trim().length < 2) {
      return '제목은 2자 이상 입력해주세요';
    }
    if (value.trim().length > 100) {
      return '제목은 100자 이하로 입력해주세요';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '설명을 입력해주세요';
    }
    if (value.trim().length < 10) {
      return '설명은 10자 이상 입력해주세요';
    }
    if (value.trim().length > 1000) {
      return '설명은 1000자 이하로 입력해주세요';
    }
    return null;
  }

  static String? validateReward(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '리워드를 입력해주세요';
    }
    
    final reward = int.tryParse(value);
    if (reward == null) {
      return '숫자를 입력해주세요';
    }
    
    if (reward < 100) {
      return '리워드는 100원 이상이어야 합니다';
    }
    
    if (reward > 1000000) {
      return '리워드는 1,000,000원 이하여야 합니다';
    }
    
    return null;
  }

  static String? validateAgeRange(RangeValues values) {
    if (values.start < 10 || values.end > 90) {
      return '나이 범위는 10세 이상 90세 이하여야 합니다';
    }
    
    if (values.end - values.start < 5) {
      return '나이 범위는 최소 5세 이상이어야 합니다';
    }
    
    return null;
  }

  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return '성별을 선택해주세요';
    }
    return null;
  }

  static String? validateInterest(List<String> interests) {
    if (interests.isEmpty) {
      return '관심사를 최소 1개 이상 선택해주세요';
    }
    if (interests.length > 10) {
      return '관심사는 최대 10개까지 선택할 수 있습니다';
    }
    return null;
  }

  static String? validateMedia(List<File> images, File? audioFile) {
    if (images.isEmpty && audioFile == null) {
      return '이미지 또는 오디오 파일을 최소 1개 이상 추가해주세요';
    }
    
    if (images.length > 10) {
      return '이미지는 최대 10개까지 추가할 수 있습니다';
    }
    
    return null;
  }

  // 미디어 크기 검증
  static String? validateMediaSize(List<File> images, File? audioFile) {
    for (final image in images) {
      final sizeKB = image.lengthSync() / 1024;
      if (sizeKB > 10240) { // 10MB
        return '이미지 파일 크기는 10MB 이하여야 합니다';
      }
    }
    
    if (audioFile != null) {
      final sizeKB = audioFile.lengthSync() / 1024;
      if (sizeKB > 51200) { // 50MB
        return '오디오 파일 크기는 50MB 이하여야 합니다';
      }
    }
    
    return null;
  }

  // 전체 폼 유효성 검사
  static Map<String, String?> validateForm({
    required String title,
    required String description,
    required String reward,
    required RangeValues ageRange,
    required String gender,
    required List<String> interests,
    required List<File> images,
    File? audioFile,
  }) {
    return {
      'title': validateTitle(title),
      'description': validateDescription(description),
      'reward': validateReward(reward),
      'ageRange': validateAgeRange(ageRange),
      'gender': validateGender(gender),
      'interests': validateInterest(interests),
      'media': validateMedia(images, audioFile),
      'mediaSize': validateMediaSize(images, audioFile),
    };
  }

  // 에러 메시지 표시
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 성공 메시지 표시
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 로딩 다이얼로그 표시
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 로딩 다이얼로그 닫기
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }

  // 확인 다이얼로그 표시
  static Future<bool> showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  // 파일 크기 포맷팅
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 시간 포맷팅
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 나이 범위 텍스트 생성
  static String generateAgeRangeText(RangeValues values) {
    return '${values.start.toInt()}세 - ${values.end.toInt()}세';
  }

  // 성별 텍스트 생성
  static String generateGenderText(String gender) {
    switch (gender) {
      case 'male':
        return '남성';
      case 'female':
        return '여성';
      case 'all':
        return '전체';
      default:
        return '알 수 없음';
    }
  }

  // 관심사 텍스트 생성
  static String generateInterestText(List<String> interests) {
    if (interests.isEmpty) return '없음';
    if (interests.length == 1) return interests.first;
    if (interests.length <= 3) return interests.join(', ');
    return '${interests.take(3).join(', ')} 외 ${interests.length - 3}개';
  }

  // 미디어 타입 텍스트 생성
  static String generateMediaTypeText(List<String> mediaTypes) {
    if (mediaTypes.isEmpty) return '없음';
    if (mediaTypes.length == 1) {
      return mediaTypes.first == 'image' ? '이미지' : '오디오';
    }
    return '이미지, 오디오';
  }

  // 포스트 미리보기 데이터 생성
  static Map<String, dynamic> generatePreviewData({
    required String title,
    required String description,
    required int reward,
    required RangeValues ageRange,
    required String gender,
    required List<String> interests,
    required List<String> mediaTypes,
    required List<File> images,
    File? audioFile,
  }) {
    return {
      'title': title,
      'description': description,
      'reward': reward,
      'ageRange': generateAgeRangeText(ageRange),
      'gender': generateGenderText(gender),
      'interests': generateInterestText(interests),
      'mediaTypes': generateMediaTypeText(mediaTypes),
      'imageCount': images.length,
      'hasAudio': audioFile != null,
      'totalSize': images.fold<int>(0, (sum, image) => sum + image.lengthSync()) +
                  (audioFile?.lengthSync() ?? 0),
    };
  }
}

