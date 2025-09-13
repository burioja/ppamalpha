import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'package:intl/intl.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showStatus;
  final bool showExpiry;
  final bool showDeleteButton;

  const PostCard({
    super.key, 
    required this.post, 
    this.onTap,
    this.onDelete,
    this.showStatus = true,
    this.showExpiry = true,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = post.isExpired();
    final isCollected = post.isCollected;
    final daysUntilExpiry = post.expiresAt.difference(DateTime.now()).inDays;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 제목과 상태
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title.isNotEmpty ? post.title : '(제목 없음)',
                      style: const TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusChip(isExpired, isCollected),
                  // 삭제 버튼 (내 포스트인 경우에만 표시)
                  if (showDeleteButton && onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      iconSize: 20,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 이미지 표시 (mediaUrl에서 이미지가 있는 경우)
              if (post.mediaUrl.isNotEmpty && _hasImageMedia(post)) ...[
                const SizedBox(height: 8),
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _buildImageWidget(post),
                ),
                const SizedBox(height: 12),
              ],
              
              // 설명
              if (post.description.isNotEmpty) ...[
                Text(
                  post.description,
                  style: const TextStyle(
                    fontSize: 14, 
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              
              // 메타 정보 행
              Row(
                children: [
                  // 작성자 정보
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.creatorName,
                            style: TextStyle(
                              fontSize: 13, 
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 리워드
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '₩${NumberFormat('#,###').format(post.reward)}',
                      style: const TextStyle(
                        color: Colors.blue, 
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 하단 정보 행
              Row(
                children: [
                  // 생성일
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MM/dd').format(post.createdAt),
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 만료일 또는 남은 기간
                  if (showExpiry) ...[
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                                                     Icon(
                             isExpired ? Icons.access_time_filled : Icons.timer,
                             size: 14, 
                             color: isExpired ? Colors.red.shade500 : Colors.orange.shade500,
                           ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired 
                              ? '만료됨' 
                              : daysUntilExpiry > 0 
                                ? '$daysUntilExpiry일 남음'
                                : '오늘 만료',
                            style: TextStyle(
                              fontSize: 12, 
                              color: isExpired ? Colors.red.shade500 : Colors.orange.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              
              // 수집 정보 (주운 포스트인 경우)
              if (isCollected && post.collectedAt != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('MM/dd HH:mm').format(post.collectedAt!)} 수집',
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 이미지 미디어가 있는지 확인
  bool _hasImageMedia(PostModel post) {
    return post.mediaType.contains('image') && (post.thumbnailUrl.isNotEmpty || post.mediaUrl.isNotEmpty);
  }

  // 이미지 위젯 빌드 (썸네일 우선 사용)
  Widget _buildImageWidget(PostModel post) {
    // 썸네일이 있으면 썸네일 사용, 없으면 원본 사용
    final imageUrl = _getThumbnailUrl(post) ?? _getOriginalImageUrl(post);
    
    if (imageUrl == null) {
      return Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 40, color: Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              '이미지 없음',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 40, color: Colors.grey.shade500),
              const SizedBox(height: 8),
              Text(
                '이미지를 불러올 수 없습니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }

  // 썸네일 URL 가져오기
  String? _getThumbnailUrl(PostModel post) {
    final imageIndex = post.mediaType.indexOf('image');
    if (imageIndex >= 0 && imageIndex < post.thumbnailUrl.length) {
      return post.thumbnailUrl[imageIndex];
    }
    return null;
  }

  // 원본 이미지 URL 가져오기
  String? _getOriginalImageUrl(PostModel post) {
    final imageIndex = post.mediaType.indexOf('image');
    if (imageIndex >= 0 && imageIndex < post.mediaUrl.length) {
      return post.mediaUrl[imageIndex];
    }
    return null;
  }

  Widget _buildStatusChip(bool isExpired, bool isCollected) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
                         Icon(Icons.access_time_filled, size: 14, color: Colors.red.shade600),
            const SizedBox(width: 4),
            Text(
              '만료',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (isCollected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
            const SizedBox(width: 4),
            Text(
              '수집됨',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    if (!post.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pause_circle, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '비활성',
              style: TextStyle(
                fontSize: 11, 
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radio_button_checked, size: 14, color: Colors.blue.shade600),
          const SizedBox(width: 4),
          Text(
            '활성',
            style: TextStyle(
              fontSize: 11, 
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}



