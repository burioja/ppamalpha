import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/price_calculator.dart';

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
  RangeValues _selectedAgeRange = const RangeValues(20, 30);

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
    _titleController.text = '새 포스트';
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

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        await _pickImageWeb();
      } else {
        await _pickImageMobile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')),
              );
            }
            continue;
          }

          if (mounted) {
            setState(() {
              if (file.bytes != null) {
                _selectedImages.add(file.bytes!);
              }
              _imageNames.add(file.name);
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _priceCalculatorKey.currentState?.forceRecalculate();
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      if (mounted) {
        setState(() {
          _selectedImages.add(File(image.path));
          _imageNames.add(image.name);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _priceCalculatorKey.currentState?.forceRecalculate();
        });
      }
    }
  }

  Future<void> _pickSound() async {
    try {
      if (kIsWeb) {
        await _pickSoundWeb();
      } else {
        await _pickSoundMobile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사운드 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickSoundWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')),
            );
          }
          return;
        }

        if (file.bytes != null && mounted) {
          setState(() {
            _selectedSound = file.bytes!;
            _soundFileName = file.name;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _priceCalculatorKey.currentState?.forceRecalculate();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사운드 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickSoundMobile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      if (file.path != null) {
        if (mounted) {
          setState(() {
            _selectedSound = File(file.path!);
            _soundFileName = file.name;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _priceCalculatorKey.currentState?.forceRecalculate();
          });
        }
      }
    }
  }

  void _removeSound() {
    setState(() {
      _selectedSound = null;
      _soundFileName = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _priceCalculatorKey.currentState?.forceRecalculate();
    });
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _priceCalculatorKey.currentState?.forceRecalculate();
    });
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

                      // 미디어 섹션 (헤더에 단가 포함)
                      _buildMediaSectionWithPrice(),
                      const SizedBox(height: 16),

                      // 타겟팅 (일렬로 컴팩트하게)
                      _buildCompactSection(
                        title: '타겟팅',
                        icon: Icons.people_rounded,
                        color: Colors.orange,
                        children: [
                          _buildTargetingInline(),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 추가 옵션 (기능, 타겟팅 레벨 포함)
                      _buildCompactSection(
                        title: '추가 옵션',
                        icon: Icons.tune_rounded,
                        color: Colors.teal,
                        children: [
                          _buildAdditionalOptions(),
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
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
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
                    const Text(
                      '포스트 작성',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLocationLoading 
                          ? '위치 정보 로딩 중...'
                          : _usedRefLocation 
                              ? '기본 위치 사용 중'
                              : '현재 위치에서 작성',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
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
        border: Border.all(color: color.withOpacity(0.1), width: 1),
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

  Widget _buildMediaSectionWithPrice() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // 헤더 (단가 포함)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[100]!, Colors.purple[50]!],
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  '미디어',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 단가 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '단가: ${_priceController.text.isEmpty ? '0' : _priceController.text}P',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 컨텐츠
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 미디어 타입 선택 버튼들
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaTypeButton(
                        '이미지',
                        Icons.image,
                        Colors.blue,
                        () => _pickImages(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeButton(
                        '텍스트',
                        Icons.text_fields,
                        Colors.green,
                        () => _showTextInput(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaTypeButton(
                        '사운드',
                        Icons.audiotrack,
                        Colors.orange,
                        () => _pickSound(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeButton(
                        '영상',
                        Icons.videocam,
                        Colors.red,
                        () => _pickVideo(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // 가격 계산기
                PriceCalculator(
                  key: _priceCalculatorKey,
                  images: _selectedImages,
                  sound: _selectedSound,
                  priceController: _priceController,
                  onPriceCalculated: () {
                    // 가격 계산 완료 시 호출
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypeButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextInput() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('텍스트 입력'),
        content: TextField(
          controller: _contentController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '텍스트를 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _pickVideo() {
    // 비디오 선택 기능 (추후 구현)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('비디오 선택 기능은 추후 구현 예정입니다')),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '이미지',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedImages.isEmpty)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    '이미지 추가',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb && _selectedImages[index] is Uint8List
                              ? Image.memory(
                                  _selectedImages[index],
                                  fit: BoxFit.cover,
                                )
                              : !kIsWeb && _selectedImages[index] is File
                                  ? Image.file(
                                      _selectedImages[index],
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: Colors.grey[200],
                                      child: Icon(Icons.image, color: Colors.grey[400]),
                                    ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
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
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('이미지 추가'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSoundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.audiotrack, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '사운드',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_soundFileName.isEmpty)
          GestureDetector(
            onTap: _pickSound,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    '사운드 추가',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.audiotrack, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _soundFileName,
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _removeSound,
                  child: Icon(Icons.close, color: Colors.red[600], size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildYouTubeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.video_library, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'YouTube URL',
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
          controller: _youtubeUrlController,
          decoration: InputDecoration(
            hintText: 'YouTube URL을 입력하세요',
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

  Widget _buildTargetingInline() {
    return Column(
      children: [
        // 성별과 나이를 한 줄에 배치
        Row(
          children: [
            // 성별 선택
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '성별',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGenderButton('남', 'male', Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGenderButton('여', 'female', Colors.pink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 나이 선택
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '나이',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: RangeSlider(
                      values: _selectedAgeRange,
                      min: 18,
                      max: 65,
                      divisions: 47,
                      activeColor: Colors.orange,
                      inactiveColor: Colors.grey[300],
                      onChanged: (value) => setState(() => _selectedAgeRange = value),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedAgeRange.start.round()} - ${_selectedAgeRange.end.round()}세',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderButton(String label, String value, Color color) {
    final isSelected = _selectedGenders.contains(value);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedGenders.remove(value);
              } else {
                _selectedGenders.add(value);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        // 기능 선택
        Row(
          children: [
            Expanded(
              child: _buildCompactDropdown(
                label: '기능',
                value: _selectedFunction,
                items: _functions,
                icon: Icons.settings,
                onChanged: (value) => setState(() => _selectedFunction = value!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactDropdown(
                label: '타겟팅',
                value: _selectedTargeting,
                items: _targetingOptions,
                icon: Icons.tune,
                onChanged: (value) => setState(() => _selectedTargeting = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 체크박스 옵션들
        Column(
          children: [
            _buildCheckboxOption(
              '만료일 설정',
              _hasExpiration,
              (value) => setState(() => _hasExpiration = value!),
            ),
            _buildCheckboxOption(
              '전달 가능',
              _canTransfer,
              (value) => setState(() => _canTransfer = value!),
            ),
            _buildCheckboxOption(
              '전달 가능',
              _canForward,
              (value) => setState(() => _canForward = value!),
            ),
            _buildCheckboxOption(
              '응답 가능',
              _canRespond,
              (value) => setState(() => _canRespond = value!),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue[600],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}