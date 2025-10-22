import 'package:flutter/material.dart';
import '../../../../core/models/post/post_model.dart';

/// 인박스 공통 위젯들
class InboxCommonWidgets {
  
  /// 포스트 카드 빌더
  static Widget buildPostCard(
    PostModel post,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 (제목 + 상태)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(post.status),
                ],
              ),
              const SizedBox(height: 8),
              
              // 설명
              if (post.description.isNotEmpty) ...[
                Text(
                  post.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
              
              // 메타 정보
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    post.creatorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.account_balance_wallet, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${post.reward}P',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(post.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상태 칩
  static Widget _buildStatusChip(PostStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case PostStatus.DRAFT:
        color = Colors.orange;
        label = '초안';
        break;
      case PostStatus.DEPLOYED:
        color = Colors.green;
        label = '배포됨';
        break;
      case PostStatus.DELETED:
        color = Colors.red;
        label = '삭제됨';
        break;
      case PostStatus.EXPIRED:
        color = Colors.grey;
        label = '만료됨';
        break;
      case PostStatus.RECALLED:
        color = Colors.purple;
        label = '회수됨';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 날짜 포맷팅
  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  /// 로딩 인디케이터
  static Widget buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 빈 상태 위젯
  static Widget buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 에러 상태 위젯
  static Widget buildErrorState(String message, VoidCallback? onRetry) {
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
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  /// 페이지네이션 로딩 위젯
  static Widget buildPaginationLoading() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 페이지네이션 끝 위젯
  static Widget buildPaginationEnd() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          '모든 데이터를 불러왔습니다',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  /// 새로고침 인디케이터
  static Widget buildRefreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }

  /// 검색 바
  static Widget buildSearchBar({
    required TextEditingController controller,
    required Function(String) onChanged,
    required VoidCallback onClear,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '포스트 검색...',
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[600]),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  /// 필터 토글 버튼
  static Widget buildFilterToggleButton({
    required bool showFilters,
    required VoidCallback onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onToggle,
              icon: Icon(showFilters ? Icons.filter_list_off : Icons.filter_list),
              label: Text(showFilters ? '필터 숨기기' : '필터 보기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: showFilters ? Colors.blue[600] : Colors.grey[200],
                foregroundColor: showFilters ? Colors.white : Colors.grey[700],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}