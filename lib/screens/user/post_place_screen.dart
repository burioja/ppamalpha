import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import '../../models/place_model.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';

class PostPlaceScreen extends StatefulWidget {
  final PlaceModel place;
  
  const PostPlaceScreen({
    Key? key,
    required this.place,
  }) : super(key: key);

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
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _priceController = TextEditingController();
  final _amountController = TextEditingController();
  final _periodController = TextEditingController();
  final _soundController = TextEditingController();
  
  // 선택된 값들
  String _selectedFunction = 'Using';
  String _selectedPeriodUnit = 'Hour';
  String _selectedTarget = '상관없음/상관없음';
  int _selectedAgeMin = 20;
  int _selectedAgeMax = 30;
  
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
  List<dynamic> _selectedImages = []; // File 또는 Uint8List
  List<String> _imageNames = []; // 이미지 이름 저장
  
  // 로딩 상태
  bool _isLoading = false;
  bool _isLocationLoading = false;
  bool _usedRefLocation = false;
  
  // 위치 정보
  GeoPoint? _currentLocation;
  
  // 함수 옵션들
  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  final List<String> _periodUnits = ['Hour', 'Day', 'Week', 'Month'];
  final List<String> _targets = [
    '상관없음/상관없음',
    '남성/남성',
    '여성/여성',
    '남성/여성',
    '여성/남성',
  ];
  
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
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _initializeForm() {
    // 플레이스 정보로 기본값 설정
    _titleController.text = '${widget.place.name} 관련 포스트';
    _descriptionController.text = widget.place.description;
    
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
      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        setState(() {
          _currentLocation = location;
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
    _descriptionController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _amountController.dispose();
    _periodController.dispose();
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
    // 웹용 이미지 선택 (file_picker 대신 input element 사용)
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    
    input.click();
    
    await input.onChange.first;
    
    if (input.files != null) {
      for (final file in input.files!) {
        if (file.size > 10 * 1024 * 1024) { // 10MB 제한
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')),
            );
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
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'audio/*'
      ..multiple = false;
    
    input.click();
    
    await input.onChange.first;
    
    if (input.files != null && input.files!.isNotEmpty) {
      final file = input.files!.first;
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
          _selectedSound = file;
          _soundFileName = file.name;
        });
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
      // 이미지 업로드
      List<String> imageUrls = [];
      List<String> mediaTypes = [];
      
      for (dynamic imagePath in _selectedImages) {
        String url;
        if (imagePath is File) {
          url = await _firebaseService.uploadImage(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          url = await _firebaseService.uploadImageDataUrl(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          // 바이트 데이터는 임시로 data URL로 변환하지 않고 건너뜀 또는 별도 처리 필요
          // 현재는 건너뜁니다.
          continue;
        } else {
          // 지원하지 않는 타입은 건너뜀
          continue;
        }
        imageUrls.add(url);
        mediaTypes.add('image');
      }

      // 텍스트 콘텐츠가 있는 경우 추가
      if (_contentController.text.trim().isNotEmpty) {
        mediaTypes.add('text');
        imageUrls.add(_contentController.text.trim());
      }

      // 사운드 업로드
      if (_selectedSound != null) {
        try {
          String audioUrl;
          if (kIsWeb) {
            audioUrl = await _firebaseService.uploadImageFromBlob(
              _selectedSound,
              'audios',
              _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
            );
          } else {
            audioUrl = await _firebaseService.uploadImage(
              _selectedSound as File,
              'audios',
            );
          }
          mediaTypes.add('audio');
          imageUrls.add(audioUrl);
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
        final int period = int.tryParse(_periodController.text) ?? 0;
        Duration delta;
        switch (_selectedPeriodUnit) {
          case 'Hour':
            delta = Duration(hours: period);
            break;
          case 'Day':
            delta = Duration(days: period);
            break;
          case 'Week':
            delta = Duration(days: period * 7);
            break;
          case 'Month':
            delta = Duration(days: period * 30);
            break;
          default:
            delta = const Duration(days: 7);
        }
        calculatedExpiresAt = DateTime.now().add(delta);
      } else {
        calculatedExpiresAt = DateTime.now().add(const Duration(days: 7));
      }

      // 포스트 모델 생성
      final post = PostModel(
        flyerId: '', // Firestore에서 자동 생성
        creatorId: _firebaseService.currentUser?.uid ?? '',
        creatorName: _firebaseService.currentUser?.displayName ?? '익명',
        location: _currentLocation!,
        radius: 1000, // 기본 반경 1km
        createdAt: DateTime.now(),
        expiresAt: calculatedExpiresAt,
        reward: int.tryParse(_priceController.text) ?? 0,
        targetAge: [_selectedAgeMin, _selectedAgeMax],
        targetGender: _getGenderFromTarget(_selectedTarget),
        targetInterest: [], // TODO: 사용자 관심사 연동
        targetPurchaseHistory: [], // TODO: 사용자 구매 이력 연동
        mediaType: mediaTypes,
        mediaUrl: imageUrls,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: _canTransfer,
        canUse: _selectedFunction == 'Using',
        placeId: widget.place.id, // 플레이스 ID 연결
      );

      // 포스트 저장
      await _postService.createPost(post);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 성공적으로 생성되었습니다.')),
        );
        Navigator.pop(context, true);
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

  String _getGenderFromTarget(String target) {
    if (target.contains('남성')) return 'male';
    if (target.contains('여성')) return 'female';
    return 'all';
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
              
              // PRD2.md 요구사항에 따른 UI 구성
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
                controller: _descriptionController,
                label: '설명',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '설명을 입력해주세요.';
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
              _buildTargetDropdown(),
              const SizedBox(height: 16),
              _buildAgeRange(),
              const SizedBox(height: 24),

              // 가격 및 수량 섹션
              _buildSectionTitle('가격 및 수량'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _priceController,
                      label: '가격',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _amountController,
                      label: '수량',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _periodController,
                      label: '기간',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPeriodUnitDropdown(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildTotalPrice(),
              const SizedBox(height: 24),

              // 이미지 섹션 제거됨 (상단 '미디어 업로드'에 통합)

              // 위치 정보 섹션
              _buildSectionTitle('위치 정보'),
              _buildLocationInfo(),
              const SizedBox(height: 32),
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
      value: _selectedFunction,
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

  Widget _buildTargetDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTarget,
      decoration: const InputDecoration(
        labelText: '타겟',
        border: OutlineInputBorder(),
      ),
      items: _targets.map((String target) {
        return DropdownMenuItem<String>(
          value: target,
          child: Text(target),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedTarget = newValue!;
        });
      },
    );
  }

  Widget _buildAgeRange() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedAgeMin,
            decoration: const InputDecoration(
              labelText: '최소 나이',
              border: OutlineInputBorder(),
            ),
            items: List.generate(81, (index) => index + 10).map((int age) {
              return DropdownMenuItem<int>(
                value: age,
                child: Text('$age세'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              setState(() {
                _selectedAgeMin = newValue!;
                if (_selectedAgeMax < _selectedAgeMin) {
                  _selectedAgeMax = _selectedAgeMin;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: DropdownButtonFormField<int>(
            value: _selectedAgeMax,
            decoration: const InputDecoration(
              labelText: '최대 나이',
              border: OutlineInputBorder(),
            ),
            items: List.generate(81, (index) => index + 10)
                .where((age) => age >= _selectedAgeMin)
                .map((int age) {
              return DropdownMenuItem<int>(
                value: age,
                child: Text('$age세'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              setState(() {
                _selectedAgeMax = newValue!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedPeriodUnit,
      decoration: const InputDecoration(
        labelText: '기간 단위',
        border: OutlineInputBorder(),
      ),
      items: _periodUnits.map((String unit) {
        return DropdownMenuItem<String>(
          value: unit,
          child: Text(_getPeriodUnitDisplayName(unit)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedPeriodUnit = newValue!;
        });
      },
    );
  }

  String _getPeriodUnitDisplayName(String unit) {
    switch (unit) {
      case 'Hour':
        return '시간';
      case 'Day':
        return '일';
      case 'Week':
        return '주';
      case 'Month':
        return '월';
      default:
        return unit;
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

  // 총액 표시 (가격 × 수량)
  Widget _buildTotalPrice() {
    int price = int.tryParse(_priceController.text) ?? 0;
    int amount = int.tryParse(_amountController.text) ?? 0;
    int total = price * amount;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '총액: ${total.toString()}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
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