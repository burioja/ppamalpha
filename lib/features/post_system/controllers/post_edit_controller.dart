import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';

/// PostEditScreen 관련 로직을 관리하는 컨트롤러
class PostEditController {
  /// 포스트 수정
  static Future<bool> updatePost({
    required String postId,
    String? title,
    String? description,
    List<String>? mediaUrl,
    List<String>? mediaType,
    List<String>? thumbnailUrl,
    int? reward,
    List<int>? targetAge,
    String? targetGender,
    List<String>? targetInterest,
    List<String>? targetPurchaseHistory,
    bool? canRespond,
    bool? canForward,
    bool? canRequestReward,
    bool? canUse,
    int? defaultRadius,
    DateTime? defaultExpiresAt,
    String? placeId,
    bool? isCoupon,
    String? youtubeUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (mediaUrl != null) updateData['mediaUrl'] = mediaUrl;
      if (mediaType != null) updateData['mediaType'] = mediaType;
      if (thumbnailUrl != null) updateData['thumbnailUrl'] = thumbnailUrl;
      if (reward != null) updateData['reward'] = reward;
      if (targetAge != null) updateData['targetAge'] = targetAge;
      if (targetGender != null) updateData['targetGender'] = targetGender;
      if (targetInterest != null) updateData['targetInterest'] = targetInterest;
      if (targetPurchaseHistory != null) updateData['targetPurchaseHistory'] = targetPurchaseHistory;
      if (canRespond != null) updateData['canRespond'] = canRespond;
      if (canForward != null) updateData['canForward'] = canForward;
      if (canRequestReward != null) updateData['canRequestReward'] = canRequestReward;
      if (canUse != null) updateData['canUse'] = canUse;
      if (defaultRadius != null) updateData['defaultRadius'] = defaultRadius;
      if (defaultExpiresAt != null) {
        updateData['defaultExpiresAt'] = Timestamp.fromDate(defaultExpiresAt);
      }
      if (placeId != null) updateData['placeId'] = placeId;
      if (isCoupon != null) updateData['isCoupon'] = isCoupon;
      if (youtubeUrl != null) updateData['youtubeUrl'] = youtubeUrl;

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .update(updateData);

      debugPrint('✅ 포스트 수정 완료: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 수정 실패: $e');
      return false;
    }
  }

  /// 포스트 유효성 검증
  static String? validatePostData({
    required String title,
    required String description,
    required List<String> mediaUrl,
    required int reward,
  }) {
    if (title.trim().isEmpty) {
      return '제목을 입력해주세요';
    }

    if (title.length > 100) {
      return '제목은 100자 이내로 입력해주세요';
    }

    if (description.trim().isEmpty) {
      return '설명을 입력해주세요';
    }

    if (description.length > 1000) {
      return '설명은 1000자 이내로 입력해주세요';
    }

    if (mediaUrl.isEmpty) {
      return '최소 1개 이상의 미디어를 추가해주세요';
    }

    if (reward <= 0) {
      return '리워드는 0보다 커야 합니다';
    }

    if (reward > 100000) {
      return '리워드는 100,000 이하로 설정해주세요';
    }

    return null; // 유효성 검사 통과
  }

  /// 미디어 파일 크기 검증 (bytes)
  static bool validateMediaSize(int fileSize, String mediaType) {
    const maxImageSize = 10 * 1024 * 1024; // 10MB
    const maxVideoSize = 100 * 1024 * 1024; // 100MB

    if (mediaType == 'image') {
      return fileSize <= maxImageSize;
    } else if (mediaType == 'video') {
      return fileSize <= maxVideoSize;
    }

    return true;
  }

  /// 타겟팅 유효성 검증
  static String? validateTargeting({
    required List<int> targetAge,
    required String targetGender,
  }) {
    if (targetAge.isEmpty) {
      return '최소 1개 이상의 연령대를 선택해주세요';
    }

    if (targetGender.isEmpty) {
      return '타겟 성별을 선택해주세요';
    }

    return null;
  }
}

