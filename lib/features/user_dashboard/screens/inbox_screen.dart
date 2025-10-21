import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/inbox_provider.dart';
import '../../post_system/widgets/post_tile_card.dart';
import '../widgets/inbox_widgets/inbox_common_widgets.dart';
import '../../../core/models/post/post_model.dart';

/// 인박스 화면 - Provider 패턴 사용
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    
    // 초기 데이터 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InboxProvider>().loadInitialData();
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
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (provider.currentUserId == null) {
          return const Center(child: Text('로그인이 필요합니다.'));
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(provider),
          body: Column(
          children: [
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyPostsTab(provider),
                    _buildCollectedPostsTab(provider),
                    _buildStatisticsTab(provider),
                  ],
              ),
            ),
          ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.pushNamed(context, '/post-place');
            },
            icon: const Icon(Icons.add),
            label: const Text('포스트 만들기'),
            backgroundColor: Colors.blue[600],
          ),
        );
      },
    );
  }

  PreferredSize _buildAppBar(InboxProvider provider) {
    return PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[600]!, Colors.purple[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
        ),
        title: const Text(
          '내 포스트함',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // 필터 토글 버튼
          IconButton(
            icon: Icon(
              provider.showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: Colors.white,
            ),
            onPressed: () => provider.toggleFilters(),
          ),
          // 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => provider.refreshData(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue[700],
        unselectedLabelColor: Colors.grey[500],
        indicatorColor: Colors.blue[700],
        indicatorWeight: 3,
        tabs: const [
          Tab(text: '내 포스트'),
          Tab(text: '받은 포스트'),
          Tab(text: '통계'),
        ],
      ),
    );
  }

  Widget _buildMyPostsTab(InboxProvider provider) {
    return FutureBuilder(
      future: provider.myPostsLoaded ? null : provider.loadMyPosts(),
      builder: (context, snapshot) {
        if (!provider.myPostsLoaded && snapshot.connectionState == ConnectionState.waiting) {
          return InboxCommonWidgets.buildLoadingIndicator();
        }

        final draftPosts = provider.draftPosts;
        final deployedPosts = provider.deployedPosts;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue[50]!, Colors.white],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
              // 헤더 카드
              _buildMyPostsHeader(draftPosts, deployedPosts),
              const SizedBox(height: 12),
              
              // 필터 섹션
              if (provider.showFilters) _buildFiltersSection(provider),
              
              // 포스트 리스트
              Expanded(
                child: _buildMyPostsList(draftPosts, deployedPosts, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMyPostsHeader(List draftPosts, List deployedPosts) {
    return Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
          InboxCommonWidgets.buildSummaryItem(
            '배포 대기',
            '${draftPosts.length}',
            Icons.drafts,
                ),
                Container(
                  width: 1,
            height: 60,
                  color: Colors.white.withOpacity(0.3),
                ),
          InboxCommonWidgets.buildSummaryItem(
            '배포됨',
            '${deployedPosts.length}',
            Icons.rocket_launch,
                ),
              ],
            ),
    );
  }

  Widget _buildFiltersSection(InboxProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '필터',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '포스트 검색...',
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              suffixIcon: provider.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.updateSearchQuery('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) => provider.updateSearchQuery(value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InboxCommonWidgets.buildFilterChip(
                  '전체',
                  provider.statusFilter == 'all',
                  () => provider.setStatusFilter('all'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InboxCommonWidgets.buildFilterChip(
                  '활성',
                  provider.statusFilter == 'active',
                  () => provider.setStatusFilter('active'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InboxCommonWidgets.buildFilterChip(
                  '비활성',
                  provider.statusFilter == 'inactive',
                  () => provider.setStatusFilter('inactive'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyPostsList(List draftPosts, List deployedPosts, InboxProvider provider) {
    final allMyPosts = [...draftPosts, ...deployedPosts];
    
    if (allMyPosts.isEmpty) {
      return const Center(
        child: Text(
          '포스트가 없습니다.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
    );
  }

    return RefreshIndicator(
      onRefresh: () => provider.refreshMyPosts(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = InboxProvider.getCrossAxisCount(constraints.maxWidth);

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: allMyPosts.length,
            itemBuilder: (context, index) {
              final post = allMyPosts[index];
              return GestureDetector(
                onTap: () {
                  provider.selectPost(post.postId);
                  _showPostDetailDialog(post, provider);
                },
                child: PostTileCard(post: post),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCollectedPostsTab(InboxProvider provider) {
    if (provider.isLoading) {
      return InboxCommonWidgets.buildLoadingIndicator();
    }

    final collectedPosts = provider.collectedPosts;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.purple[50]!, Colors.white],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // 헤더 카드
          Container(
            height: 140,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[400]!, Colors.pink[400]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                InboxCommonWidgets.buildSummaryItem(
                  '받은 포스트',
                  '${collectedPosts.length}',
                  Icons.inbox,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 필터 섹션
          if (provider.showFilters) _buildFiltersSection(provider),
          
          // 포스트 리스트
        Expanded(
            child: _buildCollectedPostsList(provider),
        ),
        ],
      ),
    );
  }

  Widget _buildCollectedPostsList(InboxProvider provider) {
    final collectedPosts = provider.collectedPosts;
    
    if (collectedPosts.isEmpty) {
      return const Center(
        child: Text(
          '확인된 포스트가 없습니다.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.refreshCollectedPosts(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: collectedPosts.length,
        itemBuilder: (context, index) {
          final collection = collectedPosts[index];
          final postId = collection['postId'] as String?;
          final collectedAt = (collection['collectedAt'] as Timestamp?)?.toDate();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text('포스트 ID: ${postId ?? "알 수 없음"}'),
              subtitle: Text(
                '수령: ${collectedAt != null ? "${collectedAt.month}/${collectedAt.day} ${collectedAt.hour}:${collectedAt.minute.toString().padLeft(2, '0')}" : "알 수 없음"}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                // 포스트 상세 화면으로 이동
                if (postId != null) {
                  Navigator.pushNamed(context, '/post-detail', arguments: postId);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsTab(InboxProvider provider) {
    return FutureBuilder(
      future: provider.myPostsLoaded ? null : provider.loadMyPosts(),
      builder: (context, snapshot) {
        if (!provider.myPostsLoaded && snapshot.connectionState == ConnectionState.waiting) {
          return InboxCommonWidgets.buildLoadingIndicator();
        }

        final deployedPosts = provider.deployedPosts;

        // 통계 계산
        final totalDeployed = deployedPosts.length;
        final activeDeployed = deployedPosts.where((p) => 
          p.status == PostStatus.DEPLOYED && 
          (p.expiresAt == null || p.expiresAt!.isAfter(DateTime.now()))
        ).length;
        final totalReward = deployedPosts.fold<int>(
          0, (sum, post) => sum + post.reward
        );

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              colors: [Colors.orange[50]!, Colors.white],
              ),
            ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                  '배포 통계',
                              style: TextStyle(
                    fontSize: 20,
                                fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                    children: [
                    InboxCommonWidgets.buildDetailStatCard(
                      '총 배포',
                      '$totalDeployed',
                      Icons.rocket_launch,
                      Colors.blue,
                    ),
                    InboxCommonWidgets.buildDetailStatCard(
                      '활성 배포',
                      '$activeDeployed',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    InboxCommonWidgets.buildDetailStatCard(
                      '총 리워드',
                      '$totalReward',
                      Icons.attach_money,
                      Colors.orange,
                    ),
                    InboxCommonWidgets.buildDetailStatCard(
                      '평균 리워드',
                      totalDeployed > 0 ? '${(totalReward / totalDeployed).toStringAsFixed(0)}' : '0',
                      Icons.analytics,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/my-posts-statistics'),
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('상세 통계 보기'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                            ),
                          ),
                        ],
                      ),
          ),
        );
      },
    );
  }

  void _showPostDetailDialog(post, InboxProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('설명: ${post.description}'),
              const SizedBox(height: 8),
              Text('리워드: ${post.reward}원'),
              const SizedBox(height: 8),
              Text('상태: ${post.status.name}'),
              if (post.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text('만료일: ${post.expiresAt}'),
              ],
            ],
          ),
          ),
          actions: [
          if (post.status != PostStatus.DELETED) ...[
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _confirmDelete(post, provider);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
            TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              '/post-statistics',
              arguments: {'post': post},
            ),
            child: const Text('통계 보기'),
            ),
            TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(post, InboxProvider provider) async {
    final confirmed = await showDialog<bool>(
        context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 삭제'),
        content: const Text('휴지통으로 이동하시겠습니까? 30일 후 자동 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await provider.deletePost(post.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('포스트를 휴지통으로 이동했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  }
}
