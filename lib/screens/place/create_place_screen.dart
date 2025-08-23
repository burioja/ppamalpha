import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import '../../models/place_model.dart';
import '../../services/place_service.dart';
import '../../services/firebase_service.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
      // 이미지 업로드
      final List<String> imageUrls = [];
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
        imageUrls.add(url);
      }

      final place = PlaceModel(
        id: '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        location: null, // TODO: 지도에서 위치 선택 기능 추가
        category: _selectedCategory,
        subCategory: _selectedSubCategory,
        subSubCategory: _selectedSubSubCategory,
        imageUrls: imageUrls,
        operatingHours: null,
        contactInfo: {
          'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        },
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('플레이스 생성 실패: $e'),
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
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  border: OutlineInputBorder(),
                  hintText: '예: 서울시 서초구 반포동 123-45',
                ),
              ),
              
              const SizedBox(height: 16),

              // 플레이스 이미지 업로드
              const Text(
                '플레이스 이미지',
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
                  const Text('정사각형 권장, 최대 5장'),
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
                                onTap: () => _removeImage(index),
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
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.click();
    await input.onChange.first;
    if (input.files != null) {
      for (final file in input.files!) {
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
          }
          continue;
        }
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        await reader.onLoad.first;
        if (mounted) {
          setState(() {
            _selectedImages.add(reader.result as String);
            _imageNames.add(file.name);
          });
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
  }
}

