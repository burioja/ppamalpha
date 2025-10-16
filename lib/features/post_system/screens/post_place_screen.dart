import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';
import '../widgets/post_place_helpers.dart';
import '../widgets/post_place_widgets.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();

  // 상태 변수들
  RangeValues _selectedAgeRange = const RangeValues(20, 40);
  String _selectedGender = 'all';
  List<String> _selectedInterests = [];
  List<File> _selectedImages = [];
  File? _selectedAudioFile;
  int _defaultRadius = 1000;
  DateTime? _defaultExpiresAt;
  String? _selectedPlaceId;
  bool _isCoupon = false;
  String? _youtubeUrl;

  // 로딩 상태
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _defaultExpiresAt = DateTime.now().add(const Duration(days: 30));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 롱프레스에서 전달된 location 파라미터 처리
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('location')) {
      // location 파라미터가 있으면 해당 위치로 포스트 생성 준비
      final location = args['location'];
      debugPrint('📍 롱프레스 위치에서 포스트 생성: $location');
      // TODO: location을 사용한 초기 설정 (필요시)
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '포스트 생성',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _showPreview,
            tooltip: '미리보기',
          ),
        ],
      ),
      body: _isLoading
          ? PostPlaceWidgets.buildLoadingWidget()
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
                    
                    // 제목
                    PostPlaceWidgets.buildFormField(
                      label: '제목',
                      hintText: '포스트 제목을 입력하세요',
                      controller: _titleController,
                      validator: PostPlaceHelpers.validateTitle,
                    ),
                    const SizedBox(height: 16),
                    
                    // 설명
                    PostPlaceWidgets.buildFormField(
                      label: '설명',
                      hintText: '포스트 설명을 입력하세요',
                      controller: _descriptionController,
                      validator: PostPlaceHelpers.validateDescription,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // 리워드
                    PostPlaceWidgets.buildFormField(
                      label: '리워드 (원)',
                      hintText: '리워드 금액을 입력하세요',
                      controller: _rewardController,
                      validator: PostPlaceHelpers.validateReward,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    
                    // 타겟팅 섹션
                    _buildSectionHeader('타겟팅', Icons.people, Colors.orange),
                    const SizedBox(height: 12),
                    
                    // 나이 범위
                    _buildAgeRangeSection(),
                    const SizedBox(height: 16),
                    
                    // 성별
                    _buildGenderSection(),
                    const SizedBox(height: 16),
                    
                    // 관심사
                    _buildInterestSection(),
                    const SizedBox(height: 24),
                    
                    // 미디어 섹션
                    _buildSectionHeader('미디어', Icons.perm_media, Colors.purple),
                    const SizedBox(height: 12),
                    
                    // 미디어 업로드
                    PostPlaceWidgets.buildMediaUploadWidget(
                      images: _selectedImages,
                      audioFile: _selectedAudioFile,
                      onPickImages: _pickImages,
                      onPickAudio: _pickAudioFile,
                      onRemoveImage: _removeImage,
                      onRemoveAudio: _removeAudioFile,
                    ),
                    const SizedBox(height: 24),
                    
                    // 고급 설정 섹션
                    _buildSectionHeader('고급 설정', Icons.settings, Colors.grey),
                    const SizedBox(height: 12),
                    
                    // 반경 설정
                    _buildRadiusSection(),
                    const SizedBox(height: 16),
                    
                    // 만료일 설정
                    _buildExpirySection(),
                    const SizedBox(height: 16),
                    
                    // 쿠폰 설정
                    _buildCouponSection(),
                    const SizedBox(height: 24),
                    
                    // 생성 버튼
                    _buildCreateButton(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAgeRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '나이 범위',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: PostPlaceWidgets.buildAgeRangeSlider(
            context: context,
            values: _selectedAgeRange,
            onChanged: (range) {
              setState(() {
                _selectedAgeRange = range;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          PostPlaceHelpers.generateAgeRangeText(_selectedAgeRange),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성별',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        PostPlaceWidgets.buildGenderSelector(
          selectedGender: _selectedGender,
          onChanged: (gender) {
            setState(() {
              _selectedGender = gender;
            });
          },
        ),
      ],
    );
  }

  Widget _buildInterestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '관심사',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        PostPlaceWidgets.buildInterestSelector(
          selectedInterests: _selectedInterests,
          onChanged: (interests) {
            setState(() {
              _selectedInterests = interests;
            });
          },
        ),
        if (_selectedInterests.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '선택된 관심사: ${PostPlaceHelpers.generateInterestText(_selectedInterests)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRadiusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '배포 반경 (미터)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _defaultRadius.toDouble(),
          min: 100,
          max: 5000,
          divisions: 49,
          label: '${_defaultRadius}m',
          onChanged: (value) {
            setState(() {
              _defaultRadius = value.round();
            });
          },
        ),
        Text(
          '현재 반경: ${_defaultRadius}m',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildExpirySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '만료일',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          title: Text(
            _defaultExpiresAt != null
                ? PostPlaceHelpers.formatDate(_defaultExpiresAt!)
                : '만료일을 선택하세요',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: _selectExpiryDate,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildCouponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          title: const Text('쿠폰 포스트'),
          subtitle: const Text('이 포스트를 쿠폰으로 사용할 수 있습니다'),
          value: _isCoupon,
          onChanged: (value) {
            setState(() {
              _isCoupon = value ?? false;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _createPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          '포스트 생성',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 이벤트 핸들러들
  Future<void> _pickImages() async {
    try {
      final images = await PostPlaceHelpers.pickImages();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '이미지 선택 실패: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final audioFile = await PostPlaceHelpers.pickAudioFile();
      if (audioFile != null) {
        setState(() {
          _selectedAudioFile = audioFile;
        });
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '오디오 파일 선택 실패: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeAudioFile() {
    setState(() {
      _selectedAudioFile = null;
    });
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _defaultExpiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _defaultExpiresAt = date;
      });
    }
  }

  void _showPreview() {
    final previewData = PostPlaceHelpers.generatePreviewData(
      title: _titleController.text,
      description: _descriptionController.text,
      reward: int.tryParse(_rewardController.text) ?? 0,
      ageRange: _selectedAgeRange,
      gender: _selectedGender,
      interests: _selectedInterests,
      mediaTypes: PostPlaceHelpers.determineMediaTypes(_selectedImages, _selectedAudioFile),
      images: _selectedImages,
      audioFile: _selectedAudioFile,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 미리보기'),
        content: SizedBox(
          width: double.maxFinite,
          child: PostPlaceWidgets.buildPreviewWidget(previewData: previewData),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 추가 유효성 검사
    final validationErrors = PostPlaceHelpers.validateForm(
      title: _titleController.text,
      description: _descriptionController.text,
      reward: _rewardController.text,
      ageRange: _selectedAgeRange,
      gender: _selectedGender,
      interests: _selectedInterests,
      images: _selectedImages,
      audioFile: _selectedAudioFile,
    );

    final hasErrors = validationErrors.values.any((error) => error != null);
    if (hasErrors) {
      final firstError = validationErrors.values.firstWhere((error) => error != null);
      PostPlaceHelpers.showErrorSnackBar(context, firstError!);
      return;
    }

    // 확인 다이얼로그
    final confirmed = await PostPlaceHelpers.showConfirmDialog(
      context,
      '포스트 생성',
      '포스트를 생성하시겠습니까?',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('사용자가 로그인되지 않았습니다');
      }

      // 미디어 URL 생성
      final mediaTypes = PostPlaceHelpers.determineMediaTypes(_selectedImages, _selectedAudioFile);
      final mediaUrls = await PostPlaceHelpers.generateMediaUrls(_selectedImages, _selectedAudioFile);
      final thumbnailUrls = await PostPlaceHelpers.generateThumbnailUrls(_selectedImages);

      // 포스트 생성
      final postId = await PostPlaceHelpers.createPost(
        creatorId: currentUser.uid,
        creatorName: currentUser.displayName ?? 'Unknown',
        reward: int.parse(_rewardController.text),
        targetAge: [_selectedAgeRange.start.toInt(), _selectedAgeRange.end.toInt()],
        targetGender: _selectedGender,
        targetInterest: _selectedInterests,
        targetPurchaseHistory: [], // TODO: 구매 이력 구현
        mediaType: mediaTypes,
        mediaUrl: mediaUrls,
        thumbnailUrl: thumbnailUrls,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        canRespond: true,
        canForward: true,
        canRequestReward: true,
        canUse: true,
        defaultRadius: _defaultRadius,
        defaultExpiresAt: _defaultExpiresAt,
        placeId: _selectedPlaceId,
        isCoupon: _isCoupon,
        youtubeUrl: _youtubeUrl,
      );

      if (postId != null) {
        PostPlaceHelpers.showSuccessSnackBar(context, '포스트가 성공적으로 생성되었습니다');
        Navigator.pop(context, true);
      } else {
        throw Exception('포스트 생성에 실패했습니다');
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '포스트 생성 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}