import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';

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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // 선택된 카테고리들
  String? _selectedCategory;
  String? _selectedSubCategory;
  String? _selectedSubSubCategory;

  // 카테고리 옵션들
  final Map<String, List<String>> _categoryOptions = {
    '요식업': ['한식', '중식', '일식', '양식', '카페', '디저트', '패스트푸드'],
    '배움': ['학원', '도서관', '박물관', '전시관', '문화센터'],
    '생활': ['마트', '편의점', '약국', '병원', '은행', '우체국', '주민센터'],
    '쇼핑': ['의류', '신발', '가방', '화장품', '전자제품', '가구'],
    '엔터테인먼트': ['영화관', '게임방', '노래방', '볼링장', 'PC방'],
    '정치': ['의원실', '시청', '구청', '정당사무소'],
  };

  bool _isLoading = false;
  final List<dynamic> _selectedImages = [];
  final List<String> _imageNames = [];
  final List<String> _existingImageUrls = [];

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
    _phoneController.text = widget.place.contactInfo?['phone'] ?? '';
    _emailController.text = widget.place.contactInfo?['email'] ?? '';

    _selectedCategory = widget.place.category;
    _selectedSubCategory = widget.place.subCategory;
    _selectedSubSubCategory = widget.place.subSubCategory;

    // 기존 이미지 URL 복사
    _existingImageUrls.addAll(widget.place.imageUrls);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
      // 새로 선택된 이미지 업로드
      final List<String> newImageUrls = [];
      for (final img in _selectedImages) {
        String url;
        if (img is File) {
          url = await _firebaseService.uploadImage(img, 'places');
        } else if (img is String && img.startsWith('data:image/')) {
          final safeName = 'place_${DateTime.now().millisecondsSinceEpoch}.png';
          url = await _firebaseService.uploadImageDataUrl(img, 'places', safeName);
        } else {
          continue;
        }
        newImageUrls.add(url);
      }

      // 기존 이미지 + 새 이미지 합치기
      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      final updatedPlace = widget.place.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        subSubCategory: _selectedSubSubCategory,
        imageUrls: allImageUrls,
        contactInfo: {
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        },
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
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  border: OutlineInputBorder(),
                  hintText: '예: 서울시 서초구 반포동 123-45',
                ),
              ),

              const SizedBox(height: 16),

              // 기존 이미지 표시
              if (_existingImageUrls.isNotEmpty) ...[
                const Text(
                  '기존 이미지',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _existingImageUrls[index],
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
                              ),
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
                              child: _buildCrossPlatformImage(_selectedImages[index]),
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
              const SizedBox(height: 16),
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
                    ),
                  ),
                ],
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
        return Image.memory(
          base64Decode(imageData.split(',')[1]),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else if (imageData.startsWith('http')) {
        return Image.network(imageData, width: 120, height: 120, fit: BoxFit.cover);
      } else {
        return Image.file(File(imageData), width: 120, height: 120, fit: BoxFit.cover);
      }
    } else if (imageData is File) {
      return Image.file(imageData, width: 120, height: 120, fit: BoxFit.cover);
    }
    return Container(width: 120, height: 120, color: Colors.grey[300], child: const Icon(Icons.image, size: 40, color: Colors.grey));
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
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
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

          if (mounted) {
            setState(() {
              _selectedImages.add(file.path ?? '');
              _imageNames.add(file.name);
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
    }
  }
}