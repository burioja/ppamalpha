import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';

/// 받은편지함 상태 클래스
/// 
/// **책임**: Inbox 화면의 모든 상태 관리
class InboxState {
  // ==================== 검색 및 필터 ====================
  
  String searchQuery = '';
  bool showFilters = false;
  String statusFilter = 'all'; // all, active, inactive, deleted
  String periodFilter = 'all'; // all, today, week, month
  String sortBy = 'createdAt'; // createdAt, title, reward, expiresAt
  String sortOrder = 'desc'; // asc, desc

  // ==================== 데이터 ====================
  
  List<PostModel> allPosts = [];
  List<PostModel> filteredPosts = [];
  
  // 내 포스트 캐싱
  List<PostModel> cachedDraftPosts = [];
  List<PostModel> cachedDeployedPosts = [];
  bool myPostsLoaded = false;

  // ==================== 페이지네이션 ====================
  
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  DocumentSnapshot? lastDocument;
  static const int pageSize = 20;

  // ==================== UI 상태 ====================
  
  String? selectedPostId;
  int currentTabIndex = 0;

  // ==================== 메서드 ====================

  /// 필터 초기화
  void resetFilters() {
    searchQuery = '';
    showFilters = false;
    statusFilter = 'all';
    periodFilter = 'all';
    sortBy = 'createdAt';
    sortOrder = 'desc';
  }

  /// 전체 초기화
  void reset() {
    allPosts.clear();
    filteredPosts.clear();
    cachedDraftPosts.clear();
    cachedDeployedPosts.clear();
    myPostsLoaded = false;
    lastDocument = null;
    hasMoreData = true;
    isLoading = false;
    isLoadingMore = false;
    selectedPostId = null;
    resetFilters();
  }

  /// 디버그 정보
  Map<String, dynamic> getDebugInfo() {
    return {
      'allPostsCount': allPosts.length,
      'filteredPostsCount': filteredPosts.length,
      'draftPostsCount': cachedDraftPosts.length,
      'deployedPostsCount': cachedDeployedPosts.length,
      'isLoading': isLoading,
      'hasMoreData': hasMoreData,
      'currentTab': currentTabIndex,
    };
  }
}

