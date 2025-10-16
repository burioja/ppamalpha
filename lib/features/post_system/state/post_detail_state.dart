import '../../../core/models/post/post_model.dart';

/// PostDetailScreen의 상태를 관리하는 클래스
class PostDetailState {
  PostModel currentPost;
  bool isDeveloperInfoExpanded;

  PostDetailState({
    required this.currentPost,
    this.isDeveloperInfoExpanded = false,
  });

  /// 상태 복사
  PostDetailState copyWith({
    PostModel? currentPost,
    bool? isDeveloperInfoExpanded,
  }) {
    return PostDetailState(
      currentPost: currentPost ?? this.currentPost,
      isDeveloperInfoExpanded: isDeveloperInfoExpanded ?? this.isDeveloperInfoExpanded,
    );
  }

  /// 개발자 정보 토글
  void toggleDeveloperInfo() {
    isDeveloperInfoExpanded = !isDeveloperInfoExpanded;
  }

  /// 포스트 업데이트
  void updatePost(PostModel newPost) {
    currentPost = newPost;
  }
}

