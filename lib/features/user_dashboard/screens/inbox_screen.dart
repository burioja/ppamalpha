import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/models/post/post_model.dart';
import '../../post_system/widgets/post_tile_card.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PostService _postService = PostService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  
  // 검색 및 필터링 상태
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showFilters = false;
  String _statusFilter = 'all'; // all, active, inactive, deleted
  String _periodFilter = 'all'; // all, today, week, month
  String _sortBy = 'createdAt'; // createdAt, title, reward, expiresAt
  String _sortOrder = 'desc'; // asc, desc
  
  // 페이지네이션 상태
  final List<PostModel> _allPosts = [];
  final List<PostModel> _filteredPosts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 20;

  // 내 포스트 캐싱
  List<PostModel> _cachedDraftPosts = [];
  List<PostModel> _cachedDeployedPosts = [];
  bool _myPostsLoaded = false;

  // 선택된 포스트 ID 추적 (터치 UX용)
  String? _selectedPostId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 내 포스트/받은 포스트/통계 3개 탭
    _tabController.addListener(() {
      setState(() {});
    });
    
    // 초기 데이터 로딩
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove automatic reload to prevent double loading
    // Data will be loaded once in initState
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 검색 및 필터링 적용
  void _applyFilters() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  // 데이터 초기 로딩
  Future<void> _loadInitialData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _allPosts.clear();
      _filteredPosts.clear();
      _lastDocument = null;
      _hasMoreData = true;
      _myPostsLoaded = false; // 내 포스트도 새로고침
    });

    try {
      await _loadMoreData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 추가 데이터 로딩
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newPosts = await _postService.getUserPosts(
        _currentUserId!,
        limit: _pageSize,
        lastDocument: _lastDocument,
      );

      if (newPosts.isNotEmpty) {
        _allPosts.addAll(newPosts);
        // TODO: PostModel에 DocumentSnapshot 저장 필드 추가 필요
        // _lastDocument = newPosts.last.rawData;
        _hasMoreData = newPosts.length == _pageSize;
      } else {
        _hasMoreData = false;
      }

      // 필터링 및 정렬 적용
      _applyFiltersAndSorting();
    } catch (e) {
      debugPrint('❌ 추가 데이터 로딩 실패: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // 필터링 및 정렬 적용
  void _applyFiltersAndSorting() {
    _filteredPosts.clear();
    _filteredPosts.addAll(_filterAndSortPosts(_allPosts));
  }



  // 상태 필터 변경
  void _onStatusFilterChanged(String? value) {
    if (value != null) {
      setState(() {
        _statusFilter = value;
      });
    }
  }

  // 기간 필터 변경
  void _onPeriodFilterChanged(String? value) {
    if (value != null) {
      setState(() {
        _periodFilter = value;
      });
    }
  }

  // 정렬 기준 변경
  void _onSortByChanged(String? value) {
    if (value != null) {
      setState(() {
        _sortBy = value;
      });
    }
  }

  // 정렬 순서 변경
  void _onSortOrderChanged(String? value) {
    if (value != null) {
      setState(() {
        _sortOrder = value;
      });
    }
  }

  // 포스트 필터링 및 정렬
  List<PostModel> _filterAndSortPosts(List<PostModel> posts) {
    // 1단계: 필터링
    List<PostModel> filtered = posts.where((post) {
      // 검색어 필터링
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!post.title.toLowerCase().contains(query) && 
            !post.description.toLowerCase().contains(query) &&
            !post.creatorName.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // 상태 필터링
      if (_statusFilter != 'all') {
        switch (_statusFilter) {
          case 'active':
            if (post.status != PostStatus.DEPLOYED) return false;
            break;
          case 'inactive':
            if (post.status != PostStatus.DRAFT) return false;
            break;
          case 'deleted':
            if (post.status != PostStatus.DELETED) return false;
            break;
        }
      }
      
      // 기간 필터링
      if (_periodFilter != 'all') {
        final now = DateTime.now();
        final postDate = post.createdAt;
        switch (_periodFilter) {
          case 'today':
            if (!_isSameDay(postDate, now)) return false;
            break;
          case 'week':
            if (postDate.isBefore(now.subtract(const Duration(days: 7)))) return false;
            break;
          case 'month':
            if (postDate.isBefore(now.subtract(const Duration(days: 30)))) return false;
            break;
        }
      }
      
      return true;
    }).toList();
    
    // 2단계: 정렬
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'title':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'reward':
          comparison = a.reward.compareTo(b.reward);
          break;
        case 'expiresAt':
          comparison = a.defaultExpiresAt.compareTo(b.defaultExpiresAt);
          break;
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
      }
      
      // 정렬 순서 적용
      return _sortOrder == 'desc' ? -comparison : comparison;
    });
    
    return filtered;
  }

  // 같은 날짜인지 확인
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

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

  // 로딩 인디케이터 위젯
  Widget _buildLoadingIndicator() {
    if (!_hasMoreData) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              '로딩중...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return Scaffold(
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
            // TODO: SnackBar 대신 다른 방식으로 사용자에게 알림
            // 예: 상태 변수를 통해 UI에 메시지 표시
          }
        },
        backgroundColor: Colors.blue,
        tooltip: '포스트 만들기',
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  // 내 포스트 통합 탭 (배포 전 + 배포된 모두 표시)
  Widget _buildMyPostsUnifiedTab() {
    // 첫 로드 시에만 데이터 가져오기
    if (!_myPostsLoaded) {
      _loadMyPosts();
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

    final allMyPosts = [..._cachedDraftPosts, ..._cachedDeployedPosts];
    final filteredPosts = _filterAndSortPosts(allMyPosts);

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
          if (_showFilters) _buildFiltersSection(),
          
          const SizedBox(height: 20),
          // 요약 통계 카드
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
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
                  child: _buildSummaryItem('배포 전', '${_cachedDraftPosts.length}', Icons.drafts),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildSummaryItem('배포됨', '${_cachedDeployedPosts.length}', Icons.rocket_launch),
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
                // 필터 버튼
                IconButton(
                  icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, 
                    color: Colors.blue.shade700, size: 20),
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  tooltip: '필터',
                ),
                // 새로고침 버튼
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue.shade700, size: 20),
                  onPressed: _refreshMyPosts,
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
              onRefresh: _refreshMyPosts,
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
                              isSelected: _selectedPostId == post.postId,
                              showDeleteButton: _currentUserId == post.creatorId && isDraft,
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
                                setState(() {
                                  if (_selectedPostId == post.postId) {
                                    _selectedPostId = null;
                                  } else {
                                    _selectedPostId = post.postId;
                                  }
                                });
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
                                  setState(() {
                                    _selectedPostId = null;
                                    _myPostsLoaded = false; // 새로고침
                                  });
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
  }

  // 내 포스트 탭 (배포 전/배포된 nested tabs) - 하위 호환성 유지
  Widget _buildMyPostsTab() {
    // 첫 로드 시에만 데이터 가져오기
    if (!_myPostsLoaded) {
      _loadMyPosts();
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

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.grey.shade100,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: '배포 전'),
                Tab(text: '배포된'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDraftPostsTabContent(_cachedDraftPosts, _cachedDeployedPosts),
                _buildDeployedPostsTabContent(_cachedDeployedPosts),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 내 포스트 새로고침
  Future<void> _refreshMyPosts() async {
    setState(() {
      _myPostsLoaded = false;
    });
    await _loadMyPosts();
  }

  // 내 포스트 로드 (한 번만 실행)
  Future<void> _loadMyPosts() async {
    if (_myPostsLoaded) return;

    try {
      final results = await Future.wait([
        _postService.getDraftPosts(_currentUserId!),
        _postService.getDeployedPosts(_currentUserId!),
      ]);

      if (mounted) {
        setState(() {
          _cachedDraftPosts = results[0];
          _cachedDeployedPosts = results[1];
          _myPostsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('❌ 내 포스트 로드 에러: $e');
      if (mounted) {
        setState(() {
          _myPostsLoaded = true; // 에러여도 재시도 방지
        });
      }
    }
  }

  // 배포 전 포스트 탭 콘텐츠 (데이터 이미 로드됨)
  Widget _buildDraftPostsTabContent(List<PostModel> draftPosts, List<PostModel> deployedPosts) {
    final totalPosts = draftPosts.length + deployedPosts.length;
    final filteredPosts = _filterAndSortPosts(draftPosts);

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
          const SizedBox(height: 20),
          // 요약 통계 카드
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
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
                  child: _buildSummaryItem('전체', '$totalPosts', Icons.list_alt),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildSummaryItem('배포 전', '${draftPosts.length}', Icons.drafts),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildSummaryItem('배포됨', '${deployedPosts.length}', Icons.rocket_launch),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 데이터 정보 헤더
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
                // 배포 포스트 통계 링크 (PRD 요구사항)
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
                ),
              ],
            ),
          ),
        // 포스트 목록
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadInitialData,
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
              : NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                      // 스크롤이 끝에 도달했을 때 추가 데이터 로딩
                      _loadMoreData();
                    }
                    return true;
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.68, // 하단 오버플로우 방지를 위해 높이 증가
                        ),
                          itemCount: filteredPosts.length + (_hasMoreData ? 1 : 0),
                          itemBuilder: (context, index) {
                            // 로딩 인디케이터 표시
                            if (index == filteredPosts.length) {
                              return _buildLoadingIndicator();
                            }
                            
                            final post = filteredPosts[index];
                            return PostTileCard(
                              post: post,
                              isSelected: _selectedPostId == post.postId,
                              showDeleteButton: _currentUserId == post.creatorId,
                              onDelete: () => _showDeleteConfirmation(post),
                              showStatisticsButton: false,
                              onStatistics: null,
                              // 1번 탭: 선택 토글
                              onTap: () {
                                setState(() {
                                  if (_selectedPostId == post.postId) {
                                    _selectedPostId = null; // 선택 해제
                                  } else {
                                    _selectedPostId = post.postId; // 선택
                                  }
                                });
                              },
                              // 2번 탭: 상세 화면 이동
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
                                  setState(() {
                                    _selectedPostId = null;
                                  });
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ),
        ],
      ),
    );
  }

  // 필터 섹션
  Widget _buildFiltersSection() {
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
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _applyFilters();
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
            onChanged: (value) => _applyFilters(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip('전체', _statusFilter == 'all', () {
                  setState(() => _statusFilter = 'all');
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip('활성', _statusFilter == 'active', () {
                  setState(() => _statusFilter = 'active');
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterChip('비활성', _statusFilter == 'inactive', () {
                  setState(() => _statusFilter = 'inactive');
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.blue[400]!, Colors.purple[400]!],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // 요약 통계 아이템 위젯
  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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

  // 배포된 포스트 탭 콘텐츠 (데이터 이미 로드됨)
  Widget _buildDeployedPostsTabContent(List<PostModel> deployedPosts) {
    debugPrint('✅ 배포된 포스트 로드 성공: ${deployedPosts.length}개');

    // 디버그: 각 포스트 정보 출력
    for (var post in deployedPosts) {
      debugPrint('  📦 배포된 포스트: ${post.title} (status: ${post.status.name})');
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.green[50]!, Colors.white],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // 헤더 카드
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.teal[400]!],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
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
                  child: const Icon(Icons.rocket_launch, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '배포된 포스트',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${deployedPosts.length}개',
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

        // 포스트 그리드
        Expanded(
          child: deployedPosts.isEmpty
              ? const Center(
                  child: Text(
                    '배포된 포스트가 없습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInitialData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.65, // 오버플로우 방지를 위해 높이 증가
                        ),
                        itemCount: deployedPosts.length,
                        itemBuilder: (context, index) {
                          try {
                            final post = deployedPosts[index];

                            return PostTileCard(
                              post: post,
                              isSelected: _selectedPostId == post.postId,
                              showStatisticsButton: true,
                              onTap: () {
                                setState(() {
                                  if (_selectedPostId == post.postId) {
                                    _selectedPostId = null;
                                  } else {
                                    _selectedPostId = post.postId;
                                  }
                                });
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
                                if (result == true && mounted) {
                                  setState(() {
                                    _selectedPostId = null;
                                  });
                                }
                              },
                              onStatistics: () {
                                Navigator.pushNamed(
                                  context,
                                  '/post-statistics',
                                  arguments: {
                                    'post': post,
                                  },
                                );
                              },
                            );
                          } catch (e, stackTrace) {
                            debugPrint('❌ PostTileCard 렌더링 에러 (index=$index): $e');
                            debugPrint('스택 트레이스: $stackTrace');
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                border: Border.all(color: Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('포스트 로드 오류: $e', style: const TextStyle(color: Colors.red)),
                            );
                          }
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

  // 배포된 포스트 탭 (DEPLOYED 상태만) - 하위 호환성 유지
  Widget _buildDeployedPostsTab() {
    return FutureBuilder<List<PostModel>>(
      future: _postService.getDeployedPosts(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('배포된 포스트를 불러오는 중...', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          debugPrint('❌ 배포된 포스트 탭 에러: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text('배포된 포스트 로드 오류', style: TextStyle(fontSize: 18, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('${snapshot.error}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {}); // 재시도
                  },
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          debugPrint('📭 배포된 포스트 없음: 데이터 ${snapshot.data?.length ?? 0}개');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('아직 배포된 포스트가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('배포 전 포스트를 마커에 배포해보세요!',
                     style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        } else {
          final deployedPosts = snapshot.data!;
          debugPrint('✅ 배포된 포스트 로드 성공: ${deployedPosts.length}개');

          // 디버그: 각 포스트 정보 출력
          for (var post in deployedPosts) {
            debugPrint('  📦 배포된 포스트: ${post.title} (status: ${post.status.name})');
          }

          return Column(
            children: [
              // 데이터 정보 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '총 ${deployedPosts.length}개 배포됨',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 포스트 그리드
              Expanded(
                child: deployedPosts.isEmpty
                    ? const Center(
                        child: Text(
                          '배포된 포스트가 없습니다.',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInitialData,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.70, // 오버플로우 방지를 위해 높이 증가
                              ),
                              itemCount: deployedPosts.length,
                              itemBuilder: (context, index) {
                                try {
                                  final post = deployedPosts[index];
                                  debugPrint('🎨 렌더링 중: index=$index, postId=${post.postId}, title=${post.title}');

                                  return PostTileCard(
                                    post: post,
                                    isSelected: _selectedPostId == post.postId,
                                    showStatisticsButton: true,
                                    onTap: () {
                                      setState(() {
                                        if (_selectedPostId == post.postId) {
                                          _selectedPostId = null;
                                        } else {
                                          _selectedPostId = post.postId;
                                        }
                                      });
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
                                      if (result == true && mounted) {
                                        setState(() {
                                          _selectedPostId = null;
                                        });
                                      }
                                    },
                                    onStatistics: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/post-statistics',
                                        arguments: post,
                                      );
                                    },
                                  );
                                } catch (e, stackTrace) {
                                  debugPrint('❌ PostTileCard 렌더링 에러 (index=$index): $e');
                                  debugPrint('스택 트레이스: $stackTrace');
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      border: Border.all(color: Colors.red),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('포스트 로드 오류: $e', style: const TextStyle(color: Colors.red)),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        }
      },
    );
  }

  // 받은 포스트 탭 (PRD에 맞게 수정)
  Widget _buildCollectedPostsTab() {
    return FutureBuilder<List<PostModel>>(
      future: _postService.getCollectedPosts(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('받은 포스트 로드 오류: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
        } else {
          final filteredPosts = _filterAndSortPosts(snapshot.data!);
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
                if (_showFilters) _buildFiltersSection(),
                
                const SizedBox(height: 20),
                // 헤더 카드
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
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
                              '${snapshot.data!.length}개',
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
                      // 필터 버튼
                      IconButton(
                        icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list, 
                          color: Colors.purple.shade700, size: 20),
                        onPressed: () => setState(() => _showFilters = !_showFilters),
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
                  onRefresh: _loadInitialData,
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
                              childAspectRatio: 0.68, // 하단 오버플로우 방지를 위해 높이 증가
                            ),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
                          return PostTileCard(
                            post: post,
                            isSelected: _selectedPostId == post.postId,
                            onTap: () {
                              setState(() {
                                if (_selectedPostId == post.postId) {
                                  _selectedPostId = null;
                                } else {
                                  _selectedPostId = post.postId;
                                }
                              });
                            },
                            onDoubleTap: () async {
                              final result = await Navigator.pushNamed(
                                context,
                                '/post-detail',
                                arguments: {
                                  'post': post,
                                  'isEditable': false,
                                },
                              );

                              if (result == true || result == 'used') {
                                setState(() {
                                  _selectedPostId = null;
                                });
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
        }
      },
    );
  }

  // 포스트 삭제 확인 다이얼로그
  void _showDeleteConfirmation(PostModel post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('포스트 삭제'),
          content: Text(
            '정말 이 포스트를 삭제하겠습니까?\n\n"${post.title}"\n\n삭제된 포스트는 복구할 수 없습니다.',
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
                foregroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  // 포스트 삭제 실행
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
                Text("포스트를 삭제하는 중..."),
              ],
            ),
          );
        },
      );

      // 포스트 삭제
      await _postService.deletePost(post.postId);

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 인박스 새로고침
        setState(() {});
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포스트 삭제에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 배포 포스트 통계 표시 (PRD 요구사항) - 전체 페이지로 이동
  void _showDistributedPostsStats(BuildContext context) {
    Navigator.pushNamed(context, '/my-posts-statistics');
  }

  // 포스트 통계 화면으로 이동
  void _showPostStatistics(PostModel post) {
    Navigator.pushNamed(
      context,
      '/post-statistics',
      arguments: {
        'post': post,
      },
    );
  }


  // 내 스토어로 이동 (PRD 요구사항)
  void _navigateToMyStore(BuildContext context) {
    Navigator.pushNamed(context, '/store');
  }

  // 통계 탭
  Widget _buildStatisticsTab() {
    return FutureBuilder<List<PostModel>>(
      future: _postService.getDeployedPosts(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final deployedPosts = snapshot.data ?? [];
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
            padding: const EdgeInsets.all(20),
            children: [
              // 전체 통계 카드
              Container(
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.bar_chart, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Text(
                          '배포 통계',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
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


}
