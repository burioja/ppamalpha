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
import '../../../screens/auth/address_search_screen.dart';
import 'edit_place_screen_fields.dart';

class EditPlaceScreen extends StatefulWidget {
  final PlaceModel place;

  const EditPlaceScreen({super.key, required this.place});

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _placeService = PlaceService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final _firebaseService = FirebaseService();

  // 폼 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _couponPasswordController = TextEditingController();

  // Phase 1 필드 컨트롤러
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _faxController = TextEditingController();
  final TextEditingController _parkingFeeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();

  // Phase 2 필드 컨트롤러
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _areaSizeController = TextEditingController();

  // Phase 3 필드 컨트롤러
  final TextEditingController _reservationUrlController = TextEditingController();
  final TextEditingController _reservationPhoneController = TextEditingController();
  final TextEditingController _virtualTourUrlController = TextEditingController();
  final TextEditingController _closureReasonController = TextEditingController();

  // 선택된 카테고리들
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;

  // 쿠폰 활성화 여부
  bool _enableCoupon = false;

  // 선택된 위치 좌표
  GeoPoint? _selectedLocation;

  // 주소 검색을 통해 입력되었는지 여부
  bool _isAddressSearchBased = false;

  // 대문 이미지 인덱스
  int _coverImageIndex = 0;

  // Phase 1 상태 변수
  Map<String, dynamic> _operatingHours = {}; // 요일별 운영시간
  List<String> _selectedFacilities = [];
  List<String> _selectedPaymentMethods = [];
  String? _selectedParkingType;
  int? _parkingCapacity;
  bool _isOpen24Hours = false;
  bool _hasValetParking = false;
  Map<String, String> _socialMediaHandles = {};
  List<String> _regularHolidays = [];
  Map<String, String> _breakTimes = {};

  // Phase 2 상태 변수
  List<String> _selectedAccessibility = [];
  String? _selectedPriceRange;
  int? _capacity;
  List<String> _nearbyTransit = [];

  // Phase 3 상태 변수
  List<String> _certifications = [];
  List<String> _awards = [];
  bool _hasReservation = false;
  List<String> _videoUrls = [];
  List<String> _interiorImageUrls = [];
  List<String> _exteriorImageUrls = [];
  bool _isTemporarilyClosed = false;
  DateTime? _reopeningDate;

  // 카테고리 옵션들
  final Map<String, List<String>> _categoryOptions = {
    '음식점': ['한식', '중식', '일식', '양식', '분식', '치킨', '피자', '버거', '아시안', '뷔페', '해산물', '고기집', '찌개/탕', '국수/면', '죽/백반'],
    '카페/디저트': ['커피전문점', '베이커리', '아이스크림', '디저트카페', '브런치카페', '차/전통차'],
    '소매/쇼핑': ['편의점', '슈퍼마켓', '대형마트', '백화점', '아울렛', '전통시장'],
    '의류/패션': ['의류', '신발', '가방', '액세서리', '안경/선글라스', '시계', '속옷'],
    '뷰티/화장품': ['화장품', '향수', '네일샵', '왁싱샵'],
    '생활용품': ['생활잡화', '문구', '꽃집', '인테리어소품', '애완용품'],
    '전자/가전': ['휴대폰', '컴퓨터', '가전제품', '카메라', '게임'],
    '가구/인테리어': ['가구', '침구', '조명', '커튼/블라인드', '주방용품'],
    '숙박': ['호텔', '모텔', '펜션', '게스트하우스', '리조트', '민박'],
    '문화/여가': ['영화관', '공연장', '박물관', '미술관', '전시관', '도서관', '문화센터'],
    '오락': ['노래방', 'PC방', '게임장', '볼링장', '당구장', '만화카페', 'VR카페'],
    '병원/의료': ['종합병원', '내과', '외과', '치과', '한의원', '소아과', '산부인과', '정형외과', '피부과', '안과', '이비인후과', '약국', '동물병원'],
    '교육': ['학원', '어학원', '컴퓨터학원', '예체능학원', '독서실', '스터디카페', '도서관'],
    '미용/뷰티': ['미용실', '네일샵', '피부관리', '마사지', '스파', '사우나', '찜질방'],
    '운동/스포츠': ['헬스장', '필라테스', '요가', '수영장', '태권도', '골프연습장', '클라이밍', '스쿼시', '배드민턴'],
    '생활서비스': ['세탁소', '수선집', '열쇠', '이사', '택배', '렌터카', '주차장', '세차장'],
    '금융/보험': ['은행', '증권사', '보험사', '대부업체', '환전소'],
    '부동산': ['부동산중개', '공인중개사'],
    '자동차': ['자동차판매', '정비소', '세차장', '주유소', '충전소', '카센터', '타이어'],
    '공공기관': ['주민센터', '우체국', '경찰서', '소방서', '시청', '구청', '도서관', '보건소'],
  };

  bool _isLoading = false;
  final List<dynamic> _selectedImages = [];
  final List<String> _imageNames = [];
  final List<String> _existingImageUrls = [];
  final List<String> _existingThumbnailUrls = [];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    // 기존 플레이스 정보로 폼 초기화
    _nameController.text = widget.place.name;
    _descriptionController.text = widget.place.description;
    _addressController.text = widget.place.address ?? '';
    _detailAddressController.text = widget.place.detailAddress ?? '';
    _phoneController.text = widget.place.contactInfo?['phone'] ?? '';
    _emailController.text = widget.place.contactInfo?['email'] ?? '';
    _couponPasswordController.text = widget.place.couponPassword ?? '';

    // Phase 1 필드 초기화
    _operatingHours = Map.from(widget.place.operatingHours ?? {});
    _mobileController.text = widget.place.mobile ?? '';
    _faxController.text = widget.place.fax ?? '';
    _websiteController.text = widget.place.contactInfo?['website'] ?? '';
    _parkingFeeController.text = widget.place.parkingFee ?? '';
    _selectedFacilities = List.from(widget.place.facilities);
    _selectedPaymentMethods = List.from(widget.place.paymentMethods);
    _selectedParkingType = widget.place.parkingType;
    _parkingCapacity = widget.place.parkingCapacity;
    _isOpen24Hours = widget.place.isOpen24Hours;
    _hasValetParking = widget.place.hasValetParking;
    _socialMediaHandles = Map.from(widget.place.socialMedia ?? {});
    _regularHolidays = List.from(widget.place.regularHolidays ?? []);
    _breakTimes = Map.from(widget.place.breakTimes ?? {});

    // Phase 2 필드 초기화
    _selectedAccessibility = List.from(widget.place.accessibility ?? []);
    _selectedPriceRange = widget.place.priceRange;
    _capacity = widget.place.capacity;
    _floorController.text = widget.place.floor ?? '';
    _buildingNameController.text = widget.place.buildingName ?? '';
    _landmarkController.text = widget.place.landmark ?? '';
    _areaSizeController.text = widget.place.areaSize ?? '';
    _nearbyTransit = List.from(widget.place.nearbyTransit ?? []);

    // Phase 3 필드 초기화
    _certifications = List.from(widget.place.certifications ?? []);
    _awards = List.from(widget.place.awards ?? []);
    _hasReservation = widget.place.hasReservation;
    _reservationUrlController.text = widget.place.reservationUrl ?? '';
    _reservationPhoneController.text = widget.place.reservationPhone ?? '';
    _videoUrls = List.from(widget.place.videoUrls ?? []);
    _virtualTourUrlController.text = widget.place.virtualTourUrl ?? '';
    _interiorImageUrls = List.from(widget.place.interiorImageUrls ?? []);
    _exteriorImageUrls = List.from(widget.place.exteriorImageUrls ?? []);
    _isTemporarilyClosed = widget.place.isTemporarilyClosed;
    _reopeningDate = widget.place.reopeningDate;
    _closureReasonController.text = widget.place.closureReason ?? '';

    // 카테고리 마이그레이션 (이전 카테고리 → 새 카테고리)
    final categoryMapping = {
      '요식업': '음식점',
      '배움': '교육',
      '생활': '생활서비스',
      '쇼핑': '소매/쇼핑',
      '엔터테인먼트': '문화/여가',
      '정치': '공공기관',
    };

    // 기존 카테고리를 새 카테고리로 매핑하거나 그대로 사용
    String? category = widget.place.category;
    if (category != null) {
      category = categoryMapping[category] ?? category;
      // 새 카테고리 목록에 없으면 null로 설정
      if (!_categoryOptions.containsKey(category)) {
        category = null;
      }
    }

    _selectedCategory = category;

    // 서브 카테고리 검증
    if (_selectedCategory != null && widget.place.subCategory != null) {
      final subCategories = _categoryOptions[_selectedCategory] ?? [];
      if (subCategories.contains(widget.place.subCategory)) {
        _selectedSubCategory = widget.place.subCategory;
      }
    }

    _selectedSubSubCategory = widget.place.subSubCategory;

    // 쿠폰 활성화 상태 초기화
    _enableCoupon = widget.place.isCouponEnabled;

    // 위치 정보 초기화
    _selectedLocation = widget.place.location;

    // 기존 주소가 있으면 검색 기반으로 간주
    _isAddressSearchBased = widget.place.address != null && widget.place.address!.isNotEmpty;

    // 기존 이미지 URL 복사
    _existingImageUrls.addAll(widget.place.imageUrls);
    _existingThumbnailUrls.addAll(widget.place.thumbnailUrls);

    // 대문 이미지 인덱스 초기화
    _coverImageIndex = widget.place.coverImageIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _couponPasswordController.dispose();

    // Phase 1 컨트롤러 dispose
    _mobileController.dispose();
    _faxController.dispose();
    _parkingFeeController.dispose();
    _websiteController.dispose();

    // Phase 2 컨트롤러 dispose
    _floorController.dispose();
    _buildingNameController.dispose();
    _landmarkController.dispose();
    _areaSizeController.dispose();

    // Phase 3 컨트롤러 dispose
    _reservationUrlController.dispose();
    _reservationPhoneController.dispose();
    _virtualTourUrlController.dispose();
    _closureReasonController.dispose();

    super.dispose();
  }

  Future<void> _updatePlace() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }

    // 현재 사용자가 플레이스 소유자인지 확인
    if (_currentUserId != widget.place.createdBy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('플레이스를 수정할 권한이 없습니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 새로 선택된 이미지 업로드 (원본 + 썸네일)
      final List<String> newImageUrls = [];
      final List<String> newThumbnailUrls = [];

      for (final img in _selectedImages) {
        Map<String, String> uploadResult;

        if (img is File) {
          uploadResult = await _firebaseService.uploadImageWithThumbnail(img, 'places');
        } else if (img is String && img.startsWith('data:image/')) {
          final safeName = 'place_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(img, 'places', safeName);
        } else {
          continue;
        }

        newImageUrls.add(uploadResult['original']!);
        newThumbnailUrls.add(uploadResult['thumbnail']!);
      }

      // 기존 이미지 + 새 이미지 합치기
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];
      final allThumbnailUrls = [..._existingThumbnailUrls, ...newThumbnailUrls];

      // coverImageIndex 검증 (이미지 개수 범위 내로 제한)
      final validCoverIndex = _coverImageIndex.clamp(0, allImageUrls.length - 1);

      final updatedPlace = widget.place.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        detailAddress: _detailAddressController.text.trim().isEmpty ? null : _detailAddressController.text.trim(),
        location: _selectedLocation,
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        subSubCategory: _selectedSubSubCategory,
        imageUrls: allImageUrls,
        thumbnailUrls: allThumbnailUrls,
        coverImageIndex: validCoverIndex,
        contactInfo: {
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        },
        couponPassword: _enableCoupon && _couponPasswordController.text.trim().isNotEmpty
            ? _couponPasswordController.text.trim()
            : null,
        isCouponEnabled: _enableCoupon && _couponPasswordController.text.trim().isNotEmpty,

        // Phase 1 필드
        operatingHours: _operatingHours.isEmpty ? null : _operatingHours,
        mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        fax: _faxController.text.trim().isEmpty ? null : _faxController.text.trim(),
        regularHolidays: _regularHolidays.isEmpty ? null : _regularHolidays,
        isOpen24Hours: _isOpen24Hours,
        breakTimes: _breakTimes.isEmpty ? null : _breakTimes,
        socialMedia: _socialMediaHandles.isEmpty ? null : _socialMediaHandles,
        parkingType: _selectedParkingType,
        parkingCapacity: _parkingCapacity,
        parkingFee: _parkingFeeController.text.trim().isEmpty ? null : _parkingFeeController.text.trim(),
        hasValetParking: _hasValetParking,
        facilities: _selectedFacilities,
        paymentMethods: _selectedPaymentMethods,

        // Phase 2 필드
        accessibility: _selectedAccessibility.isEmpty ? null : _selectedAccessibility,
        priceRange: _selectedPriceRange,
        capacity: _capacity,
        areaSize: _areaSizeController.text.trim().isEmpty ? null : _areaSizeController.text.trim(),
        floor: _floorController.text.trim().isEmpty ? null : _floorController.text.trim(),
        buildingName: _buildingNameController.text.trim().isEmpty ? null : _buildingNameController.text.trim(),
        landmark: _landmarkController.text.trim().isEmpty ? null : _landmarkController.text.trim(),
        nearbyTransit: _nearbyTransit.isEmpty ? null : _nearbyTransit,

        // Phase 3 필드
        certifications: _certifications.isEmpty ? null : _certifications,
        awards: _awards.isEmpty ? null : _awards,
        hasReservation: _hasReservation,
        reservationUrl: _reservationUrlController.text.trim().isEmpty ? null : _reservationUrlController.text.trim(),
        reservationPhone: _reservationPhoneController.text.trim().isEmpty ? null : _reservationPhoneController.text.trim(),
        videoUrls: _videoUrls.isEmpty ? null : _videoUrls,
        virtualTourUrl: _virtualTourUrlController.text.trim().isEmpty ? null : _virtualTourUrlController.text.trim(),
        interiorImageUrls: _interiorImageUrls.isEmpty ? null : _interiorImageUrls,
        exteriorImageUrls: _exteriorImageUrls.isEmpty ? null : _exteriorImageUrls,
        isTemporarilyClosed: _isTemporarilyClosed,
        reopeningDate: _reopeningDate,
        closureReason: _closureReasonController.text.trim().isEmpty ? null : _closureReasonController.text.trim(),

        updatedAt: DateTime.now(),
      );

      await _placeService.updatePlace(widget.place.id, updatedPlace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('플레이스가 성공적으로 수정되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 플레이스 수정 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');

      if (mounted) {
        String errorMessage = '플레이스 수정 실패';
        String suggestion = '';

        final errorString = e.toString();
        if (errorString.contains('permission-denied')) {
          errorMessage = '권한 오류';
          suggestion = '플레이스를 수정할 권한이 없습니다.';
        } else if (errorString.contains('network')) {
          errorMessage = '네트워크 오류';
          suggestion = '인터넷 연결을 확인해주세요.';
        } else if (errorString.contains('not-found')) {
          errorMessage = '플레이스 없음';
          suggestion = '플레이스가 삭제되었거나 찾을 수 없습니다.';
        } else if (errorString.contains('storage')) {
          errorMessage = '이미지 업로드 실패';
          suggestion = '이미지 크기를 줄이거나 다시 시도해주세요.';
        } else {
          suggestion = errorString.length > 80 ? errorString.substring(0, 80) + '...' : errorString;
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            content: Text(suggestion),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이스 수정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 플레이스명
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '플레이스명 *',
                  border: OutlineInputBorder(),
                  hintText: '예: 뺌햄버거 서초점',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '플레이스명을 입력해주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 설명
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명 *',
                  border: OutlineInputBorder(),
                  hintText: '플레이스에 대한 간단한 설명을 입력하세요.',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '설명을 입력해주세요.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 카테고리 선택
              const Text(
                '카테고리 *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              // 메인 카테고리
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: '메인 카테고리',
                  border: OutlineInputBorder(),
                ),
                items: _categoryOptions.keys.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedSubCategory = null;
                    _selectedSubSubCategory = null;
                  });
                },
              ),

              const SizedBox(height: 16),

              // 서브 카테고리
              if (_selectedCategory != null)
                DropdownButtonFormField<String>(
                  value: _selectedSubCategory,
                  decoration: const InputDecoration(
                    labelText: '서브 카테고리',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryOptions[_selectedCategory]!.map((subCategory) {
                    return DropdownMenuItem(
                      value: subCategory,
                      child: Text(subCategory),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubCategory = value;
                      _selectedSubSubCategory = null;
                    });
                  },
                ),

              const SizedBox(height: 16),

              // 주소
              const Text(
                '주소',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: '주소를 검색하세요',
                        border: const OutlineInputBorder(),
                        errorText: _addressController.text.isNotEmpty && !_isAddressSearchBased
                            ? '유효하지 않은 주소입니다. 주소 검색을 이용하세요.'
                            : null,
                      ),
                      readOnly: true,
                      onTap: () {
                        if (_addressController.text.isNotEmpty && !_isAddressSearchBased) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('주소 변경 필요'),
                              content: const Text('기존 주소는 유효하지 않습니다.\n주소 검색을 통해 다시 입력해주세요.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('확인'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pickAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _addressController.text.isNotEmpty && !_isAddressSearchBased
                          ? Colors.orange
                          : null,
                    ),
                    child: const Text('주소 검색'),
                  ),
                ],
              ),
              if (_addressController.text.isNotEmpty && !_isAddressSearchBased)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '이 주소는 검색 기반이 아닙니다. 정확한 위치 정보를 위해 주소 검색을 다시 해주세요.',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),

              // 상세주소 입력 필드
              TextFormField(
                controller: _detailAddressController,
                decoration: const InputDecoration(
                  hintText: '상세주소 (동/호수 등)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // 기존 이미지 표시
              if (_existingImageUrls.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      '기존 이미지',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    if (_existingImageUrls.length >= 2) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '(⭐ 대문 이미지)',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: _existingImageUrls.length >= 2 ? 160 : 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length,
                    itemBuilder: (context, index) {
                      final isCover = index == _coverImageIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: isCover ? Border.all(color: Colors.orange, width: 3) : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: _buildImageWidget(_existingImageUrls[index]),
                                  ),
                                ),
                                if (_existingImageUrls.length >= 2) ...[
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 120,
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: isCover ? null : () {
                                        setState(() {
                                          _coverImageIndex = index;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        backgroundColor: isCover ? Colors.orange : Colors.grey[200],
                                        foregroundColor: isCover ? Colors.white : Colors.black87,
                                      ),
                                      child: Text(
                                        isCover ? '⭐ 대문' : '대문으로',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeExistingImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                            if (isCover)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '⭐',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 새 이미지 업로드
              const Text(
                '새 이미지 추가',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('이미지 추가'),
                  ),
                  const SizedBox(width: 8),
                  const Text('최대 5장'),
                ],
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildImageWidget(_selectedImages[index]),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeNewImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              // 연락처 정보
              const SizedBox(height: 24),
              const Text(
                '연락처 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: '전화번호',
                        border: OutlineInputBorder(),
                        hintText: '02-1234-5678',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _mobileController,
                      decoration: const InputDecoration(
                        labelText: '휴대전화',
                        border: OutlineInputBorder(),
                        hintText: '010-1234-5678',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                        hintText: 'example@email.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return '올바른 이메일 형식이 아닙니다';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _faxController,
                      decoration: const InputDecoration(
                        labelText: '팩스',
                        border: OutlineInputBorder(),
                        hintText: '02-1234-5678',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteController,
                decoration: const InputDecoration(
                  labelText: '웹사이트',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com',
                  prefixIcon: Icon(Icons.language),
                ),
              ),

              const SizedBox(height: 24),

              // 요일별 운영시간
              EditPlaceFieldsHelper.buildOperatingHoursDetailSection(
                operatingHours: _operatingHours,
                onEditOperatingHours: _editOperatingHours,
              ),

              const SizedBox(height: 24),

              // 쿠폰 설정 섹션
              const Text(
                '쿠폰 설정 (선택사항)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _enableCoupon ? Colors.orange.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _enableCoupon ? Colors.orange.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox to enable coupon
                    CheckboxListTile(
                      value: _enableCoupon,
                      onChanged: (value) {
                        setState(() {
                          _enableCoupon = value ?? false;
                          if (!_enableCoupon) {
                            _couponPasswordController.clear();
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            color: _enableCoupon ? Colors.orange.shade700 : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '쿠폰 시스템 사용',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _enableCoupon ? Colors.black87 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_enableCoupon) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '고객이 쿠폰 사용 시 입력해야 하는 암호를 설정하세요.\n매장에서 암호를 알려주면 고객이 입력하여 포인트를 받을 수 있습니다.',
                        style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _couponPasswordController,
                        decoration: InputDecoration(
                          labelText: '쿠폰 암호 *',
                          border: const OutlineInputBorder(),
                          hintText: '예: 1234',
                          prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                          helperText: '숫자 또는 문자 4자리 이상 권장',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (_enableCoupon) {
                            if (value == null || value.isEmpty) {
                              return '쿠폰을 활성화하려면 암호를 입력해주세요.';
                            }
                            if (value.length < 4) {
                              return '암호는 4자리 이상이어야 합니다.';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ========== Phase 1 입력 폼 ==========

              // 주차 정보
              EditPlaceFieldsHelper.buildParkingSection(
                selectedParkingType: _selectedParkingType,
                parkingCapacity: _parkingCapacity,
                parkingFeeController: _parkingFeeController,
                hasValetParking: _hasValetParking,
                onParkingTypeChanged: (value) => setState(() => _selectedParkingType = value),
                onCapacityChanged: (value) => setState(() => _parkingCapacity = value),
                onValetParkingChanged: (value) => setState(() => _hasValetParking = value),
              ),

              const SizedBox(height: 24),

              // 편의시설
              EditPlaceFieldsHelper.buildFacilitiesSection(
                selectedFacilities: _selectedFacilities,
                onFacilityChanged: (facility, selected) {
                  setState(() {
                    if (selected) {
                      _selectedFacilities.add(facility);
                    } else {
                      _selectedFacilities.remove(facility);
                    }
                  });
                },
              ),

              const SizedBox(height: 24),

              // 결제 수단
              EditPlaceFieldsHelper.buildPaymentMethodsSection(
                selectedPaymentMethods: _selectedPaymentMethods,
                onPaymentMethodChanged: (method, selected) {
                  setState(() {
                    if (selected) {
                      _selectedPaymentMethods.add(method);
                    } else {
                      _selectedPaymentMethods.remove(method);
                    }
                  });
                },
              ),

              const SizedBox(height: 24),

              // 운영시간 상세
              EditPlaceFieldsHelper.buildOperatingHoursSection(
                isOpen24Hours: _isOpen24Hours,
                regularHolidays: _regularHolidays,
                breakTimes: _breakTimes,
                on24HoursChanged: (value) => setState(() => _isOpen24Hours = value),
                onAddHoliday: _addHoliday,
                onRemoveHoliday: (index) => setState(() => _regularHolidays.removeAt(index)),
                onAddBreakTime: _addBreakTime,
              ),

              const SizedBox(height: 32),

              // ========== Phase 2 입력 폼 ==========

              // 접근성
              EditPlaceFieldsHelper.buildAccessibilitySection(
                selectedAccessibility: _selectedAccessibility,
                onAccessibilityChanged: (item, selected) {
                  setState(() {
                    if (selected) {
                      _selectedAccessibility.add(item);
                    } else {
                      _selectedAccessibility.remove(item);
                    }
                  });
                },
              ),

              const SizedBox(height: 24),

              // 가격대 및 규모
              EditPlaceFieldsHelper.buildPriceAndCapacitySection(
                selectedPriceRange: _selectedPriceRange,
                capacity: _capacity,
                areaSizeController: _areaSizeController,
                onPriceRangeChanged: (value) => setState(() => _selectedPriceRange = value),
                onCapacityChanged: (value) => setState(() => _capacity = value),
              ),

              const SizedBox(height: 24),

              // 상세 위치 정보
              EditPlaceFieldsHelper.buildLocationDetailsSection(
                floorController: _floorController,
                buildingNameController: _buildingNameController,
                landmarkController: _landmarkController,
              ),

              const SizedBox(height: 32),

              // ========== Phase 3 입력 폼 ==========

              // 예약 시스템
              EditPlaceFieldsHelper.buildReservationSection(
                hasReservation: _hasReservation,
                reservationUrlController: _reservationUrlController,
                reservationPhoneController: _reservationPhoneController,
                onReservationChanged: (value) => setState(() => _hasReservation = value),
              ),

              const SizedBox(height: 24),

              // 임시 휴업
              EditPlaceFieldsHelper.buildClosureSection(
                isTemporarilyClosed: _isTemporarilyClosed,
                reopeningDate: _reopeningDate,
                closureReasonController: _closureReasonController,
                onClosureChanged: (value) => setState(() => _isTemporarilyClosed = value),
                onSelectReopeningDate: _selectReopeningDate,
              ),

              const SizedBox(height: 24),

              // 추가 미디어
              EditPlaceFieldsHelper.buildMediaSection(
                virtualTourUrlController: _virtualTourUrlController,
              ),

              const SizedBox(height: 32),

              // 수정 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePlace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '플레이스 수정',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
      if (index < _existingThumbnailUrls.length) {
        _existingThumbnailUrls.removeAt(index);
      }

      // 대문 이미지 인덱스 조정
      if (_coverImageIndex == index) {
        // 삭제된 이미지가 대문이었다면 첫 번째 이미지를 대문으로
        _coverImageIndex = 0;
      } else if (_coverImageIndex > index) {
        // 대문 이미지보다 앞의 이미지가 삭제되면 인덱스 조정
        _coverImageIndex--;
      }
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  // 이미지 선택 및 도우미 메서드들 (CreatePlaceScreen과 동일)
  Widget _buildCrossPlatformImage(dynamic imageData) {
    if (imageData is String) {
      if (imageData.startsWith('data:image/')) {
        try {
          return Image.memory(
            base64Decode(imageData.split(',')[1]),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
              );
            },
          );
        } catch (e) {
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          );
        }
      } else if (imageData.startsWith('http')) {
        return Image.network(
          imageData,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 120,
              height: 120,
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
            );
          },
        );
      } else {
        // 로컬 파일 경로 (웹에서는 사용 불가)
        if (kIsWeb) {
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 40, color: Colors.grey),
          );
        } else {
          return Image.file(
            File(imageData),
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 120,
                height: 120,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
              );
            },
          );
        }
      }
    } else if (imageData is Uint8List) {
      // 웹에서 선택된 바이트 데이터
      return Image.memory(
        imageData,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          );
        },
      );
    } else if (imageData is File) {
      // 모바일에서 선택된 File 객체
      if (kIsWeb) {
        return Container(
          width: 120,
          height: 120,
          color: Colors.grey[300],
          child: const Icon(Icons.image, size: 40, color: Colors.grey),
        );
      } else {
        return Image.file(
          imageData,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 120,
              height: 120,
              color: Colors.grey[300],
              child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
            );
          },
        );
      }
    }
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  Future<void> _pickImage() async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS) {
        await _pickImageMobile();
      } else {
        await _pickImageWeb();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
    }
  }

  Future<void> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
    if (image != null) {
      if (mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
          _imageNames.add(image.name);
        });
      }
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
            }
            continue;
          }

          // 웹에서는 bytes를 base64로 변환해서 저장
          if (file.bytes != null) {
            final base64Image = 'data:image/${file.extension};base64,${base64Encode(file.bytes!)}';
            if (mounted) {
              setState(() {
                _selectedImages.add(base64Image);
                _imageNames.add(file.name);
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
    }
  }

  Future<void> _pickAddress() async {
    // 주소 검색 화면으로 이동
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final address = result['address'] as String?;
      final detailAddress = result['detailAddress'] as String?;
      final lat = double.tryParse(result['lat']?.toString() ?? '');
      final lon = double.tryParse(result['lon']?.toString() ?? '');

      if (address != null && lat != null && lon != null) {
        setState(() {
          _addressController.text = address;
          _detailAddressController.text = detailAddress ?? '';
          _selectedLocation = GeoPoint(lat, lon);
          _isAddressSearchBased = true; // 검색을 통해 입력됨
        });
      }
    }
  }

  Widget _buildImageWidget(dynamic image) {
    if (kIsWeb) {
      // 웹 플랫폼
      if (image is String && image.startsWith('http')) {
        return Image.network(
          image,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
        );
      } else if (image is Uint8List) {
        return Image.memory(
          image,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    } else {
      // 모바일 플랫폼
      if (image is File) {
        return Image.file(
          image,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else if (image is String && image.startsWith('http')) {
        return Image.network(
          image,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    }

    return _buildErrorPlaceholder();
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
    );
  }

  // ========== Phase 1-3 헬퍼 메서드 ==========

  void _addHoliday() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedDay;
        return AlertDialog(
          title: const Text('정기 휴무일 추가'),
          content: DropdownButtonFormField<String>(
            value: selectedDay,
            decoration: const InputDecoration(
              labelText: '요일 선택',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: '월요일', child: Text('월요일')),
              DropdownMenuItem(value: '화요일', child: Text('화요일')),
              DropdownMenuItem(value: '수요일', child: Text('수요일')),
              DropdownMenuItem(value: '목요일', child: Text('목요일')),
              DropdownMenuItem(value: '금요일', child: Text('금요일')),
              DropdownMenuItem(value: '토요일', child: Text('토요일')),
              DropdownMenuItem(value: '일요일', child: Text('일요일')),
              DropdownMenuItem(value: '첫째주', child: Text('매월 첫째주')),
              DropdownMenuItem(value: '셋째주', child: Text('매월 셋째주')),
            ],
            onChanged: (value) => selectedDay = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (selectedDay != null && !_regularHolidays.contains(selectedDay)) {
                  setState(() => _regularHolidays.add(selectedDay!));
                }
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _addBreakTime() {
    showDialog(
      context: context,
      builder: (context) {
        String? selectedDay;
        String? breakTimeText;
        return AlertDialog(
          title: const Text('브레이크타임 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedDay,
                decoration: const InputDecoration(
                  labelText: '요일 선택',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: '평일', child: Text('평일')),
                  DropdownMenuItem(value: '주말', child: Text('주말')),
                  DropdownMenuItem(value: '매일', child: Text('매일')),
                ],
                onChanged: (value) => selectedDay = value,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: '브레이크타임',
                  border: OutlineInputBorder(),
                  hintText: '예: 15:00-17:00',
                ),
                onChanged: (value) => breakTimeText = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (selectedDay != null && breakTimeText != null && breakTimeText!.isNotEmpty) {
                  setState(() => _breakTimes[selectedDay!] = breakTimeText!);
                }
                Navigator.pop(context);
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _selectReopeningDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _reopeningDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _reopeningDate = picked);
    }
  }

  void _editOperatingHours() {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final controllers = <String, TextEditingController>{};

    // 기존 운영시간으로 컨트롤러 초기화
    for (final day in days) {
      controllers[day] = TextEditingController(text: _operatingHours[day] ?? '');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('요일별 운영시간 설정'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: days.map((day) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          day,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: controllers[day],
                          decoration: const InputDecoration(
                            hintText: '09:00-18:00 또는 "휴무"',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              for (final controller in controllers.values) {
                controller.dispose();
              }
              Navigator.pop(context);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final newOperatingHours = <String, dynamic>{};
              for (final day in days) {
                final value = controllers[day]!.text.trim();
                if (value.isNotEmpty && value != '휴무') {
                  newOperatingHours[day] = value;
                }
              }
              setState(() => _operatingHours = newOperatingHours);

              for (final controller in controllers.values) {
                controller.dispose();
              }
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}