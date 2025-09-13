import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'dart:convert';

import '../../models/place_model.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../widgets/range_slider_with_input.dart';
import '../../widgets/gender_checkbox_group.dart';
import '../../widgets/period_slider_with_input.dart';
import '../../widgets/price_calculator.dart';

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
  final _postService = PostService();
  final _firebaseService = FirebaseService();
  static const GeoPoint _kRefLocation = GeoPoint(37.5665, 126.9780); // 기본 참조 위치 (서울시청 인근)
  
  // 폼 컨트롤러들
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final _soundController = TextEditingController();
  
  // 선택된 값들
  String _selectedFunction = 'Using';
  int _selectedPeriod = 7; // 기본 7일
  List<String> _selectedGenders = ['male', 'female']; // 기본 남성/여성 모두
  RangeValues _selectedAgeRange = const RangeValues(20, 30);
  
  // PRD2.md 요구사항 추가
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
  final List<dynamic> _selectedImages = []; // File 또는 Uint8List
  final List<String> _imageNames = []; // 이미지 이름 저장
  
  // 로딩 상태
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _usedRefLocation = false;
  
  // 위치 정보
  GeoPoint? _currentLocation;
  
  // 함수 옵션들
  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  
  // PRD2.md 요구사항 옵션들
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
    // 플레이스 정보로 기본값 설정
    _titleController.text = '${widget.place.name} 관련 포스트';
    
    // 플레이스 위치를 기본 위치로 설정
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
      // 위치를 가져올 수 없는 경우 플레이스 위치 사용
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        // 웹에서는 file_picker 사용
        await _pickImageWeb();
      } else {
        // 모바일에서는 image_picker 사용
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
      // 웹에서는 file_picker 사용
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) { // 10MB 제한
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')),
              );
            }
            continue;
          }
          
          if (mounted) {
            setState(() {
              // 웹에서는 항상 bytes를 사용
              if (file.bytes != null) {
                _selectedImages.add(file.bytes!);
              }
              _imageNames.add(file.name);
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
        if (file.size > 50 * 1024 * 1024) { // 50MB 제한
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')),
            );
          }
          return;
        }
        
        if (mounted) {
          setState(() {
            // 웹에서는 항상 bytes를 사용
            if (file.bytes != null) {
              _selectedSound = file.bytes!;
            }
            _soundFileName = file.name;
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
        }
      }
    }
  }

  void _removeSound() {
    setState(() {
      _selectedSound = null;
      _soundFileName = '';
    });
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  Widget _buildCrossPlatformImage(dynamic imageData) {
    if (imageData is String) {
      // 웹에서 파일 경로인 경우
      if (imageData.startsWith('data:image/')) {
        // Base64 이미지
        return Image.memory(
          base64Decode(imageData.split(',')[1]),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else if (imageData.startsWith('http')) {
        // 네트워크 이미지
        return Image.network(
          imageData,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else {
        // 로컬 파일 경로 (모바일)
        return Image.file(
          File(imageData),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    } else if (imageData is Uint8List) {
      // 웹에서 바이트 데이터
      return Image.memory(
        imageData,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (imageData is File) {
      // 모바일에서 File 객체
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
    
    // 기본 이미지
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
      // 매체 데이터 초기화
      List<String> mediaUrls = []; // 전체 미디어 URL (이미지 원본 + 텍스트 + 오디오)
      List<String> thumbnailUrls = []; // 이미지 썸네일만
      List<String> mediaTypes = []; // 매체 타입
      
      for (dynamic imagePath in _selectedImages) {
        Map<String, String> uploadResult;
        if (imagePath is File) {
          uploadResult = await _firebaseService.uploadImageWithThumbnail(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          // 웹에서 선택된 바이트 데이터 - 원본과 썸네일 분리 업로드
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          debugPrint('Uint8List 이미지 업로드 시작: $safeName');
          uploadResult = await _firebaseService.uploadImageBytesWithThumbnail(imagePath, 'posts', safeName);
        } else {
          // 지원하지 않는 타입은 건너뜀
          continue;
        }
        final originalUrl = uploadResult['original']!;
        final thumbnailUrl = uploadResult['thumbnail']!;
        
        // 디버그 로깅
        debugPrint('=== 이미지 업로드 결과 ===');
        debugPrint('원본 URL: $originalUrl');
        debugPrint('썸네일 URL: $thumbnailUrl');
        debugPrint('원본에 /original/ 포함: ${originalUrl.contains('/original/')}');
        debugPrint('썸네일에 /thumbnails/ 포함: ${thumbnailUrl.contains('/thumbnails/')}');
        
        mediaUrls.add(originalUrl); // 원본 이미지 URL
        thumbnailUrls.add(thumbnailUrl); // 썸네일 URL
        mediaTypes.add('image');
      }

      // 텍스트 콘텐츠가 있는 경우 추가
      if (_contentController.text.trim().isNotEmpty) {
        mediaTypes.add('text');
        mediaUrls.add(_contentController.text.trim()); // 텍스트는 mediaUrls에만 추가
        // thumbnailUrls에는 추가하지 않음 (인덱스 맞춤을 위해)
      }

      // 사운드 업로드
      if (_selectedSound != null) {
        try {
          String? audioUrl;
          if (_selectedSound is Uint8List) {
            // 웹에서 선택된 바이트 데이터 처리
            audioUrl = await _firebaseService.uploadImageFromBlob(
              _selectedSound,
              'audios',
              _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
            );
          } else if (_selectedSound is File) {
            // 모바일에서 선택된 파일 처리
            audioUrl = await _firebaseService.uploadImage(
              _selectedSound,
              'audios',
            );
          }
          
          // audioUrl이 성공적으로 생성된 경우에만 추가
          if (audioUrl != null) {
            mediaTypes.add('audio');
            mediaUrls.add(audioUrl); // 오디오 URL
          }
        } catch (e) {
          // 사운드 업로드 실패는 치명적이지 않으므로 경고만 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('사운드 업로드 실패: $e')),
            );
          }
        }
      }

      // 만료기간 계산
      DateTime calculatedExpiresAt;
      if (_hasExpiration) {
        calculatedExpiresAt = DateTime.now().add(Duration(days: _selectedPeriod));
      } else {
        calculatedExpiresAt = DateTime.now().add(const Duration(days: 7));
      }

      // 저장 전 데이터 검증 로깅
      debugPrint('=== 포스트 저장 데이터 ===');
      debugPrint('mediaTypes: $mediaTypes');
      debugPrint('mediaUrls (원본): $mediaUrls');
      debugPrint('thumbnailUrls: $thumbnailUrls');
      debugPrint('mediaTypes.length: ${mediaTypes.length}');
      debugPrint('mediaUrls.length: ${mediaUrls.length}');
      debugPrint('thumbnailUrls.length: ${thumbnailUrls.length}');
      
      for (int i = 0; i < mediaTypes.length && i < mediaUrls.length; i++) {
        debugPrint('[$i] type=${mediaTypes[i]}, url=${mediaUrls[i]}');
        if (mediaTypes[i] == 'image' && i < thumbnailUrls.length) {
          debugPrint('[$i] thumbnail=${thumbnailUrls[i]}');
        }
      }
      
      // 포스트 저장 (createPost 메서드 사용)
      final postId = await _postService.createPost(
        creatorId: _firebaseService.currentUser?.uid ?? '',
        creatorName: _firebaseService.currentUser?.displayName ?? '익명',
        location: _currentLocation!,
        radius: 1000, // 기본 반경 1km
        reward: int.tryParse(_priceController.text) ?? 0,
        targetAge: [_selectedAgeRange.start.toInt(), _selectedAgeRange.end.toInt()],
        targetGender: _getGenderFromTarget(_selectedGenders),
        targetInterest: [], // TODO: 사용자 관심사 연동
        targetPurchaseHistory: [], // TODO: 사용자 구매 이력 연동
        mediaType: mediaTypes,
        mediaUrl: mediaUrls, // 원본 이미지 + 텍스트 + 오디오
        thumbnailUrl: thumbnailUrls,
        title: _titleController.text.trim(),
        description: '', // 설명 필드 제거
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: _canTransfer,
        canUse: _selectedFunction == 'Using',
        expiresAt: calculatedExpiresAt,
        isSuperPost: false, // 일반 포스트
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 성공적으로 생성되었습니다.')),
        );
        
        // PostDeployScreen에서 온 경우와 일반적인 경우를 구분
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final fromPostDeploy = args?['fromPostDeploy'] ?? false;
        
        if (fromPostDeploy) {
          // PostDeployScreen에서 온 경우: PostDeployScreen으로 돌아가기
          Navigator.pop(context, true);
        } else {
          // 일반적인 경우: 이전 화면으로 돌아가기
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
    return 'both'; // 남성/여성 모두
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.place.name}에서 포스트 작성'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('작성'),
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
              // 플레이스 정보 표시
              _buildPlaceInfo(),
              const SizedBox(height: 24),
              
              // 포스트 기본 정보
              _buildSectionTitle('포스트 기본 정보'),
              _buildTextField(
                controller: _titleController,
                label: '제목',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contentController,
                label: '내용 (선택사항)',
                maxLines: 5,
              ),
              const SizedBox(height: 16),
              
              // 포스트 타입 선택
              _buildDropdown(
                label: '포스트 타입',
                value: _selectedPostType,
                items: _postTypes,
                onChanged: (value) {
                  setState(() {
                    _selectedPostType = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 미디어 업로드 섹션
              _buildSectionTitle('미디어 업로드'),
              _buildImageUpload(),
              const SizedBox(height: 16),
              _buildSoundUpload(),
              const SizedBox(height: 24),

              // 기능 옵션 섹션
              _buildSectionTitle('기능 옵션'),
              _buildCheckboxOption(
                title: '소멸시효',
                value: _hasExpiration,
                onChanged: (value) {
                  setState(() {
                    _hasExpiration = value!;
                  });
                },
              ),
              _buildCheckboxOption(
                title: '송금 기능',
                value: _canTransfer,
                onChanged: (value) {
                  setState(() {
                    _canTransfer = value!;
                  });
                },
              ),
              _buildCheckboxOption(
                title: '전달 기능',
                value: _canForward,
                onChanged: (value) {
                  setState(() {
                    _canForward = value!;
                  });
                },
              ),
              _buildCheckboxOption(
                title: '응답 기능',
                value: _canRespond,
                onChanged: (value) {
                  setState(() {
                    _canRespond = value!;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 타겟팅 옵션
              _buildSectionTitle('타겟팅 옵션'),
              _buildDropdown(
                label: '타겟팅 레벨',
                value: _selectedTargeting,
                items: _targetingOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedTargeting = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildFunctionDropdown(),
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
              const SizedBox(height: 24),

              // 단가 및 기간 섹션
              _buildSectionTitle('단가 및 기간'),
              PriceCalculator(
                images: _selectedImages,
                sound: _selectedSound,
                priceController: _priceController,
              ),
              const SizedBox(height: 16),
              PeriodSliderWithInput(
                initialValue: _selectedPeriod,
                onChanged: (period) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                },
              ),
              const SizedBox(height: 24),

              // 이미지 섹션 제거됨 (상단 '미디어 업로드'에 통합)

              // 위치 정보 섹션
              _buildSectionTitle('위치 정보'),
              _buildLocationInfo(),
              const SizedBox(height: 32),
              
              // 하단 완료 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createPost,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    _isLoading ? '포스트 작성 중...' : '포스트 작성 완료',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4D4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  Widget _buildPlaceInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                '플레이스 정보',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.place.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.place.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.place.description,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
          if (widget.place.address != null && widget.place.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.place.address!,
                    style: TextStyle(
                      color: Colors.grey[600],
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildFunctionDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedFunction,
      decoration: const InputDecoration(
        labelText: '기능',
        border: OutlineInputBorder(),
      ),
      items: _functions.map((String function) {
        return DropdownMenuItem<String>(
          value: function,
          child: Text(_getFunctionDisplayName(function)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedFunction = newValue!;
        });
      },
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







  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('이미지 추가'),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
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
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
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
        ],
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLocationLoading) ...[
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('위치 정보를 가져오는 중...'),
            ],
          ),
        ] else if (_currentLocation != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '위치 정보 확인됨',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: Colors.red[600]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('위치 정보를 가져올 수 없습니다.'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '플레이스 위치를 기준으로 포스트가 생성됩니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 공통 드롭다운 위젯 (String 전용)
  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  // 미디어 업로드 - 이미지 (기존 이미지 피커를 래핑)
  Widget _buildImageUpload() {
    return _buildImagePicker();
  }

  // 미디어 업로드 - 사운드
  Widget _buildSoundUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _pickSound,
          icon: const Icon(Icons.audiotrack),
          label: const Text('사운드 선택'),
        ),
        if (_soundFileName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _soundFileName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _removeSound,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('제거'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }



  // 공통 체크박스 옵션 위젯
  Widget _buildCheckboxOption({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
} 