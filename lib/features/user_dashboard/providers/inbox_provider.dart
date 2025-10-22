import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/models/post/post_model.dart';

/// 인박스 화면의 상태 및 비즈니스 로직 관리
class InboxProvider with ChangeNotifier {
  final PostService _postService = PostService();
  final String? currentUserId;

  InboxProvider({required this.currentUserId});

  // ==================== 상태 변수들 ====================
  
  // 검색 및 필터링 상태
  String searchQuery = '';
  bool showFilters = false;
  String statusFilter = 'all'; // all, active, inactive, deleted
  String periodFilter = 'all'; // all, today, week, month
  String sortBy = 'createdAt'; // createdAt, title, reward, expiresAt
  String sortOrder = 'desc'; // asc, desc
  
  // 페이지네이션 상태
  final List<PostModel> allPosts = [];
  final List<PostModel> filteredPosts = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  DocumentSnapshot? lastDocument;
  static const int pageSize = 20;

  // 내 포스트 캐싱
  List<PostModel> cachedDraftPosts = [];
  List<PostModel> cachedDeployedPosts = [];
  bool myPostsLoaded = false;

  // 수령한 포스트
  List<PostModel> collectedPosts = [];
  bool collectedPostsLoaded = false;

  // 선택된 포스트 ID 추적 (터치 UX용)
  String? selectedPostId;

  // 사용자 포인트
  int? userBalance;

  // 통계 데이터
  Map<String, dynamic> statistics = {};
  bool statisticsLoaded = false;

  // ==================== 필터 및 검색 ====================
  
  /// 필터 표시 토글
  void toggleFilters() {
    showFilters = !showFilters;
    notifyListeners();
  }
  
  /// 검색어 적용
  void applyFilters(String query) {
    searchQuery = query.trim();
    _applyFiltersAndSorting();
  }
  
  /// 상태 필터 변경
  void onStatusFilterChanged(String? value) {
    if (value != null) {
      statusFilter = value;
      _applyFiltersAndSorting();
    }
  }
  
  /// 기간 필터 변경
  void onPeriodFilterChanged(String? value) {
    if (value != null) {
      periodFilter = value;
      _applyFiltersAndSorting();
    }
  }
  
  /// 정렬 기준 변경
  void onSortByChanged(String? value) {
    if (value != null) {
      sortBy = value;
      _applyFiltersAndSorting();
    }
  }
  
  /// 정렬 순서 변경
  void onSortOrderChanged(String? value) {
    if (value != null) {
      sortOrder = value;
      _applyFiltersAndSorting();
    }
  }
  
  /// 선택된 포스트 ID 설정
  void setSelectedPostId(String? postId) {
    selectedPostId = postId;
    notifyListeners();
  }
  
  /// 필터링 및 정렬 적용
  void _applyFiltersAndSorting() {
    filteredPosts.clear();
    filteredPosts.addAll(_filterAndSortPosts(allPosts));
    notifyListeners();
  }
  
  /// 포스트 필터링 및 정렬
  List<PostModel> _filterAndSortPosts(List<PostModel> posts) {
    // 1단계: 필터링
    List<PostModel> filtered = posts.where((post) {
      // 검색어 필터링
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!post.title.toLowerCase().contains(query) && 
            !post.description.toLowerCase().contains(query) &&
            !post.creatorName.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // 상태 필터링
      if (statusFilter != 'all') {
        switch (statusFilter) {
          case 'active':
            return post.status == PostStatus.DEPLOYED;
          case 'inactive':
            return post.status == PostStatus.DRAFT;
          case 'deleted':
            return post.status == PostStatus.DELETED;
        }
      }
      
      // 기간 필터링
      if (periodFilter != 'all') {
        final now = DateTime.now();
        switch (periodFilter) {
          case 'today':
            return post.createdAt.isAfter(now.subtract(const Duration(days: 1)));
          case 'week':
            return post.createdAt.isAfter(now.subtract(const Duration(days: 7)));
          case 'month':
            return post.createdAt.isAfter(now.subtract(const Duration(days: 30)));
        }
      }
      
      return true;
    }).toList();
    
    // 2단계: 정렬
    filtered.sort((a, b) {
      int comparison = 0;
      
      switch (sortBy) {
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'reward':
          comparison = a.reward.compareTo(b.reward);
          break;
        case 'expiresAt':
          comparison = a.defaultExpiresAt.compareTo(b.defaultExpiresAt);
          break;
      }
      
      return sortOrder == 'desc' ? -comparison : comparison;
    });
    
    return filtered;
  }

  // ==================== 데이터 로딩 ====================
  
  /// 초기 데이터 로딩
  Future<void> loadInitialData() async {
    if (isLoading || currentUserId == null) return;

    isLoading = true;
    allPosts.clear();
    filteredPosts.clear();
    lastDocument = null;
    hasMoreData = true;
    myPostsLoaded = false;
    collectedPostsLoaded = false;
    notifyListeners();

    try {
      await Future.wait([
        loadMoreData(),
        loadCollectedPosts(), // 수령한 포스트도 로딩
        loadUserBalance(), // 사용자 포인트 로딩
        loadStatistics(), // 통계 데이터 로딩
      ]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 사용자 포인트 로딩
  Future<void> loadUserBalance() async {
    if (currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId!)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        userBalance = data?['points'] as int? ?? 0;
        debugPrint('✅ 사용자 포인트 로딩 완료: $userBalance P');
      } else {
        userBalance = 0;
        debugPrint('⚠️ 사용자 문서를 찾을 수 없음');
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 사용자 포인트 로딩 실패: $e');
      userBalance = 0;
    }
  }

  /// 추가 데이터 로딩 (페이지네이션)
  Future<void> loadMoreData() async {
    if (isLoadingMore || !hasMoreData || currentUserId == null) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final newPosts = await _postService.getUserPosts(
        currentUserId!,
        limit: pageSize,
        lastDocument: lastDocument,
      );

      if (newPosts.isNotEmpty) {
        allPosts.addAll(newPosts);
        hasMoreData = newPosts.length == pageSize;
      } else {
        hasMoreData = false;
      }

      applyFiltersAndSorting();
    } catch (e) {
      debugPrint('❌ 추가 데이터 로딩 실패: $e');
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 내 포스트 로딩 (캐시 활용)
  Future<void> loadMyPosts() async {
    if (myPostsLoaded || currentUserId == null) return;

    try {
      // 내 포스트 전체 조회
      final allMyPosts = await _postService.getUserPosts(currentUserId!, limit: 100);
      
      // 상태별로 분류
      cachedDraftPosts = allMyPosts.where((p) => p.status == PostStatus.DRAFT).toList();
      cachedDeployedPosts = allMyPosts.where((p) => p.status == PostStatus.DEPLOYED).toList();
      
      debugPrint('✅ 내 포스트 로딩 완료: 초안 ${cachedDraftPosts.length}개, 배포 ${cachedDeployedPosts.length}개');
      
      myPostsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 내 포스트 로딩 실패: $e');
    }
  }

  /// 수령한 포스트 로딩 (확인된 포스트만)
  Future<void> loadCollectedPosts() async {
    if (collectedPostsLoaded || currentUserId == null) return;

    try {
      // post_collections에서 확인된 포스트만 조회
      final collectionDocs = await FirebaseFirestore.instance
          .collection('post_collections')
          .doc(currentUserId!)
          .collection('received')
          .where('confirmed', isEqualTo: true) // ✅ 확인된 포스트만
          .orderBy('collectedAt', descending: true)
          .limit(100)
          .get();
      
      // 수집된 포스트 정보를 PostModel로 변환
      collectedPosts = collectionDocs.docs.map((doc) {
        final data = doc.data();
        return PostModel(
          postId: data['postId'] ?? doc.id,
          creatorId: data['creatorId'] ?? '',
          creatorName: data['creatorName'] ?? '익명',
          createdAt: (data['collectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          reward: data['reward'] ?? 0,
          defaultRadius: 1000,
          defaultExpiresAt: DateTime.now().add(const Duration(days: 30)),
          targetAge: const [20, 30],
          targetGender: 'all',
          targetInterest: const [],
          targetPurchaseHistory: const [],
          mediaType: const ['text'],
          mediaUrl: const [],
          thumbnailUrl: const [],
          title: data['title'] ?? '받은 포스트',
          description: data['description'] ?? '',
          canRespond: false,
          canForward: false,
          canRequestReward: false,
          canUse: true,
          placeId: null,
          status: PostStatus.DEPLOYED,
          rawSnapshot: doc,
          collectedAt: (data['collectedAt'] as Timestamp?)?.toDate(),
          expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
          isCoupon: data['isCoupon'] ?? false,
          couponData: data['couponData'],
          youtubeUrl: data['youtubeUrl'],
        );
      }).toList();
      
      debugPrint('✅ 수령한 포스트 (확인됨) 로딩 완료: ${collectedPosts.length}개');
      
      collectedPostsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 수령한 포스트 로딩 실패: $e');
    }
  }

  // ==================== 필터링 및 정렬 ====================
  

  /// 상태 필터 변경
  void setStatusFilter(String value) {
    statusFilter = value;
    applyFiltersAndSorting();
    notifyListeners();
  }

  /// 기간 필터 변경
  void setPeriodFilter(String value) {
    periodFilter = value;
    applyFiltersAndSorting();
    notifyListeners();
  }

  /// 정렬 기준 변경
  void setSortBy(String value) {
    sortBy = value;
    applyFiltersAndSorting();
    notifyListeners();
  }

  /// 정렬 순서 변경
  void setSortOrder(String value) {
    sortOrder = value;
    applyFiltersAndSorting();
    notifyListeners();
  }

  /// 필터링 및 정렬 적용
  void applyFiltersAndSorting() {
    filteredPosts.clear();
    filteredPosts.addAll(filterAndSortPosts(allPosts));
  }

  /// 포스트 필터링 및 정렬
  List<PostModel> filterAndSortPosts(List<PostModel> posts) {
    var result = posts.where((post) {
      // 검색 쿼리 필터
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!post.title.toLowerCase().contains(query) &&
            !post.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // 상태 필터
      if (statusFilter != 'all') {
        final now = DateTime.now();
        switch (statusFilter) {
          case 'active':
            if (post.status != PostStatus.DEPLOYED) return false;
            if (post.expiresAt != null && post.expiresAt!.isBefore(now)) return false;
            break;
          case 'inactive':
            if (post.status == PostStatus.DEPLOYED &&
                post.expiresAt != null &&
                post.expiresAt!.isAfter(now)) return false;
            break;
          case 'deleted':
            if (post.status != PostStatus.DELETED) return false;
            break;
        }
      }

      // 기간 필터
      if (periodFilter != 'all') {
        final now = DateTime.now();
        DateTime cutoffDate;
        
        switch (periodFilter) {
          case 'today':
            cutoffDate = DateTime(now.year, now.month, now.day);
            break;
          case 'week':
            cutoffDate = now.subtract(const Duration(days: 7));
            break;
          case 'month':
            cutoffDate = now.subtract(const Duration(days: 30));
            break;
          default:
            cutoffDate = DateTime(2000);
        }

        if (post.createdAt.isBefore(cutoffDate)) return false;
      }

      return true;
    }).toList();

    // 정렬
    result.sort((a, b) {
      int comparison;
      
      switch (sortBy) {
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'reward':
          comparison = a.reward.compareTo(b.reward);
          break;
        case 'expiresAt':
          comparison = (a.expiresAt ?? DateTime.now()).compareTo(
            b.expiresAt ?? DateTime.now()
          );
          break;
        case 'createdAt':
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }

      return sortOrder == 'asc' ? comparison : -comparison;
    });

    return result;
  }

  // ==================== 액션 ====================
  
  /// 포스트 ID 선택
  void selectPost(String? postId) {
    selectedPostId = postId;
    notifyListeners();
  }

  /// 데이터 새로고침
  Future<void> refreshData() async {
    await Future.wait([
      loadInitialData(),
      loadUserBalance(),
      loadStatistics(),
    ]);
  }

  /// 내 포스트 새로고침
  Future<void> refreshMyPosts() async {
    myPostsLoaded = false;
    await loadMyPosts();
  }

  /// 수령한 포스트 새로고침
  Future<void> refreshCollectedPosts() async {
    collectedPostsLoaded = false;
    await loadCollectedPosts();
  }

  /// 통계 데이터 로딩
  Future<void> loadStatistics() async {
    if (statisticsLoaded || currentUserId == null) return;

    try {
      // 배포된 포스트 통계
      final deployedPosts = await _postService.getUserPosts(currentUserId!, limit: 1000);
      final activePosts = deployedPosts.where((p) => p.status == PostStatus.DEPLOYED).toList();
      
      // 수집 통계 (마커 데이터에서)
      int totalCollections = 0;
      int totalViews = 0;
      
      // TODO: 실제 마커 데이터에서 수집 수 계산
      // 현재는 임시로 0으로 설정
      
      // 포인트 통계
      final totalSpent = activePosts.fold<int>(0, (sum, post) => sum + post.reward);
      final totalEarned = collectedPosts.fold<int>(0, (sum, post) => sum + post.reward);
      
      statistics = {
        'totalDeployed': activePosts.length,
        'totalCollections': totalCollections,
        'totalViews': totalViews,
        'collectionRate': activePosts.isNotEmpty ? (totalCollections / activePosts.length * 100).toStringAsFixed(1) : '0.0',
        'totalSpent': totalSpent,
        'totalEarned': totalEarned,
        'netBalance': totalEarned - totalSpent,
        'userBalance': userBalance ?? 0,
      };
      
      debugPrint('✅ 통계 데이터 로딩 완료: $statistics');
      
      statisticsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 통계 데이터 로딩 실패: $e');
    }
  }

  /// 필터 초기화
  void resetFilters() {
    searchQuery = '';
    statusFilter = 'all';
    periodFilter = 'all';
    sortBy = 'createdAt';
    sortOrder = 'desc';
    applyFiltersAndSorting();
    notifyListeners();
  }

  // ==================== 포스트 액션 ====================
  
  /// 포스트 삭제 (휴지통으로 이동)
  Future<void> deletePost(String postId) async {
    try {
      await _postService.updatePostStatus(postId, PostStatus.DELETED);
      myPostsLoaded = false; // 캐시 무효화
      await refreshMyPosts();
    } catch (e) {
      debugPrint('❌ 포스트 삭제 실패: $e');
      rethrow;
    }
  }

  /// 수령한 포스트 삭제 (수집 기록 제거)
  Future<void> deleteCollectedPost(String postId, String userId) async {
    try {
      final collectionId = '${postId}_$userId';
      await FirebaseFirestore.instance
          .collection('post_collections')
          .doc(collectionId)
          .delete();
      await refreshData();
    } catch (e) {
      debugPrint('❌ 수집 기록 삭제 실패: $e');
      rethrow;
    }
  }

  // ==================== Getter ====================
  
  /// 초안 포스트 목록
  List<PostModel> get draftPosts => cachedDraftPosts;

  /// 배포된 포스트 목록
  List<PostModel> get deployedPosts => cachedDeployedPosts;

  /// 필터링된 포스트 개수
  int get filteredPostCount => filteredPosts.length;

  /// 전체 포스트 개수
  int get totalPostCount => allPosts.length;
  
  /// 크로스축 개수 계산 (그리드뷰용)
  static int getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 800) return 3;
    if (width > 600) return 2;
    return 1;
  }

  // ==================== 통계 Getter ====================
  
  /// 총 배포된 포스트 수
  int get totalDeployed => statistics['totalDeployed'] ?? 0;
  
  /// 총 수집 수
  int get totalCollections => statistics['totalCollections'] ?? 0;
  
  /// 총 조회 수
  int get totalViews => statistics['totalViews'] ?? 0;
  
  /// 수집률 (%)
  String get collectionRate => statistics['collectionRate'] ?? '0.0';
  
  /// 총 지출 포인트
  int get totalSpent => statistics['totalSpent'] ?? 0;
  
  /// 총 획득 포인트
  int get totalEarned => statistics['totalEarned'] ?? 0;
  
  /// 순수익 포인트
  int get netBalance => statistics['netBalance'] ?? 0;
  
  /// 현재 포인트 잔액
  int get currentBalance => statistics['userBalance'] ?? 0;
}
