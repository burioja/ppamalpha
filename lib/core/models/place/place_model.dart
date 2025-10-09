import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name;
  final String description;
  final String? address;
  final String? detailAddress; // 상세주소 필드 추가
  final GeoPoint? location;
  final String? category;
  final String? subCategory;
  final String? subSubCategory;
  final List<String> imageUrls;
  final List<String> thumbnailUrls; // 썸네일 URL 목록
  final int coverImageIndex; // 대문 이미지 인덱스 (기본값 0)
  final Map<String, dynamic>? operatingHours;
  final Map<String, dynamic>? contactInfo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Map<String, dynamic>? originalData;

  // 쿠폰 시스템
  final String? couponPassword; // 플레이스 주인이 설정한 쿠폰 사용 암호
  final bool isCouponEnabled; // 쿠폰 사용 활성화 여부

  // 인증 시스템
  final bool isVerified; // 사업자등록 인증 여부
  final String? businessRegistrationNumber; // 사업자등록번호 (추후 확장용)

  // === Phase 1: 필수 정보 ===

  // 운영시간 상세
  final List<String>? regularHolidays; // 정기 휴무일 ["월요일", "화요일"]
  final bool isOpen24Hours; // 24시간 운영 여부
  final Map<String, String>? breakTimes; // 브레이크타임 {"평일": "15:00-17:00"}

  // 연락처 확장
  final String? mobile; // 휴대전화
  final String? fax; // 팩스
  final Map<String, String>? socialMedia; // 소셜미디어 {"instagram": "@handle", "facebook": "url"}

  // 주차 정보
  final String? parkingType; // "self", "valet", "none", "nearby"
  final int? parkingCapacity; // 주차 가능 대수
  final String? parkingFee; // "무료", "시간당 3000원"
  final bool hasValetParking; // 발레파킹 제공 여부

  // 편의시설
  final List<String> facilities; // ["wifi", "wheelchair", "kids_zone", "pet_friendly", "smoking_area"]

  // 결제 수단
  final List<String> paymentMethods; // ["card", "cash", "mobile_pay", "cryptocurrency"]

  // === Phase 2: 부가 정보 ===

  // 접근성
  final List<String>? accessibility; // ["wheelchair_ramp", "elevator", "braille", "accessible_restroom"]

  // 가격대
  final String? priceRange; // "저렴", "보통", "비쌈", "매우비쌈" 또는 "₩", "₩₩", "₩₩₩", "₩₩₩₩"

  // 용량/규모
  final int? capacity; // 최대 수용 인원
  final String? areaSize; // "150평", "500㎡"

  // 상세 위치
  final String? floor; // "3층", "지하 1층"
  final String? buildingName; // 건물명
  final String? landmark; // "스타벅스 옆", "CGV 건너편"

  // 대중교통
  final List<String>? nearbyTransit; // ["지하철 2호선 강남역 3번출구 200m", "버스 146번 정류장 앞"]

  // === Phase 3: 고급 기능 ===

  // 인증/자격
  final List<String>? certifications; // ["식품위생우수업소", "장애인편의시설 우수업소"]
  final List<String>? awards; // ["미슐랭 1스타", "청년상인 대상"]

  // 예약 시스템
  final bool hasReservation; // 예약 가능 여부
  final String? reservationUrl; // 예약 URL
  final String? reservationPhone; // 예약 전용 번호

  // 추가 미디어
  final List<String>? videoUrls; // 동영상 URL 목록
  final String? virtualTourUrl; // 360도 가상투어 URL
  final List<String>? interiorImageUrls; // 인테리어 사진
  final List<String>? exteriorImageUrls; // 외관 사진

  // 상태 관리
  final bool isTemporarilyClosed; // 임시 휴업
  final DateTime? reopeningDate; // 재개업 예정일
  final String? closureReason; // 휴업 사유

  PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    this.address,
    this.detailAddress,
    this.location,
    this.category,
    this.subCategory,
    this.subSubCategory,
    this.imageUrls = const [],
    this.thumbnailUrls = const [],
    this.coverImageIndex = 0,
    this.operatingHours,
    this.contactInfo,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.originalData,
    this.couponPassword,
    this.isCouponEnabled = false,
    this.isVerified = false,
    this.businessRegistrationNumber,
    // Phase 1 필드
    this.regularHolidays,
    this.isOpen24Hours = false,
    this.breakTimes,
    this.mobile,
    this.fax,
    this.socialMedia,
    this.parkingType,
    this.parkingCapacity,
    this.parkingFee,
    this.hasValetParking = false,
    this.facilities = const [],
    this.paymentMethods = const [],
    // Phase 2 필드
    this.accessibility,
    this.priceRange,
    this.capacity,
    this.areaSize,
    this.floor,
    this.buildingName,
    this.landmark,
    this.nearbyTransit,
    // Phase 3 필드
    this.certifications,
    this.awards,
    this.hasReservation = false,
    this.reservationUrl,
    this.reservationPhone,
    this.videoUrls,
    this.virtualTourUrl,
    this.interiorImageUrls,
    this.exteriorImageUrls,
    this.isTemporarilyClosed = false,
    this.reopeningDate,
    this.closureReason,
  });

  factory PlaceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return PlaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      address: data['address'],
      detailAddress: data['detailAddress'],
      location: data['location'],
      category: data['category'],
      subCategory: data['subCategory'],
      subSubCategory: data['subSubCategory'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      thumbnailUrls: List<String>.from(data['thumbnailUrls'] ?? []),
      coverImageIndex: data['coverImageIndex'] ?? 0,
      operatingHours: data['operatingHours'],
      contactInfo: data['contactInfo'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      isActive: data['isActive'] ?? true,
      originalData: data['originalData'],
      couponPassword: data['couponPassword'],
      isCouponEnabled: data['isCouponEnabled'] ?? false,
      isVerified: data['isVerified'] ?? false,
      businessRegistrationNumber: data['businessRegistrationNumber'],
      // Phase 1 필드
      regularHolidays: data['regularHolidays'] != null ? List<String>.from(data['regularHolidays']) : null,
      isOpen24Hours: data['isOpen24Hours'] ?? false,
      breakTimes: data['breakTimes'] != null ? Map<String, String>.from(data['breakTimes']) : null,
      mobile: data['mobile'],
      fax: data['fax'],
      socialMedia: data['socialMedia'] != null ? Map<String, String>.from(data['socialMedia']) : null,
      parkingType: data['parkingType'],
      parkingCapacity: data['parkingCapacity'],
      parkingFee: data['parkingFee'],
      hasValetParking: data['hasValetParking'] ?? false,
      facilities: List<String>.from(data['facilities'] ?? []),
      paymentMethods: List<String>.from(data['paymentMethods'] ?? []),
      // Phase 2 필드
      accessibility: data['accessibility'] != null ? List<String>.from(data['accessibility']) : null,
      priceRange: data['priceRange'],
      capacity: data['capacity'],
      areaSize: data['areaSize'],
      floor: data['floor'],
      buildingName: data['buildingName'],
      landmark: data['landmark'],
      nearbyTransit: data['nearbyTransit'] != null ? List<String>.from(data['nearbyTransit']) : null,
      // Phase 3 필드
      certifications: data['certifications'] != null ? List<String>.from(data['certifications']) : null,
      awards: data['awards'] != null ? List<String>.from(data['awards']) : null,
      hasReservation: data['hasReservation'] ?? false,
      reservationUrl: data['reservationUrl'],
      reservationPhone: data['reservationPhone'],
      videoUrls: data['videoUrls'] != null ? List<String>.from(data['videoUrls']) : null,
      virtualTourUrl: data['virtualTourUrl'],
      interiorImageUrls: data['interiorImageUrls'] != null ? List<String>.from(data['interiorImageUrls']) : null,
      exteriorImageUrls: data['exteriorImageUrls'] != null ? List<String>.from(data['exteriorImageUrls']) : null,
      isTemporarilyClosed: data['isTemporarilyClosed'] ?? false,
      reopeningDate: data['reopeningDate']?.toDate(),
      closureReason: data['closureReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'detailAddress': detailAddress,
      'location': location,
      'category': category,
      'subCategory': subCategory,
      'subSubCategory': subSubCategory,
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'coverImageIndex': coverImageIndex,
      'operatingHours': operatingHours,
      'contactInfo': contactInfo,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'originalData': originalData,
      'couponPassword': couponPassword,
      'isCouponEnabled': isCouponEnabled,
      'isVerified': isVerified,
      'businessRegistrationNumber': businessRegistrationNumber,
      // Phase 1 필드
      'regularHolidays': regularHolidays,
      'isOpen24Hours': isOpen24Hours,
      'breakTimes': breakTimes,
      'mobile': mobile,
      'fax': fax,
      'socialMedia': socialMedia,
      'parkingType': parkingType,
      'parkingCapacity': parkingCapacity,
      'parkingFee': parkingFee,
      'hasValetParking': hasValetParking,
      'facilities': facilities,
      'paymentMethods': paymentMethods,
      // Phase 2 필드
      'accessibility': accessibility,
      'priceRange': priceRange,
      'capacity': capacity,
      'areaSize': areaSize,
      'floor': floor,
      'buildingName': buildingName,
      'landmark': landmark,
      'nearbyTransit': nearbyTransit,
      // Phase 3 필드
      'certifications': certifications,
      'awards': awards,
      'hasReservation': hasReservation,
      'reservationUrl': reservationUrl,
      'reservationPhone': reservationPhone,
      'videoUrls': videoUrls,
      'virtualTourUrl': virtualTourUrl,
      'interiorImageUrls': interiorImageUrls,
      'exteriorImageUrls': exteriorImageUrls,
      'isTemporarilyClosed': isTemporarilyClosed,
      'reopeningDate': reopeningDate != null ? Timestamp.fromDate(reopeningDate!) : null,
      'closureReason': closureReason,
    };
  }

  PlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    String? detailAddress,
    GeoPoint? location,
    String? category,
    String? subCategory,
    String? subSubCategory,
    List<String>? imageUrls,
    List<String>? thumbnailUrls,
    int? coverImageIndex,
    Map<String, dynamic>? operatingHours,
    Map<String, dynamic>? contactInfo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? originalData,
    String? couponPassword,
    bool? isCouponEnabled,
    bool? isVerified,
    String? businessRegistrationNumber,
    // Phase 1 필드
    List<String>? regularHolidays,
    bool? isOpen24Hours,
    Map<String, String>? breakTimes,
    String? mobile,
    String? fax,
    Map<String, String>? socialMedia,
    String? parkingType,
    int? parkingCapacity,
    String? parkingFee,
    bool? hasValetParking,
    List<String>? facilities,
    List<String>? paymentMethods,
    // Phase 2 필드
    List<String>? accessibility,
    String? priceRange,
    int? capacity,
    String? areaSize,
    String? floor,
    String? buildingName,
    String? landmark,
    List<String>? nearbyTransit,
    // Phase 3 필드
    List<String>? certifications,
    List<String>? awards,
    bool? hasReservation,
    String? reservationUrl,
    String? reservationPhone,
    List<String>? videoUrls,
    String? virtualTourUrl,
    List<String>? interiorImageUrls,
    List<String>? exteriorImageUrls,
    bool? isTemporarilyClosed,
    DateTime? reopeningDate,
    String? closureReason,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      detailAddress: detailAddress ?? this.detailAddress,
      location: location ?? this.location,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      subSubCategory: subSubCategory ?? this.subSubCategory,
      imageUrls: imageUrls ?? this.imageUrls,
      thumbnailUrls: thumbnailUrls ?? this.thumbnailUrls,
      coverImageIndex: coverImageIndex ?? this.coverImageIndex,
      operatingHours: operatingHours ?? this.operatingHours,
      contactInfo: contactInfo ?? this.contactInfo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      originalData: originalData ?? this.originalData,
      couponPassword: couponPassword ?? this.couponPassword,
      isCouponEnabled: isCouponEnabled ?? this.isCouponEnabled,
      isVerified: isVerified ?? this.isVerified,
      businessRegistrationNumber: businessRegistrationNumber ?? this.businessRegistrationNumber,
      // Phase 1 필드
      regularHolidays: regularHolidays ?? this.regularHolidays,
      isOpen24Hours: isOpen24Hours ?? this.isOpen24Hours,
      breakTimes: breakTimes ?? this.breakTimes,
      mobile: mobile ?? this.mobile,
      fax: fax ?? this.fax,
      socialMedia: socialMedia ?? this.socialMedia,
      parkingType: parkingType ?? this.parkingType,
      parkingCapacity: parkingCapacity ?? this.parkingCapacity,
      parkingFee: parkingFee ?? this.parkingFee,
      hasValetParking: hasValetParking ?? this.hasValetParking,
      facilities: facilities ?? this.facilities,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      // Phase 2 필드
      accessibility: accessibility ?? this.accessibility,
      priceRange: priceRange ?? this.priceRange,
      capacity: capacity ?? this.capacity,
      areaSize: areaSize ?? this.areaSize,
      floor: floor ?? this.floor,
      buildingName: buildingName ?? this.buildingName,
      landmark: landmark ?? this.landmark,
      nearbyTransit: nearbyTransit ?? this.nearbyTransit,
      // Phase 3 필드
      certifications: certifications ?? this.certifications,
      awards: awards ?? this.awards,
      hasReservation: hasReservation ?? this.hasReservation,
      reservationUrl: reservationUrl ?? this.reservationUrl,
      reservationPhone: reservationPhone ?? this.reservationPhone,
      videoUrls: videoUrls ?? this.videoUrls,
      virtualTourUrl: virtualTourUrl ?? this.virtualTourUrl,
      interiorImageUrls: interiorImageUrls ?? this.interiorImageUrls,
      exteriorImageUrls: exteriorImageUrls ?? this.exteriorImageUrls,
      isTemporarilyClosed: isTemporarilyClosed ?? this.isTemporarilyClosed,
      reopeningDate: reopeningDate ?? this.reopeningDate,
      closureReason: closureReason ?? this.closureReason,
    );
  }

  // 카테고리 전체 경로 반환
  String get fullCategoryPath {
    List<String> categories = [];
    if (category != null) categories.add(category!);
    if (subCategory != null) categories.add(subCategory!);
    if (subSubCategory != null) categories.add(subSubCategory!);
    return categories.join(' - ');
  }

  // 위치 정보가 있는지 확인
  bool get hasLocation => location != null;

  // 이미지가 있는지 확인
  bool get hasImages => imageUrls.isNotEmpty;

  // 운영 시간이 설정되어 있는지 확인
  bool get hasOperatingHours => operatingHours != null && operatingHours!.isNotEmpty;

  // 연락처 정보가 있는지 확인
  bool get hasContactInfo => contactInfo != null && contactInfo!.isNotEmpty;

  // 추가 getter들
  String? get formattedAddress {
    if (address == null) return null;
    if (detailAddress != null && detailAddress!.isNotEmpty) {
      return '$address $detailAddress';
    }
    return address;
  }
  String? get phoneNumber => contactInfo?['phone'];
  String? get website => contactInfo?['website'];
}











