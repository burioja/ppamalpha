import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../state/inbox_state.dart';

/// 받은편지함 Provider
/// 
/// **책임**: 받은편지함 상태 관리, 포스트 로드/필터/정렬
/// **원칙**: 얇은 액션만, Service 사용
class InboxProvider with ChangeNotifier {
  final PostService _postService;
  final InboxState _state = InboxState();

  // Getters
  InboxState get state => _state;
  List<PostModel> get allPosts => List.unmodifiable(_state.allPosts);
  List<PostModel> get filteredPosts => List.unmodifiable(_state.filteredPosts);
  List<PostModel> get draftPosts => List.unmodifiable(_state.cachedDraftPosts);
  List<PostModel> get deployedPosts => List.unmodifiable(_state.cachedDeployedPosts);
  bool get isLoading => _state.isLoading;
  bool get hasMoreData => _state.hasMoreData;

  InboxProvider({PostService? postService})
      : _postService = postService ?? PostService();

  // ==================== 데이터 로드 ====================

  /// 초기 데이터 로드
  Future<void> loadInitialData() async {
    if (_state.isLoading) return;

    _state.isLoading = true;
    _state.allPosts.clear();
    _state.filteredPosts.clear();
    _state.lastDocument = null;
    _state.hasMoreData = true;
    _state.myPostsLoaded = false;
    notifyListeners();

    try {
      await _loadMoreData();
    } finally {
      _state.isLoading = false;
      notifyListeners();
    }
  }

  /// 추가 데이터 로드 (페이지네이션)
  Future<void> _loadMoreData() async {
    if (_state.isLoadingMore || !_state.hasMoreData) return;

    _state.isLoadingMore = true;
    notifyListeners();

    try {
      // TODO: PostService에 getPostsWithPagination 메서드 필요
      final result = (posts: <PostModel>[], lastDocument: null);
      // final result = await _postService.getPostsWithPagination(
      //   limit: InboxState.pageSize,
      //   lastDocument: _state.lastDocument,
      // );

      if (result.posts.isEmpty) {
        _state.hasMoreData = false;
      } else {
        _state.allPosts.addAll(result.posts);
        _state.lastDocument = result.lastDocument;
        _applyFiltersAndSort();
      }
    } catch (e) {
      debugPrint('❌ 포스트 로드 실패: $e');
    } finally {
      _state.isLoadingMore = false;
      notifyListeners();
    }
  }

  /// 내 포스트 로드
  Future<void> loadMyPosts(String userId) async {
    if (_state.myPostsLoaded) return;

    try {
      final posts = await _postService.getUserPosts(userId);
      
      _state.cachedDraftPosts = posts
          .where((p) => p.status == 'draft')
          .toList();
      
      _state.cachedDeployedPosts = posts
          .where((p) => p.status == 'deployed')
          .toList();
      
      _state.myPostsLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 내 포스트 로드 실패: $e');
    }
  }

  /// 새로고침
  Future<void> refresh() async {
    _state.reset();
    await loadInitialData();
  }

  // ==================== 필터 및 정렬 ====================

  /// 검색어 설정
  void setSearchQuery(String query) {
    _state.searchQuery = query.trim();
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 상태 필터 설정
  void setStatusFilter(String status) {
    _state.statusFilter = status;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 기간 필터 설정
  void setPeriodFilter(String period) {
    _state.periodFilter = period;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 정렬 기준 설정
  void setSortBy(String sortBy) {
    _state.sortBy = sortBy;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 정렬 순서 설정
  void setSortOrder(String order) {
    _state.sortOrder = order;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 필터 표시 토글
  void toggleFilters() {
    _state.showFilters = !_state.showFilters;
    notifyListeners();
  }

  /// 필터 초기화
  void resetFilters() {
    _state.resetFilters();
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// 필터 및 정렬 적용
  void _applyFiltersAndSort() {
    var posts = List<PostModel>.from(_state.allPosts);

    // 검색어 필터
    if (_state.searchQuery.isNotEmpty) {
      posts = posts.where((post) {
        final query = _state.searchQuery.toLowerCase();
        return post.title.toLowerCase().contains(query) ||
            post.description.toLowerCase().contains(query);
      }).toList();
    }

    // 상태 필터
    if (_state.statusFilter != 'all') {
      posts = posts.where((post) {
        return post.status == _state.statusFilter;
      }).toList();
    }

    // 기간 필터
    if (_state.periodFilter != 'all') {
      final now = DateTime.now();
      posts = posts.where((post) {
        final createdAt = post.createdAt;
        
        switch (_state.periodFilter) {
          case 'today':
            return createdAt.isAfter(DateTime(now.year, now.month, now.day));
          case 'week':
            return createdAt.isAfter(now.subtract(const Duration(days: 7)));
          case 'month':
            return createdAt.isAfter(now.subtract(const Duration(days: 30)));
          default:
            return true;
        }
      }).toList();
    }

    // 정렬
    posts.sort((a, b) {
      int result = 0;
      
      switch (_state.sortBy) {
        case 'title':
          result = a.title.compareTo(b.title);
          break;
        case 'reward':
          result = (a.reward ?? 0).compareTo(b.reward ?? 0);
          break;
        case 'expiresAt':
          result = (a.defaultExpiresAt ?? DateTime(2099))
              .compareTo(b.defaultExpiresAt ?? DateTime(2099));
          break;
        case 'createdAt':
        default:
          result = a.createdAt.compareTo(b.createdAt);
          break;
      }
      
      return _state.sortOrder == 'asc' ? result : -result;
    });

    _state.filteredPosts = posts;
  }

  // ==================== CRUD ====================

  /// 포스트 삭제
  Future<bool> deletePost(String postId) async {
    try {
      // TODO: PostService에 deletePost 메서드 필요
      // await _postService.deletePost(postId);
      
      // 로컬 상태 업데이트
      _state.allPosts.removeWhere((p) => p.postId == postId);
      _state.cachedDraftPosts.removeWhere((p) => p.postId == postId);
      _state.cachedDeployedPosts.removeWhere((p) => p.postId == postId);
      _applyFiltersAndSort();
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 삭제 실패: $e');
      return false;
    }
  }

  /// 포스트 선택
  void selectPost(String? postId) {
    _state.selectedPostId = postId;
    notifyListeners();
  }

  /// 탭 변경
  void setTabIndex(int index) {
    _state.currentTabIndex = index;
    notifyListeners();
  }
}

