import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/firebase_service.dart';

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
  late final TextEditingController _descriptionController;
  late final TextEditingController _rewardController;
  late final TextEditingController _contentController;
  late final TextEditingController _amountController;
  late final TextEditingController _periodController;

  bool _canRespond = false;
  bool _canForward = false;
  bool _canRequestReward = true;
  bool _hasExpiration = false;

  bool _isSaving = false;

  // Targeting
  String _selectedTarget = '상관없음/상관없음';
  int _selectedAgeMin = 20;
  int _selectedAgeMax = 30;

  // Function
  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  String _selectedFunction = 'Using';

  // Period unit
  final List<String> _periodUnits = ['Hour', 'Day', 'Week', 'Month'];
  String _selectedPeriodUnit = 'Day';

  // Targeting option (UI only)
  final List<String> _targetingOptions = ['기본', '고급', '맞춤형'];
  String _selectedTargeting = '기본';

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
    _descriptionController = TextEditingController(text: widget.post.description);
    _rewardController = TextEditingController(text: widget.post.reward.toString());
    _contentController = TextEditingController(text: _extractExistingTextContent());
    _amountController = TextEditingController(text: '');
    _periodController = TextEditingController(text: '');
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
    _descriptionController.dispose();
    _rewardController.dispose();
    _contentController.dispose();
    _amountController.dispose();
    _periodController.dispose();
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
      DateTime newExpiresAt = widget.post.expiresAt;
      if (_hasExpiration) {
        final int period = int.tryParse(_periodController.text.trim()) ?? 0;
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
        newExpiresAt = DateTime.now().add(delta);
      }

      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'reward': reward,
        'canRespond': _canRespond,
        'canForward': _canForward,
        'canRequestReward': _canRequestReward,
        'canUse': _selectedFunction == 'Using',
        'targetGender': _getGenderFromTarget(_selectedTarget),
        'targetAge': [_selectedAgeMin, _selectedAgeMax],
        'mediaType': mediaTypes,
        'mediaUrl': mediaUrls,
        'expiresAt': Timestamp.fromDate(newExpiresAt),
        'updatedAt': DateTime.now(),
      };

      // Optional UI-only fields stored for reference
      final amount = int.tryParse(_amountController.text.trim());
      if (amount != null) {
        updates['amount'] = amount;
      }
      updates['periodUnit'] = _selectedPeriodUnit;
      updates['hasExpiration'] = _hasExpiration;

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
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: '설명', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? '설명을 입력해주세요.' : null,
                enabled: !widget.post.isDistributed,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '내용 (선택사항)', border: OutlineInputBorder()),
                maxLines: 5,
                enabled: !widget.post.isDistributed,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('미디어 업로드'),
              _buildImageUpload(),
              const SizedBox(height: 12),
              _buildExistingMediaList(),
              const SizedBox(height: 16),
              _buildSoundUpload(),
              const SizedBox(height: 24),
              _buildSectionTitle('기능 옵션'),
              TextFormField(
                controller: _rewardController,
                decoration: const InputDecoration(labelText: '리워드', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                enabled: !widget.post.isDistributed,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 8),
              _buildFunctionDropdown(),
              const SizedBox(height: 24),
              _buildSectionTitle('타겟팅 옵션'),
              _buildDropdown(
                label: '타겟팅 레벨',
                value: _selectedTargeting,
                items: _targetingOptions,
                onChanged: widget.post.isDistributed ? null : (value) { setState(() { _selectedTargeting = value!; }); },
              ),
              const SizedBox(height: 16),
              _buildTargetDropdown(),
              const SizedBox(height: 16),
              _buildAgeRange(),
              const SizedBox(height: 24),
              _buildSectionTitle('가격/수량 및 기간'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      enabled: !widget.post.isDistributed,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _periodController,
                      decoration: const InputDecoration(labelText: '기간', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      enabled: !widget.post.isDistributed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPeriodUnitDropdown()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('소멸시효 사용'),
                      value: _hasExpiration,
                      onChanged: widget.post.isDistributed ? null : (v) { setState(() { _hasExpiration = v ?? false; }); },
                    ),
                  ),
                ],
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
    _selectedAgeMin = widget.post.targetAge.isNotEmpty ? widget.post.targetAge[0] : 20;
    _selectedAgeMax = widget.post.targetAge.length > 1 ? widget.post.targetAge[1] : _selectedAgeMin;
    switch (widget.post.targetGender) {
      case 'male':
        _selectedTarget = '남성/남성';
        break;
      case 'female':
        _selectedTarget = '여성/여성';
        break;
      default:
        _selectedTarget = '상관없음/상관없음';
    }
  }

  void _initFunctionFromPost() {
    _selectedFunction = widget.post.canUse ? 'Using' : 'Selling';
  }

  void _initPeriodFromPost() {
    final now = DateTime.now();
    if (widget.post.expiresAt.isAfter(now)) {
      _hasExpiration = true;
      final diff = widget.post.expiresAt.difference(now);
      if (diff.inHours < 24) {
        _selectedPeriodUnit = 'Hour';
        _periodController.text = diff.inHours.clamp(1, 8760).toString();
      } else if (diff.inDays < 7) {
        _selectedPeriodUnit = 'Day';
        _periodController.text = diff.inDays.clamp(1, 365).toString();
      } else if (diff.inDays < 30) {
        _selectedPeriodUnit = 'Week';
        _periodController.text = (diff.inDays ~/ 7).clamp(1, 52).toString();
      } else {
        _selectedPeriodUnit = 'Month';
        _periodController.text = (diff.inDays ~/ 30).clamp(1, 24).toString();
      }
    } else {
      _hasExpiration = false;
      _periodController.text = '';
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

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
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

  Widget _buildTargetDropdown() {
    final targets = [
      '상관없음/상관없음',
      '남성/남성',
      '여성/여성',
      '남성/여성',
      '여성/남성',
    ];
    return DropdownButtonFormField<String>(
      value: _selectedTarget,
      decoration: const InputDecoration(
        labelText: '타겟',
        border: OutlineInputBorder(),
      ),
      items: targets.map((t) => DropdownMenuItem<String>(value: t, child: Text(t))).toList(),
      onChanged: widget.post.isDistributed ? null : (v) { setState(() { _selectedTarget = v!; }); },
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
            items: List.generate(81, (index) => index + 10).map((age) => DropdownMenuItem<int>(value: age, child: Text('$age세'))).toList(),
            onChanged: widget.post.isDistributed ? null : (v) {
              setState(() {
                _selectedAgeMin = v!;
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
            items: List.generate(81, (index) => index + 10).where((age) => age >= _selectedAgeMin).map((age) => DropdownMenuItem<int>(value: age, child: Text('$age세'))).toList(),
            onChanged: widget.post.isDistributed ? null : (v) {
              setState(() { _selectedAgeMax = v!; });
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
      items: _periodUnits.map((u) => DropdownMenuItem<String>(value: u, child: Text(_getPeriodUnitDisplayName(u)))).toList(),
      onChanged: widget.post.isDistributed ? null : (v) { setState(() { _selectedPeriodUnit = v!; }); },
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
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.click();
    await input.onChange.first;
    if (input.files != null) {
      for (final file in input.files!) {
        if (file.size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
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
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'audio/*'
      ..multiple = false;
    input.click();
    await input.onChange.first;
    if (input.files != null && input.files!.isNotEmpty) {
      final file = input.files!.first;
      if (file.size > 50 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')));
        }
        return;
      }
      if (mounted) {
        setState(() {
          _selectedSound = file;
          _soundFileName = file.name;
          _existingAudioUrl = '';
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
            _existingAudioUrl = '';
          });
        }
      }
    }
  }

  String _getGenderFromTarget(String target) {
    if (target.contains('남성')) return 'male';
    if (target.contains('여성')) return 'female';
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


