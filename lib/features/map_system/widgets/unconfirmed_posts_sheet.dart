import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/post_collection_service.dart';
import '../../../core/models/post/post_model.dart';

/// 미확인 포스트 목록 바텀시트
class UnconfirmedPostsSheet extends StatefulWidget {
  final String userId;
  final VoidCallback onConfirmComplete;

  const UnconfirmedPostsSheet({
    super.key,
    required this.userId,
    required this.onConfirmComplete,
  });

  @override
  State<UnconfirmedPostsSheet> createState() => _UnconfirmedPostsSheetState();
}

class _UnconfirmedPostsSheetState extends State<UnconfirmedPostsSheet> {
  final PostCollectionService _collectionService = PostCollectionService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _unconfirmedPosts = [];

  @override
  void initState() {
    super.initState();
    _loadUnconfirmedPosts();
  }

  Future<void> _loadUnconfirmedPosts() async {
    setState(() => _isLoading = true);
    
    try {
      final posts = await _collectionService.getUnconfirmedPosts(widget.userId);
      setState(() {
        _unconfirmedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 미확인 포스트 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmPost(Map<String, dynamic> collection) async {
    try {
      final postId = collection['postId'] as String;
      
      await _collectionService.confirmPost(
        postId: postId,
        userId: widget.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트를 확인했습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // 목록 새로고침
        await _loadUnconfirmedPosts();
        widget.onConfirmComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('확인 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[400]!, Colors.red[400]!],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  '미확인 포스트',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_unconfirmedPosts.length}개',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // 포스트 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _unconfirmedPosts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              '모든 포스트를 확인했습니다!',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _unconfirmedPosts.length,
                        itemBuilder: (context, index) {
                          final collection = _unconfirmedPosts[index];
                          return _buildPostCard(collection);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> collection) {
    final postId = collection['postId'] as String?;
    final collectedAt = (collection['collectedAt'] as Timestamp?)?.toDate();
    final reward = collection['reward'] as int? ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _confirmPost(collection),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard,
                  color: Colors.orange[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '포스트 ID: ${postId?.substring(0, 8) ?? "알 수 없음"}...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '수령: ${_formatDateTime(collectedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 14, color: Colors.green[600]),
                        Text(
                          '$reward P',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 확인 버튼
              ElevatedButton(
                onPressed: () => _confirmPost(collection),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('확인하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '알 수 없음';
    
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inMinutes < 1) {
      return '방금 전';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}시간 전';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

