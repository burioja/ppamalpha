import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

class _CreatePlaceScreenState extends State<CreatePlaceScreen> {
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

  // 선택된 카테고리들
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;

  // 쿠폰 활성화 여부
  bool _enableCoupon = false;

  // 선택된 위치 좌표
  GeoPoint? _selectedLocation;

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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _couponPasswordController.dispose();
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
        } else {
          // 지원하지 않는 타입
          continue;
        }

        imageUrls.add(uploadResult['original']!);
        thumbnailUrls.add(uploadResult['thumbnail']!);
      }

      // coverImageIndex 검증 (이미지 개수 범위 내로 제한)
      final validCoverIndex = imageUrls.isNotEmpty ? _coverImageIndex.clamp(0, imageUrls.length - 1) : 0;

      final place = PlaceModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        detailAddress: _detailAddressController.text.trim().isEmpty ? null : _detailAddressController.text.trim(),
        location: _selectedLocation,
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        subSubCategory: _selectedSubSubCategory,
        imageUrls: imageUrls,
        thumbnailUrls: thumbnailUrls,
        coverImageIndex: validCoverIndex,
        operatingHours: null,
        contactInfo: {
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        },
        couponPassword: _enableCoupon && _couponPasswordController.text.trim().isNotEmpty
            ? _couponPasswordController.text.trim()
            : null,
        isCouponEnabled: _enableCoupon && _couponPasswordController.text.trim().isNotEmpty,
        createdBy: _currentUserId!,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _placeService.createPlace(place);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('플레이스가 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 플레이스 생성 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');

      if (mounted) {
        String errorMessage = '플레이스 생성 실패';
        String suggestion = '';

        final errorString = e.toString();
        if (errorString.contains('permission-denied')) {
          errorMessage = '권한 오류';
          suggestion = '플레이스를 생성할 권한이 없습니다.';
        } else if (errorString.contains('network')) {
          errorMessage = '네트워크 오류';
          suggestion = '인터넷 연결을 확인해주세요.';
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
        title: const Text('플레이스 생성'),
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
                      decoration: const InputDecoration(
                        hintText: '주소를 검색하세요',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _pickAddress,
                    child: const Text('주소 검색'),
                  ),
                ],
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

              // 플레이스 이미지 업로드
              Row(
                children: [
                  const Text(
                    '플레이스 이미지',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  if (_selectedImages.length >= 2) ...[
                    const SizedBox(width: 8),
                    const Text(
                      '(⭐ 대문 이미지)',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ],
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
                  height: _selectedImages.length >= 2 ? 160 : 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
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
                                    child: _buildCrossPlatformImage(_selectedImages[index]),
                                  ),
                                ),
                                if (_selectedImages.length >= 2) ...[
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
                                onTap: () => _removeImage(index),
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
              ],
              
              // 연락처 정보
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: '전화번호',
                        border: OutlineInputBorder(),
                        hintText: '010-1234-5678',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
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
                        if (value == null || value.isEmpty) return null; // 선택사항
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return '올바른 이메일 형식이 아닙니다';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
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

              // 생성 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createPlace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '플레이스 생성',
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
}

// Helpers for image selection (web/mobile)
extension _CreatePlaceScreenImageHelpers on _CreatePlaceScreenState {
  Widget _buildCrossPlatformImage(dynamic imageData) {
    if (imageData is String) {
      if (imageData.startsWith('data:image/')) {
        // 웹: base64 데이터
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
        // 네트워크 URL
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
      } else if (!kIsWeb) {
        // 모바일: 파일 경로
        return Image.file(
          FileHelper.createFile(imageData),
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
          _selectedImages.add(image.path); // 파일 경로를 String으로 저장
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);

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
        });
      }
    }
  }
}

