import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart' as core_marker;

/// 포스트 관련 로직을 관리하는 컨트롤러
class PostController {
  /// 포스트 수령 처리
  /// 
  /// [postId]: 포스트 ID
  /// [userId]: 사용자 ID
  /// 
  /// Returns: (성공 여부, 포인트 보상, 에러 메시지)
  static Future<(bool, int, String?)> collectPost({
    required String postId,
    required String userId,
  }) async {
    try {
      await PostService().collectPost(
        postId: postId,
        userId: userId,
      );
      
      // 포스트 정보 가져와서 포인트 확인
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      final reward = postDoc.data()?['reward'] as int? ?? 0;
      
      debugPrint('✅ 포스트 수령 완료: $postId, 보상: $reward포인트');
      return (true, reward, null);
    } catch (e) {
      debugPrint('❌ 포스트 수령 실패: $e');
      return (false, 0, e.toString());
    }
  }

  /// 마커에서 포스트 수령 (postId 검증 포함)
  /// 
  /// [marker]: 마커 정보
  /// [userId]: 사용자 ID
  /// [currentPosition]: 현재 위치
  /// 
  /// Returns: (성공 여부, 보상 포인트, 메시지)
  static Future<(bool, int, String)> collectPostFromMarker({
    required MarkerModel marker,
    required String userId,
    required LatLng currentPosition,
  }) async {
    try {
      // 거리 확인 (200m 이내)
      final canCollect = core_marker.MarkerService.canCollectMarker(
        currentPosition,
        LatLng(marker.position.latitude, marker.position.longitude),
      );

      if (!canCollect) {
        return (false, 0, '마커에서 200m 이내로 접근해주세요');
      }

      // 수량 확인
      if (marker.quantity <= 0) {
        return (false, 0, '수령 가능한 수량이 없습니다');
      }

      // postId 검증 및 수령
      String actualPostId = marker.postId;
      
      // postId가 markerId와 같거나 비어있으면 실제 마커 문서에서 postId 가져오기
      if (actualPostId == marker.markerId || actualPostId.isEmpty) {
        debugPrint('[COLLECT_FIX] postId가 잘못됨. markerId로 실제 마커 조회 중...');
        
        final markerDoc = await FirebaseFirestore.instance
            .collection('markers')
            .doc(marker.markerId)
            .get();

        if (!markerDoc.exists || markerDoc.data() == null) {
          return (false, 0, '마커 문서를 찾을 수 없습니다');
        }

        final realPostId = markerDoc.data()!['postId'] as String?;
        
        if (realPostId == null || realPostId.isEmpty || realPostId == marker.markerId) {
          return (false, 0, '마커에서 유효한 postId를 찾을 수 없습니다');
        }
        
        actualPostId = realPostId;
        debugPrint('[COLLECT_FIX] 올바른 postId로 수령 진행: $actualPostId');
      }

      // 포스트 수령
      await PostService().collectPost(
        postId: actualPostId,
        userId: userId,
      );

      final reward = marker.reward ?? 0;
      final remainingCount = marker.quantity - 1;
      
      final message = reward > 0
          ? '포스트를 수령했습니다! 🎉\n${reward}포인트가 지급되었습니다! ($remainingCount개 남음)'
          : '포스트를 수령했습니다! ($remainingCount개 남음)';

      return (true, reward, message);
    } catch (e) {
      debugPrint('❌ 마커에서 포스트 수령 실패: $e');
      return (false, 0, '오류: $e');
    }
  }

  /// 포스트 회수 (삭제)
  static Future<bool> removePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != userId) {
        debugPrint('❌ 포스트 회수 권한 없음');
        return false;
      }

      // TODO: PostService에 deletePost 메서드 추가 필요
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .delete();

      debugPrint('✅ 포스트 회수 완료: $postId');
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 회수 실패: $e');
      return false;
    }
  }

  /// 포스트 확인 처리
  /// 
  /// [collectionId]: 수령 기록 ID
  /// [userId]: 사용자 ID
  /// [postId]: 포스트 ID
  /// [creatorId]: 포스트 생성자 ID
  /// [reward]: 보상 포인트
  static Future<bool> confirmPost({
    required String collectionId,
    required String userId,
    required String postId,
    required String creatorId,
    required int reward,
  }) async {
    try {
      await PostService().confirmPost(
        collectionId: collectionId,
        userId: userId,
        postId: postId,
        creatorId: creatorId,
        reward: reward,
      );
      
      debugPrint('✅ 포스트 확인 완료: $postId, 보상: $reward포인트');
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 확인 실패: $e');
      return false;
    }
  }

  /// 미확인 포스트 개수 계산
  static int countUnconfirmedPosts(List<PostModel> posts, Set<String> confirmedPostIds) {
    return posts.where((post) => !confirmedPostIds.contains(post.postId)).length;
  }
}

