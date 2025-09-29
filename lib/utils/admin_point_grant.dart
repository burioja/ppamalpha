import '../core/services/data/points_service.dart';

/// 관리자용 포인트 지급 유틸리티
class AdminPointGrant {
  static final PointsService _pointsService = PointsService();

  /// guest11@gmail.com에게 100,000 포인트 지급
  static Future<void> grantPointsToGuest11() async {
    try {
      print('🚀 guest11@gmail.com에게 포인트 지급 시작...');

      await _pointsService.grantPointsToUser('guest11@gmail.com', 100000);

      print('✅ guest11@gmail.com 포인트 지급 완료!');

    } catch (e) {
      print('❌ 포인트 지급 실패: $e');
    }
  }

  /// 특정 사용자에게 포인트 지급
  static Future<void> grantPointsToUser(String email, int points) async {
    try {
      print('🚀 $email에게 $points 포인트 지급 시작...');

      await _pointsService.grantPointsToUser(email, points);

      print('✅ $email 포인트 지급 완료!');

    } catch (e) {
      print('❌ 포인트 지급 실패: $e');
    }
  }
}