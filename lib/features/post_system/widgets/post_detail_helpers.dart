import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../routes/app_routes.dart';
import '../widgets/coupon_usage_dialog.dart';

/// 포스트 상세 화면의 헬퍼 함수들
class PostDetailHelpers {
  // 미디어 타입 아이콘
  static IconData getPostTypeIcon(String mediaType) {
    switch (mediaType) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.post_add;
    }
  }

  // 날짜 포맷팅
  static String formatDate(DateTime? date) {
    if (date == null) return '없음';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  // 날짜/시간 포맷팅
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 기능 텍스트 생성
  static String buildCapabilitiesText(PostModel post) {
    final caps = <String>[];
    if (post.canRespond) caps.add('응답');
    if (post.canForward) caps.add('전달');
    if (post.canRequestReward) caps.add('리워드 수령');
    if (post.canUse) caps.add('사용');
    if (post.isCoupon) caps.add('쿠폰');
    return caps.isEmpty ? '없음' : caps.join(', ');
  }

  // 타겟 텍스트 생성
  static String buildTargetText(PostModel post) {
    final gender = post.targetGender == 'all' ? '전체' : post.targetGender == 'male' ? '남성' : '여성';
    final age = '${post.targetAge[0]}~${post.targetAge[1]}세';
    final interests = post.targetInterest.isNotEmpty ? post.targetInterest.join(', ') : '관심사 없음';
    return '$gender / $age / $interests';
  }

  // 배포 기간 계산
  static int calculateDeploymentDuration(PostModel post) {
    if (!post.isDeployed || post.deployedAt == null) {
      return 0;
    }
    final duration = post.defaultExpiresAt.difference(post.deployedAt!);
    return duration.inDays;
  }

  // 쿠폰 사용 처리
  static Future<void> useCoupon(
    BuildContext context,
    PostModel post,
    void Function(PostModel) onPostUpdated,
  ) async {
    // 쿠폰 사용 가능 여부 체크
    if (!post.canUse || !post.isCoupon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 포스트는 쿠폰으로 사용할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 이미 사용된 쿠폰인지 체크
    try {
      final currentUser = FirebaseService().currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final usageQuery = await FirebaseFirestore.instance
        .collection('coupon_usage')
        .where('postId', isEqualTo: post.postId)
        .where('userId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

      if (usageQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 사용된 쿠폰입니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('쿠폰 사용 이력 확인 중 오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 연결된 플레이스 정보 가져오기
    if (post.placeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('플레이스 정보를 찾을 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 플레이스 정보 가져오기
      final placeService = PlaceService();
      final place = await placeService.getPlace(post.placeId!);

      // 로딩 다이얼로그 닫기
      if (context.mounted) Navigator.of(context).pop();

      if (place == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('플레이스 정보를 가져올 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 쿠폰 암호가 설정되어 있는지 체크
      if (place.couponPassword == null || place.couponPassword!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이 플레이스에 쿠폰 암호가 설정되지 않았습니다.\n플레이스 사장에게 문의하세요.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // 쿠폰 사용 다이얼로그 표시
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CouponUsageDialog(
            postTitle: post.title,
            placeName: place.name,
            expectedPassword: place.couponPassword!,
            onSuccess: () async {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              await _processCouponUsage(context, post, place);
            },
            onCancel: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
            },
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그가 열려있다면 닫기
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 쿠폰 사용 처리
  static Future<void> _processCouponUsage(
    BuildContext context,
    PostModel post,
    PlaceModel place,
  ) async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUser = FirebaseService().currentUser;
      if (currentUser == null) {
        throw Exception('사용자 로그인이 필요합니다.');
      }

      // Firebase에 쿠폰 사용 기록 저장
      final batch = FirebaseFirestore.instance.batch();

      // 1. 포스트 사용 상태 업데이트
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(post.postId);

      batch.update(postRef, {
        'usedAt': Timestamp.fromDate(DateTime.now()),
        'isUsedByCurrentUser': true,
        'totalUsed': FieldValue.increment(1),
      });

      // 2. 사용자의 쿠폰 사용 기록 추가
      final usageRef = FirebaseFirestore.instance
          .collection('coupon_usage')
          .doc();

      batch.set(usageRef, {
        'postId': post.postId,
        'placeId': place.id,
        'userId': currentUser.uid,
        'placeName': place.name,
        'postTitle': post.title,
        'rewardPoints': post.reward,
        'usedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      // 배치 커밋
      await batch.commit();

      // 성공 다이얼로그 표시
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CouponSuccessDialog(
            postTitle: post.title,
            rewardPoints: post.reward,
            onClose: () {
              Navigator.of(context).pop(); // 성공 다이얼로그 닫기
            },
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('쿠폰 사용 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 포스트 삭제/회수
  static Future<void> deletePost(
    BuildContext context,
    PostModel post,
  ) async {
    debugPrint('');
    debugPrint('🟣🟣🟣 [post_detail_helpers] deletePost() 시작 🟣🟣🟣');
    debugPrint('🟣 postId: ${post.postId}');
    debugPrint('🟣 status: ${post.status}');

    // 배포된 포스트인지 확인
    final isDeployed = post.status == PostStatus.DEPLOYED;
    debugPrint('🟣 isDeployed: $isDeployed');

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // PostService를 사용하여 포스트 삭제 또는 회수
      final postService = PostService();
      String successMessage;

      if (isDeployed) {
        debugPrint('🟣 배포된 포스트 → recallPost() 호출');
        await postService.recallPost(post.postId);
        successMessage = '포스트가 회수되었습니다. 회수한 포스트는 내 포스트에서 확인할 수 있습니다.';
        debugPrint('🟣 ✅ recallPost() 완료');
      } else {
        debugPrint('🟣 DRAFT 포스트 → deletePost() 호출');
        // TODO: deletePost 메소드 구현 필요
        // await postService.deletePost(post.postId);
        
        // 임시로 상태만 DELETED로 변경
        await postService.updatePostStatus(post.postId, PostStatus.DELETED);
        successMessage = '포스트가 삭제되었습니다.';
        debugPrint('🟣 ✅ deletePost() 완료');
      }

      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // 잠시 후 화면 닫기
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (context.mounted) {
          Navigator.of(context).pop(); // 현재 화면 닫기
        }
      }

      debugPrint('🟣 성공 메시지 표시 및 화면 닫기 완료');
      debugPrint('🟣🟣🟣 [post_detail_helpers] deletePost() 종료 (성공) 🟣🟣🟣');
      debugPrint('');
    } catch (e) {
      debugPrint('🔴 [post_detail_helpers] 에러 발생: $e');
      
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isDeployed ? '회수' : '삭제'} 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('🟣🟣🟣 [post_detail_helpers] deletePost() 종료 (에러) 🟣🟣🟣');
      debugPrint('');
    }
  }

  // 포스트 편집
  static Future<void> editPost(
    BuildContext context,
    PostModel post,
    Future<void> Function() onRefresh,
  ) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: {'post': post},
    );
    if (result == true) {
      await onRefresh();
    }
  }

  // 포스트 공유
  static void forwardPost(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('포스트 전달 기능은 준비 중입니다.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 포스트 통계 보기
  static void showPostStatistics(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 통계'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 총 수령 횟수: 마커에서 확인 가능'),
            Text('• 남은 수량: 마커에서 확인 가능'),
            Text('• 배포 위치: 마커에서 확인 가능'),
            Text('• 배포 시간: 마커에서 확인 가능'),
            SizedBox(height: 16),
            Text(
              '상세한 통계는 마커 정보에서 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 이미지 갤러리 표시
  static void showImageGallery(
    BuildContext context,
    PostModel post,
    List<int> imageIndices,
    Widget Function(String, int) buildReliableImage,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 갤러리'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: imageIndices.length,
            itemBuilder: (context, index) {
              final mediaIndex = imageIndices[index];
              final imageUrl = post.mediaUrl[mediaIndex].toString();
              final firebaseService = FirebaseService();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이미지 ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: FutureBuilder<String?>(
                          future: firebaseService.resolveImageUrl(imageUrl),
                          builder: (context, snapshot) {
                            final effectiveUrl = snapshot.data ?? imageUrl;
                            return buildReliableImage(effectiveUrl, 0);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}


