import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/storage/storage_service.dart';

/// 플레이스 편집 화면의 헬퍼 함수들
class EditPlaceHelpers {
  // 플레이스 정보 로드
  static Future<PlaceModel?> loadPlace(String placeId) async {
    try {
      final placeService = PlaceService();
      return await placeService.getPlaceById(placeId);
    } catch (e) {
      debugPrint('플레이스 정보 로드 실패: $e');
      return null;
    }
  }

  // 플레이스 정보 업데이트
  static Future<bool> updatePlace(String placeId, Map<String, dynamic> placeData) async {
    try {
      // TODO: PlaceService.updatePlace는 PlaceModel을 받으므로 
      // edit_place_screen에서 직접 처리하도록 변경됨
      // 이 함수는 더 이상 사용되지 않음
      return false;
    } catch (e) {
      debugPrint('플레이스 정보 업데이트 실패: $e');
      return false;
    }
  }

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

  // 이미지 업로드
  static Future<List<String>> uploadImages(List<File> images) async {
    try {
      final storageService = StorageService();
      final urls = <String>[];
      
      // TODO: uploadImageWithThumbnail 메소드 구현 필요
      // for (final image in images) {
      //   final url = await storageService.uploadImageWithThumbnail(image);
      //   if (url != null) {
      //     urls.add(url);
      //   }
      // }
      
      return urls;
    } catch (e) {
      debugPrint('이미지 업로드 실패: $e');
      return [];
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

  // 폼 유효성 검사
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '플레이스명을 입력해주세요';
    }
    if (value.trim().length < 2) {
      return '플레이스명은 2자 이상 입력해주세요';
    }
    if (value.trim().length > 100) {
      return '플레이스명은 100자 이하로 입력해주세요';
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

  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '주소를 입력해주세요';
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

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이메일을 입력해주세요';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return '올바른 이메일 형식이 아닙니다';
    }
    
    return null;
  }

  static String? validateCouponPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '쿠폰 암호를 입력해주세요';
    }
    if (value.trim().length < 4) {
      return '쿠폰 암호는 4자 이상 입력해주세요';
    }
    return null;
  }

  static String? validateCategory(String? value) {
    if (value == null || value.isEmpty) {
      return '카테고리를 선택해주세요';
    }
    return null;
  }

  // 전체 폼 유효성 검사
  static Map<String, String?> validateForm({
    required String name,
    required String description,
    required String address,
    required String phone,
    required String email,
    required String? category,
    String? couponPassword,
  }) {
    return {
      'name': validateName(name),
      'description': validateDescription(description),
      'address': validateAddress(address),
      'phone': validatePhone(phone),
      'email': validateEmail(email),
      'category': validateCategory(category),
      'couponPassword': couponPassword != null ? validateCouponPassword(couponPassword) : null,
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

  // 주소 검색 다이얼로그 표시
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

  // 카테고리 선택 다이얼로그 표시
  static Future<String?> showCategoryDialog(BuildContext context) async {
    final categories = [
      '음식점', '카페', '쇼핑', '문화', '스포츠', '의료', '교육', '교통', '숙박', '기타'
    ];

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                title: Text(category),
                onTap: () => Navigator.pop(context, category),
              );
            },
          ),
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

  // 이미지 선택 다이얼로그 표시
  static Future<String?> showImageSourceDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 선택'),
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

  // 플레이스 정보 미리보기 데이터 생성
  static Map<String, dynamic> generatePlacePreviewData({
    required String name,
    required String description,
    required String address,
    required String detailAddress,
    required String phone,
    required String email,
    required String? category,
    required List<String> images,
    required bool enableCoupon,
    String? couponPassword,
  }) {
    return {
      'name': name,
      'description': description,
      'address': address,
      'detailAddress': detailAddress,
      'phone': phone,
      'email': email,
      'category': category ?? '미선택',
      'imageCount': images.length,
      'enableCoupon': enableCoupon,
      'couponPassword': couponPassword,
    };
  }

  // 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 시간 포맷팅
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 전화번호 포맷팅
  static String formatPhone(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 3)}-${phone.substring(3, 7)}-${phone.substring(7)}';
    }
    return phone;
  }

  // 카테고리 텍스트 생성
  static String generateCategoryText(String? category) {
    return category ?? '미선택';
  }

  // 쿠폰 상태 텍스트 생성
  static String generateCouponStatusText(bool enableCoupon) {
    return enableCoupon ? '사용' : '미사용';
  }

  // 플레이스 상태 텍스트 생성
  static String generatePlaceStatusText(bool isActive) {
    return isActive ? '활성' : '비활성';
  }

  // 플레이스 상태 색상 생성
  static Color generatePlaceStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.red;
  }

  // 플레이스 정보 요약 텍스트 생성
  static String generatePlaceSummaryText(Map<String, dynamic> placeData) {
    final name = placeData['name'] ?? '';
    final category = placeData['category'] ?? '미선택';
    final address = placeData['address'] ?? '';
    final phone = placeData['phone'] ?? '';
    
    return '$name ($category)\n$address\n$phone';
  }

  // 플레이스 정보 상세 텍스트 생성
  static String generatePlaceDetailText(Map<String, dynamic> placeData) {
    final name = placeData['name'] ?? '';
    final description = placeData['description'] ?? '';
    final category = placeData['category'] ?? '미선택';
    final address = placeData['address'] ?? '';
    final detailAddress = placeData['detailAddress'] ?? '';
    final phone = placeData['phone'] ?? '';
    final email = placeData['email'] ?? '';
    final enableCoupon = placeData['enableCoupon'] ?? false;
    
    return '''
플레이스명: $name
설명: $description
카테고리: $category
주소: $address
상세주소: $detailAddress
전화번호: $phone
이메일: $email
쿠폰 사용: ${enableCoupon ? '사용' : '미사용'}
''';
  }
}

