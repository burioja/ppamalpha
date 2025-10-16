import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/post/post_model.dart';

/// 포스트 생성 관련 헬퍼 클래스
class PostCreationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 포스트 템플릿 데이터 생성
  static Map<String, dynamic> createPostTemplate({
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
    bool isVerified = false,
  }) {
    final now = DateTime.now();
    final expiresAt = defaultExpiresAt ?? now.add(const Duration(days: 30));

    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'reward': reward,
      'targetAge': targetAge,
      'targetGender': targetGender,
      'targetInterest': targetInterest,
      'targetPurchaseHistory': targetPurchaseHistory,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl ?? mediaUrl,
      'title': title,
      'description': description,
      'canRespond': canRespond,
      'canForward': canForward,
      'canRequestReward': canRequestReward,
      'canUse': canUse,
      'createdAt': FieldValue.serverTimestamp(),
      'status': PostStatus.DRAFT.name,
      'defaultRadius': defaultRadius,
      'defaultExpiresAt': Timestamp.fromDate(expiresAt),
      'totalQuantity': 0,
      'placeId': placeId,
      'isCoupon': isCoupon,
      'youtubeUrl': youtubeUrl,
      'isVerified': isVerified,
    };
  }

  /// 사용자 인증 상태 확인
  static Future<bool> checkUserVerification(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['isVerified'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ 사용자 인증 확인 실패: $e');
      return false;
    }
  }

  /// 포스트 유효성 검증
  static bool validatePostData({
    required String title,
    required String description,
    required List<String> mediaUrl,
    required int reward,
  }) {
    if (title.trim().isEmpty) {
      debugPrint('❌ 제목이 비어있습니다');
      return false;
    }

    if (description.trim().isEmpty) {
      debugPrint('❌ 설명이 비어있습니다');
      return false;
    }

    if (mediaUrl.isEmpty) {
      debugPrint('❌ 미디어 URL이 비어있습니다');
      return false;
    }

    if (reward <= 0) {
      debugPrint('❌ 리워드가 0 이하입니다');
      return false;
    }

    return true;
  }

  /// 포스트 ID 생성
  static String generatePostId() {
    return _firestore.collection('posts').doc().id;
  }
}

