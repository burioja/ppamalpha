import 'package:flutter/foundation.dart';
import '../../../core/models/post/post_model.dart';

/// Inbox 화면의 필터링 및 정렬 로직을 관리하는 컨트롤러
class InboxController {
  /// 포스트 필터링
  static List<PostModel> filterPosts({
    required List<PostModel> posts,
    String? statusFilter,
    String? periodFilter,
  }) {
    var filtered = posts;

    // 상태 필터
    if (statusFilter != null && statusFilter != '전체') {
      filtered = filtered.where((post) {
        switch (statusFilter) {
          case '초안':
            return post.status == PostStatus.DRAFT;
          case '배포됨':
            return post.status == PostStatus.DEPLOYED;
          case '회수됨':
            return post.status == PostStatus.RECALLED;
          case '만료됨':
            return post.status == PostStatus.EXPIRED;
          default:
            return true;
        }
      }).toList();
    }

    // 기간 필터
    if (periodFilter != null && periodFilter != '전체') {
      final now = DateTime.now();
      filtered = filtered.where((post) {
        final createdAt = post.createdAt;
        if (createdAt == null) return false;

        switch (periodFilter) {
          case '오늘':
            return createdAt.year == now.year &&
                   createdAt.month == now.month &&
                   createdAt.day == now.day;
          case '이번 주':
            final weekAgo = now.subtract(const Duration(days: 7));
            return createdAt.isAfter(weekAgo);
          case '이번 달':
            return createdAt.year == now.year &&
                   createdAt.month == now.month;
          case '3개월':
            final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
            return createdAt.isAfter(threeMonthsAgo);
          default:
            return true;
        }
      }).toList();
    }

    return filtered;
  }

  /// 포스트 정렬
  static List<PostModel> sortPosts({
    required List<PostModel> posts,
    String sortBy = '날짜',
    bool ascending = false,
  }) {
    final sorted = List<PostModel>.from(posts);

    switch (sortBy) {
      case '날짜':
        sorted.sort((a, b) {
          final dateA = a.createdAt ?? DateTime.now();
          final dateB = b.createdAt ?? DateTime.now();
          return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
        break;
      
      case '제목':
        sorted.sort((a, b) {
          return ascending 
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title);
        });
        break;
      
      case '리워드':
        sorted.sort((a, b) {
          final rewardA = a.reward ?? 0;
          final rewardB = b.reward ?? 0;
          return ascending 
              ? rewardA.compareTo(rewardB)
              : rewardB.compareTo(rewardA);
        });
        break;
      
      case '수량':
        sorted.sort((a, b) {
          final qtyA = a.totalQuantity ?? 0;
          final qtyB = b.totalQuantity ?? 0;
          return ascending 
              ? qtyA.compareTo(qtyB)
              : qtyB.compareTo(qtyA);
        });
        break;
      
      case '상태':
        sorted.sort((a, b) {
          final statusOrder = {
            PostStatus.DEPLOYED: 0,
            PostStatus.DRAFT: 1,
            PostStatus.RECALLED: 2,
            PostStatus.EXPIRED: 3,
          };
          final orderA = statusOrder[a.status] ?? 99;
          final orderB = statusOrder[b.status] ?? 99;
          return ascending 
              ? orderA.compareTo(orderB)
              : orderB.compareTo(orderA);
        });
        break;
    }

    return sorted;
  }

  /// 포스트 통계 계산
  static Map<String, int> calculateStatistics(List<PostModel> posts) {
    return {
      'total': posts.length,
      'draft': posts.where((p) => p.status == PostStatus.DRAFT).length,
      'deployed': posts.where((p) => p.status == PostStatus.DEPLOYED).length,
      'recalled': posts.where((p) => p.status == PostStatus.RECALLED).length,
      'expired': posts.where((p) => p.status == PostStatus.EXPIRED).length,
    };
  }

  /// 총 포인트 계산
  static int calculateTotalPoints(List<PostModel> posts) {
    return posts.fold<int>(
      0,
      (sum, post) => sum + ((post.reward ?? 0) * (post.totalQuantity ?? 0)),
    );
  }

  /// 총 수량 계산
  static int calculateTotalQuantity(List<PostModel> posts) {
    return posts.fold<int>(
      0,
      (sum, post) => sum + (post.totalQuantity ?? 0),
    );
  }

  /// 수집된 포스트 필터링 (확인 여부)
  static Map<String, List<PostModel>> separateConfirmedPosts(
    List<PostModel> posts,
  ) {
    final unconfirmed = <PostModel>[];
    final confirmed = <PostModel>[];

    for (final post in posts) {
      // confirmed 필드로 구분 (필드가 없으면 metadata 확인)
      final isConfirmed = post.metadata?['confirmed'] == true;
      
      if (isConfirmed) {
        confirmed.add(post);
      } else {
        unconfirmed.add(post);
      }
    }

    return {
      'unconfirmed': unconfirmed,
      'confirmed': confirmed,
    };
  }

  /// 상태별 색상 반환
  static Map<String, dynamic> getStatusInfo(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return {'color': 0xFF9E9E9E, 'text': '초안', 'icon': 0xe3ab}; // grey, edit
      case PostStatus.DEPLOYED:
        return {'color': 0xFF4CAF50, 'text': '배포됨', 'icon': 0xe5ca}; // green, check_circle
      case PostStatus.RECALLED:
        return {'color': 0xFFFF9800, 'text': '회수됨', 'icon': 0xe166}; // orange, undo
      case PostStatus.EXPIRED:
        return {'color': 0xFFF44336, 'text': '만료됨', 'icon': 0xe5cd}; // red, timer_off
      default:
        return {'color': 0xFF9E9E9E, 'text': '알 수 없음', 'icon': 0xe88f}; // grey, help
    }
  }
}

