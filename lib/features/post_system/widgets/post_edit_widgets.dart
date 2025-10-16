import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/storage/storage_service.dart';
import '../../../core/utils/logger.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';
import '../widgets/post_edit_media_handler.dart';
import 'post_edit_helpers.dart';

/// 포스트 편집 화면의 UI 위젯들
class PostEditWidgets {
  // 포스트 헤더 위젯
  static Widget buildPostHeader({
    required PostModel post,
    required PlaceModel? place,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PostEditHelpers.getPostStatusIcon(post.status),
                color: PostEditHelpers.getPostStatusColor(post.status),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                PostEditHelpers.formatPostStatus(post.status),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: PostEditHelpers.getPostStatusColor(post.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (place != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 기본 정보 섹션
  static Widget buildBasicInfoSection({
    required GlobalKey<FormState> formKey,
    required TextEditingController titleController,
    required TextEditingController contentController,
    required TextEditingController rewardController,
    required TextEditingController youtubeUrlController,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기본 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 제목
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '포스트 제목을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 내용
              TextFormField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '포스트 내용을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '내용을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // 보상
              TextFormField(
                controller: rewardController,
                decoration: const InputDecoration(
                  labelText: '보상',
                  hintText: '보상 금액을 입력하세요',
                  border: OutlineInputBorder(),
                  suffixText: '원',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '보상을 입력해주세요.';
                  }
                  final reward = double.tryParse(value);
                  if (reward == null || reward <= 0) {
                    return '올바른 보상 금액을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // YouTube URL
              TextFormField(
                controller: youtubeUrlController,
                decoration: const InputDecoration(
                  labelText: 'YouTube URL (선택사항)',
                  hintText: 'YouTube URL을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
                      return '올바른 YouTube URL을 입력해주세요.';
                    }
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 타겟 설정 섹션
  static Widget buildTargetSection({
    required List<String> selectedGenders,
    required ValueChanged<List<String>> onGenderChanged,
    required RangeValues selectedAgeRange,
    required ValueChanged<RangeValues> onAgeRangeChanged,
    required int selectedPeriod,
    required ValueChanged<int> onPeriodChanged,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '타겟 설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 성별 선택
            GenderCheckboxGroup(
              selectedGenders: selectedGenders,
              onChanged: onGenderChanged,
            ),
            const SizedBox(height: 16),
            
            // 나이 범위
            RangeSliderWithInput(
              label: '나이 범위',
              initialValues: selectedAgeRange,
              onChanged: onAgeRangeChanged,
              min: 18,
              max: 80,
              labelBuilder: (value) => '${value.round()}세',
            ),
            const SizedBox(height: 16),
            
            // 기간
            PeriodSliderWithInput(
              initialValue: selectedPeriod,
              onChanged: onPeriodChanged,
            ),
          ],
        ),
      ),
    );
  }

  // 기능 설정 섹션
  static Widget buildFunctionSection({
    required String selectedFunction,
    required ValueChanged<String> onFunctionChanged,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기능 설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: selectedFunction,
              decoration: const InputDecoration(
                labelText: '기능',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Using', child: Text('사용')),
                DropdownMenuItem(value: 'Selling', child: Text('판매')),
                DropdownMenuItem(value: 'Buying', child: Text('구매')),
                DropdownMenuItem(value: 'Sharing', child: Text('공유')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onFunctionChanged(value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 권한 설정 섹션
  static Widget buildPermissionSection({
    required bool canRespond,
    required ValueChanged<bool> onCanRespondChanged,
    required bool canForward,
    required ValueChanged<bool> onCanForwardChanged,
    required bool canRequestReward,
    required ValueChanged<bool> onCanRequestRewardChanged,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '권한 설정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 응답 가능
            SwitchListTile(
              title: const Text('응답 가능'),
              subtitle: const Text('사용자가 포스트에 응답할 수 있습니다'),
              value: canRespond,
              onChanged: onCanRespondChanged,
            ),
            
            // 전달 가능
            SwitchListTile(
              title: const Text('전달 가능'),
              subtitle: const Text('사용자가 포스트를 전달할 수 있습니다'),
              value: canForward,
              onChanged: onCanForwardChanged,
            ),
            
            // 보상 요청 가능
            SwitchListTile(
              title: const Text('보상 요청 가능'),
              subtitle: const Text('사용자가 보상을 요청할 수 있습니다'),
              value: canRequestReward,
              onChanged: onCanRequestRewardChanged,
            ),
          ],
        ),
      ),
    );
  }

  // 미디어 섹션
  static Widget buildMediaSection({
    required List<String> imageUrls,
    required Function() onAddImage,
    required Function(int) onRemoveImage,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '미디어',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 이미지 추가 버튼
            ElevatedButton.icon(
              onPressed: onAddImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('이미지 추가'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrls[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return PostEditHelpers.buildImageLoadingWidget();
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return PostEditHelpers.buildImageErrorWidget();
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => onRemoveImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
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
        ),
      ),
    );
  }

  // 미리보기 섹션
  static Widget buildPreviewSection({
    required Map<String, dynamic> previewData,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '미리보기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildPreviewRow('제목', previewData['title']),
            _buildPreviewRow('내용', previewData['content']),
            _buildPreviewRow('보상', previewData['reward']),
            _buildPreviewRow('이미지 수', '${previewData['imageCount']}개'),
            _buildPreviewRow('플레이스', previewData['placeName']),
            _buildPreviewRow('타겟 성별', previewData['targetGenders']),
            _buildPreviewRow('타겟 나이', previewData['targetAgeRange']),
            _buildPreviewRow('기간', previewData['period']),
            _buildPreviewRow('기능', previewData['function']),
            _buildPreviewRow('응답 가능', previewData['canRespond']),
            _buildPreviewRow('전달 가능', previewData['canForward']),
            _buildPreviewRow('보상 요청 가능', previewData['canRequestReward']),
            _buildPreviewRow('YouTube URL', previewData['youtubeUrl']),
          ],
        ),
      ),
    );
  }

  // 미리보기 행 위젯
  static Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 액션 버튼들
  static Widget buildActionButtons({
    required VoidCallback onSave,
    required VoidCallback onCancel,
    required bool isLoading,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('취소'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isLoading ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }

  // 로딩 위젯
  static Widget buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('포스트 정보를 불러오는 중...'),
        ],
      ),
    );
  }

  // 에러 위젯
  static Widget buildErrorWidget(String message, VoidCallback? onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            '오류 발생',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  // 빈 상태 위젯
  static Widget buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.edit_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '포스트 없음',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 섹션 헤더 위젯
  static Widget buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 정보 카드 위젯
  static Widget buildInfoCard({
    required String title,
    required String content,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Colors.blue, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 설정 항목 위젯
  static Widget buildSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // 스위치 설정 항목 위젯
  static Widget buildSwitchSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // 정보 행 위젯
  static Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

