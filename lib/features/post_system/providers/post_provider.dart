import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/post/post_instance_model.dart';
import '../../../core/repositories/posts_repository.dart';

/// 포스트 상태 관리 Provider
/// 
/// **책임**:
/// - 포스트 목록 상태 관리
/// - 포스트 CRUD 액션
/// - 수령/확정 흐름 관리
/// - 로딩/에러 상태 관리
/// 
/// **금지**:
/// - Firebase 직접 호출 (Repository 사용)
/// - 복잡한 비즈니스 로직 (Service로 분리)
class PostProvider with ChangeNotifier {
  final PostsRepository _repository;

  // ==================== 상태 ====================
  
  /// 포스트 목록 (스트리밍)
  List<PostModel> _posts = [];
  
  /// 선택된 포스트 상세
  PostModel? _selectedPost;
  
  /// 포스트 인스턴스 목록
  List<PostInstanceModel> _instances = [];
  
  /// 로딩 상태
  bool _isLoading = false;
  
  /// 에러 메시지
  String? _errorMessage;
  
  /// 스트림 구독
  StreamSubscription<List<PostModel>>? _postsSubscription;
  StreamSubscription<List<PostInstanceModel>>? _instancesSubscription;

  // ==================== Getters ====================
  
  List<PostModel> get posts => List.unmodifiable(_posts);
  PostModel? get selectedPost => _selectedPost;
  List<PostInstanceModel> get instances => List.unmodifiable(_instances);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get postCount => _posts.length;

  // ==================== Constructor ====================
  
  PostProvider({PostsRepository? repository})
      : _repository = repository ?? PostsRepository();

  // ==================== 액션 - 조회 ====================

  /// 포스트 목록 스트리밍 시작
  /// 
  /// [userId]: 사용자 ID (null이면 전체 조회)
  void streamPosts({String? userId}) {
    _postsSubscription?.cancel();
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _postsSubscription = _repository.streamPosts(userId: userId).listen(
      (posts) {
        _posts = posts;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '포스트 로드 실패: $error';
        _isLoading = false;
        notifyListeners();
        debugPrint('❌ 포스트 스트림 에러: $error');
      },
    );
  }

  /// 특정 포스트 조회 및 선택
  Future<void> selectPost(String postId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedPost = await _repository.getPostById(postId);
      
      if (_selectedPost != null) {
        // 인스턴스 스트리밍 시작
        _streamInstances(postId);
      }
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = '포스트 조회 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 포스트 조회 실패: $e');
    }
  }

  /// 포스트 인스턴스 스트리밍
  void _streamInstances(String postId) {
    _instancesSubscription?.cancel();

    _instancesSubscription = _repository.streamPostInstances(postId).listen(
      (instances) {
        _instances = instances;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('❌ 인스턴스 스트림 에러: $error');
      },
    );
  }

  /// 선택 해제
  void clearSelection() {
    _selectedPost = null;
    _instances = [];
    _instancesSubscription?.cancel();
    notifyListeners();
  }

  // ==================== 액션 - 생성 ====================

  /// 포스트 생성
  Future<String?> createPost(PostModel post) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final postId = await _repository.createPost(post);
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('✅ 포스트 생성 성공: $postId');
      return postId;
    } catch (e) {
      _errorMessage = '포스트 생성 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 포스트 생성 실패: $e');
      return null;
    }
  }

  /// 포스트 배포 (마커 생성)
  Future<String?> deployPost({
    required String postId,
    required Map<String, dynamic> instanceData,
    bool deductPoints = false,
    int? pointCost,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final instanceId = await _repository.deployPost(
        postId: postId,
        instanceData: instanceData,
        deductPoints: deductPoints,
        pointCost: pointCost,
      );
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('✅ 포스트 배포 성공: $instanceId');
      return instanceId;
    } catch (e) {
      _errorMessage = '포스트 배포 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 포스트 배포 실패: $e');
      return null;
    }
  }

  // ==================== 액션 - 수령/확정 ====================

  /// 포스트 수령
  Future<bool> collectPost({
    required String markerId,
    required String userId,
    int? rewardPoints,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.collectPost(
        markerId: markerId,
        userId: userId,
        rewardPoints: rewardPoints,
      );
      
      _isLoading = false;
      
      if (success) {
        _errorMessage = null;
        debugPrint('✅ 포스트 수령 성공: $markerId');
      } else {
        _errorMessage = '포스트 수령 실패';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = '포스트 수령 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 포스트 수령 실패: $e');
      return false;
    }
  }

  /// 포스트 확정
  Future<bool> confirmPost({
    required String markerId,
    required String collectionId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.confirmPost(
        markerId: markerId,
        collectionId: collectionId,
      );
      
      _isLoading = false;
      
      if (success) {
        _errorMessage = null;
        debugPrint('✅ 포스트 확정 성공');
      } else {
        _errorMessage = '포스트 확정 실패';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = '포스트 확정 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 포스트 확정 실패: $e');
      return false;
    }
  }

  // ==================== 액션 - 업데이트/삭제 ====================

  /// 포스트 업데이트
  Future<bool> updatePost(
    String postId,
    Map<String, dynamic> data,
  ) async {
    try {
      final success = await _repository.updatePost(postId, data);
      
      if (success) {
        debugPrint('✅ 포스트 업데이트 성공: $postId');
      }
      
      return success;
    } catch (e) {
      _errorMessage = '포스트 업데이트 실패: $e';
      notifyListeners();
      debugPrint('❌ 포스트 업데이트 실패: $e');
      return false;
    }
  }

  /// 포스트 삭제
  Future<bool> deletePost(String postId) async {
    try {
      final success = await _repository.deletePost(postId);
      
      if (success) {
        debugPrint('✅ 포스트 삭제 성공: $postId');
      }
      
      return success;
    } catch (e) {
      _errorMessage = '포스트 삭제 실패: $e';
      notifyListeners();
      debugPrint('❌ 포스트 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 유틸리티 ====================

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 리셋
  void reset() {
    _posts = [];
    _selectedPost = null;
    _instances = [];
    _isLoading = false;
    _errorMessage = null;
    _postsSubscription?.cancel();
    _instancesSubscription?.cancel();
    notifyListeners();
  }

  // ==================== Dispose ====================

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _instancesSubscription?.cancel();
    super.dispose();
  }

  // ==================== 디버그 ====================

  Map<String, dynamic> getDebugInfo() {
    return {
      'postsCount': _posts.length,
      'selectedPost': _selectedPost?.postId,
      'instancesCount': _instances.length,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
    };
  }
}

