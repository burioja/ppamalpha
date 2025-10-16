import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'post_place_helpers.dart';

/// 포스트 생성 화면의 UI 위젯들
class PostPlaceWidgets {
  // 커스텀 네모 썸 Shape (나이 텍스트 포함) - RangeSliderThumbShape 반환
  static RangeSliderThumbShape buildRectangularAgeThumbShape({
    double thumbWidth = 32,
    double thumbHeight = 24,
    required RangeValues values,
  }) {
    return RectangularAgeThumbShape(
      thumbWidth: thumbWidth,
      thumbHeight: thumbHeight,
      values: values,
    );
  }

  // 나이 범위 슬라이더
  static Widget buildAgeRangeSlider({
    required BuildContext context,
    required RangeValues values,
    required ValueChanged<RangeValues> onChanged,
  }) {
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
          values: values,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
      ),
      child: RangeSlider(
        values: values,
        min: 10,
        max: 90,
        divisions: 80,
        onChanged: onChanged,
      ),
    );
  }

  // 성별 선택 위젯
  static Widget buildGenderSelector({
    required String selectedGender,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildGenderChip(
            '남성',
            'male',
            selectedGender,
            Colors.blue,
            onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGenderChip(
            '여성',
            'female',
            selectedGender,
            Colors.pink,
            onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildGenderChip(
            '전체',
            'all',
            selectedGender,
            Colors.grey,
            onChanged,
          ),
        ),
      ],
    );
  }

  // 성별 칩 위젯
  static Widget _buildGenderChip(
    String label,
    String value,
    String selectedGender,
    Color color,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = selectedGender == value;
    
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        height: 40,
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

  // 관심사 선택 위젯
  static Widget buildInterestSelector({
    required List<String> selectedInterests,
    required ValueChanged<List<String>> onChanged,
  }) {
    final interestOptions = [
      '패션', '뷰티', '음식', '여행', '스포츠',
      '영화', '음악', '게임', '독서', '예술',
      '건강', '교육', '기술', '자동차', '부동산',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: interestOptions.map((interest) {
        final isSelected = selectedInterests.contains(interest);
        return GestureDetector(
          onTap: () {
            final newInterests = List<String>.from(selectedInterests);
            if (isSelected) {
              newInterests.remove(interest);
            } else {
              newInterests.add(interest);
            }
            onChanged(newInterests);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
              ),
            ),
            child: Text(
              interest,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 미디어 업로드 위젯
  static Widget buildMediaUploadWidget({
    required List<File> images,
    File? audioFile,
    required VoidCallback onPickImages,
    required VoidCallback onPickAudio,
    required Function(int) onRemoveImage,
    VoidCallback? onRemoveAudio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 업로드 버튼들
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onPickImages,
                icon: const Icon(Icons.image, size: 16),
                label: const Text('이미지 추가', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onPickAudio,
                icon: const Icon(Icons.audiotrack, size: 16),
                label: const Text('오디오 추가', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 이미지 미리보기
        if (images.isNotEmpty) ...[
          const Text(
            '이미지 미리보기',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          images[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
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
                              size: 12,
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
          const SizedBox(height: 12),
        ],
        
        // 오디오 미리보기
        if (audioFile != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.audiotrack, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    audioFile.path.split('/').last,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onRemoveAudio != null)
                  GestureDetector(
                    onTap: onRemoveAudio,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 폼 필드 위젯
  static Widget buildFormField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
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

  // 미리보기 위젯
  static Widget buildPreviewWidget({
    required Map<String, dynamic> previewData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '포스트 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 제목
          Text(
            previewData['title'] ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // 설명
          Text(
            previewData['description'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          
          // 정보 행들
          _buildPreviewRow('리워드', '${previewData['reward']}원'),
          _buildPreviewRow('나이 범위', previewData['ageRange']),
          _buildPreviewRow('성별', previewData['gender']),
          _buildPreviewRow('관심사', previewData['interests']),
          _buildPreviewRow('미디어', previewData['mediaTypes']),
        ],
      ),
    );
  }

  // 미리보기 행 위젯
  static Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
          Text('포스트를 생성하는 중...'),
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
}

// RectangularAgeThumbShape 클래스 (별도 파일로 분리할 수 있음)
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

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: thumbWidth, height: thumbHeight),
      const Radius.circular(4),
    );

    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.orange
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rect, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rect, borderPaint);

    // Determine which thumb is being painted and get its value
    final value = thumb == Thumb.start ? values.start.toInt() : values.end.toInt();
    
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

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }
}

