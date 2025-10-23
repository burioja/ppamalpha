import 'package:flutter/material.dart';

class PostMediaWidgets {
  // 미디어 섹션 (1줄 배치, 자동 단가 계산)
  static Widget buildMediaSectionInline({
    required String priceText,
    required int imageCount,
    required List<dynamic> selectedImages,
    required VoidCallback onImageTap,
    required VoidCallback onTextTap,
    required VoidCallback onSoundTap,
    required VoidCallback onVideoTap,
    required Function(String) onPriceChanged,
    required Function(int) onRemoveImage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // 헤더 (단가 포함)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[100]!, Colors.purple[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  '미디어',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 단가 입력 필드
                Container(
                  width: 120,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: TextField(
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: '${priceText}P',
                      hintStyle: TextStyle(
                        color: Colors.purple[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    onChanged: onPriceChanged,
                  ),
                ),
              ],
            ),
          ),
          // 컨텐츠 (1줄 배치)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // 미디어 타입 버튼들
                Row(
                  children: [
                    Expanded(
                      child: _buildMediaTypeButtonWithCount(
                        '이미지',
                        Icons.image,
                        Colors.blue,
                        imageCount,
                        onImageTap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeButton(
                        '텍스트',
                        Icons.text_fields,
                        Colors.green,
                        onTextTap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeButton(
                        '사운드',
                        Icons.audiotrack,
                        Colors.orange,
                        onSoundTap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMediaTypeButton(
                        '영상',
                        Icons.videocam,
                        Colors.red,
                        onVideoTap,
                      ),
                    ),
                  ],
                ),
                // 이미지 미리보기 섹션
                if (selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildImagePreview(selectedImages, onRemoveImage),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 미디어 타입 버튼 (개수 표시 포함)
  static Widget _buildMediaTypeButtonWithCount(String label, IconData icon, Color color, int count, VoidCallback onTap) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(icon, color: color, size: 24),
                  if (count > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 미디어 타입 버튼
  static Widget _buildMediaTypeButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 이미지 섹션
  static Widget buildImageSection({
    required List<dynamic> selectedImages,
    required VoidCallback onAddImage,
    required Function(int) onRemoveImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '이미지',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedImages.isEmpty)
          InkWell(
            onTap: onAddImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    '이미지 추가',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: [
              // 이미지 그리드
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: selectedImages[index] is String
                              ? Image.network(
                                  selectedImages[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Icon(Icons.error, color: Colors.grey[400]),
                                    );
                                  },
                                )
                              : Image.memory(
                                  selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
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
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddImage,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('이미지 추가'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 사운드 섹션
  static Widget buildSoundSection({
    required dynamic selectedSound,
    required String soundFileName,
    required VoidCallback onAddSound,
    required VoidCallback onRemoveSound,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.audiotrack, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '사운드',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedSound == null)
          InkWell(
            onTap: onAddSound,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    '사운드 추가',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.audiotrack, color: Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    soundFileName,
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onRemoveSound,
                  icon: Icon(Icons.close, color: Colors.red[400], size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // YouTube 섹션
  static Widget buildYouTubeSection({
    required TextEditingController youtubeController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.play_circle_outline, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              'YouTube URL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: youtubeController,
          decoration: InputDecoration(
            hintText: 'YouTube URL을 입력하세요',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: Icon(Icons.link, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  // 이미지 미리보기
  static Widget _buildImagePreview(List<dynamic> selectedImages, Function(int) onRemoveImage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_library, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '선택된 이미지 (${selectedImages.length}개)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: selectedImages.length,
            itemBuilder: (context, index) {
              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: selectedImages[index] is String
                          ? Image.network(
                              selectedImages[index],
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.error, color: Colors.grey[400]),
                                );
                              },
                            )
                          : Image.memory(
                              selectedImages[index],
                              width: 80,
                              height: 80,
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
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
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
    );
  }
}
