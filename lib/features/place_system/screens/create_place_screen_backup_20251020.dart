import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/utils/file_helper.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../screens/auth/address_search_screen.dart';

class CreatePlaceScreen extends StatefulWidget {
  const CreatePlaceScreen({super.key});

  @override
  State<CreatePlaceScreen> createState() => _CreatePlaceScreenState();
}

class _CreatePlaceScreenState extends State<CreatePlaceScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _placeService = PlaceService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final _firebaseService = FirebaseService();
  late TabController _tabController;
  
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

  // 기본 필드들
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;
  Map<String, dynamic> _operatingHours = {};
  List<String> _regularHolidays = [];
  List<String> _breakTimes = [];
  bool _isOpen24Hours = false;
  List<String> _selectedFacilities = [];
  List<String> _selectedPaymentMethods = [];
  String? _selectedParkingType;
  int? _parkingCapacity;
  bool _hasValetParking = false;
  bool _enableCoupon = false;
  List<String> _selectedAccessibility = [];
  String? _selectedPriceRange;
  int? _capacity;
  bool _hasReservation = false;
  List<String> _videoUrls = [];
  List<String> _interiorImageUrls = [];
  List<String> _exteriorImageUrls = [];
  bool _isTemporarilyClosed = false;
  DateTime? _reopeningDate;

  // 섹션 접기/펼치기 상태
  bool _isOperatingInfoExpanded = false;
  bool _isAdditionalInfoExpanded = false;

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
  int _coverImageIndex = 0; // 대문 이미지 인덱스 (기본값: 첫 번째 이미지)

  // 옵션 리스트들
  final List<String> _facilityOptions = [
    'WiFi', '에어컨', '화장실', '주차장', '엘리베이터', '에스컬레이터',
    '휠체어 접근', '흡연실', '금연실', '냉난방', '음료 서비스',
    '간식 서비스', '대기실', '로커', '샤워실', '체육관', '수영장',
    '사우나', '마사지', '네일샵', '미용실', '세탁소', '편의점',
  ];

  final List<String> _paymentOptions = [
    '현금', '카드', '계좌이체', '모바일페이', '간편결제', '쿠폰',
    '포인트', '상품권', '할인카드', '신용카드', '체크카드',
  ];

  final List<String> _accessibilityOptions = [
    '휠체어 접근', '엘리베이터', '경사로', '점자 안내', '청각 보조',
    '시각 보조', '장애인 화장실', '장애인 주차장', '보조견 동반',
    '수화 통역', '음성 안내', '큰 글씨 안내',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _createPlace() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 이미지 업로드 (원본 + 썸네일)
      final List<String> imageUrls = [];
      final List<String> thumbnailUrls = [];

      for (final img in _selectedImages) {
        Map<String, String> uploadResult;

        if (img is String && img.startsWith('data:image/')) {
          // 웹: base64 데이터
          final safeName = 'place_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(
            img,
            'places',
            safeName,
          );
        } else if (img is String && !kIsWeb) {
          // 모바일: 파일 경로
          uploadResult = await _firebaseService.uploadImageWithThumbnail(
            FileHelper.createFile(img),
            'places',
          );
        } else if (img is Uint8List) {
          // 모바일: 바이트 데이터
          uploadResult = await _firebaseService.uploadImageBytesWithThumbnail(
            img,
            'places',
            'place_${DateTime.now().millisecondsSinceEpoch}.png',
          );
        } else {
          continue;
        }

        imageUrls.add(uploadResult['original']!);
        thumbnailUrls.add(uploadResult['thumbnail']!);
      }

      // PlaceModel 생성
      final place = PlaceModel(
        id: '', // Firestore에서 자동 생성
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        subCategory: _selectedSubCategory,
        subSubCategory: _selectedSubSubCategory,
        address: _addressController.text.trim(),
        detailAddress: _detailAddressController.text.trim(),
        location: null, // 주소 검색에서 설정
        imageUrls: imageUrls,
        thumbnailUrls: thumbnailUrls,
        coverImageIndex: _coverImageIndex,
        operatingHours: _operatingHours,
        contactInfo: {
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
        },
        createdBy: _currentUserId!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
        isOpen24Hours: _isOpen24Hours,
        regularHolidays: _regularHolidays,
        breakTimes: _breakTimes.isNotEmpty ? {for (int i = 0; i < _breakTimes.length; i++) i.toString(): _breakTimes[i]} : null,
        mobile: _mobileController.text.trim(),
        fax: _faxController.text.trim(),
        socialMedia: _websiteController.text.trim().isNotEmpty ? {'website': _websiteController.text.trim()} : null,
        parkingType: _selectedParkingType,
        parkingCapacity: _parkingCapacity,
        parkingFee: _parkingFeeController.text.trim(),
        hasValetParking: _hasValetParking,
        facilities: _selectedFacilities,
        paymentMethods: _selectedPaymentMethods,
        accessibility: _selectedAccessibility,
        priceRange: _selectedPriceRange,
        capacity: _capacity,
        areaSize: _areaSizeController.text.trim(),
        floor: _floorController.text.trim(),
        buildingName: _buildingNameController.text.trim(),
        landmark: _landmarkController.text.trim(),
        hasReservation: _hasReservation,
        reservationUrl: _reservationUrlController.text.trim(),
        reservationPhone: _reservationPhoneController.text.trim(),
        videoUrls: _videoUrls,
        virtualTourUrl: _virtualTourUrlController.text.trim(),
        interiorImageUrls: _interiorImageUrls,
        exteriorImageUrls: _exteriorImageUrls,
        isTemporarilyClosed: _isTemporarilyClosed,
        reopeningDate: _reopeningDate,
        closureReason: _closureReasonController.text.trim(),
        isCouponEnabled: _enableCoupon,
        couponPassword: _couponPasswordController.text.trim(),
        isVerified: false,
      );

      await _placeService.createPlace(place);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배포자가 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배포자 생성 실패: $e'),
            backgroundColor: Colors.red,
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

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (_selectedImages.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('최대 5장까지만 업로드할 수 있습니다.')),
          );
          return;
        }

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64String';
          setState(() {
            _selectedImages.add(dataUrl);
            _imageNames.add(image.name);
          });
        } else {
          setState(() {
            _selectedImages.add(image.path);
            _imageNames.add(image.name);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
      
      // 대문 이미지 인덱스 조정
      if (_coverImageIndex >= _selectedImages.length) {
        _coverImageIndex = _selectedImages.length - 1;
      }
      if (_coverImageIndex < 0) {
        _coverImageIndex = 0;
      }
    });
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.pushNamed(
      context,
      '/address-search',
      arguments: {'returnAddress': true},
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _addressController.text = result['address'] ?? '';
      });
    }
  }

  Future<void> _addHoliday() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴무일 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '예: 매주 월요일',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _regularHolidays.add(result.trim());
      });
    }
  }

  Future<void> _addBreakTime() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴게시간 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '예: 15:00-16:00',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _breakTimes.add(result.trim());
      });
    }
  }

  Future<void> _selectReopeningDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _reopeningDate = date;
      });
    }
  }

  Future<void> _editOperatingHours() async {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final controllers = <String, TextEditingController>{};
    
    for (final day in days) {
      controllers[day] = TextEditingController(
        text: _operatingHours[day] ?? '',
      );
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('운영시간 설정'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: days.map((day) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        day,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controllers[day],
                        decoration: const InputDecoration(
                          hintText: '예: 09:00-22:00 또는 휴무',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.purple[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '배포자 생성',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.palette, color: Colors.white),
              tooltip: '디자인 프리뷰',
              onPressed: () {
                Navigator.pushNamed(context, '/create-place-design-demo');
              },
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 기본 정보 섹션
                    _buildSectionHeader('기본 정보', Icons.info_outline, Colors.blue),
                    const SizedBox(height: 12),
                    
                    // 배포자명 + 카테고리 (같은 행)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 배포자명 (flex: 3)
                        Expanded(
                          flex: 3,
                          child: _buildCompactField(
                            icon: Icons.store,
                            iconColor: Colors.blue.shade700,
                            label: '배포자명',
                            required: true,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: _buildInputDecoration(hintText: '배포자 이름'),
                              style: const TextStyle(fontSize: 14),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '배포자명을 입력해주세요.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 카테고리 (flex: 1)
                        Expanded(
                          flex: 1,
                          child: _buildCompactField(
                            icon: Icons.category,
                            iconColor: Colors.orange.shade700,
                            label: '카테고리',
                            required: true,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration: _buildInputDecoration(
                                fillColor: Colors.orange.shade50,
                                borderColor: Colors.orange.shade200,
                                hintText: '선택',
                              ),
                              isExpanded: true,
                              items: _categoryOptions.keys.map((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    category,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCategory = newValue;
                                  _selectedSubCategory = null;
                                  _selectedSubSubCategory = null;
                                });
                              },
                              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                              dropdownColor: Colors.white,
                              icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.orange.shade700),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return '선택';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // 설명
                    _buildCompactField(
                      icon: Icons.description,
                      iconColor: Colors.green.shade700,
                      label: '설명',
                      required: true,
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _buildInputDecoration(hintText: '배포자에 대한 설명을 입력하세요'),
                        style: const TextStyle(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '설명을 입력해주세요.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 주소
                    _buildCompactField(
                      icon: Icons.location_on,
                      iconColor: Colors.red.shade700,
                      label: '주소',
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  readOnly: true,
                                  decoration: _buildInputDecoration(hintText: '주소 검색'),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _pickAddress,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  minimumSize: Size.zero,
                                ),
                                child: const Icon(Icons.search, size: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _detailAddressController,
                            decoration: _buildInputDecoration(hintText: '상세주소 (동/호수 등)'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 이미지 업로드
                    _buildCompactField(
                      icon: Icons.image,
                      iconColor: Colors.purple.shade700,
                      label: '이미지',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('이미지 추가', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '최대 5장',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          if (_selectedImages.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: _selectedImages[index] is String
                                              ? Image.network(
                                                  _selectedImages[index],
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                )
                                              : Image.memory(
                                                  _selectedImages[index],
                                                  width: 80,
                                                  height: 80,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (index == _coverImageIndex)
                                          Positioned(
                                            bottom: 4,
                                            left: 4,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                '대문',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 연락처 정보
                    _buildCompactField(
                      icon: Icons.contact_phone,
                      iconColor: Colors.teal.shade700,
                      label: '연락처 정보',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _buildInputDecoration(
                              hintText: '이메일',
                              prefixIcon: Icons.email,
                            ),
                            style: const TextStyle(fontSize: 14),
                            validator: (value) {
                              if (value == null || value.isEmpty) return null;
                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                              if (!emailRegex.hasMatch(value)) {
                                return '올바른 이메일 형식이 아닙니다';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(
                              hintText: '전화번호',
                              prefixIcon: Icons.phone,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // 운영 정보 섹션
                    _buildCollapsibleSectionHeader(
                      '운영 정보',
                      Icons.schedule,
                      Colors.teal,
                      _isOperatingInfoExpanded,
                      () {
                        setState(() {
                          _isOperatingInfoExpanded = !_isOperatingInfoExpanded;
                        });
                      },
                    ),
                    if (_isOperatingInfoExpanded) ...[
                    const SizedBox(height: 12),
                    
                    // 운영시간
                    _buildCompactField(
                      icon: Icons.access_time,
                      iconColor: Colors.teal,
                      label: '운영시간',
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _operatingHours.isEmpty ? '운영시간 설정' : '${_operatingHours.length}일 설정됨',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _editOperatingHours,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('편집', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 24시간 운영
                    _buildCompactField(
                      icon: Icons.all_inclusive,
                      iconColor: Colors.indigo,
                      label: '24시간 운영',
                      child: CheckboxListTile(
                        value: _isOpen24Hours,
                        onChanged: (value) {
                          setState(() {
                            _isOpen24Hours = value ?? false;
                          });
                        },
                        title: const Text('24시간 운영', style: TextStyle(fontSize: 14)),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 정기 휴무일
                    _buildCompactField(
                      icon: Icons.event_busy,
                      iconColor: Colors.red,
                      label: '정기 휴무일',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _regularHolidays.isEmpty ? '휴무일 없음' : '${_regularHolidays.length}개 설정됨',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                              ),
                              TextButton(
                                onPressed: _addHoliday,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('추가', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (_regularHolidays.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _regularHolidays.map((holiday) {
                                return Chip(
                                  label: Text(holiday, style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _regularHolidays.remove(holiday);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 휴게시간
                    _buildCompactField(
                      icon: Icons.coffee,
                      iconColor: Colors.brown,
                      label: '휴게시간',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _breakTimes.isEmpty ? '휴게시간 없음' : '${_breakTimes.length}개 설정됨',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                              ),
                              TextButton(
                                onPressed: _addBreakTime,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('추가', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (_breakTimes.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _breakTimes.map((breakTime) {
                                return Chip(
                                  label: Text(breakTime, style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      _breakTimes.remove(breakTime);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 시설
                    _buildCompactField(
                      icon: Icons.home_work,
                      iconColor: Colors.cyan,
                      label: '시설',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _facilityOptions.map((facility) {
                          return _buildFacilityChip(facility);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 결제방법
                    _buildCompactField(
                      icon: Icons.payment,
                      iconColor: Colors.green,
                      label: '결제방법',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _paymentOptions.map((payment) {
                          return _buildPaymentChip(payment);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 주차 정보
                    _buildCompactField(
                      icon: Icons.local_parking,
                      iconColor: Colors.amber,
                      label: '주차 정보',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedParkingType,
                            decoration: _buildInputDecoration(hintText: '주차 형태'),
                            items: const [
                              DropdownMenuItem(value: 'self', child: Text('자체 주차장')),
                              DropdownMenuItem(value: 'valet', child: Text('발레파킹')),
                              DropdownMenuItem(value: 'nearby', child: Text('인근 주차장 이용')),
                              DropdownMenuItem(value: 'none', child: Text('주차 불가')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedParkingType = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _parkingCapacity?.toString() ?? '',
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(hintText: '주차 가능 대수'),
                                  onChanged: (value) {
                                    _parkingCapacity = int.tryParse(value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _parkingFeeController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(hintText: '주차 요금'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            value: _hasValetParking,
                            onChanged: (value) {
                              setState(() {
                                _hasValetParking = value ?? false;
                              });
                            },
                            title: const Text('발레파킹 서비스', style: TextStyle(fontSize: 14)),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 추가 연락처
                    _buildCompactField(
                      icon: Icons.contact_mail,
                      iconColor: Colors.deepPurple,
                      label: '추가 연락처',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(hintText: '모바일'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _faxController,
                            keyboardType: TextInputType.phone,
                            decoration: _buildInputDecoration(hintText: '팩스'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                            decoration: _buildInputDecoration(hintText: '웹사이트'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 쿠폰 설정
                    _buildCompactField(
                      icon: Icons.card_giftcard,
                      iconColor: Colors.orange,
                      label: '쿠폰 설정',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            title: const Text('쿠폰 시스템 사용', style: TextStyle(fontSize: 14)),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                          if (_enableCoupon) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _couponPasswordController,
                              decoration: _buildInputDecoration(hintText: '쿠폰 암호'),
                              obscureText: true,
                              validator: (value) {
                                if (_enableCoupon && (value == null || value.length < 4)) {
                                  return '4자리 이상 입력해주세요';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    ], // 운영 정보 섹션 끝
                    
                    const SizedBox(height: 24),
                    
                    // 추가 정보 섹션
                    _buildCollapsibleSectionHeader(
                      '추가 정보',
                      Icons.more_horiz,
                      Colors.purple,
                      _isAdditionalInfoExpanded,
                      () {
                        setState(() {
                          _isAdditionalInfoExpanded = !_isAdditionalInfoExpanded;
                        });
                      },
                    ),
                    if (_isAdditionalInfoExpanded) ...[
                    const SizedBox(height: 12),
                    
                    // 접근성
                    _buildCompactField(
                      icon: Icons.accessibility,
                      iconColor: Colors.pink,
                      label: '접근성',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _accessibilityOptions.map((accessibility) {
                          return _buildAccessibilityChip(accessibility);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 가격대 & 수용인원 & 면적
                    _buildCompactField(
                      icon: Icons.attach_money,
                      iconColor: Colors.green,
                      label: '가격대 & 수용인원 & 면적',
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedPriceRange,
                            decoration: _buildInputDecoration(hintText: '가격대'),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('저가 (1만원 이하)')),
                              DropdownMenuItem(value: 'medium', child: Text('중가 (1-5만원)')),
                              DropdownMenuItem(value: 'high', child: Text('고가 (5만원 이상)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedPriceRange = value;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _capacity?.toString() ?? '',
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(hintText: '수용인원'),
                                  onChanged: (value) => _capacity = int.tryParse(value),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _areaSizeController,
                                  keyboardType: TextInputType.number,
                                  decoration: _buildInputDecoration(hintText: '면적'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 상세 위치 정보
                    _buildCompactField(
                      icon: Icons.apartment,
                      iconColor: Colors.cyan,
                      label: '상세 위치 정보',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _floorController,
                            decoration: _buildInputDecoration(hintText: '층수'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _buildingNameController,
                            decoration: _buildInputDecoration(hintText: '건물명'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _landmarkController,
                            decoration: _buildInputDecoration(hintText: '주변 랜드마크'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 예약 시스템
                    _buildCompactField(
                      icon: Icons.event_seat,
                      iconColor: Colors.indigo,
                      label: '예약 시스템',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _hasReservation,
                            onChanged: (value) {
                              setState(() {
                                _hasReservation = value ?? false;
                              });
                            },
                            title: const Text('예약 가능', style: TextStyle(fontSize: 14)),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                          if (_hasReservation) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reservationUrlController,
                              keyboardType: TextInputType.url,
                              decoration: _buildInputDecoration(hintText: '예약 URL'),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _reservationPhoneController,
                              keyboardType: TextInputType.phone,
                              decoration: _buildInputDecoration(hintText: '예약 전화번호'),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 임시 휴업
                    _buildCompactField(
                      icon: Icons.pause_circle,
                      iconColor: Colors.red,
                      label: '임시 휴업',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _isTemporarilyClosed,
                            onChanged: (value) {
                              setState(() {
                                _isTemporarilyClosed = value ?? false;
                              });
                            },
                            title: const Text('임시 휴업', style: TextStyle(fontSize: 14)),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          ),
                          if (_isTemporarilyClosed) ...[
                            const SizedBox(height: 8),
                            ListTile(
                              title: Text(
                                _reopeningDate != null
                                    ? '재개업일: ${_reopeningDate!.toString().split(' ')[0]}'
                                    : '재개업일 선택',
                                style: const TextStyle(fontSize: 14),
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectReopeningDate,
                              contentPadding: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _closureReasonController,
                              decoration: _buildInputDecoration(hintText: '휴업 사유'),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 추가 미디어
                    _buildCompactField(
                      icon: Icons.video_library,
                      iconColor: Colors.deepOrange,
                      label: '추가 미디어',
                      child: TextFormField(
                        controller: _virtualTourUrlController,
                        keyboardType: TextInputType.url,
                        decoration: _buildInputDecoration(hintText: '가상투어 URL'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    ], // 추가 정보 섹션 끝
                    
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlace,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('배포자 생성', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 섹션 헤더
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 접을 수 있는 섹션 헤더
  Widget _buildCollapsibleSectionHeader(
    String title,
    IconData icon,
    Color color,
    bool isExpanded,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 24,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  // 컴팩트 필드
  Widget _buildCompactField({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (required)
                const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // 입력 필드 데코레이션
  InputDecoration _buildInputDecoration({
    String? hintText,
    IconData? prefixIcon,
    Color? fillColor,
    Color? borderColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: Colors.grey[600]) : null,
      filled: true,
      fillColor: fillColor ?? Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor ?? Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor ?? Colors.blue.shade300, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  // 시설 칩
  Widget _buildFacilityChip(String facility) {
    final isSelected = _selectedFacilities.contains(facility);
    return FilterChip(
      label: Text(facility, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedFacilities.add(facility);
          } else {
            _selectedFacilities.remove(facility);
          }
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.cyan.withOpacity(0.3),
      checkmarkColor: Colors.cyan.shade700,
    );
  }

  // 결제방법 칩
  Widget _buildPaymentChip(String payment) {
    final isSelected = _selectedPaymentMethods.contains(payment);
    return FilterChip(
      label: Text(payment, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedPaymentMethods.add(payment);
          } else {
            _selectedPaymentMethods.remove(payment);
          }
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.green.withOpacity(0.3),
      checkmarkColor: Colors.green.shade700,
    );
  }

  // 접근성 칩
  Widget _buildAccessibilityChip(String accessibility) {
    final isSelected = _selectedAccessibility.contains(accessibility);
    return FilterChip(
      label: Text(accessibility, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedAccessibility.add(accessibility);
          } else {
            _selectedAccessibility.remove(accessibility);
          }
        });
      },
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.pink.withOpacity(0.3),
      checkmarkColor: Colors.pink.shade700,
    );
  }
}