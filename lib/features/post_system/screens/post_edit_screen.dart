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
  late final TextEditingController _youtubeUrlController;

  bool _canRespond = false;
  bool _canForward = false;
  bool _canRequestReward = true;
  bool _isSaving = false;

  List<String> _selectedGenders = ['male', 'female'];
  RangeValues _selectedAgeRange = const RangeValues(20, 30);
  int _selectedPeriod = 7;

  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  String _selectedFunction = 'Using';

  final List<dynamic> _selectedImages = [];
  final List<String> _imageNames = [];
  final List<Map<String, String>> _existingMedia = [];
  String _existingAudioUrl = '';
  dynamic _selectedSound;
  String _soundFileName = '';

  String? _selectedPlaceId;
  PlaceModel? _selectedPlace;

  @override
  void initState() {
    super.initState();

    if (!widget.post.canEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCannotEditDialog();
      });
      return;
    }

    _titleController = TextEditingController(text: widget.post.title);
    _rewardController = TextEditingController(text: widget.post.reward.toString());
    _contentController = TextEditingController(text: _extractExistingTextContent());
    _youtubeUrlController = TextEditingController(text: widget.post.youtubeUrl ?? '');
    _canRespond = widget.post.canRespond;
    _canForward = widget.post.canForward;
    _canRequestReward = widget.post.canRequestReward;

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
    _youtubeUrlController.dispose();
    _titleController.dispose();
    _rewardController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isDistributed = false;
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

      final List<String> mediaTypes = [];
      final List<String> mediaUrls = [];

      for (final item in _existingMedia) {
        mediaTypes.add(item['type']!);
        mediaUrls.add(item['url']!);
      }

      if (_existingAudioUrl.isNotEmpty && _selectedSound == null) {
        mediaTypes.add('audio');
        mediaUrls.add(_existingAudioUrl);
      }

      for (final dynamic imagePath in _selectedImages) {
        Map<String, String> uploadResult;
        if (imagePath is File) {
          uploadResult = await _firebaseService.uploadImageWithThumbnail(imagePath, 'posts');
        } else if (imagePath is String && imagePath.startsWith('data:image/')) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageDataUrlWithThumbnail(imagePath, 'posts', safeName);
        } else if (imagePath is Uint8List) {
          final safeName = 'img_${DateTime.now().millisecondsSinceEpoch}.png';
          uploadResult = await _firebaseService.uploadImageBytesWithThumbnail(imagePath, 'posts', safeName);
        } else {
          continue;
        }
        mediaTypes.add('image');
        mediaUrls.add(uploadResult['original']!);
      }

      if (_selectedSound != null) {
        String audioUrl;
        if (kIsWeb && _selectedSound is Uint8List) {
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
          audioUrl = await _firebaseService.uploadImageFromBlob(
            _selectedSound,
            'audios',
            _soundFileName.isNotEmpty ? _soundFileName : 'audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
          );
        }
        mediaTypes.add('audio');
        mediaUrls.add(audioUrl);
      }

      final content = _contentController.text.trim();
      if (content.isNotEmpty) {
        mediaTypes.add('text');
        mediaUrls.add(content);
      }

      final Duration delta = Duration(days: _selectedPeriod);
      final DateTime newExpiresAt = DateTime.now().add(delta);

      final updates = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': '',
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
        'placeId': _selectedPlaceId,
        'youtubeUrl': _youtubeUrlController.text.trim().isNotEmpty
            ? _youtubeUrlController.text.trim()
            : null,
      };

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('포스트 수정'),
        backgroundColor: const Color(0xFF4D4DFF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _isSaving || !widget.post.canEdit ? null : _save,
              icon: _isSaving
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.post.canEdit)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red.shade600, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${widget.post.status.name} 상태의 포스트는 수정할 수 없습니다.',
                          style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // 플레이스 정보 카드
              if (_selectedPlace != null) _buildPlaceInfoCard(),
              if (_selectedPlace != null) const SizedBox(height: 20),

              // 포스트 기본 정보
              _buildSectionCard(
                title: '기본 정보',
                icon: Icons.edit_note,
                children: [
                  _buildStyledTextField(
                    controller: _titleController,
                    label: '제목',
                    icon: Icons.title,
                    validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해주세요.' : null,
                    enabled: widget.post.canEdit,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledTextField(
                    controller: _contentController,
                    label: '내용 (선택사항)',
                    icon: Icons.description,
                    maxLines: 4,
                    enabled: widget.post.canEdit,
                  ),
                  const SizedBox(height: 16),
                  _buildStyledDropdown(
                    label: '기능',
                    value: _selectedFunction,
                    items: _functions,
                    icon: Icons.settings,
                    onChanged: widget.post.canEdit ? (value) {
                      setState(() {
                        _selectedFunction = value!;
                      });
                    } : null,
                    displayName: _getFunctionDisplayName,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 미디어 섹션
              _buildSectionCard(
                title: '미디어',
                icon: Icons.perm_media,
                children: [
                  _buildMediaUpload(),
                ],
              ),
              const SizedBox(height: 20),

              // 연결된 스토어
              _buildSectionCard(
                title: '연결된 스토어',
                icon: Icons.store,
                children: [
                  _buildPlaceSelection(),
                ],
              ),
              const SizedBox(height: 20),

              // 타겟팅 옵션
              _buildSectionCard(
                title: '타겟팅 설정',
                icon: Icons.people,
                children: [
                  GenderCheckboxGroup(
                    selectedGenders: _selectedGenders,
                    onChanged: (genders) {
                      if (widget.post.canEdit) {
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
                      if (widget.post.canEdit) {
                        setState(() {
                          _selectedAgeRange = range;
                        });
                      }
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
                  onPressed: _isSaving || !widget.post.canEdit ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.save, color: Colors.white, size: 24),
                  label: Text(
                    _isSaving ? '수정 중...' : '수정 완료',
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
    if (_selectedPlace == null) return const SizedBox.shrink();

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
            _selectedPlace!.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_selectedPlace!.address != null && _selectedPlace!.address!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPlace!.address!,
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
    bool enabled = true,
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
      enabled: enabled,
    );
  }

  Widget _buildStyledDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?>? onChanged,
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
                onPressed: widget.post.canEdit ? _pickImage : null,
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
                          onTap: () => _removeNewImage(index),
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
        if (_existingMedia.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('기존 미디어', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 8),
          ..._existingMedia.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(item['type'] == 'image' ? Icons.image : Icons.insert_drive_file, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(item['url']!, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    onPressed: widget.post.canEdit ? () => _removeExistingMedia(idx) : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 16),

        // 사운드 업로드
        OutlinedButton.icon(
          onPressed: widget.post.canEdit ? _pickSound : null,
          icon: const Icon(Icons.audiotrack),
          label: Text(_soundFileName.isEmpty && _existingAudioUrl.isEmpty
              ? '사운드 추가'
              : _soundFileName.isNotEmpty
                  ? _soundFileName
                  : '기존 사운드 있음'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            side: BorderSide(
                color: _soundFileName.isEmpty && _existingAudioUrl.isEmpty
                    ? Colors.grey[300]!
                    : Colors.green),
            backgroundColor: _soundFileName.isEmpty && _existingAudioUrl.isEmpty ? null : Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_soundFileName.isNotEmpty || _existingAudioUrl.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.post.canEdit
                ? () {
                    setState(() {
                      _selectedSound = null;
                      _soundFileName = '';
                      _existingAudioUrl = '';
                    });
                  }
                : null,
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
          enabled: widget.post.canEdit,
        ),
      ],
    );
  }

  Widget _buildPlaceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPlace != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.store, color: Colors.blue.shade600),
                const SizedBox(width: 12),
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
                if (widget.post.canEdit)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedPlace = null;
                        _selectedPlaceId = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('연결된 스토어가 없습니다.'),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.post.canEdit ? _selectPlace : null,
            icon: const Icon(Icons.store),
            label: Text(_selectedPlace == null ? '스토어 선택' : '스토어 변경'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
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

  // Helper methods
  void _initTargetingFromPost() {
    final ageMin = widget.post.targetAge.isNotEmpty ? widget.post.targetAge[0].toDouble() : 20.0;
    final ageMax = widget.post.targetAge.length > 1 ? widget.post.targetAge[1].toDouble() : ageMin;
    _selectedAgeRange = RangeValues(ageMin, ageMax);

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
      _selectedPeriod = 7;
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
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')));
            }
            continue;
          }

          if (file.bytes != null && mounted) {
            setState(() {
              _selectedImages.add(file.bytes!);
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
      await _pickImageWeb();
      return;
    }

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

  void _removeExistingMedia(int index) {
    setState(() {
      _existingMedia.removeAt(index);
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
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')));
          }
          return;
        }

        if (file.bytes != null && mounted) {
          setState(() {
            _selectedSound = file.bytes!;
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
