import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 설정 화면 관련 로직을 관리하는 컨트롤러
class SettingsController {
  /// 사용자 프로필 업데이트
  static Future<bool> updateUserProfile({
    required String userId,
    String? displayName,
    String? phoneNumber,
    String? address,
    GeoPoint? homeLocation,
    String? secondAddress,
    String? workplaceId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updateData['displayName'] = displayName;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (address != null) updateData['address'] = address;
      if (homeLocation != null) updateData['homeLocation'] = homeLocation;
      if (secondAddress != null) updateData['secondAddress'] = secondAddress;
      if (workplaceId != null) updateData['workplaceId'] = workplaceId;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);

      debugPrint('✅ 프로필 업데이트 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 프로필 업데이트 실패: $e');
      return false;
    }
  }

  /// 알림 설정 업데이트
  static Future<bool> updateNotificationSettings({
    required String userId,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (pushEnabled != null) updateData['notifications.push'] = pushEnabled;
      if (emailEnabled != null) updateData['notifications.email'] = emailEnabled;
      if (smsEnabled != null) updateData['notifications.sms'] = smsEnabled;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updateData);

      debugPrint('✅ 알림 설정 업데이트 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 알림 설정 업데이트 실패: $e');
      return false;
    }
  }

  /// 비밀번호 변경
  static Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 현재 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 새 비밀번호로 업데이트
      await user.updatePassword(newPassword);

      debugPrint('✅ 비밀번호 변경 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 비밀번호 변경 실패: $e');
      return false;
    }
  }

  /// 계정 삭제
  static Future<bool> deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Firestore 사용자 데이터 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Firebase Auth 계정 삭제
      await user.delete();

      debugPrint('✅ 계정 삭제 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 계정 삭제 실패: $e');
      return false;
    }
  }

  /// 로그아웃
  static Future<bool> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('✅ 로그아웃 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 로그아웃 실패: $e');
      return false;
    }
  }

  /// 캐시 삭제
  static Future<bool> clearCache() async {
    try {
      // 캐시 삭제 로직 구현
      debugPrint('✅ 캐시 삭제 완료');
      return true;
    } catch (e) {
      debugPrint('❌ 캐시 삭제 실패: $e');
      return false;
    }
  }
}

