import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/price_calculator.dart';
import '../widgets/post_media_widgets.dart';
import '../widgets/post_targeting_widgets.dart';
import '../services/post_file_service.dart';
import '../../user_dashboard/providers/inbox_provider.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceCalculatorKey = GlobalKey<PriceCalculatorState>();
  final _postService = PostService();
  final _firebaseService = FirebaseService();
  static const GeoPoint _kRefLocation = GeoPoint(37.5665, 126.9780);

  // 폼 컨트롤러들
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final _soundController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  // 선택된 값들
  String _selectedFunction = 'Using';
  List<String> _selectedGenders = ['male', 'female'];
  RangeValues _selectedAgeRange = const RangeValues(20, 60); // 기본값 20-60

  String _selectedPostType = '일반';
  bool _hasExpiration = false;
  bool _canTransfer = false;
  bool _canForward = false;
  bool _canRespond = false;
  String _selectedTargeting = '기본';

  // 사운드 파일
  dynamic _selectedSound;
  String _soundFileName = '';

  // 크로스 플랫폼 이미지 저장
  final List<dynamic> _selectedImages = [];
  final List<String> _imageNames = [];

  // 로딩 상태
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _usedRefLocation = false;

  // 위치 정보
  GeoPoint? _currentLocation;

  // 함수 옵션들
  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];

  final List<String> _postTypes = ['일반', '쿠폰'];
  final List<String> _targetingOptions = ['기본', '고급', '맞춤형'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initializeForm();
    _priceController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _initializeForm() {
    _titleController.text = '미미믹'; // 배포자명을 기본값으로 설정
    _priceController.text = _calculateAutoPrice(); // 최소 단가 자동 설정
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final location = await LocationService.getCurrentPosition();
      if (location != null) {
        setState(() {
          _currentLocation = GeoPoint(location.latitude, location.longitude);
        });
      }
    } catch (e) {
      setState(() {
        _currentLocation = _kRefLocation;
        _usedRefLocation = true;
      });
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _soundController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await PostFileService.pickImages(context);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  Future<void> _pickImage() async {
    final images = await PostFileService.pickImage(context);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _showTextInput() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('텍스트 입력'),
          content: const Text('텍스트 입력 기능은 추후 구현될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickSound() async {
    final soundData = await PostFileService.pickSound(context);
    if (soundData != null) {
      setState(() {
        _selectedSound = soundData['bytes'];
        _soundFileName = soundData['name'];
      });
    }
  }

  void _pickVideo() {
    // 비디오 선택 기능 (추후 구현)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비디오 선택 기능은 추후 구현될 예정입니다.')),
    );
  }

  // 자동 단가 계산 (1M까지 30원, 그 이상 300KB당 10원)
  String _calculateAutoPrice() {
    int totalSize = 0;
    
    // 이미지 크기 계산
    for (var image in _selectedImages) {
      if (image is List<int>) {
        totalSize += (image.length as num).toInt();
      } else if (image is Uint8List) {
        totalSize += (image.length as num).toInt();
      }
    }
    
    // 사운드 크기 계산
    if (_selectedSound != null) {
      try {
        totalSize += ((_selectedSound as dynamic).length as num).toInt();
      } catch (e) {
        // 타입 변환 실패 시 무시
      }
    }
    
    // 단가 계산
    int price = 0;
    if (totalSize <= 1024 * 1024) { // 1MB 이하
      price = 30;
    } else {
      price = 30 + ((totalSize - 1024 * 1024) ~/ (300 * 1024)) * 10; // 300KB당 10원 추가
    }
    
    return price.toString();
  }


  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // 이미지 업로드
      List<String> imageUrls = [];
      List<String> thumbnailUrls = [];
      
      for (int i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        String? imageUrl;
        String? thumbnailUrl;

        if (kIsWeb && image is Uint8List) {
          final result = await _firebaseService.uploadImageBytesWithThumbnail(image, 'posts', 'image_${DateTime.now().millisecondsSinceEpoch}');
          imageUrl = result['original'];
          thumbnailUrl = result['thumbnail'];
        } else if (!kIsWeb && image is File) {
          imageUrl = await _firebaseService.uploadImage(image, 'posts');
          thumbnailUrl = imageUrl; // 썸네일과 동일
        }

        if (imageUrl != null) {
          imageUrls.add(imageUrl);
          thumbnailUrls.add(thumbnailUrl!);
          debugPrint('✅ 이미지 업로드 완료: $imageUrl');
        }
      }

      // 사운드 업로드 (현재는 사용하지 않음)
      if (_selectedSound != null) {
        if (kIsWeb && _selectedSound is Uint8List) {
          await _firebaseService.uploadAudioBytes(_selectedSound, 'posts', 'sound_${DateTime.now().millisecondsSinceEpoch}');
        } else if (!kIsWeb && _selectedSound is File) {
          final bytes = await _selectedSound.readAsBytes();
          await _firebaseService.uploadAudioBytes(bytes, 'posts', 'sound_${DateTime.now().millisecondsSinceEpoch}');
        }
      }

      // 포스트 생성
      debugPrint('🚀 포스트 생성 시작:');
      debugPrint('   imageUrls: $imageUrls');
      debugPrint('   thumbnailUrls: $thumbnailUrls');
      debugPrint('   mediaType: ${imageUrls.map((url) => 'image').toList()}');
      
      await _postService.createPost(
        creatorId: user.uid,
        creatorName: user.displayName ?? '익명',
        reward: int.parse(_priceController.text),
        targetAge: [_selectedAgeRange.start.round(), _selectedAgeRange.end.round()],
        targetGender: _selectedGenders.length == 2 ? 'both' : _selectedGenders.first,
        targetInterest: [], // 기본값
        targetPurchaseHistory: [], // 기본값
        mediaType: imageUrls.map((url) => 'image').toList(),
        mediaUrl: imageUrls,
        thumbnailUrl: thumbnailUrls,
        title: _titleController.text,
        description: _contentController.text,
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: false, // 기본값
        canUse: true, // 기본값
        defaultExpiresAt: DateTime.now().add(const Duration(days: 30)),
        placeId: null,
        isCoupon: _selectedPostType == '쿠폰',
        youtubeUrl: _youtubeUrlController.text.isNotEmpty ? _youtubeUrlController.text : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 성공적으로 생성되었습니다!')),
        );
        
        // 인박스 프로바이더 새로고침
        final inboxProvider = Provider.of<InboxProvider>(context, listen: false);
        await inboxProvider.refreshMyPosts();
        
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 생성 실패: $e')),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('포스트 작성'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createPost,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('완료'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // 플레이스 헤더
                _buildModernPlaceHeader(),
                
                // 메인 컨텐츠
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 기본 정보 섹션 (제목과 타입만)
                      _buildCompactSection(
                        title: '기본 정보',
                        icon: Icons.edit_note_rounded,
                        color: Colors.blue,
                        children: [
                          // 제목과 타입을 같은 줄에 배치 (7:3 비율)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: _buildCompactTextField(
                                  controller: _titleController,
                                  label: '제목',
                                  icon: Icons.title,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '제목을 입력해주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _buildCompactDropdown(
                                  label: '타입',
                                  value: _selectedPostType,
                                  items: _postTypes,
                                  icon: Icons.category_outlined,
                                  onChanged: (value) => setState(() => _selectedPostType = value!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 미디어 섹션 (1줄 배치, 자동 단가 계산)
                      PostMediaWidgets.buildMediaSectionInline(
                        priceText: _calculateAutoPrice(),
                        imageCount: _selectedImages.length,
                        selectedImages: _selectedImages,
                        onImageTap: _pickImages,
                        onTextTap: _showTextInput,
                        onSoundTap: _pickSound,
                        onVideoTap: _pickVideo,
                        onPriceChanged: (price) {
                          _priceController.text = price;
                        },
                        onRemoveImage: (index) {
                          setState(() {
                            _selectedImages.removeAt(index);
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 타겟팅 (일렬로 컴팩트하게)
                      _buildCompactSection(
                        title: '타겟팅',
                        icon: Icons.people_rounded,
                        color: Colors.orange,
                        children: [
                          PostTargetingWidgets.buildTargetingInline(
                            selectedGenders: _selectedGenders,
                            selectedAgeRange: _selectedAgeRange,
                            onGenderChanged: (genders) => setState(() => _selectedGenders = genders),
                            onAgeRangeChanged: (range) => setState(() => _selectedAgeRange = range),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 추가 옵션 (기능, 타겟팅 레벨 포함)
                      _buildCompactSection(
                        title: '추가 옵션',
                        icon: Icons.tune_rounded,
                        color: Colors.teal,
                        children: [
                          PostTargetingWidgets.buildAdditionalOptions(
                            selectedFunction: _selectedFunction,
                            selectedTargeting: _selectedTargeting,
                            hasExpiration: _hasExpiration,
                            canTransfer: _canTransfer,
                            canForward: _canForward,
                            canRespond: _canRespond,
                            functions: _functions,
                            targetingOptions: _targetingOptions,
                            onFunctionChanged: (value) => setState(() => _selectedFunction = value!),
                            onTargetingChanged: (value) => setState(() => _selectedTargeting = value!),
                            onExpirationChanged: (value) => setState(() => _hasExpiration = value!),
                            onTransferChanged: (value) => setState(() => _canTransfer = value!),
                            onForwardChanged: (value) => setState(() => _canForward = value!),
                            onRespondChanged: (value) => setState(() => _canRespond = value!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 하단 완료 버튼 with enhanced styling
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.purple[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createPost,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.rocket_launch, color: Colors.white, size: 26),
                          label: Text(
                            _isLoading ? '포스트 생성 중...' : '포스트 생성하기',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernPlaceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[300]!, Colors.purple[200]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '미미믹', // 배포자명
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '종각, 지하55, 종로, 종로1가, 종로1·2·3·4가동, 종로구, 서울특별시, 031...', // 배포자 주소
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_currentLocation != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Column(
        children: [
          // 헤더 with enhanced styling
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '설정',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 컨텐츠 with enhanced styling
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: '$label을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[400]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[400]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }

}
