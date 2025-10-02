import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';
import 'post_place_selection_screen.dart';

class PostEditScreen extends StatefulWidget {
  final PostModel post;

  const PostEditScreen({super.key, required this.post});

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _postService = PostService();
  final _firebaseService = FirebaseService();

  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late final TextEditingController _contentController;

  bool _canRespond = false;
  bool _canForward = false;
  bool _canRequestReward = true;

  bool _isSaving = false;

  // Targeting - 새로운 형태
  List<String> _selectedGenders = ['male', 'female'];
  RangeValues _selectedAgeRange = const RangeValues(20, 30);
  
  // Period - 새로운 형태
  int _selectedPeriod = 7;

  // Function
  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  String _selectedFunction = 'Using';

  // Media
  final List<dynamic> _selectedImages = [];
  final List<String> _imageNames = [];
  final List<Map<String, String>> _existingMedia = [];
  String _existingAudioUrl = '';
  dynamic _selectedSound;
  String _soundFileName = '';

  // Place
  String? _selectedPlaceId;
  PlaceModel? _selectedPlace;

  @override
  void initState() {
    super.initState();

    // 수정 권한 확인 - 배포되거나 만료된 포스트는 수정 불가
    if (!widget.post.canEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCannotEditDialog();
      });
      return;
    }

    _titleController = TextEditingController(text: widget.post.title);
    _rewardController = TextEditingController(text: widget.post.reward.toString());
    _contentController = TextEditingController(text: _extractExistingTextContent());
    _canRespond = widget.post.canRespond;
    _canForward = widget.post.canForward;
    _canRequestReward = widget.post.canRequestReward;

    // Place 초기화
    _selectedPlaceId = widget.post.placeId;
    if (_selectedPlaceId != null && _selectedPlaceId!.isNotEmpty) {
      _loadPlace(_selectedPlaceId!);
    }

    _initTargetingFromPost();
    _initFunctionFromPost();
    _initPeriodFromPost();
    _initExistingMedia();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // TODO: 마커 배포 여부 쿼리로 대체
    final isDistributed = false; // 임시: 공백 포스트는 모두 수정 가능
    if (isDistributed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배포된 포스트는 수정할 수 없습니다.')),
        );
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() { _isSaving = true; });
    try {
      final int reward = int.tryParse(_rewardController.text.trim()) ?? widget.post.reward;

      // Build media arrays
      final List<String> mediaTypes = [];
      final List<String> mediaUrls = [];

      // Keep existing non-text media (except audio if replacing)
      for (final item in _existingMedia) {
        mediaTypes.add(item['type']!);
        mediaUrls.add(item['url']!);
      }

      // Existing audio retained
      if (_existingAudioUrl.isNotEmpty && _selectedSound == null) {
        mediaTypes.add('audio');
        mediaUrls.add(_existingAudioUrl);
      }

      // Upload new images with thumbnails
      for (final dynamic imagePath in _selectedImages) {
        Map<String, String> uploadResult;
        if (imagePath is File) {
          uploadResult = await _firebaseService.uploadImageWithThumbnail(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          // Web에서 선택된 이미지 (bytes)를 업로드
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageBytesWithThumbnail(imagePath, 'posts', safeName);
        } else {
          continue;
        }
        mediaTypes.add('image');
        mediaUrls.add(uploadResult['original']!);
        // Note: thumbnailUrl handling would need additional logic for post editing
      }

      // Upload new audio if selected
      if (_selectedSound != null) {
        String audioUrl;
        if (kIsWeb && _selectedSound is Uint8List) {
          // Web에서 선택된 오디오 (bytes)를 업로드
          final safeName = _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3';
          audioUrl = await _firebaseService.uploadAudioBytes(
            _selectedSound as Uint8List,
            'audios',
            safeName,
          );
        } else if (_selectedSound is File) {
          audioUrl = await _firebaseService.uploadImage(
            _selectedSound as File,
            'audios',
          );
        } else {
          // Legacy blob handling
          audioUrl = await _firebaseService.uploadImageFromBlob(
            _selectedSound,
            'audios',
            _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
        }
        mediaTypes.add('audio');
        mediaUrls.add(audioUrl);
      }

      // Text content
      final content = _contentController.text.trim();
      if (content.isNotEmpty) {
        mediaTypes.add('text');
        mediaUrls.add(content);
      }

      // Compute expiresAt
      final Duration delta = Duration(days: _selectedPeriod);
      final DateTime newExpiresAt = DateTime.now().add(delta);

      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': '', // 설명 필드 제거
        'reward': reward,
        'canRespond': _canRespond,
        'canForward': _canForward,
        'canRequestReward': _canRequestReward,
        'canUse': _selectedFunction == 'Using',
        'targetGender': _getGenderFromTarget(_selectedGenders),
        'targetAge': [_selectedAgeRange.start.toInt(), _selectedAgeRange.end.toInt()],
        'mediaType': mediaTypes,
        'mediaUrl': mediaUrls,
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'updatedAt': DateTime.now(),
        'placeId': _selectedPlaceId, // 플레이스 ID 추가
      };

      debugPrint('🔄 포스트 수정 데이터:');
      debugPrint('  - postId: ${widget.post.postId}');
      debugPrint('  - targetAge: ${updates['targetAge']}');
      debugPrint('  - targetGender: ${updates['targetGender']}');
      debugPrint('  - _selectedAgeRange: ${_selectedAgeRange.start.toInt()}-${_selectedAgeRange.end.toInt()}');
      debugPrint('  - _selectedGenders: $_selectedGenders');

      await _postService.updatePost(widget.post.postId, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 수정되었습니다.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포스트 수정'),
        actions: [
          TextButton(
            onPressed: _isSaving || !widget.post.canEdit ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.post.canEdit)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${widget.post.status.name} 상태의 포스트는 수정할 수 없습니다.', style: TextStyle(color: Colors.red.shade800))),
                    ],
                  ),
                ),
              _buildSectionTitle('포스트 기본 정보'),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해주세요.' : null,
                enabled: true, // TODO: 마커 배포 여부로 대체
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '내용 (선택사항)', border: OutlineInputBorder()),
                maxLines: 5,
                enabled: true, // TODO: 마커 배포 여부로 대체
              ),
              const SizedBox(height: 16),
              _buildFunctionDropdown(),
              const SizedBox(height: 24),
              _buildSectionTitle('미디어 업로드'),
              _buildImageUpload(),
              const SizedBox(height: 12),
              _buildExistingMediaList(),
              const SizedBox(height: 16),
              _buildSoundUpload(),
              const SizedBox(height: 24),
              _buildSectionTitle('연결된 스토어'),
              _buildPlaceSelection(),
              const SizedBox(height: 24),
              _buildSectionTitle('기능 옵션'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('응답 허용'),
                value: _canRespond,
                onChanged: (v) { setState(() { _canRespond = v ?? false; }); }, // TODO: 마커 배포 여부로 대체
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('전달 허용'),
                value: _canForward,
                onChanged: (v) { setState(() { _canForward = v ?? false; }); }, // TODO: 마커 배포 여부로 대체
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('리워드 수령 허용'),
                value: _canRequestReward,
                onChanged: (v) { setState(() { _canRequestReward = v ?? true; }); }, // TODO: 마커 배포 여부로 대체
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('타겟팅 옵션'),
              GenderCheckboxGroup(
                selectedGenders: _selectedGenders,
                onChanged: (genders) {
                  // TODO: 마커 배포 여부로 대체
                  if (!false) {
                    setState(() {
                      _selectedGenders = genders;
                    });
                  }
                },
                validator: (genders) {
                  if (genders.isEmpty) {
                    return '최소 하나의 성별을 선택해주세요.';
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
                }, // TODO: 마커 배포 여부로 대체
                labelBuilder: (value) => '${value.toInt()}세',
                validator: (range) {
                  if (range.start < 10 || range.end > 90) {
                    return '10~90 사이의 값을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('단가'),
              PriceCalculator(
                images: _selectedImages,
                sound: _selectedSound,
                priceController: _rewardController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '단가를 입력해주세요.';
                  }
                  final price = int.tryParse(value.trim());
                  if (price == null || price <= 0) {
                    return '올바른 단가를 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // 배포된 포스트인지 여부에 따라 다른 안내 메시지 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, // TODO: 마커 배포 여부로 대체
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.shade200, // TODO: 마커 배포 여부로 대체
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline, // TODO: 마커 배포 여부로 대체
                      color: Colors.blue.shade600, // TODO: 마커 배포 여부로 대체
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '배포 기간은 지도에서 마커를 뿌릴 때 설정됩니다', // TODO: 마커 배포 여부로 대체
                        style: TextStyle(
                          color: Colors.blue.shade700, // TODO: 마커 배포 여부로 대체
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildReadonlyInfo('생성일', widget.post.createdAt),
              _buildReadonlyInfo('기본 만료일', widget.post.defaultExpiresAt),
              // TODO: 위치는 템플릿에서 제거됨, 배포된 마커에서 확인
              _buildReadonlyInfo('위치', '템플릿 - 배포 시 설정됨'),
              
              const SizedBox(height: 32),
              // 하단 완료 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || !widget.post.canEdit ? null : _save,
                  icon: _isSaving
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
                    _isSaving ? '수정 중...' : '포스트 수정 완료',
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

  // Initialization helpers
  void _initTargetingFromPost() {
    // 나이 범위 초기화
    final ageMin = widget.post.targetAge.isNotEmpty ? widget.post.targetAge[0].toDouble() : 20.0;
    final ageMax = widget.post.targetAge.length > 1 ? widget.post.targetAge[1].toDouble() : ageMin;
    _selectedAgeRange = RangeValues(ageMin, ageMax);
    
    // 성별 초기화
    switch (widget.post.targetGender) {
      case 'male':
        _selectedGenders = ['male'];
        break;
      case 'female':
        _selectedGenders = ['female'];
        break;
      default:
        _selectedGenders = ['male', 'female'];
    }
  }

  void _initFunctionFromPost() {
    _selectedFunction = widget.post.canUse ? 'Using' : 'Selling';
  }

  void _initPeriodFromPost() {
    final now = DateTime.now();
    if (widget.post.defaultExpiresAt.isAfter(now)) {
      final diff = widget.post.defaultExpiresAt.difference(now);
      _selectedPeriod = diff.inDays.clamp(1, 30);
    } else {
      _selectedPeriod = 7; // 기본값
    }
  }

  void _initExistingMedia() {
    String textCaptured = '';
    for (int i = 0; i < widget.post.mediaType.length && i < widget.post.mediaUrl.length; i++) {
      final type = widget.post.mediaType[i];
      final url = widget.post.mediaUrl[i];
      if (type == 'text') {
        if (textCaptured.isEmpty) textCaptured = url;
        continue;
      }
      if (type == 'audio') {
        if (_existingAudioUrl.isEmpty) _existingAudioUrl = url;
        continue;
      }
      _existingMedia.add({'type': type, 'url': url});
    }
  }

  String _extractExistingTextContent() {
    for (int i = 0; i < widget.post.mediaType.length && i < widget.post.mediaUrl.length; i++) {
      if (widget.post.mediaType[i] == 'text') {
        return widget.post.mediaUrl[i];
      }
    }
    return '';
  }

  // UI helpers borrowed from create screen
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



  Widget _buildFunctionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFunction,
      decoration: const InputDecoration(
        labelText: '기능',
        border: OutlineInputBorder(),
      ),
      items: _functions.map((f) => DropdownMenuItem<String>(value: f, child: Text(_getFunctionDisplayName(f)))).toList(),
      onChanged: null, // TODO: 마커 배포 여부로 대체
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







  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: widget.post.canEdit ? _pickImage : null,
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
      ],
    );
  }

  Widget _buildSoundUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: null, // TODO: 마커 배포 여부로 대체
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
                  // TODO: 마커 배포 여부로 대체
                  onPressed: false
                      ? null
                      : () {
                          setState(() {
                            _selectedSound = null;
                            _soundFileName = '';
                          });
                        },
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

  Widget _buildExistingMediaList() {
    if (_existingMedia.isEmpty && _existingAudioUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('기존 미디어', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._existingMedia.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item['type'] == 'image' ? Icons.image : Icons.insert_drive_file, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(item['url']!, overflow: TextOverflow.ellipsis)),
                IconButton(
                  onPressed: widget.post.canEdit ? () => _removeExistingMedia(idx) : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        if (_existingAudioUrl.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.audiotrack),
                const SizedBox(width: 8),
                Expanded(child: Text(_existingAudioUrl, overflow: TextOverflow.ellipsis)),
                IconButton(
                  onPressed: widget.post.canEdit ? () => _removeExistingAudio() : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
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
      );
    }
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지 선택 실패: $e')));
      }
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
        withData: true, // Enable bytes data for web
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
            }
            continue;
          }
          
          // Web에서는 bytes 사용, path는 null
          if (file.bytes != null && mounted) {
            setState(() {
              _selectedImages.add(file.bytes!); // Uint8List 사용
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

  Future<void> _pickImageMobile() async {
    if (kIsWeb) {
      // 웹에서는 FilePicker를 사용
      await _pickImageWeb();
      return;
    }
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
    if (image != null) {
      if (mounted) {
        setState(() {
          // 모바일에서만 File 사용
          _selectedImages.add(File(image.path));
          _imageNames.add(image.name);
        });
      }
    }
  }

  void _removeNewImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _imageNames.removeAt(index);
    });
  }

  void _removeExistingMedia(int index) {
    setState(() {
      _existingMedia.removeAt(index);
    });
  }

  void _removeExistingAudio() {
    setState(() {
      _existingAudioUrl = '';
    });
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사운드 선택 실패: $e')));
      }
    }
  }

  Future<void> _pickSoundWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true, // Enable bytes data for web
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')));
          }
          return;
        }
        
        // Web에서는 bytes 사용, path는 null
        if (file.bytes != null && mounted) {
          setState(() {
            _selectedSound = file.bytes!; // Uint8List 사용
            _soundFileName = file.name;
            _existingAudioUrl = '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사운드 선택 실패: $e')));
      }
    }
  }

  Future<void> _pickSoundMobile() async {
    if (kIsWeb) {
      // 웹에서는 _pickSoundWeb을 호출
      await _pickSoundWeb();
      return;
    }
    
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      if (file.path != null) {
        if (mounted) {
          setState(() {
            _selectedSound = File(file.path!);
            _soundFileName = file.name;
            _existingAudioUrl = '';
          });
        }
      }
    }
  }

  String _getGenderFromTarget(List<String> genders) {
    if (genders.contains('male') && genders.contains('female')) {
      return 'all';
    } else if (genders.contains('male')) {
      return 'male';
    } else if (genders.contains('female')) {
      return 'female';
    }
    return 'all';
  }
  Widget _buildReadonlyInfo(String label, dynamic value) {
    String text;
    if (value is DateTime) {
      text = '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    } else if (value is GeoPoint) {
      text = '${value.latitude.toStringAsFixed(6)}, ${value.longitude.toStringAsFixed(6)}';
    } else {
      text = value.toString();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(text),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // 수정 불가 다이얼로그 표시
  void _showCannotEditDialog() {
    String message;
    String statusText;

    switch (widget.post.status) {
      case PostStatus.DEPLOYED:
        statusText = '배포됨';
        message = '이 포스트는 이미 지도에 배포되어 수정할 수 없습니다.';
        break;
      case PostStatus.DELETED:
        statusText = '삭제됨';
        message = '이 포스트는 삭제되어 수정할 수 없습니다.';
        break;
      default:
        statusText = '알 수 없음';
        message = '이 포스트는 현재 수정할 수 없는 상태입니다.';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade600, size: 24),
              const SizedBox(width: 8),
              const Text('수정 불가'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '포스트 상태: $statusText',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '배포 대기 상태의 포스트만 수정 가능합니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
                Navigator.of(context).pop(); // 편집 화면 닫기
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 플레이스 로드
  Future<void> _loadPlace(String placeId) async {
    try {
      final placeService = PlaceService();
      final place = await placeService.getPlaceById(placeId);
      if (mounted && place != null) {
        setState(() {
          _selectedPlace = place;
        });
      }
    } catch (e) {
      debugPrint('플레이스 로드 실패: $e');
    }
  }

  // 플레이스 선택
  Future<void> _selectPlace() async {
    final result = await Navigator.push<PlaceModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const PostPlaceSelectionScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedPlace = result;
        _selectedPlaceId = result.id;
      });
    }
  }

  // 플레이스 선택 UI
  Widget _buildPlaceSelection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedPlace != null) ...[
            Row(
              children: [
                Icon(Icons.store, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPlace!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedPlace!.address != null && _selectedPlace!.address!.isNotEmpty)
                        Text(
                          _selectedPlace!.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.post.canEdit ? () {
                    setState(() {
                      _selectedPlace = null;
                      _selectedPlaceId = null;
                    });
                  } : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ] else ...[
            const Text('연결된 스토어가 없습니다.'),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.post.canEdit ? _selectPlace : null,
              icon: const Icon(Icons.store),
              label: Text(_selectedPlace == null ? '스토어 선택' : '스토어 변경'),
            ),
          ),
        ],
      ),
    );
  }
}


