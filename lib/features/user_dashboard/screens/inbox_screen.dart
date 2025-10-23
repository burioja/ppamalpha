import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/inbox_provider.dart';
import '../../../core/models/post/post_model.dart';
import '../widgets/inbox/inbox_statistics_tab.dart';
import '../widgets/inbox/inbox_filter_section.dart';
import '../widgets/inbox_widgets/inbox_common_widgets.dart';
import '../../post_system/widgets/post_tile_card.dart';

/// 인박스 화면 - 8cb9a693 디자인 복원
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
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: AppBar(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: SafeArea(
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: '내 포스트'),
                  Tab(text: '받은 포스트'),
                  Tab(text: '통계'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMyPostsUnifiedTab(),
            _buildCollectedPostsTab(),
            _buildStatisticsTab(),
          ],
        ),
        floatingActionButton: _tabController.index == 0 ? FloatingActionButton(
          onPressed: () async {
            // context를 로컬 변수로 저장
            final currentContext = context;
            
            // 플레이스 선택 화면으로 이동
            final result = await Navigator.pushNamed(
              currentContext, 
              '/post-place-selection',
              arguments: {
                'fromInbox': true,
                'returnToInbox': true,
              },
            );
            
            // 포스트 생성 완료 후 인박스 갱신
            if (result == true && mounted) {
              setState(() {
                // 상태 갱신으로 데이터 재로드
              });
            }
          },
          backgroundColor: Colors.blue,
          tooltip: '포스트 만들기',
          child: const Icon(Icons.add, color: Colors.white),
        ) : null,
      ),
    );
  }

  // 내 포스트 통합 탭 (배포 전 + 배포된 모두 표시)
  Widget _buildMyPostsUnifiedTab() {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        // 첫 로드 시에만 데이터 가져오기
        if (!provider.myPostsLoaded) {
          provider.loadMyPosts();
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('포스트를 불러오는 중...', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        final allMyPosts = [...provider.draftPosts, ...provider.deployedPosts];
        final filteredPosts = provider.filterAndSortPosts(allMyPosts);

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
              // 필터 영역 (토글)
              if (provider.showFilters) _buildFiltersSection(provider),
              
              const SizedBox(height: 16),
              // 요약 통계 카드
              Container(
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
                  children: [
                    Expanded(
                      child: _buildSummaryItem('전체', '${allMyPosts.length}', Icons.list_alt),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildSummaryItem('배포 전', '${provider.draftPosts.length}', Icons.drafts),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildSummaryItem('배포됨', '${provider.deployedPosts.length}', Icons.rocket_launch),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 데이터 정보 헤더 + 필터/새로고침 버튼
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${filteredPosts.length}개 표시 중',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // 정렬 드롭다운
                    PopupMenuButton<String>(
                      icon: Icon(Icons.sort, color: Colors.blue.shade700, size: 20),
                      tooltip: '정렬',
                      padding: const EdgeInsets.all(4),
                      onSelected: (value) {
                        provider.setSortBy(value);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'createdAt',
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: provider.sortBy == 'createdAt' ? Colors.blue : Colors.grey),
                              const SizedBox(width: 8),
                              Text('최신순', style: TextStyle(color: provider.sortBy == 'createdAt' ? Colors.blue : Colors.black)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reward',
                          child: Row(
                            children: [
                              Icon(Icons.attach_money, size: 16, color: provider.sortBy == 'reward' ? Colors.blue : Colors.grey),
                              const SizedBox(width: 8),
                              Text('가격순', style: TextStyle(color: provider.sortBy == 'reward' ? Colors.blue : Colors.black)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'title',
                          child: Row(
                            children: [
                              Icon(Icons.text_fields, size: 16, color: provider.sortBy == 'title' ? Colors.blue : Colors.grey),
                              const SizedBox(width: 8),
                              Text('이름순', style: TextStyle(color: provider.sortBy == 'title' ? Colors.blue : Colors.black)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 휴지통 버튼
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.orange.shade700, size: 20),
                      onPressed: () => Navigator.pushNamed(context, '/trash'),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '휴지통',
                    ),
                    // 필터 버튼
                    IconButton(
                      icon: Icon(provider.showFilters ? Icons.filter_list_off : Icons.filter_list, 
                        color: Colors.blue.shade700, size: 20),
                      onPressed: () => provider.toggleFilters(),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '필터',
                    ),
                    // 새로고침 버튼
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.blue.shade700, size: 20),
                      onPressed: () => provider.refreshMyPosts(),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '새로고침',
                    ),
                    // 배포 포스트 통계 링크
                    TextButton.icon(
                      onPressed: () => _showDistributedPostsStats(context),
                      icon: Icon(Icons.analytics, size: 16, color: Colors.blue.shade700),
                      label: Text(
                        '통계',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              // 포스트 목록
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refreshMyPosts(),
                  child: filteredPosts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.filter_list, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('검색어나 필터를 변경해보세요.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
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
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post = filteredPosts[index];
                                final isDraft = post.status == PostStatus.DRAFT;
                                
                                return PostTileCard(
                                  post: post,
                                  isSelected: provider.selectedPostId == post.postId,
                                  showDeleteButton: true, // 모든 포스트에 삭제 버튼 표시
                                  onDelete: () => _showDeleteConfirmation(post),
                                  showStatisticsButton: !isDraft,
                                  onStatistics: !isDraft ? () {
                                    Navigator.pushNamed(
                                      context,
                                      '/post-statistics',
                                      arguments: {'post': post},
                                    );
                                  } : null,
                                  onTap: () {
                                    provider.setSelectedPostId(
                                      provider.selectedPostId == post.postId ? null : post.postId
                                    );
                                  },
                                  onDoubleTap: () async {
                                    final result = await Navigator.pushNamed(
                                      context,
                                      '/post-detail',
                                      arguments: {
                                        'post': post,
                                        'isEditable': _currentUserId == post.creatorId,
                                      },
                                    );

                                    if (result == true || result == 'deleted') {
                                      provider.setSelectedPostId(null);
                                      provider.myPostsLoaded = false; // 새로고침
                                    }
                                  },
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
      },
    );
  }

  /// 통계 탭 (8cb9a693 디자인 복원)
  Widget _buildStatisticsTab() {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final deployedPosts = provider.deployedPosts;
        final totalDeployed = deployedPosts.length;
        
        // 간단한 통계 계산
        int totalCollections = 0;
        for (var post in deployedPosts) {
          // TODO: 실제 수집 수 계산 (마커 데이터에서)
          totalCollections += 0;
        }
        
        final collectionRate = totalDeployed > 0 ? (totalCollections / totalDeployed * 100).toStringAsFixed(0) : '0';

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orange[50]!, Colors.white],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 전체 통계 카드
              Container(
                height: 140,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[400]!, Colors.red[400]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('총 배포', '$totalDeployed개', Icons.rocket_launch),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildStatItem('총 수집', '${totalCollections}개', Icons.download),
                    ),
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: _buildStatItem('수집률', '$collectionRate%', Icons.trending_up),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 개별 통계 카드들
              _buildDetailStatCard(
                '오늘 배포',
                '${deployedPosts.where((p) => _isSameDay(p.createdAt, DateTime.now())).length}개',
                Icons.today,
                Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildDetailStatCard(
                '이번 주 배포',
                '${deployedPosts.where((p) => p.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length}개',
                Icons.date_range,
                Colors.green,
              ),
              const SizedBox(height: 16),
              _buildDetailStatCard(
                '배포된 포스트',
                '$totalDeployed개',
                Icons.list_alt,
                Colors.purple,
              ),
              
              const SizedBox(height: 24),
              
              // 상세 통계 버튼
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/deployment-statistics');
                },
                icon: const Icon(Icons.analytics),
                label: const Text('상세 통계 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 필터 섹션 빌더
  Widget _buildFiltersSection(InboxProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 필터 헤더
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '필터 옵션',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: provider.resetFilters,
                child: Text(
                  '초기화',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 검색 바
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '포스트 검색...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        provider.applyFilters('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              provider.applyFilters(value);
            },
          ),
          const SizedBox(height: 12),
          
          // 상태 필터
          _buildFilterRow(
            '상태',
            provider.statusFilter,
            ['all', 'active', 'inactive', 'deleted'],
            ['전체', '활성', '비활성', '삭제됨'],
            provider.onStatusFilterChanged,
          ),
          const SizedBox(height: 12),
          
          // 기간 필터
          _buildFilterRow(
            '기간',
            provider.periodFilter,
            ['all', 'today', 'week', 'month'],
            ['전체', '오늘', '1주일', '1개월'],
            provider.onPeriodFilterChanged,
          ),
          const SizedBox(height: 12),
          
          // 정렬 기준
          _buildFilterRow(
            '정렬 기준',
            provider.sortBy,
            ['createdAt', 'title', 'reward', 'expiresAt'],
            ['생성일', '제목', '보상', '만료일'],
            provider.onSortByChanged,
          ),
          const SizedBox(height: 12),
          
          // 정렬 순서
          _buildFilterRow(
            '정렬 순서',
            provider.sortOrder,
            ['desc', 'asc'],
            ['내림차순', '오름차순'],
            provider.onSortOrderChanged,
          ),
        ],
      ),
    );
  }

  /// 필터 행 빌더
  Widget _buildFilterRow(
    String label,
    String currentValue,
    List<String> values,
    List<String> labels,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: values.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;
            final isSelected = currentValue == value;
            
            return _buildFilterChip(
              labels[index],
              isSelected,
              () => onChanged(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 필터 칩
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 크로스축 개수 계산
  int _getCrossAxisCount(double width) {
    // 반응형 그리드 컬럼 수 계산 (3열 기본으로 조정)
    if (width < 600) {
      return 3; // 모바일: 3열 (기본)
    } else if (width < 1000) {
      return 3; // 태블릿: 3열 (웹에서 4열이 너무 작아서 3열 유지)
    } else {
      return 4; // 데스크톱: 4열 (큰 화면에서만 4열)
    }
  }

  /// 요약 아이템 빌더
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  /// 통계 아이템 빌더
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  /// 상세 통계 카드 빌더
  Widget _buildDetailStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color[300]!, color[500]!],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color[700],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 20, color: Colors.grey[300]),
        ],
      ),
    );
  }

  /// 같은 날짜인지 확인
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  /// 받은 포스트 탭 (8cb9a693 디자인 복원)
  Widget _buildCollectedPostsTab() {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.collectedPosts.isEmpty) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.purple[50]!, Colors.white],
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('아직 받은 포스트가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('지도에서 포스트를 찾아 수집해보세요!', 
                       style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        final filteredPosts = provider.filterAndSortPosts(provider.collectedPosts);
        
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
              // 필터 영역 (토글)
              if (provider.showFilters) _buildFiltersSection(provider),
              
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.card_giftcard, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '수집한 포스트',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${provider.collectedPosts.length}개',
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
              const SizedBox(height: 12),
              // 필터 버튼 바
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.purple.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${filteredPosts.length}개 표시 중',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // 정렬 드롭다운
                    PopupMenuButton<String>(
                      icon: Icon(Icons.sort, color: Colors.purple.shade700, size: 20),
                      tooltip: '정렬',
                      padding: const EdgeInsets.all(4),
                      onSelected: (value) {
                        provider.setSortBy(value);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'createdAt',
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 16, color: provider.sortBy == 'createdAt' ? Colors.purple : Colors.grey),
                              const SizedBox(width: 8),
                              Text('최신순', style: TextStyle(color: provider.sortBy == 'createdAt' ? Colors.purple : Colors.black)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reward',
                          child: Row(
                            children: [
                              Icon(Icons.attach_money, size: 16, color: provider.sortBy == 'reward' ? Colors.purple : Colors.grey),
                              const SizedBox(width: 8),
                              Text('가격순', style: TextStyle(color: provider.sortBy == 'reward' ? Colors.purple : Colors.black)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'title',
                          child: Row(
                            children: [
                              Icon(Icons.text_fields, size: 16, color: provider.sortBy == 'title' ? Colors.purple : Colors.grey),
                              const SizedBox(width: 8),
                              Text('이름순', style: TextStyle(color: provider.sortBy == 'title' ? Colors.purple : Colors.black)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 필터 버튼
                    IconButton(
                      icon: Icon(provider.showFilters ? Icons.filter_list_off : Icons.filter_list, 
                        color: Colors.purple.shade700, size: 20),
                      onPressed: () => provider.toggleFilters(),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      tooltip: '필터',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 포스트 목록
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.refreshCollectedPosts(),
                  child: filteredPosts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 200),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.filter_list, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('검색 결과가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                                  SizedBox(height: 8),
                                  Text('검색어나 필터를 변경해보세요.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : LayoutBuilder(
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
                              itemCount: filteredPosts.length,
                              itemBuilder: (context, index) {
                                final post = filteredPosts[index];
                                return PostTileCard(
                                  post: post,
                                  isSelected: provider.selectedPostId == post.postId,
                                  showDeleteButton: true, // 받은 포스트도 삭제 버튼 표시
                                  onDelete: () => _showDeleteCollectedPost(post),
                                  hideTextOverlay: true, // 제목/가격 숨김
                                  enableImageViewer: true, // 이미지 확대 뷰어 활성화
                                  onTap: () {
                                    provider.setSelectedPostId(
                                      provider.selectedPostId == post.postId ? null : post.postId
                                    );
                                  },
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
      },
    );
  }

  /// 내 포스트 휴지통 이동 확인 다이얼로그
  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('휴지통으로 이동'),
          content: Text(
            '이 포스트를 휴지통으로 이동하시겠습니까?\n\n"${post.title}"\n\n휴지통에서 30일 이내에 복원할 수 있습니다.\n30일 후 자동으로 영구 삭제됩니다.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePost(post);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('휴지통으로 이동'),
            ),
          ],
        );
      },
    );
  }

  /// 받은 포스트 삭제 확인 다이얼로그
  void _showDeleteCollectedPost(PostModel post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('수집 기록 삭제'),
          content: Text(
            '이 포스트의 수집 기록을 삭제하시겠습니까?\n\n"${post.title}"\n\n삭제된 기록은 복구할 수 없습니다.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCollectedPost(post);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  /// 내 포스트 휴지통으로 이동
  Future<void> _deletePost(PostModel post) async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("휴지통으로 이동하는 중..."),
              ],
            ),
          );
        },
      );

      // 포스트를 휴지통으로 이동
      await context.read<InboxProvider>().deletePost(post.postId);

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트를 휴지통으로 이동했습니다. 30일 후 자동 삭제됩니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // 인박스 새로고침
        context.read<InboxProvider>().myPostsLoaded = false;
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('휴지통 이동에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 받은 포스트 삭제 실행 (수집 기록 제거)
  Future<void> _deleteCollectedPost(PostModel post) async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("수집 기록을 삭제하는 중..."),
              ],
            ),
          );
        },
      );

      // 수집 기록 삭제
      await context.read<InboxProvider>().deleteCollectedPost(
        post.postId,
        _currentUserId!,
      );

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('수집 기록이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 인박스 새로고침
        context.read<InboxProvider>().refreshData();
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수집 기록 삭제에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 배포 포스트 통계 표시 (PRD 요구사항) - 전체 페이지로 이동
  void _showDistributedPostsStats(BuildContext context) {
    Navigator.pushNamed(context, '/my-posts-statistics');
  }
}