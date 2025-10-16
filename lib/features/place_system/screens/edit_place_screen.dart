import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/storage/storage_service.dart';
import '../../../core/services/location/location_service.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/utils/file_helper.dart';
import '../../../core/utils/logger.dart';
import '../widgets/edit_place_helpers.dart';
import '../widgets/edit_place_widgets.dart';

/// 플레이스 편집 화면
class EditPlaceScreen extends StatefulWidget {
  final String placeId;

  const EditPlaceScreen({
    Key? key,
    required this.placeId,
  }) : super(key: key);

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  // 폼 컨트롤러들
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _couponPasswordController = TextEditingController();

  // 상태 변수들
  String? _selectedCategory;
  List<String> _selectedImages = [];
  bool _enableCoupon = false;
  bool _isLoading = false;
  bool _isSaving = false;
  PlaceModel? _place;
  String? _error;

  // 위치 정보
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadPlaceData();
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
    super.dispose();
  }

  /// 플레이스 데이터 로드
  Future<void> _loadPlaceData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final place = await PlaceService().getPlaceById(widget.placeId);
      if (place != null) {
        setState(() {
          _place = place;
          _nameController.text = place.name;
          _descriptionController.text = place.description;
          _selectedCategory = place.category;
          _addressController.text = place.address ?? '';
          _detailAddressController.text = place.detailAddress ?? '';
          _phoneController.text = place.contactInfo?['phone'] ?? '';
          _emailController.text = place.contactInfo?['email'] ?? '';
          _selectedImages = place.imageUrls;
          _enableCoupon = place.isCouponEnabled;
          _couponPasswordController.text = place.couponPassword ?? '';
          _latitude = place.location?.latitude;
          _longitude = place.location?.longitude;
        });
      } else {
        setState(() {
          _error = '플레이스를 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      debugPrint('플레이스 데이터 로드 실패: $e');
      setState(() {
        _error = '데이터를 불러오는 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 주소 검색
  Future<void> _searchAddress() async {
    try {
      // TODO: 주소 검색 다이얼로그 구현 필요
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소 검색 기능은 준비 중입니다.')),
      );
    } catch (e) {
      debugPrint('주소 검색 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주소 검색 중 오류가 발생했습니다: $e')),
      );
    }
  }

  /// 이미지 추가
  Future<void> _addImage() async {
    try {
      // TODO: 이미지 선택 다이얼로그 구현 필요
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지 업로드 기능은 준비 중입니다.')),
      );
    } catch (e) {
      debugPrint('이미지 추가 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 추가 중 오류가 발생했습니다: $e')),
      );
    }
  }

  /// 이미지 제거
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// 플레이스 저장
  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // PlaceService의 updatePlace는 PlaceModel을 받으므로 직접 호출
      await PlaceService().updatePlace(
        widget.placeId,
        _place!.copyWith(
          name: _nameController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          address: _addressController.text,
          detailAddress: _detailAddressController.text,
          contactInfo: {
            'phone': _phoneController.text,
            'email': _emailController.text,
          },
          imageUrls: _selectedImages,
          isCouponEnabled: _enableCoupon,
          couponPassword: _couponPasswordController.text,
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이스가 성공적으로 저장되었습니다.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('플레이스 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 미리보기 데이터 생성
  Map<String, dynamic> _getPreviewData() {
    return {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'category': _selectedCategory ?? '미선택',
      'address': _addressController.text,
      'detailAddress': _detailAddressController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'imageCount': _selectedImages.length,
      'enableCoupon': _enableCoupon,
      'couponPassword': _enableCoupon ? _couponPasswordController.text : null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이스 편집'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: '디자인 프리뷰',
            onPressed: () {
              Navigator.pushNamed(context, '/create-place-design-demo');
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  /// 메인 바디 위젯
  Widget _buildBody() {
    if (_isLoading) {
      return EditPlaceWidgets.buildLoadingWidget();
    }

    if (_error != null) {
      return EditPlaceWidgets.buildErrorWidget(_error!, _loadPlaceData);
    }

    if (_place == null) {
      return EditPlaceWidgets.buildEmptyWidget('플레이스 정보를 찾을 수 없습니다.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기본 정보 섹션
            EditPlaceWidgets.buildSectionHeader(
              '기본 정보',
              Icons.info_outline,
              Colors.blue,
            ),
            const SizedBox(height: 16),
            
            // 플레이스명
            EditPlaceWidgets.buildFormField(
              label: '플레이스명',
              hintText: '플레이스명을 입력하세요',
              controller: _nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '플레이스명을 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // 설명
            EditPlaceWidgets.buildFormField(
              label: '설명',
              hintText: '플레이스에 대한 설명을 입력하세요',
              controller: _descriptionController,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // 카테고리
            EditPlaceWidgets.buildCategorySelector(
              selectedCategory: _selectedCategory,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // 위치 정보 섹션
            EditPlaceWidgets.buildSectionHeader(
              '위치 정보',
              Icons.location_on,
              Colors.green,
            ),
            const SizedBox(height: 16),
            
            // 주소
            EditPlaceWidgets.buildAddressField(
              controller: _addressController,
              onSearch: _searchAddress,
            ),
            const SizedBox(height: 16),
            
            // 상세주소
            EditPlaceWidgets.buildFormField(
              label: '상세주소',
              hintText: '상세주소를 입력하세요',
              controller: _detailAddressController,
            ),
            const SizedBox(height: 24),
            
            // 이미지 섹션
            EditPlaceWidgets.buildSectionHeader(
              '이미지',
              Icons.image,
              Colors.orange,
            ),
            const SizedBox(height: 16),
            
            EditPlaceWidgets.buildImageUploadWidget(
              images: _selectedImages,
              onAddImage: _addImage,
              onRemoveImage: _removeImage,
            ),
            const SizedBox(height: 24),
            
            // 연락처 정보 섹션
            EditPlaceWidgets.buildSectionHeader(
              '연락처 정보',
              Icons.contact_phone,
              Colors.purple,
            ),
            const SizedBox(height: 16),
            
            // 전화번호
            EditPlaceWidgets.buildFormField(
              label: '전화번호',
              hintText: '전화번호를 입력하세요',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            
            // 이메일
            EditPlaceWidgets.buildFormField(
              label: '이메일',
              hintText: '이메일을 입력하세요',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return '올바른 이메일 형식을 입력해주세요.';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // 쿠폰 설정 섹션
            EditPlaceWidgets.buildSectionHeader(
              '쿠폰 설정',
              Icons.local_offer,
              Colors.red,
            ),
            const SizedBox(height: 16),
            
            EditPlaceWidgets.buildCouponSettings(
              enableCoupon: _enableCoupon,
              onChanged: (value) {
                setState(() {
                  _enableCoupon = value;
                });
              },
              passwordController: _couponPasswordController,
              validator: (value) {
                if (_enableCoupon && (value == null || value.trim().isEmpty)) {
                  return '쿠폰 암호를 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // 미리보기 섹션
            EditPlaceWidgets.buildSectionHeader(
              '미리보기',
              Icons.preview,
              Colors.teal,
            ),
            const SizedBox(height: 16),
            
            EditPlaceWidgets.buildPlacePreview(
              previewData: _getPreviewData(),
            ),
            const SizedBox(height: 24),
            
            // 저장 버튼
            EditPlaceWidgets.buildSaveButton(
              onPressed: _savePlace,
              isLoading: _isSaving,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}