import 'package:flutter/foundation.dart';
import '../data/points_service.dart';

/// 관리자 유틸리티 서비스
class AdminService {
  final PointsService _pointsService = PointsService();

  /// 모든 사용자에게 100만 포인트 임시 지급
  ///
  /// 이 메서드는 지갑 시스템이 완성되기 전까지 임시로 사용됩니다.
  /// 모든 기존 사용자와 신규 사용자에게 100만 포인트를 보장합니다.
  Future<void> grantMillionPointsToAllUsers() async {
    try {
      debugPrint('🚀 AdminService: 모든 사용자 100만 포인트 지급 시작');

      // 기존 사용자들에게 100만 포인트 보장
      await _pointsService.grantMillionPointsToAllUsers();

      debugPrint('✅ AdminService: 포인트 지급 완료');

    } catch (e) {
      debugPrint('❌ AdminService: 포인트 지급 실패: $e');
      rethrow;
    }
  }

  /// 특정 사용자의 포인트를 100만으로 보장
  Future<void> ensureUserHasMillionPoints(String userId) async {
    try {
      await _pointsService.ensureMinimumPoints(userId);
    } catch (e) {
      debugPrint('❌ AdminService: 사용자 포인트 보장 실패: $e');
    }
  }

  /// 임시 포인트 시스템 초기화 (앱 시작 시 호출)
  Future<void> initializeTemporaryPointsSystem() async {
    try {
      debugPrint('⚙️ AdminService: 임시 포인트 시스템 초기화 시작');

      // 모든 기존 사용자에게 100만 포인트 보장
      await grantMillionPointsToAllUsers();

      debugPrint('✅ AdminService: 임시 포인트 시스템 초기화 완료');
      debugPrint('📝 신규 가입 사용자는 자동으로 100만 포인트를 받습니다.');

    } catch (e) {
      debugPrint('❌ AdminService: 임시 포인트 시스템 초기화 실패: $e');
      // 실패해도 앱 실행은 계속 진행
    }
  }
}