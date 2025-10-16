import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/user_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../utils/admin_point_grant.dart';

/// 설정 화면의 헬퍼 함수들
class SettingsHelpers {
  // 사용자 정보 로드
  static Future<Map<String, dynamic>?> loadUserInfo() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final userService = UserService();
      // TODO: getUserInfo 메소드 구현 필요
      // return await userService.getUserInfo(currentUser.uid);
      return {}; // 임시로 빈 맵 반환
    } catch (e) {
      debugPrint('사용자 정보 로드 실패: $e');
      return null;
    }
  }

  // 사용자 정보 업데이트
  static Future<bool> updateUserInfo(Map<String, dynamic> userData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final userService = UserService();
      // TODO: updateUserInfo 메소드 구현 필요
      // return await userService.updateUserInfo(currentUser.uid, userData);
      return true; // 임시로 true 반환
    } catch (e) {
      debugPrint('사용자 정보 업데이트 실패: $e');
      return false;
    }
  }

  // 프로필 이미지 업로드
  static Future<String?> uploadProfileImage(String imagePath) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      final userService = UserService();
      // TODO: uploadProfileImage 메소드 구현 필요
      // return await userService.uploadProfileImage(currentUser.uid, imagePath);
      return ''; // 임시로 빈 문자열 반환
    } catch (e) {
      debugPrint('프로필 이미지 업로드 실패: $e');
      return null;
    }
  }

  // 사용자 플레이스 목록 조회
  static Future<List<PlaceModel>> getUserPlaces() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final placeService = PlaceService();
      // TODO: getUserPlaces 메소드 구현 필요
      // return await placeService.getUserPlaces(currentUser.uid);
      return []; // 임시로 빈 리스트 반환
    } catch (e) {
      debugPrint('사용자 플레이스 조회 실패: $e');
      return [];
    }
  }

  // 플레이스 삭제
  static Future<bool> deletePlace(String placeId) async {
    try {
      final placeService = PlaceService();
      await placeService.deletePlace(placeId);
      return true;
    } catch (e) {
      debugPrint('플레이스 삭제 실패: $e');
      return false;
    }
  }

  // 주소 검색
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      final nominatimService = NominatimService();
      // TODO: searchAddress 메소드 구현 필요
      // return await nominatimService.searchAddress(query);
      return []; // 임시로 빈 리스트 반환
    } catch (e) {
      debugPrint('주소 검색 실패: $e');
      return [];
    }
  }

  // 관리자 포인트 부여
  static Future<bool> grantAdminPoints(String userId, int amount) async {
    try {
      return await grantAdminPoints(userId, amount);
    } catch (e) {
      debugPrint('관리자 포인트 부여 실패: $e');
      return false;
    }
  }

  // 폼 유효성 검사
  static String? validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '닉네임을 입력해주세요';
    }
    if (value.trim().length < 2) {
      return '닉네임은 2자 이상 입력해주세요';
    }
    if (value.trim().length > 20) {
      return '닉네임은 20자 이하로 입력해주세요';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '전화번호를 입력해주세요';
    }
    
    final phoneRegex = RegExp(r'^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return '올바른 전화번호 형식이 아닙니다';
    }
    
    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '주소를 입력해주세요';
    }
    return null;
  }

  static String? validateAccount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '계좌번호를 입력해주세요';
    }
    
    final accountRegex = RegExp(r'^\d{3}-\d{6}-\d{6}$');
    if (!accountRegex.hasMatch(value.trim())) {
      return '올바른 계좌번호 형식이 아닙니다 (예: 123-456789-123456)';
    }
    
    return null;
  }

  static String? validateBirth(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '생년월일을 입력해주세요';
    }
    
    final birthRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!birthRegex.hasMatch(value.trim())) {
      return '올바른 생년월일 형식이 아닙니다 (예: 1990-01-01)';
    }
    
    return null;
  }

  static String? validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return '성별을 선택해주세요';
    }
    return null;
  }

  // 전체 폼 유효성 검사
  static Map<String, String?> validateForm({
    required String nickname,
    required String phone,
    required String address,
    required String account,
    required String birth,
    required String? gender,
  }) {
    return {
      'nickname': validateNickname(nickname),
      'phone': validatePhone(phone),
      'address': validateAddress(address),
      'account': validateAccount(account),
      'birth': validateBirth(birth),
      'gender': validateGender(gender),
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

  // 플레이스 삭제 확인 다이얼로그
  static Future<bool> showDeletePlaceDialog(
    BuildContext context,
    String placeName,
  ) async {
    return await showConfirmDialog(
      context,
      '플레이스 삭제',
      '$placeName을(를) 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
    );
  }

  // 프로필 이미지 선택 다이얼로그
  static Future<String?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('프로필 이미지 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 주소 검색 다이얼로그
  static Future<Map<String, dynamic>?> showAddressSearchDialog(
    BuildContext context,
  ) async {
    final controller = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isLoading = false;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('주소 검색'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: '주소를 검색하세요',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        
                        setState(() {
                          isLoading = true;
                        });
                        
                        try {
                          final results = await searchAddress(controller.text.trim());
                          setState(() {
                            searchResults = results;
                            isLoading = false;
                          });
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                          });
                          showErrorSnackBar(context, '주소 검색 실패: $e');
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final result = searchResults[index];
                            return ListTile(
                              title: Text(result['display_name'] ?? ''),
                              subtitle: Text(result['address'] ?? ''),
                              onTap: () => Navigator.pop(context, result),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }

  // 성별 선택 다이얼로그
  static Future<String?> showGenderDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성별 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('남성'),
              onTap: () => Navigator.pop(context, 'male'),
            ),
            ListTile(
              title: const Text('여성'),
              onTap: () => Navigator.pop(context, 'female'),
            ),
            ListTile(
              title: const Text('기타'),
              onTap: () => Navigator.pop(context, 'other'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 관리자 포인트 부여 다이얼로그
  static Future<void> showAdminPointDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('관리자 포인트 부여'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '포인트 금액',
                hintText: '부여할 포인트를 입력하세요',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text);
              if (amount == null || amount <= 0) {
                showErrorSnackBar(context, '올바른 포인트 금액을 입력해주세요');
                return;
              }
              
              Navigator.pop(context);
              
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                showErrorSnackBar(context, '로그인이 필요합니다');
                return;
              }
              
              showLoadingDialog(context);
              
              try {
                final success = await grantAdminPoints(currentUser.uid, amount);
                hideLoadingDialog(context);
                
                if (success) {
                  showSuccessSnackBar(context, '${amount}포인트가 부여되었습니다');
                } else {
                  showErrorSnackBar(context, '포인트 부여에 실패했습니다');
                }
              } catch (e) {
                hideLoadingDialog(context);
                showErrorSnackBar(context, '포인트 부여 실패: $e');
              }
            },
            child: const Text('부여'),
          ),
        ],
      ),
    );
  }

  // 로그아웃 확인 다이얼로그
  static Future<bool> showLogoutDialog(BuildContext context) async {
    return await showConfirmDialog(
      context,
      '로그아웃',
      '정말 로그아웃하시겠습니까?',
    );
  }

  // 계정 삭제 확인 다이얼로그
  static Future<bool> showDeleteAccountDialog(BuildContext context) async {
    return await showConfirmDialog(
      context,
      '계정 삭제',
      '정말 계정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
    );
  }

  // 성별 텍스트 생성
  static String generateGenderText(String? gender) {
    switch (gender) {
      case 'male':
        return '남성';
      case 'female':
        return '여성';
      case 'other':
        return '기타';
      default:
        return '선택 안함';
    }
  }

  // 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 전화번호 포맷팅
  static String formatPhone(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    }
    return phone;
  }

  // 계좌번호 포맷팅
  static String formatAccount(String account) {
    if (account.length == 14) {
      return '${account.substring(0, 3)}-${account.substring(3, 9)}-${account.substring(9)}';
    }
    return account;
  }

  // 사용자 정보 미리보기 데이터 생성
  static Map<String, dynamic> generateUserPreviewData({
    required String nickname,
    required String phone,
    required String address,
    required String secondAddress,
    required String account,
    required String birth,
    required String? gender,
    required String? profileImageUrl,
  }) {
    return {
      'nickname': nickname,
      'phone': formatPhone(phone),
      'address': address,
      'secondAddress': secondAddress,
      'account': formatAccount(account),
      'birth': birth,
      'gender': generateGenderText(gender),
      'profileImageUrl': profileImageUrl,
    };
  }
}

