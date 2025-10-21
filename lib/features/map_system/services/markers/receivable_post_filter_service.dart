import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/marker/marker_model.dart';
import '../../../../core/models/user/user_model.dart';

/// 수령 가능 포스트 필터링 서비스
/// 
/// **책임**: 
/// - 타겟팅 조건 검증 (나이, 성별)
/// - 필터 조건 적용 (쿠폰, 스탬프, 마감임박, 인증)
/// - 수령 가능 개수 계산
class ReceivablePostFilterService {
  /// 수령 가능한 마커 필터링
  /// 
  /// [markers]: 전체 마커 목록
  /// [filters]: 필터 조건 (showCouponsOnly, showMyPostsOnly 등)
  /// 
  /// Returns: 수령 가능한 마커 목록
  static Future<List<MarkerModel>> filterReceivableMarkers({
    required List<MarkerModel> markers,
    required Map<String, dynamic> filters,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    // 사용자 정보 조회
    final userModel = await _getUserModel(user.uid);
    if (userModel == null) return [];
    
    final receivable = <MarkerModel>[];
    
    for (final marker in markers) {
      // 1. 본인 포스트 제외
      if (marker.creatorId == user.uid) continue;
      
      // 2. 수량 확인
      if (marker.remainingQuantity <= 0 || !marker.isActive) continue;
      
      // 3. 타겟팅 조건 검증 (서버사이드 로직)
      if (!await _matchesTargeting(marker, userModel)) continue;
      
      // 4. 필터 조건 적용 (클라이언트사이드)
      if (!_matchesFilters(marker, filters)) continue;
      
      receivable.add(marker);
    }
    
    return receivable;
  }
  
  /// 타겟팅 조건 검증 (나이, 성별)
  static Future<bool> _matchesTargeting(
    MarkerModel marker,
    UserModel user,
  ) async {
    try {
      // 마커의 postId로 포스트 정보 조회
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(marker.postId)
          .get();
      
      if (!postDoc.exists) return false;
      
      final postData = postDoc.data()!;
      
      // 나이 타겟팅
      final targetAge = List<int>.from(postData['targetAge'] ?? []);
      if (targetAge.isNotEmpty && targetAge.length >= 2) {
        final userAge = _calculateAge(user.birth);
        if (userAge == null || userAge < targetAge[0] || userAge > targetAge[1]) {
          return false;
        }
      }
      
      // 성별 타겟팅
      final targetGender = postData['targetGender'] as String? ?? 'all';
      // 'all' 또는 'both'이면 모두 허용
      if (targetGender != 'all' && targetGender != 'both') {
        final userGender = user.gender ?? '';
        if (targetGender != userGender) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 필터 조건 검증
  static bool _matchesFilters(
    MarkerModel marker,
    Map<String, dynamic> filters,
  ) {
    // 쿠폰 필터
    if (filters['showCouponsOnly'] == true) {
      // TODO: marker에 isCoupon 필드 확인 (현재는 post에서 확인 필요)
      // 일단 통과
    }
    
    // 스탬프 필터 (현재 미구현)
    if (filters['showStampsOnly'] == true) {
      // TODO: 스탬프 로직 확인
    }
    
    // 마감임박 필터 (24시간 이내)
    if (filters['showUrgentOnly'] == true) {
      final expiresAt = marker.expiresAt;
      if (expiresAt != null) {
        final hoursLeft = expiresAt.difference(DateTime.now()).inHours;
        if (hoursLeft > 24) return false;
      }
    }
    
    // 인증/미인증 필터
    if (filters['showVerifiedOnly'] == true) {
      // TODO: marker에 isVerified 필드 확인
    } else if (filters['showUnverifiedOnly'] == true) {
      // TODO: marker에 isVerified 필드 확인
    }
    
    return true;
  }
  
  /// 사용자 모델 조회
  static Future<UserModel?> _getUserModel(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }
  
  /// 생년월일에서 나이 계산
  static int? _calculateAge(String? birth) {
    if (birth == null || birth.isEmpty) return null;
    
    try {
      // birth 형식: "YYYY-MM-DD" 또는 "YYYYMMDD"
      DateTime birthDate;
      
      if (birth.contains('-')) {
        birthDate = DateTime.parse(birth);
      } else if (birth.length == 8) {
        // YYYYMMDD 형식
        final year = int.parse(birth.substring(0, 4));
        final month = int.parse(birth.substring(4, 6));
        final day = int.parse(birth.substring(6, 8));
        birthDate = DateTime(year, month, day);
      } else {
        return null;
      }
      
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      
      // 생일이 아직 안 지났으면 -1
      if (now.month < birthDate.month || 
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      
      return age;
    } catch (e) {
      return null;
    }
  }
}

