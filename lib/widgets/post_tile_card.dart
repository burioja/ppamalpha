import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/network_image_fallback_web.dart' if (dart.library.io) '../widgets/network_image_fallback_stub.dart';
import 'package:intl/intl.dart';

class PostTileCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool showDeleteButton;
  final VoidCallback? onDelete;

  const PostTileCard({
    super.key,
    required this.post,
    this.onTap,
    this.isSelected = false,
    this.showDeleteButton = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = post.isExpired();
    final isCollected = post.isCollected;
    final isUsed = post.isUsed || post.isUsedByCurrentUser;
    
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
                      child: _buildStatusBadge(isExpired, isCollected, isUsed),
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    const SizedBox(height: 8),
                    // 하단 정보 (리워드, 만료일)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 리워드
                        Text(
                          isUsed ? '사용완료' : '₩${NumberFormat('#,###').format(post.reward)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUsed ? Colors.grey.shade600 : const Color(0xFF4D4DFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // 만료일
                        Text(
                          isExpired 
                            ? '만료됨'
                            : DateFormat('MM/dd').format(post.expiresAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isExpired ? Colors.red.shade500 : Colors.grey.shade600,
                            fontWeight: isExpired ? FontWeight.w500 : FontWeight.normal,
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

  Widget _buildStatusBadge(bool isExpired, bool isCollected, bool isUsed) {
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
    // 만료 상태
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '만료',
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
    
    if (!post.isActive) {
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