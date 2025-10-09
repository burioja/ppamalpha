import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'dart:convert';

import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';

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
    _titleController.text = '${widget.place.name} 관련 포스트';

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
          SnackBar(content: Text(_usedRefLocation ? '위치 정보를 가져올 수 없어 기본 참조 위치를 사용합니다.' : '플레이스 위치를 사용합니다.')),
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('포스트 작성'),
        backgroundColor: const Color(0xFF4D4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _createPost,
              icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, color: Colors.white),
              label: const Text('완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 플레이스 정보 카드
              _buildPlaceInfoCard(),
              const SizedBox(height: 20),

              // 포스트 기본 정보
              _buildSectionCard(
                title: '기본 정보',
                icon: Icons.edit_note,
                children: [
                  _buildStyledTextField(
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
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _contentController,
                    label: '내용 (선택사항)',
                    icon: Icons.description,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledDropdown(
                    label: '포스트 타입',
                    value: _selectedPostType,
                    items: _postTypes,
                    icon: Icons.category,
                    onChanged: (value) {
                      setState(() {
                        _selectedPostType = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 미디어 업로드
              _buildSectionCard(
                title: '미디어',
                icon: Icons.perm_media,
                children: [
                  _buildMediaUpload(),
                ],
              ),
              const SizedBox(height: 20),

              // 타겟팅 옵션
              _buildSectionCard(
                title: '타겟팅 설정',
                icon: Icons.people,
                children: [
                  _buildStyledDropdown(
                    label: '타겟팅 레벨',
                    value: _selectedTargeting,
                    items: _targetingOptions,
                    icon: Icons.adjust,
                    onChanged: (value) {
                      setState(() {
                        _selectedTargeting = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildStyledDropdown(
                    label: '기능',
                    value: _selectedFunction,
                    items: _functions,
                    icon: Icons.settings,
                    onChanged: (value) {
                      setState(() {
                        _selectedFunction = value!;
                      });
                    },
                    displayName: _getFunctionDisplayName,
                  ),
                  const SizedBox(height: 16),
                  GenderCheckboxGroup(
                    selectedGenders: _selectedGenders,
                    onChanged: (genders) {
                      setState(() {
                        _selectedGenders = genders;
                      });
                    },
                    validator: (genders) {
                      if (genders.isEmpty) {
                        return '최소 하나의 성별을 선택해야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  RangeSliderWithInput(
                    label: '나이 범위',
                    initialValues: _selectedAgeRange,
                    min: 10,
                    max: 90,
                    divisions: 80,
                    onChanged: (range) {
                      setState(() {
                        _selectedAgeRange = range;
                      });
                    },
                    labelBuilder: (value) => '${value.toInt()}세',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 단가 섹션
              _buildSectionCard(
                title: '단가',
                icon: Icons.monetization_on,
                children: [
                  PriceCalculator(
                    key: _priceCalculatorKey,
                    images: _selectedImages,
                    sound: _selectedSound,
                    priceController: _priceController,
                  ),
                  const SizedBox(height: 12),
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
                '연결된 플레이스',
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
