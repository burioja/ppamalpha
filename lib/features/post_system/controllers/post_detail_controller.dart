import 'package:flutter/material.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';

/// PostDetail 관련 액션을 관리하는 컨트롤러
class PostDetailController {
  /// 포스트 삭제 또는 회수
  /// 
  /// [context]: BuildContext
  /// [post]: 포스트 모델
  /// 
  /// Returns: (성공 여부, 메시지)
  static Future<(bool, String)> deleteOrRecallPost({
    required BuildContext context,
    required PostModel post,
  }) async {
    debugPrint('');
    debugPrint('🟣🟣🟣 [PostDetailController] deleteOrRecallPost() 시작 🟣🟣🟣');
    debugPrint('🟣 postId: ${post.postId}');
    debugPrint('🟣 status: ${post.status}');

    // 배포된 포스트인지 확인
    final isDeployed = post.status == PostStatus.DEPLOYED;
    debugPrint('🟣 isDeployed: $isDeployed');

    try {
      final postService = PostService();
      String successMessage;

      if (isDeployed) {
        debugPrint('🟣 배포된 포스트 → recallPost() 호출');
        await postService.recallPost(post.postId);
        successMessage = '포스트가 회수되었습니다. 회수한 포스트는 내 포스트에서 확인할 수 있습니다.';
        debugPrint('🟣 ✅ recallPost() 완료');
      } else {
        debugPrint('🟣 DRAFT 포스트 → deletePost() 호출');
        await postService.deletePost(post.postId);
        successMessage = '포스트가 삭제되었습니다.';
        debugPrint('🟣 ✅ deletePost() 완료');
      }

      debugPrint('🟣🟣🟣 [PostDetailController] deleteOrRecallPost() 종료 (성공) 🟣🟣🟣');
      debugPrint('');
      return (true, successMessage);
    } catch (e) {
      debugPrint('🔴 [PostDetailController] 에러 발생: $e');
      debugPrint('🟣🟣🟣 [PostDetailController] deleteOrRecallPost() 종료 (에러) 🟣🟣🟣');
      debugPrint('');
      
      final errorMessage = '${isDeployed ? '회수' : '삭제'} 실패: $e';
      return (false, errorMessage);
    }
  }

  /// 로딩 다이얼로그 표시
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// 성공 메시지 표시
  static void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 에러 메시지 표시
  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 확인 다이얼로그 표시
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = '확인',
    String cancelText = '취소',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  /// 포스트 공유 데이터 생성
  static String generateShareText(PostModel post) {
    return '''
🎁 ${post.title}

${post.description}

💰 리워드: ${post.reward}P
${post.isCoupon ? '🎫 쿠폰 사용 가능' : ''}

앱에서 확인하세요!
''';
  }

  /// 미디어 타입 primary 찾기
  static String getPrimaryMediaType(PostModel post) {
    if (post.mediaType.isEmpty) return '일반';
    
    final Map<String, int> typeCount = {};
    for (final type in post.mediaType) {
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }
    
    // 가장 많은 타입 찾기
    String primaryType = typeCount.keys.first;
    int maxCount = typeCount[primaryType] ?? 0;
    
    for (final entry in typeCount.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        primaryType = entry.key;
      }
    }
    
    // 한글로 변환
    switch (primaryType) {
      case 'image':
        return '이미지';
      case 'video':
        return '동영상';
      case 'audio':
        return '오디오';
      default:
        return '미디어';
    }
  }

  /// 원본 이미지 URL 찾기
  static String? findOriginalImageUrl(PostModel post, String thumbnailUrl) {
    // thumbnailUrl에서 _thumb를 제거하여 원본 URL 생성
    if (thumbnailUrl.contains('_thumb')) {
      return thumbnailUrl.replaceAll('_thumb', '');
    }
    return thumbnailUrl;
  }

  /// 포스트 상태 텍스트 반환
  static String getStatusText(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return '초안';
      case PostStatus.DEPLOYED:
        return '배포됨';
      case PostStatus.RECALLED:
        return '회수됨';
      case PostStatus.EXPIRED:
        return '만료됨';
      default:
        return '알 수 없음';
    }
  }

  /// 포스트 상태 색상 반환
  static Color getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return Colors.grey;
      case PostStatus.DEPLOYED:
        return Colors.green;
      case PostStatus.RECALLED:
        return Colors.orange;
      case PostStatus.EXPIRED:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

