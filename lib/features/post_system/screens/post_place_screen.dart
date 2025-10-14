import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// 커스텀 네모 썸 Shape (나이 텍스트 포함)
class RectangularAgeThumbShape extends RangeSliderThumbShape {
  final double thumbWidth;
  final double thumbHeight;
  final RangeValues values;

  RectangularAgeThumbShape({
    this.thumbWidth = 32,
    this.thumbHeight = 24,
    required this.values,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(thumbWidth, thumbHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool? isDiscrete,
    bool? isEnabled,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final Canvas canvas = context.canvas;

    // 네모 배경
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: thumbWidth, height: thumbHeight),
      const Radius.circular(4),
    );

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.orange
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, paint);

    // 테두리
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rect, borderPaint);

    // 어느 썸인지에 따라 다른 값 표시
    final value = thumb == Thumb.start ? values.start.toInt() : values.end.toInt();
    
    // 텍스트 페인터 생성
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 텍스트 그리기
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }
}

class PostPlaceScreen extends StatefulWidget {
  final PlaceModel place;

  const PostPlaceScreen({
    super.key,
    required this.place,
  });

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
  int _selectedPeriod = 7;
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
    _titleController.text = '';

    if (widget.place.hasLocation) {
      _currentLocation = widget.place.location;
    }
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
      if (widget.place.hasLocation) {
        setState(() {
          _currentLocation = widget.place.location;
        });
      }
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
        return Image.network(
          imageData,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else {
        return Image.file(
          File(imageData),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    } else if (imageData is Uint8List) {
      return Image.memory(
        imageData,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (imageData is File) {
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
            child: const Icon(Icons.error, size: 40, color: Colors.red),
          );
        },
      );
    }

    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentLocation == null) {
      setState(() {
        if (widget.place.hasLocation) {
          _currentLocation = widget.place.location;
          _usedRefLocation = false;
        } else {
          _currentLocation = _kRefLocation;
          _usedRefLocation = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_usedRefLocation ? '위치 정보를 가져올 수 없어 기본 참조 위치를 사용합니다.' : '배포자 위치를 사용합니다.')),
        );
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> mediaUrls = [];
      List<String> thumbnailUrls = [];
      List<String> mediaTypes = [];

      for (dynamic imagePath in _selectedImages) {
        Map<String, String> uploadResult;
        if (imagePath is File) {
          uploadResult = await _firebaseService.uploadImageWithThumbnail(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          debugPrint('Uint8List 이미지 업로드 시작: $safeName');
          uploadResult = await _firebaseService.uploadImageBytesWithThumbnail(imagePath, 'posts', safeName);
        } else {
          continue;
        }
        final originalUrl = uploadResult['original']!;
        final thumbnailUrl = uploadResult['thumbnail']!;

        debugPrint('=== 이미지 업로드 결과 ===');
        debugPrint('원본 URL: $originalUrl');
        debugPrint('썸네일 URL: $thumbnailUrl');

        mediaUrls.add(originalUrl);
        thumbnailUrls.add(thumbnailUrl);
        mediaTypes.add('image');
      }

      if (_contentController.text.trim().isNotEmpty) {
        mediaTypes.add('text');
        mediaUrls.add(_contentController.text.trim());
      }

      if (_selectedSound != null) {
        try {
          String? audioUrl;
          if (_selectedSound is Uint8List) {
            audioUrl = await _firebaseService.uploadImageFromBlob(
              _selectedSound,
              'audios',
              _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
            );
          } else if (_selectedSound is File) {
            audioUrl = await _firebaseService.uploadImage(
              _selectedSound,
              'audios',
            );
          }

          if (audioUrl != null) {
            mediaTypes.add('audio');
            mediaUrls.add(audioUrl);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('사운드 업로드 실패: $e')),
            );
          }
        }
      }

      DateTime calculatedExpiresAt;
      if (_hasExpiration) {
        calculatedExpiresAt = DateTime.now().add(Duration(days: _selectedPeriod));
      } else {
        calculatedExpiresAt = DateTime.now().add(const Duration(days: 7));
      }

      debugPrint('=== 포스트 저장 데이터 ===');
      debugPrint('mediaTypes: $mediaTypes');
      debugPrint('mediaUrls (원본): $mediaUrls');
      debugPrint('thumbnailUrls: $thumbnailUrls');

      final postId = await _postService.createPost(
        creatorId: _firebaseService.currentUser?.uid ?? '',
        creatorName: _firebaseService.currentUser?.displayName ?? '익명',
        defaultRadius: 1000,
        reward: int.tryParse(_priceController.text) ?? 0,
        targetAge: [_selectedAgeRange.start.toInt(), _selectedAgeRange.end.toInt()],
        targetGender: _getGenderFromTarget(_selectedGenders),
        targetInterest: [],
        targetPurchaseHistory: [],
        mediaType: mediaTypes,
        mediaUrl: mediaUrls,
        thumbnailUrl: thumbnailUrls,
        title: _titleController.text.trim(),
        description: '',
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: _canTransfer,
        canUse: _selectedFunction == 'Using',
        defaultExpiresAt: calculatedExpiresAt,
        placeId: widget.place.id,
        isCoupon: _selectedPostType == '쿠폰',
        youtubeUrl: _youtubeUrlController.text.trim().isNotEmpty
            ? _youtubeUrlController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 성공적으로 생성되었습니다.')),
        );

        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final fromPostDeploy = args?['fromPostDeploy'] ?? false;

        if (fromPostDeploy) {
          Navigator.pop(context, true);
        } else {
          Navigator.pop(context, true);
        }
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

  String _getGenderFromTarget(List<String> genders) {
    if (genders.isEmpty) return 'all';
    if (genders.length == 1) return genders.first;
    return 'both';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('포스트 작성'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: '디자인 프리뷰',
            onPressed: () {
              Navigator.pushNamed(context, '/post-place-design-demo');
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
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
                backgroundColor: const Color(0xFF4D4DFF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
                // 배포자 헤더
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

                      // 하단 완료 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createPost,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
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
                            backgroundColor: const Color(0xFF4D4DFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFF4D4DFF).withOpacity(0.4),
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

  Widget _buildPlaceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
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
                child: const Icon(Icons.store, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                '연결된 배포자',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.place.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (widget.place.address != null && widget.place.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.place.address!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4D4DFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF4D4DFF), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF4D4DFF)),
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
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayName,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4D4DFF)),
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
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(displayName != null ? displayName(item) : item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMediaUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이미지 업로드
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('이미지 추가'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildCrossPlatformImage(_selectedImages[index]),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
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
        const SizedBox(height: 16),

        // 사운드 업로드
        OutlinedButton.icon(
          onPressed: _pickSound,
          icon: const Icon(Icons.audiotrack),
          label: Text(_soundFileName.isEmpty ? '사운드 추가' : _soundFileName),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            side: BorderSide(color: _soundFileName.isEmpty ? Colors.grey[300]! : Colors.green),
            backgroundColor: _soundFileName.isEmpty ? null : Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_soundFileName.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _removeSound,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('사운드 제거', style: TextStyle(color: Colors.red)),
          ),
        ],
        const SizedBox(height: 16),

        // 유튜브 URL
        _buildStyledTextField(
          controller: _youtubeUrlController,
          label: '유튜브 링크 (선택)',
          icon: Icons.video_library,
          hint: 'https://www.youtube.com/watch?v=...',
        ),
      ],
    );
  }

  // ========== 새로운 컴팩트 디자인 메서드들 ==========

  Widget _buildModernPlaceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4D4DFF),
            const Color(0xFF4D4DFF).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D4DFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
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
                  widget.place.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (widget.place.address != null && widget.place.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.place.address!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          // 섹션 컨텐츠
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontSize: 14),
      validator: validator,
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    String Function(String)? displayName,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item, 
        child: Text(
          displayName != null ? displayName(item) : item, 
          style: const TextStyle(fontSize: 14),
        ),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMediaSectionWithPrice() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더 (미디어 + PriceCalculator)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.perm_media_rounded, color: Colors.purple, size: 20),
                const SizedBox(width: 10),
                Text(
                  '미디어',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                // PriceCalculator 위젯 (컴팩트 버전)
                SizedBox(
                  width: 120,
                  child: PriceCalculator(
                    key: _priceCalculatorKey,
                    images: _selectedImages,
                    sound: _selectedSound,
                    priceController: _priceController,
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ),
          // 미디어 버튼들 (4개: 이미지, 텍스트, 사운드, 영상)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.image,
                      label: '이미지',
                      count: _selectedImages.length,
                      color: Colors.blue,
                      onTap: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.text_fields,
                      label: '텍스트',
                      count: _contentController.text.isNotEmpty ? 1 : 0,
                      color: Colors.green,
                      onTap: _showTextInputDialog,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.audiotrack,
                      label: '사운드',
                      count: _selectedSound != null ? 1 : 0,
                      color: Colors.orange,
                      onTap: _pickSound,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.videocam,
                      label: '영상',
                      count: _youtubeUrlController.text.isNotEmpty ? 1 : 0,
                      color: Colors.red,
                      onTap: _showYoutubeInputDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 선택된 미디어 미리보기
          if (_selectedImages.isNotEmpty || _selectedSound != null || _contentController.text.isNotEmpty || _youtubeUrlController.text.isNotEmpty)
            _buildMediaPreview(),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // 동그라미 숫자 배지 (오른쪽 상단)
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '미리보기',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          // 이미지 미리보기
          if (_selectedImages.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildCrossPlatformImage(_selectedImages[index]),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.removeAt(index);
                                _imageNames.removeAt(index);
                              });
                              _priceCalculatorKey.currentState?.forceRecalculate();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 텍스트 미리보기
          if (_contentController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _contentController.text,
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: Colors.green.shade700),
                    onPressed: _showTextInputDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 사운드 미리보기
          if (_selectedSound != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.audiotrack, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _soundFileName,
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: Colors.orange.shade700),
                    onPressed: () {
                      setState(() {
                        _selectedSound = null;
                        _soundFileName = '';
                      });
                      _priceCalculatorKey.currentState?.forceRecalculate();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // YouTube 미리보기
          if (_youtubeUrlController.text.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.videocam, size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _youtubeUrlController.text,
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 16, color: Colors.red.shade700),
                    onPressed: _showYoutubeInputDialog,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTextInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('텍스트 입력'),
        content: TextField(
          controller: _contentController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '포스트 내용을 입력하세요',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _contentController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showYoutubeInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('YouTube URL 입력'),
        content: TextField(
          controller: _youtubeUrlController,
          decoration: const InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _youtubeUrlController.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetingInline() {
    return Column(
      children: [
        Row(
          children: [
            // 성별 선택
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      const Text('성별', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _buildGenderChipCompact('남', 'male', Colors.blue)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildGenderChipCompact('여', 'female', Colors.pink)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 나이 범위
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cake, size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      const Text('나이', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 40, // 성별 칩과 동일한 높이
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: _buildAgeRangeSlider(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeRangeSlider() {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: Colors.orange.shade400,
        inactiveTrackColor: Colors.orange.shade200,
        thumbColor: Colors.orange.shade600,
        overlayColor: Colors.transparent,
        trackHeight: 3,
        rangeThumbShape: RectangularAgeThumbShape(
          thumbWidth: 32,
          thumbHeight: 24,
          values: _selectedAgeRange,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
      ),
      child: RangeSlider(
        values: _selectedAgeRange,
        min: 10,
        max: 90,
        divisions: 80,
        onChanged: (range) {
          setState(() {
            _selectedAgeRange = range;
          });
        },
      ),
    );
  }

  Widget _buildGenderChipCompact(String label, String value, Color color) {
    final isSelected = _selectedGenders.contains(value);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_selectedGenders.length > 1) {
              _selectedGenders.remove(value);
            }
          } else {
            _selectedGenders.add(value);
          }
        });
      },
      child: Container(
        height: 40, // 나이 박스와 동일한 높이
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        // 타겟팅 레벨과 기능
        _buildCompactDropdown(
          label: '타겟팅 레벨',
          value: _selectedTargeting,
          items: _targetingOptions,
          icon: Icons.adjust,
          onChanged: (value) => setState(() => _selectedTargeting = value!),
        ),
        const SizedBox(height: 12),
        _buildCompactDropdown(
          label: '기능',
          value: _selectedFunction,
          items: _functions,
          icon: Icons.settings,
          onChanged: (value) => setState(() => _selectedFunction = value!),
          displayName: _getFunctionDisplayName,
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        // 체크박스 옵션들
        _buildOptionRow('기한 설정', _hasExpiration, (v) => setState(() => _hasExpiration = v), Icons.schedule),
        const Divider(height: 20),
        _buildOptionRow('전달 가능', _canForward, (v) => setState(() => _canForward = v), Icons.forward),
        const Divider(height: 20),
        _buildOptionRow('응답 가능', _canRespond, (v) => setState(() => _canRespond = v), Icons.reply),
        const Divider(height: 20),
        _buildOptionRow('송금 요청', _canTransfer, (v) => setState(() => _canTransfer = v), Icons.attach_money),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        // 배포 기간 안내
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '배포 기간은 지도에서 마커를 뿌릴 때 설정됩니다',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow(String label, bool value, Function(bool) onChanged, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: value ? const Color(0xFF4D4DFF) : Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: value ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4D4DFF),
          ),
        ),
      ],
    );
  }

  // ========== 기존 메서드 ==========

  String _getFunctionDisplayName(String function) {
    switch (function) {
      case 'Using':
        return '사용하기';
      case 'Selling':
        return '팔기';
      case 'Buying':
        return '사기';
      case 'Sharing':
        return '나누기';
      default:
        return function;
    }
  }
}
