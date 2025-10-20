import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../providers/post_place_provider.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostPlaceProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostPlaceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('포스트 작성'),
            backgroundColor: Colors.blue[600],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(provider),
                        const SizedBox(height: 24),
                        _buildTargetingSection(provider),
                        const SizedBox(height: 24),
                        _buildMediaSection(provider),
                        const SizedBox(height: 24),
                        _buildSettingsSection(provider),
                        const SizedBox(height: 24),
                        _buildSubmitButton(provider),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBasicInfoSection(PostPlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기본 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rewardController,
              decoration: const InputDecoration(
                labelText: '리워드 (원)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '리워드를 입력해주세요';
                }
                final reward = int.tryParse(value);
                if (reward == null || reward < provider.minPrice) {
                  return '최소 ${provider.minPrice}원 이상이어야 합니다';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetingSection(PostPlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '타겟팅',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('연령대', style: TextStyle(fontWeight: FontWeight.w600)),
            RangeSlider(
              values: provider.selectedAgeRange,
              min: 10,
              max: 80,
              divisions: 70,
              labels: RangeLabels(
                '${provider.selectedAgeRange.start.toInt()}세',
                '${provider.selectedAgeRange.end.toInt()}세',
              ),
              onChanged: (values) => provider.setAgeRange(values),
            ),
            const SizedBox(height: 16),
            const Text('성별', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('남성'),
                    selected: provider.selectedGenders.contains('male'),
                    onSelected: (_) => provider.toggleGender('male'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('여성'),
                    selected: provider.selectedGenders.contains('female'),
                    onSelected: (_) => provider.toggleGender('female'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection(PostPlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '미디어',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _pickImage(provider),
                      icon: const Icon(Icons.image),
                      tooltip: '이미지 추가',
                    ),
                    IconButton(
                      onPressed: () => _pickAudio(provider),
                      icon: const Icon(Icons.audiotrack),
                      tooltip: '오디오 추가',
                    ),
                  ],
                ),
              ],
            ),
            if (provider.selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Image.file(
                            provider.selectedImages[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => provider.removeImage(index),
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
            if (provider.selectedAudioFile != null) ...[
              const SizedBox(height: 8),
              Chip(
                label: Text('오디오: ${provider.selectedAudioFile!.path.split('/').last}'),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => provider.setAudioFile(null),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(PostPlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '설정',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('전달 가능'),
              value: provider.canForward,
              onChanged: (value) => provider.toggleCanForward(value),
            ),
            SwitchListTile(
              title: const Text('답글 가능'),
              value: provider.canRespond,
              onChanged: (value) => provider.toggleCanRespond(value),
            ),
            SwitchListTile(
              title: const Text('쿠폰'),
              value: provider.isCoupon,
              onChanged: (value) => provider.setIsCoupon(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(PostPlaceProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: provider.isLoading ? null : () => _submitPost(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '포스트 작성',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _pickImage(PostPlaceProvider provider) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        provider.addImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _pickAudio(PostPlaceProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        provider.setAudioFile(File(result.files.single.path!));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오디오 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _submitPost(PostPlaceProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final reward = int.tryParse(_rewardController.text);
    if (reward == null) return;

    final success = await provider.createPost(
      title: _titleController.text,
      description: _descriptionController.text,
      reward: reward,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트가 성공적으로 작성되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트 작성에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
