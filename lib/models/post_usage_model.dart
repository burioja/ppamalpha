import 'package:cloud_firestore/cloud_firestore.dart';

/// 포스트 사용 이력 모델
class PostUsageModel {
  final String id;
  final String postId;
  final String userId;
  final String creatorId;
  final String title;
  final int reward;
  final DateTime usedAt;
  final DateTime createdAt;

  const PostUsageModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.creatorId,
    required this.title,
    required this.reward,
    required this.usedAt,
    required this.createdAt,
  });

  /// Firestore 문서에서 PostUsageModel 생성
  factory PostUsageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PostUsageModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      title: data['title'] ?? '',
      reward: data['reward'] ?? 0,
      usedAt: (data['usedAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Map에서 PostUsageModel 생성 (PostService에서 사용)
  factory PostUsageModel.fromMap(Map<String, dynamic> data) {
    return PostUsageModel(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      title: data['title'] ?? '',
      reward: data['reward'] ?? 0,
      usedAt: (data['usedAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'creatorId': creatorId,
      'title': title,
      'reward': reward,
      'usedAt': Timestamp.fromDate(usedAt),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 사용한 지 얼마나 됐는지 (예: "2시간 전", "3일 전")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(usedAt);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    } else {
      return '${(difference.inDays / 30).floor()}개월 전';
    }
  }

  /// 포맷된 사용 날짜 (예: "2024-03-15 14:30")
  String get formattedUsedDate {
    return '${usedAt.year}-${usedAt.month.toString().padLeft(2, '0')}-${usedAt.day.toString().padLeft(2, '0')} '
           '${usedAt.hour.toString().padLeft(2, '0')}:${usedAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'PostUsageModel(id: $id, postId: $postId, userId: $userId, title: $title, reward: $reward, usedAt: $usedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PostUsageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// 복사본 생성
  PostUsageModel copyWith({
    String? id,
    String? postId,
    String? userId,
    String? creatorId,
    String? title,
    int? reward,
    DateTime? usedAt,
    DateTime? createdAt,
  }) {
    return PostUsageModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      reward: reward ?? this.reward,
      usedAt: usedAt ?? this.usedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}