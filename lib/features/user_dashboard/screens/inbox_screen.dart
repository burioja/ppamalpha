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
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.blue[600],
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        '파이오락스',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_formatNumber(provider.userBalance ?? 0)}P',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.shopping_bag, color: Colors.white),
                      const SizedBox(width: 12),
                      const Icon(Icons.search, color: Colors.white),
                    ],
                  ),
                ),
                // DEBUG 라벨
                Positioned(
                  top: 0,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

          // 필터/정렬 바
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${collectedPosts.length}개 표시 중',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.grey, size: 20),
                  onPressed: () => provider.toggleFilters(),
                ),
                IconButton(
                  icon: const Icon(Icons.sort, color: Colors.grey, size: 20),
                  onPressed: () {
                    // 정렬 기능
                  },
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
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3개씩 세로로 쌓기
          childAspectRatio: 0.75, // 카드 비율 조정
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: collectedPosts.length,
        itemBuilder: (context, index) {
          final collection = collectedPosts[index];
          final postId = collection['postId'] as String?;
          final collectedAt = (collection['collectedAt'] as Timestamp?)?.toDate();
          final reward = collection['reward'] as int? ?? 0;
          final postTitle = collection['postTitle'] as String? ?? '포스트';
          
          return GestureDetector(
            onTap: () {
              // 포스트 상세 화면으로 이동
              if (postId != null) {
                Navigator.pushNamed(context, '/post-detail', arguments: postId);
              }
            },
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green[50]!,
                      Colors.white,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상단 아이콘과 삭제 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 16,
                        ),
                        Icon(
                          Icons.delete_outline,
                          color: Colors.grey[400],
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // 포스트 이미지 영역 (플레이스홀더)
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image,
                          color: Colors.grey[400],
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    
                    // 포스트 제목
                    Text(
                      postTitle.length > 8 ? '${postTitle.substring(0, 8)}...' : postTitle,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    
                    // 보상 포인트 버튼
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${reward}P',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    // 수령 시간
                    Text(
                      collectedAt != null 
                        ? '${collectedAt.month}/${collectedAt.day}'
                        : '알 수 없음',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
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
                  // 상단 통계 카드 (예전 디자인)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[400]!, Colors.red[400]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
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
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // 총 배포
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  '$totalDeployed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                fontWeight: FontWeight.bold,
                  ),
                ),
                                const Text(
                                  '총 배포',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 구분선
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          // 총 수집
                          Expanded(
                            child: Column(
                    children: [
                                const Icon(Icons.download, color: Colors.white, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  '0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '총 수집',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                    ),
                  ],
                ),
                          ),
                          // 구분선
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          // 수집률
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.trending_up, color: Colors.white, size: 24),
                                const SizedBox(height: 8),
                                const Text(
                                  '0%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '수집률',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 개별 통계 카드들
                  _buildStatCard(
                    '오늘 배포',
                    '0',
                    Icons.today,
                    Colors.lightBlue,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    '이번 주 배포',
                    '$totalDeployed',
                    Icons.date_range,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildStatCard(
                    '배포된 포스트',
                    '$totalDeployed',
                    Icons.article,
                    Colors.purple,
                  ),
                  const SizedBox(height: 20),

                  // 상세 통계 보기 버튼
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        // 상세 통계 화면으로 이동
                      },
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      label: const Text(
                        '상세 통계 보기',
                        style: TextStyle(color: Colors.white, fontSize: 16),
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

    Widget _buildStatCard(String label, String value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${value}개',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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

  /// 숫자 포맷팅 (천단위 콤마)
  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
