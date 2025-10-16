import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/models/post/post_model.dart';
import '../../post_system/widgets/post_tile_card.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final PostService _postService = PostService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  List<PostModel> _trashPosts = [];
  bool _isLoading = true;
  String? _selectedPostId;

  @override
  void initState() {
    super.initState();
    _loadTrashPosts();
  }

  Future<void> _loadTrashPosts() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: getTrashPosts 메소드 구현 필요
      // final posts = await _postService.getTrashPosts(_currentUserId!);
      final posts = <PostModel>[]; // 임시로 빈 리스트 반환
      if (mounted) {
        setState(() {
          _trashPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('휴지통 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _restorePost(PostModel post) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('복원하는 중...'),
            ],
          ),
        ),
      );

      // TODO: restoreFromTrash 메소드 구현 필요
      // await _postService.restoreFromTrash(post.postId);
      
      // 임시로 상태만 DRAFT로 변경
      await _postService.updatePostStatus(post.postId, PostStatus.DRAFT);

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트가 복원되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        _loadTrashPosts(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복원 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _permanentDelete(PostModel post) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영구 삭제'),
        content: Text(
          '정말로 이 포스트를 영구 삭제하시겠습니까?\n\n"${post.title}"\n\n이 작업은 되돌릴 수 없습니다.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('영구 삭제하는 중...'),
            ],
          ),
        ),
      );

      // TODO: permanentDelete 메소드 구현 필요
      // await _postService.permanentDelete(post.postId);
      
      // 임시로 Firestore에서 직접 삭제
      await FirebaseFirestore.instance.collection('posts').doc(post.postId).delete();

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트가 영구 삭제되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );

        _loadTrashPosts(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getCrossAxisCount(double width) {
    if (width < 600) {
      return 3;
    } else if (width < 1000) {
      return 3;
    } else {
      return 4;
    }
  }

  String _getRemainingDays(DateTime? deletedAt) {
    if (deletedAt == null) return '알 수 없음';
    
    final expiryDate = deletedAt.add(const Duration(days: 30));
    final remaining = expiryDate.difference(DateTime.now()).inDays;
    
    if (remaining < 0) return '만료됨';
    if (remaining == 0) return '오늘 만료';
    return '$remaining일 후 삭제';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('휴지통'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_trashPosts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('휴지통 안내'),
                    content: const Text(
                      '• 휴지통의 포스트는 30일 후 자동으로 영구 삭제됩니다.\n'
                      '• 30일 이내에 복원하면 다시 사용할 수 있습니다.\n'
                      '• 영구 삭제한 포스트는 복구할 수 없습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('확인'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '휴지통이 비어있습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '삭제된 포스트가 여기에 표시됩니다',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[400]!, Colors.red[400]!],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '휴지통',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_trashPosts.length}개',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 포스트 목록
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadTrashPosts,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: _trashPosts.length,
                              itemBuilder: (context, index) {
                                final post = _trashPosts[index];
                                final remainingDays = _getRemainingDays(post.deletedAt);

                                return Stack(
                                  children: [
                                    PostTileCard(
                                      post: post,
                                      isSelected: _selectedPostId == post.postId,
                                      onTap: () {
                                        setState(() {
                                          _selectedPostId = _selectedPostId == post.postId
                                              ? null
                                              : post.postId;
                                        });
                                      },
                                      onDoubleTap: () {
                                        // 복원/삭제 옵션 표시
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (context) => Container(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(Icons.restore, color: Colors.green),
                                                  title: const Text('복원'),
                                                  subtitle: const Text('포스트를 다시 사용할 수 있습니다'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _restorePost(post);
                                                  },
                                                ),
                                                const Divider(),
                                                ListTile(
                                                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                                                  title: const Text('영구 삭제'),
                                                  subtitle: const Text('복구할 수 없습니다'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _permanentDelete(post);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // 남은 일수 배지
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          remainingDays,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

