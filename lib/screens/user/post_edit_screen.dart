import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'dart:convert';

import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/range_slider_with_input.dart';
import '../../widgets/gender_checkbox_group.dart';
import '../../widgets/period_slider_with_input.dart';
import '../../widgets/price_calculator.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _rewardController = TextEditingController(text: widget.post.reward.toString());
    _contentController = TextEditingController(text: _extractExistingTextContent());
    _canRespond = widget.post.canRespond;
    _canForward = widget.post.canForward;
    _canRequestReward = widget.post.canRequestReward;

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
    if (widget.post.isDistributed) {
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

      // Upload new images
      for (final dynamic imagePath in _selectedImages) {
        String url;
        if (imagePath is File) {
          url = await _firebaseService.uploadImage(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          url = await _firebaseService.uploadImageDataUrl(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          continue;
        } else {
          continue;
        }
        mediaTypes.add('image');
        mediaUrls.add(url);
      }

      // Upload new audio if selected
      if (_selectedSound != null) {
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
      };

      debugPrint('🔄 포스트 수정 데이터:');
      debugPrint('  - flyerId: ${widget.post.flyerId}');
      debugPrint('  - targetAge: ${updates['targetAge']}');
      debugPrint('  - targetGender: ${updates['targetGender']}');
      debugPrint('  - _selectedAgeRange: ${_selectedAgeRange.start.toInt()}-${_selectedAgeRange.end.toInt()}');
      debugPrint('  - _selectedGenders: $_selectedGenders');

      await _postService.updatePost(widget.post.flyerId, updates);

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
            onPressed: _isSaving || widget.post.isDistributed ? null : _save,
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
              if (widget.post.isDistributed)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('이미 배포된 포스트입니다. 수정할 수 없습니다.', style: TextStyle(color: Colors.orange.shade800))),
                    ],
                  ),
                ),
              _buildSectionTitle('포스트 기본 정보'),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '제목', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해주세요.' : null,
                enabled: !widget.post.isDistributed,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '내용 (선택사항)', border: OutlineInputBorder()),
                maxLines: 5,
                enabled: !widget.post.isDistributed,
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
              _buildSectionTitle('기능 옵션'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('응답 허용'),
                value: _canRespond,
                onChanged: widget.post.isDistributed ? null : (v) { setState(() { _canRespond = v ?? false; }); },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('전달 허용'),
                value: _canForward,
                onChanged: widget.post.isDistributed ? null : (v) { setState(() { _canForward = v ?? false; }); },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('리워드 수령 허용'),
                value: _canRequestReward,
                onChanged: widget.post.isDistributed ? null : (v) { setState(() { _canRequestReward = v ?? true; }); },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('타겟팅 옵션'),
              GenderCheckboxGroup(
                selectedGenders: _selectedGenders,
                onChanged: (genders) {
                  if (!widget.post.isDistributed) {
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
                onChanged: widget.post.isDistributed ? null : (range) {
                  setState(() {
                    _selectedAgeRange = range;
                  });
                },
                labelBuilder: (value) => '${value.toInt()}세',
                validator: (range) {
                  if (range.start < 10 || range.end > 90) {
                    return '10~90 사이의 값을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('단가 및 기간'),
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
              const SizedBox(height: 16),
              PeriodSliderWithInput(
                initialValue: _selectedPeriod,
                onChanged: widget.post.isDistributed ? null : (period) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                },
                validator: (period) {
                  if (period < 1 || period > 30) {
                    return '1~30일 사이의 값을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildReadonlyInfo('생성일', widget.post.createdAt),
              _buildReadonlyInfo('만료일', widget.post.expiresAt),
              _buildReadonlyInfo('위치', widget.post.location),
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
    if (widget.post.expiresAt.isAfter(now)) {
      final diff = widget.post.expiresAt.difference(now);
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
      onChanged: widget.post.isDistributed ? null : (v) { setState(() { _selectedFunction = v!; }); },
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
          onPressed: widget.post.isDistributed ? null : _pickImage,
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
          onPressed: widget.post.isDistributed ? null : _pickSound,
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
                  onPressed: widget.post.isDistributed
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
                  onPressed: widget.post.isDistributed ? null : () { setState(() { _existingMedia.removeAt(idx); }); },
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
                  onPressed: widget.post.isDistributed ? null : () { setState(() { _existingAudioUrl = ''; }); },
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
      );
      
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
            }
            continue;
          }
          
          if (mounted) {
            setState(() {
              _selectedImages.add(file.path ?? '');
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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1080, imageQuality: 85);
    if (image != null) {
      if (mounted) {
        setState(() {
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
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')));
          }
          return;
        }
        if (mounted) {
          setState(() {
            _selectedSound = file.path ?? '';
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
}


