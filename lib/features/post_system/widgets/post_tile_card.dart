import 'package:flutter/material.dart';
import '../../../core/models/post/post_model.dart';
import '../../../../widgets/network_image_fallback_web.dart' if (dart.library.io) '../../../../widgets/network_image_fallback_stub.dart';
import 'package:intl/intl.dart';

class PostTileCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showDeleteButton;
  final VoidCallback? onDelete;
  final bool showStatisticsButton;
  final VoidCallback? onStatistics;

  const PostTileCard({
    super.key,
    required this.post,
    this.onTap,
    this.isSelected = false,
    this.showDeleteButton = false,
    this.onDelete,
    this.showStatisticsButton = false,
    this.onStatistics,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = post.status == PostStatus.DELETED;
    // 🚀 제거된 필드들: isCollected, isUsed, isUsedByCurrentUser
    // 이들은 이제 post_collections 컬렉션에서 쿼리해야 함
    final isCollected = false; // TODO: 쿼리 기반으로 변경 필요
    final isUsed = false; // TODO: 쿼리 기반으로 변경 필요
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUsed 
              ? Colors.grey.shade100
              : isSelected 
                  ? const Color(0xFF4D4DFF).withValues(alpha: 0.1) 
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUsed
                ? Colors.grey.shade400
                : isSelected 
                    ? const Color(0xFF4D4DFF) 
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isUsed ? 0.02 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Stack(
                  children: [
                    // 이미지 표시
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: _buildImageWidget(),
                    ),
                    // 상태 배지 (우상단)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildStatusBadge(isDeleted, isCollected, isUsed),
                    ),
                    // 삭제 버튼 (좌상단)
                    if (showDeleteButton && onDelete != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // 통계 버튼 (좌상단, 삭제 버튼 옆)
                    if (showStatisticsButton && onStatistics != null)
                      Positioned(
                        top: 8,
                        left: showDeleteButton && onDelete != null ? 44 : 8, // 삭제 버튼이 있으면 옆에, 없으면 처음 위치
                        child: GestureDetector(
                          onTap: onStatistics,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4D4DFF).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.analytics,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // 사용된 포스트 오버레이
                    if (isUsed)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.6),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 내용 영역
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목
                    Text(
                      post.title.isNotEmpty ? post.title : '(제목 없음)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isUsed ? Colors.grey.shade600 : Colors.black87,
                        decoration: isUsed ? TextDecoration.lineThrough : TextDecoration.none,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // 하단 정보 (리워드, 만료일)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 리워드
                        Flexible(
                          flex: 2,
                          child: Text(
                            isUsed ? '사용완료' : '₩${NumberFormat('#,###').format(post.reward)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isUsed ? Colors.grey.shade600 : const Color(0xFF4D4DFF),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 만료일
                        Text(
                          isDeleted
                            ? '삭제됨'
                            : DateFormat('MM/dd').format(post.defaultExpiresAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDeleted ? Colors.red.shade500 : Colors.grey.shade600,
                            fontWeight: isDeleted ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (post.mediaUrl.isNotEmpty) {
      // 이미지 타입 체크를 더 관대하게 변경
      bool hasImageMedia = post.mediaType.isNotEmpty &&
          (post.mediaType.any((type) => type.toLowerCase().contains('image')) ||
           post.mediaUrl.first.toLowerCase().contains('.jpg') ||
           post.mediaUrl.first.toLowerCase().contains('.jpeg') ||
           post.mediaUrl.first.toLowerCase().contains('.png') ||
           post.mediaUrl.first.toLowerCase().contains('.gif') ||
           post.mediaUrl.first.toLowerCase().contains('firebasestorage'));

      if (hasImageMedia) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
          ),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: buildNetworkImage(post.mediaUrl.first),
          ),
        );
      }
    }
    
    // 이미지가 없거나 이미지 타입이 아닌 경우 기본 아이콘 표시
    return Center(
      child: Icon(
        Icons.image,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }

  Widget _buildStatusBadge(bool isDeleted, bool isCollected, bool isUsed) {
    // 사용 상태가 최우선
    if (isUsed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade700,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '사용됨',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    // 삭제된 상태
    if (isDeleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '삭제',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    if (isCollected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '수집됨',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    // TODO: isActive 필드 제거됨, status로 대체
    if (post.status == PostStatus.DELETED) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '비활성',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4D4DFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '활성',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}