import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/inbox_provider.dart';
import '../../../core/models/post/post_model.dart';
import '../widgets/inbox/inbox_statistics_tab.dart';
import '../widgets/inbox/inbox_filter_section.dart';
import '../widgets/inbox_widgets/inbox_common_widgets.dart';

/// 인박스 화면 - Provider 기반 완전 구현
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    // 초기 데이터 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentUserId != null) {
        context.read<InboxProvider>().loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (context) => InboxProvider(currentUserId: _currentUserId!),
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppBar(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: '내 포스트'),
                    Tab(text: '받은 포스트'),
                    Tab(text: '통계'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            // 검색 바
            InboxCommonWidgets.buildSearchBar(
              controller: _searchController,
              onChanged: (value) {
                context.read<InboxProvider>().applyFilters(value);
              },
              onClear: () {
                _searchController.clear();
                context.read<InboxProvider>().applyFilters('');
              },
            ),
            
            // 필터 토글 버튼
            InboxCommonWidgets.buildFilterToggleButton(
              showFilters: context.watch<InboxProvider>().showFilters,
              onToggle: () {
                context.read<InboxProvider>().toggleFilters();
              },
            ),
            
            // 필터 섹션
            const InboxFilterSection(),
            
            // 탭 내용
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyPostsTab(),
                  _buildCollectedPostsTab(),
                  const InboxStatisticsTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _tabController.index == 0 
            ? FloatingActionButton.extended(
                onPressed: () async {
                  Navigator.pushNamed(context, '/post-place-selection');
                },
                backgroundColor: Colors.blue[600],
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('배포자 선택', style: TextStyle(color: Colors.white)),
              ) 
            : null,
      ),
    );
  }

  /// 내 포스트 탭
  Widget _buildMyPostsTab() {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return InboxCommonWidgets.buildLoadingIndicator();
        }

        return InboxCommonWidgets.buildRefreshIndicator(
          onRefresh: () => provider.refreshData(),
          child: Column(
            children: [
              // 내 포스트 요약
              _buildMyPostsSummary(provider),
              
              // 포스트 목록
              Expanded(
                child: provider.filteredPosts.isEmpty
                    ? InboxCommonWidgets.buildEmptyState(
                        '포스트가 없습니다\n새 포스트를 만들어보세요!',
                        Icons.post_add,
                      )
                    : ListView.builder(
                        itemCount: provider.filteredPosts.length + 
                            (provider.hasMoreData ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= provider.filteredPosts.length) {
                            // 페이지네이션 로딩
                            provider.loadMoreData();
                            return InboxCommonWidgets.buildPaginationLoading();
                          }
                          
                          final post = provider.filteredPosts[index];
                          return InboxCommonWidgets.buildPostCard(
                            post,
                            () => _onPostTap(post),
                            () => _onPostLongPress(post),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 내 포스트 요약
  Widget _buildMyPostsSummary(InboxProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.white],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              '전체',
              '${provider.totalPostCount}개',
              Icons.post_add,
              Colors.blue,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              '활성',
              '${provider.deployedPosts.length}개',
              Icons.send,
              Colors.green,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              '초안',
              '${provider.draftPosts.length}개',
              Icons.drafts,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /// 요약 아이템
  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 받은 포스트 탭
  Widget _buildCollectedPostsTab() {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return InboxCommonWidgets.buildLoadingIndicator();
        }

        return InboxCommonWidgets.buildRefreshIndicator(
          onRefresh: () => provider.refreshCollectedPosts(),
          child: provider.collectedPosts.isEmpty
              ? InboxCommonWidgets.buildEmptyState(
                  '받은 포스트가 없습니다\n지도에서 포스트를 수집해보세요!',
                  Icons.collections_bookmark,
                )
              : ListView.builder(
                  itemCount: provider.collectedPosts.length,
                  itemBuilder: (context, index) {
                    final post = provider.collectedPosts[index];
                    return InboxCommonWidgets.buildPostCard(
                      post,
                      () => _onCollectedPostTap(post),
                      () => _onCollectedPostLongPress(post),
                    );
                  },
                ),
        );
      },
    );
  }

  /// 포스트 탭 핸들러
  void _onPostTap(PostModel post) {
    // 포스트 상세 화면으로 이동
    Navigator.pushNamed(
      context,
      '/post-detail',
      arguments: post.postId,
    );
  }

  /// 포스트 롱프레스 핸들러
  void _onPostLongPress(PostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildPostActionSheet(post),
    );
  }

  /// 받은 포스트 탭 핸들러
  void _onCollectedPostTap(PostModel post) {
    // 받은 포스트 상세 화면으로 이동
    Navigator.pushNamed(
      context,
      '/collected-post-detail',
      arguments: post.postId,
    );
  }

  /// 받은 포스트 롱프레스 핸들러
  void _onCollectedPostLongPress(PostModel post) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildCollectedPostActionSheet(post),
    );
  }

  /// 포스트 액션 시트
  Widget _buildPostActionSheet(PostModel post) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('수정'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/post-edit',
                arguments: post.postId,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('삭제'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmDialog(post);
            },
          ),
        ],
      ),
    );
  }

  /// 받은 포스트 액션 시트
  Widget _buildCollectedPostActionSheet(PostModel post) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('삭제'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteCollectedPostConfirmDialog(post);
            },
          ),
        ],
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 삭제'),
        content: const Text('이 포스트를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<InboxProvider>().deletePost(post.postId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('포스트가 삭제되었습니다')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 받은 포스트 삭제 확인 다이얼로그
  void _showDeleteCollectedPostConfirmDialog(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('받은 포스트 삭제'),
        content: const Text('이 받은 포스트를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<InboxProvider>().deleteCollectedPost(
                  post.postId,
                  _currentUserId!,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('받은 포스트가 삭제되었습니다')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 실패: $e')),
                  );
                }
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}