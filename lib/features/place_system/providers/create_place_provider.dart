import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';

/// 플레이스 생성 화면의 상태 및 로직 관리
class CreatePlaceProvider with ChangeNotifier {
  final PlaceService _placeService = PlaceService();
  final FirebaseService _firebaseService = FirebaseService();
  final String? currentUserId;

  CreatePlaceProvider({required this.currentUserId});

  // ==================== 상태 변수들 ====================
  
  // 기본 필드
  String? selectedCategory;
  String? selectedSubCategory;
  String? selectedSubSubCategory;
  Map<String, dynamic> operatingHours = {};
  List<String> regularHolidays = [];
  List<String> breakTimes = [];
  bool isOpen24Hours = false;
  List<String> selectedFacilities = [];
  List<String> selectedPaymentMethods = [];
  String? selectedParkingType;
  int? parkingCapacity;
  bool hasValetParking = false;
  bool enableCoupon = false;
  List<String> selectedAccessibility = [];
  String? selectedPriceRange;
  int? capacity;
  bool hasReservation = false;
  List<String> videoUrls = [];
  List<String> interiorImageUrls = [];
  List<String> exteriorImageUrls = [];
  bool isTemporarilyClosed = false;
  DateTime? reopeningDate;

  // 섹션 접기/펼치기 상태
  bool isOperatingInfoExpanded = false;
  bool isAdditionalInfoExpanded = false;

  // 로딩 상태
  bool isLoading = false;

  // 이미지 선택 상태
  final List<dynamic> selectedImages = [];
  final List<String> imageNames = [];
  int coverImageIndex = 0;

  // ==================== 카테고리 관리 ====================
  
  void setCategory(String? category) {
    selectedCategory = category;
    selectedSubCategory = null;
    selectedSubSubCategory = null;
    notifyListeners();
  }

  void setSubCategory(String? subCategory) {
    selectedSubCategory = subCategory;
    selectedSubSubCategory = null;
    notifyListeners();
  }

  void setSubSubCategory(String? subSubCategory) {
    selectedSubSubCategory = subSubCategory;
    notifyListeners();
  }

  // ==================== 토글 관리 ====================
  
  void toggleOpen24Hours(bool value) {
    isOpen24Hours = value;
    notifyListeners();
  }

  void toggleValetParking(bool value) {
    hasValetParking = value;
    notifyListeners();
  }

  void toggleCoupon(bool value) {
    enableCoupon = value;
    notifyListeners();
  }

  void toggleReservation(bool value) {
    hasReservation = value;
    notifyListeners();
  }

  void toggleTemporarilyClosed(bool value) {
    isTemporarilyClosed = value;
    if (!value) {
      reopeningDate = null;
    }
    notifyListeners();
  }

  void toggleOperatingInfoExpanded() {
    isOperatingInfoExpanded = !isOperatingInfoExpanded;
    notifyListeners();
  }

  void toggleAdditionalInfoExpanded() {
    isAdditionalInfoExpanded = !isAdditionalInfoExpanded;
    notifyListeners();
  }

  // ==================== 이미지 관리 ====================
  
  void addImage(dynamic image, String name) {
    if (selectedImages.length >= 5) return;
    
    selectedImages.add(image);
    imageNames.add(name);
    notifyListeners();
  }

  void removeImage(int index) {
    selectedImages.removeAt(index);
    imageNames.removeAt(index);
    
    // 대문 이미지 인덱스 조정
    if (coverImageIndex >= selectedImages.length) {
      coverImageIndex = selectedImages.length - 1;
    }
    if (coverImageIndex < 0) {
      coverImageIndex = 0;
    }
    notifyListeners();
  }

  void setCoverImage(int index) {
    coverImageIndex = index;
    notifyListeners();
  }

  // ==================== 리스트 관리 ====================
  
  void toggleFacility(String facility) {
    if (selectedFacilities.contains(facility)) {
      selectedFacilities.remove(facility);
    } else {
      selectedFacilities.add(facility);
    }
    notifyListeners();
  }

  void togglePaymentMethod(String method) {
    if (selectedPaymentMethods.contains(method)) {
      selectedPaymentMethods.remove(method);
    } else {
      selectedPaymentMethods.add(method);
    }
    notifyListeners();
  }

  void toggleAccessibility(String option) {
    if (selectedAccessibility.contains(option)) {
      selectedAccessibility.remove(option);
    } else {
      selectedAccessibility.add(option);
    }
    notifyListeners();
  }

  void setRegularHolidays(List<String> holidays) {
    regularHolidays = holidays;
    notifyListeners();
  }

  void setBreakTimes(List<String> times) {
    breakTimes = times;
    notifyListeners();
  }

  void setVideoUrls(List<String> urls) {
    videoUrls = urls;
    notifyListeners();
  }

  // ==================== 플레이스 생성 ====================
  
  Future<bool> createPlace({
    required String name,
    required String description,
    required String address,
    required String detailAddress,
    required GeoPoint location,
    String? phone,
    String? email,
    String? couponPassword,
    String? mobile,
    String? fax,
    String? website,
    String? parkingFee,
    String? floor,
    String? buildingName,
    String? landmark,
    String? areaSize,
    String? reservationUrl,
    String? reservationPhone,
    String? virtualTourUrl,
    String? closureReason,
  }) async {
    if (currentUserId == null) return false;

    isLoading = true;
    notifyListeners();

    try {
      // 이미지 업로드
      final List<String> imageUrls = [];
      final List<String> thumbnailUrls = [];

      for (final img in selectedImages) {
        Map<String, String> uploadResult;

        if (img is String && img.startsWith('data:image/')) {
          // 웹: base64 데이터
          final safeName = 'place_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(
            img,
            'places/$currentUserId',
            safeName,
          );
        } else {
          // 모바일: 파일 경로
          uploadResult = await _firebaseService.uploadImageWithThumbnail(
            img,
            'places/$currentUserId',
          );
        }

        imageUrls.add(uploadResult['original']!);
        thumbnailUrls.add(uploadResult['thumbnail']!);
      }

      // PlaceModel 생성
      final place = PlaceModel(
        id: '', // Firestore가 생성
        name: name,
        description: description,
        category: selectedCategory ?? '',
        subCategory: selectedSubCategory,
        subSubCategory: selectedSubSubCategory,
        address: address,
        detailAddress: detailAddress.isNotEmpty ? detailAddress : null,
        location: location,
        contactInfo: {
          if (phone != null) 'phone': phone,
          if (email != null) 'email': email,
          if (mobile != null) 'mobile': mobile,
          if (fax != null) 'fax': fax,
        },
        operatingHours: operatingHours.isNotEmpty ? operatingHours : null,
        regularHolidays: regularHolidays.isNotEmpty ? regularHolidays : null,
        breakTimes: breakTimes.isNotEmpty ? {'breaks': breakTimes.join(', ')} : null,
        isOpen24Hours: isOpen24Hours,
        isCouponEnabled: enableCoupon,
        couponPassword: couponPassword,
        imageUrls: imageUrls,
        thumbnailUrls: thumbnailUrls,
        coverImageIndex: coverImageIndex,
        createdAt: DateTime.now(),
        createdBy: currentUserId!,
        mobile: mobile,
        fax: fax,
      );

      await _placeService.createPlace(place);
      
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ 플레이스 생성 실패: $e');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 초기화
  void reset() {
    selectedCategory = null;
    selectedSubCategory = null;
    selectedSubSubCategory = null;
    operatingHours = {};
    regularHolidays = [];
    breakTimes = [];
    isOpen24Hours = false;
    selectedFacilities = [];
    selectedPaymentMethods = [];
    selectedParkingType = null;
    parkingCapacity = null;
    hasValetParking = false;
    enableCoupon = false;
    selectedAccessibility = [];
    selectedPriceRange = null;
    capacity = null;
    hasReservation = false;
    videoUrls = [];
    interiorImageUrls = [];
    exteriorImageUrls = [];
    isTemporarilyClosed = false;
    reopeningDate = null;
    isOperatingInfoExpanded = false;
    isAdditionalInfoExpanded = false;
    selectedImages.clear();
    imageNames.clear();
    coverImageIndex = 0;
    notifyListeners();
  }
}

