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
    _tabController = TabController(length: 2, vsync: this); // 내 포스트/받은 포스트 2개 탭
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
      appBar: AppBar(
        title: const Text('인박스'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 배포 통계 대시보드 버튼
          if (_tabController.index == 0) // 내 포스트 탭일 때만 표시
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.pushNamed(context, '/deployment-statistics');
              },
              tooltip: '배포 통계',
            ),
          // 새로고침 버튼
          if (_tabController.index == 0) // 내 포스트 탭일 때만 표시
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshMyPosts,
              tooltip: '새로고침',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black87,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: '내 포스트'),
            Tab(text: '받은 포스트'),
          ],
        ),
      ),
      body: Column(
        children: [

          // 검색 및 필터 영역
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // 검색/필터 토글 버튼
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    icon: const Icon(Icons.search),
                    label: Text(_showFilters ? '검색/필터 닫기' : '검색/필터 열기'),
                  ),
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '포스트 검색...',
                      prefixIcon: const Icon(Icons.search),
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
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_showFilters) ...[
                  // 필터 및 정렬 옵션들
                  Row(
                   children: [
                     // 상태 필터
                     Expanded(
                       child: DropdownButtonFormField<String>(
                         value: _statusFilter,
                         decoration: const InputDecoration(
                           labelText: '상태',
                           border: OutlineInputBorder(),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         items: const [
                           DropdownMenuItem(value: 'all', child: Text('전체')),
                           DropdownMenuItem(value: 'active', child: Text('활성')),
                           DropdownMenuItem(value: 'inactive', child: Text('비활성')),
                           DropdownMenuItem(value: 'deleted', child: Text('삭제됨')),
                         ],
                         onChanged: _onStatusFilterChanged,
                         hint: const Text('상태를 선택하세요'),
                       ),
                     ),
                     
                     const SizedBox(width: 12),
                     
                     // 기간 필터
                     Expanded(
                       child: DropdownButtonFormField<String>(
                         value: _periodFilter,
                         decoration: const InputDecoration(
                           labelText: '기간',
                           border: OutlineInputBorder(),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         items: const [
                           DropdownMenuItem(value: 'all', child: Text('전체')),
                           DropdownMenuItem(value: 'today', child: Text('오늘')),
                           DropdownMenuItem(value: 'week', child: Text('1주일')),
                           DropdownMenuItem(value: 'month', child: Text('1개월')),
                         ],
                         onChanged: _onPeriodFilterChanged,
                         hint: const Text('기간을 선택하세요'),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 12),
                 // 정렬 옵션들
                 Row(
                   children: [
                     // 정렬 기준
                     Expanded(
                       child: DropdownButtonFormField<String>(
                         value: _sortBy,
                         decoration: const InputDecoration(
                           labelText: '정렬 기준',
                           border: OutlineInputBorder(),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         items: const [
                           DropdownMenuItem(value: 'createdAt', child: Text('생성일')),
                           DropdownMenuItem(value: 'title', child: Text('제목')),
                           DropdownMenuItem(value: 'reward', child: Text('리워드')),
                           DropdownMenuItem(value: 'expiresAt', child: Text('만료일')),
                         ],
                         onChanged: _onSortByChanged,
                         hint: const Text('정렬 기준을 선택하세요'),
                       ),
                     ),
                     
                     const SizedBox(width: 12),
                     
                     // 정렬 순서
                     Expanded(
                       child: DropdownButtonFormField<String>(
                         value: _sortOrder,
                         decoration: const InputDecoration(
                           labelText: '정렬 순서',
                           border: OutlineInputBorder(),
                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                         ),
                         items: const [
                           DropdownMenuItem(value: 'desc', child: Text('내림차순')),
                           DropdownMenuItem(value: 'asc', child: Text('오름차순')),
                         ],
                         onChanged: _onSortOrderChanged,
                         hint: const Text('정렬 순서를 선택하세요'),
                       ),
                     ),
                   ],
                 ),
                ],
              ],
            ),
          ),
          
          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyPostsTab(),
                _buildCollectedPostsTab(),
              ],
            ),
          ),
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

  // 내 포스트 탭 (배포 전/배포된 nested tabs)
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

    return Column(
      children: [
        // 데이터 정보 헤더
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '총 ${totalPosts}개 중 ${filteredPosts.length}개 표시',
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
                  '배포 통계',
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
    );
  }

  // 배포된 포스트 탭 콘텐츠 (데이터 이미 로드됨)
  Widget _buildDeployedPostsTabContent(List<PostModel> deployedPosts) {
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
                                    'isEditable': true,
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
                                        arguments: post,
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.collections_bookmark, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('아직 받은 포스트가 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                SizedBox(height: 8),
                Text('지도에서 포스트를 찾아 수집해보세요!', 
                     style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        } else {
          final filteredPosts = _filterAndSortPosts(snapshot.data!);
          return Column(
            children: [
              // 데이터 정보 헤더
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '총 ${snapshot.data!.length}개 중 ${filteredPosts.length}개 표시',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
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


}
