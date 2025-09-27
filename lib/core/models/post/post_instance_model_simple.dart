import 'package:cloud_firestore/cloud_firestore.dart';

// 포스트 인스턴스 상태 열거형
enum PostInstanceStatus {
  COLLECTED, // 수집됨 (사용 가능)
  USED,      // 사용됨 (완료)
  EXPIRED,   // 만료됨 (사용 불가)
  DELETED,   // 삭제됨
}

// 포스트 인스턴스 상태 확장 메서드
extension PostInstanceStatusExtension on PostInstanceStatus {
  String get name {
    switch (this) {
      case PostInstanceStatus.COLLECTED:
        return '수집됨';
      case PostInstanceStatus.USED:
        return '사용됨';
      case PostInstanceStatus.EXPIRED:
        return '만료됨';
      case PostInstanceStatus.DELETED:
        return '삭제됨';
    }
  }

  String get value {
    switch (this) {
      case PostInstanceStatus.COLLECTED:
        return 'collected';
      case PostInstanceStatus.USED:
        return 'used';
      case PostInstanceStatus.EXPIRED:
        return 'expired';
      case PostInstanceStatus.DELETED:
        return 'deleted';
    }
  }

  static PostInstanceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'collected':
        return PostInstanceStatus.COLLECTED;
      case 'used':
        return PostInstanceStatus.USED;
      case 'expired':
        return PostInstanceStatus.EXPIRED;
      case 'deleted':
        return PostInstanceStatus.DELETED;
      default:
        return PostInstanceStatus.COLLECTED;
    }
  }
}

/// 간단한 포스트 인스턴스 모델 (기존 posts/markers 구조 활용)
/// 사용자가 수집한 개별 포스트 (템플릿의 스냅샷 복사본)
class PostInstanceModel {
  // 기본 식별자
  final String instanceId;
  final String postId;        // 원본 템플릿 참조 (posts 컬렉션)
  final String markerId;      // 배포 마커 참조 (markers 컬렉션)
  final String userId;        // 수집한 사용자

  // 수집 정보
  final DateTime collectedAt; // 수집 시점
  final GeoPoint collectedLocation; // 수집 위치

  // 사용 정보
  final DateTime? usedAt;     // 사용 시점
  final GeoPoint? usedLocation; // 사용 위치
  final String? usedNote;     // 사용 메모
  final bool isUsed;          // 사용 여부

  // 인스턴스 상태
  final PostInstanceStatus status;
  final bool isActive;

  // 템플릿 데이터 스냅샷 (수집 시점의 복사본) - 기존 PostModel과 동일한 구조
  final String creatorId;
  final String creatorName;
  final String title;
  final String description;
  final int reward;           // 수집 시점의 단가
  final List<String> mediaType;
  final List<String> mediaUrl;
  final List<String> thumbnailUrl;

  // 타겟팅 정보 (스냅샷)
  final List<int> targetAge;
  final String targetGender;
  final List<String> targetInterest;
  final List<String> targetPurchaseHistory;

  // 사용자 행동 옵션 (스냅샷)
  final bool canRespond;
  final bool canForward;
  final bool canRequestReward;
  final bool canUse;

  // 만료 정보 (마커에서 복사)
  final DateTime expiresAt;   // 마커의 endDate

  // 쿠폰 시스템 (스냅샷)
  final bool isCoupon;
  final Map<String, dynamic>? couponData;

  // 플레이스 연동 (스냅샷)
  final String? placeId;

  PostInstanceModel({
    required this.instanceId,
    required this.postId,
    required this.markerId,
    required this.userId,
    required this.collectedAt,
    required this.collectedLocation,
    this.usedAt,
    this.usedLocation,
    this.usedNote,
    this.isUsed = false,
    this.status = PostInstanceStatus.COLLECTED,
    this.isActive = true,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.description,
    required this.reward,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl = const [],
    required this.targetAge,
    required this.targetGender,
    required this.targetInterest,
    required this.targetPurchaseHistory,
    required this.canRespond,
    required this.canForward,
    required this.canRequestReward,
    required this.canUse,
    required this.expiresAt,
    this.isCoupon = false,
    this.couponData,
    this.placeId,
  });

  factory PostInstanceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String instanceId = data['instanceId'] ?? doc.id;
    if (instanceId.isEmpty) {
      instanceId = doc.id;
    }

    return PostInstanceModel(
      instanceId: instanceId,
      postId: data['postId'] ?? '',
      markerId: data['markerId'] ?? '',
      userId: data['userId'] ?? '',
      collectedAt: data['collectedAt'] != null
          ? (data['collectedAt'] as Timestamp).toDate()
          : DateTime.now(),
      collectedLocation: data['collectedLocation'] ?? const GeoPoint(0, 0),
      usedAt: data['usedAt'] != null
          ? (data['usedAt'] as Timestamp).toDate()
          : null,
      usedLocation: data['usedLocation'],
      usedNote: data['usedNote'],
      isUsed: data['isUsed'] ?? false,
      status: PostInstanceStatusExtension.fromString(data['status'] ?? 'collected'),
      isActive: data['isActive'] ?? true,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      reward: data['reward'] ?? 0,
      mediaType: List<String>.from(data['mediaType'] ?? ['text']),
      mediaUrl: List<String>.from(data['mediaUrl'] ?? []),
      thumbnailUrl: List<String>.from(data['thumbnailUrl'] ?? []),
      targetAge: List<int>.from(data['targetAge'] ?? [20, 30]),
      targetGender: data['targetGender'] ?? 'all',
      targetInterest: List<String>.from(data['targetInterest'] ?? []),
      targetPurchaseHistory: List<String>.from(data['targetPurchaseHistory'] ?? []),
      canRespond: data['canRespond'] ?? false,
      canForward: data['canForward'] ?? false,
      canRequestReward: data['canRequestReward'] ?? true,
      canUse: data['canUse'] ?? false,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      isCoupon: data['isCoupon'] ?? false,
      couponData: data['couponData'],
      placeId: data['placeId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'instanceId': instanceId,
      'postId': postId,
      'markerId': markerId,
      'userId': userId,
      'collectedAt': Timestamp.fromDate(collectedAt),
      'collectedLocation': collectedLocation,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'usedLocation': usedLocation,
      'usedNote': usedNote,
      'isUsed': isUsed,
      'status': status.value,
      'isActive': isActive,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'description': description,
      'reward': reward,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'targetAge': targetAge,
      'targetGender': targetGender,
      'targetInterest': targetInterest,
      'targetPurchaseHistory': targetPurchaseHistory,
      'canRespond': canRespond,
      'canForward': canForward,
      'canRequestReward': canRequestReward,
      'canUse': canUse,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isCoupon': isCoupon,
      'couponData': couponData,
      'placeId': placeId,
    };
  }

  // 상태 확인 메서드들
  bool get isCollected => status == PostInstanceStatus.COLLECTED;
  bool get isExpired => status == PostInstanceStatus.EXPIRED || DateTime.now().isAfter(expiresAt);
  bool get canBeUsed => canUse && isCollected && !isExpired;

  // 사용 처리
  PostInstanceModel markAsUsed({
    GeoPoint? location,
    String? note,
  }) {
    if (!canBeUsed) {
      throw Exception('사용할 수 없는 상태입니다.');
    }

    return copyWith(
      isUsed: true,
      status: PostInstanceStatus.USED,
      usedAt: DateTime.now(),
      usedLocation: location,
      usedNote: note,
    );
  }

  // 만료 처리
  PostInstanceModel markAsExpired() {
    return copyWith(
      status: PostInstanceStatus.EXPIRED,
      isActive: false,
    );
  }

  // 상태 업데이트 (만료 체크)
  PostInstanceModel updateStatus() {
    if (DateTime.now().isAfter(expiresAt) && status == PostInstanceStatus.COLLECTED) {
      return markAsExpired();
    }
    return this;
  }

  PostInstanceModel copyWith({
    String? instanceId,
    String? postId,
    String? markerId,
    String? userId,
    DateTime? collectedAt,
    GeoPoint? collectedLocation,
    DateTime? usedAt,
    GeoPoint? usedLocation,
    String? usedNote,
    bool? isUsed,
    PostInstanceStatus? status,
    bool? isActive,
    String? creatorId,
    String? creatorName,
    String? title,
    String? description,
    int? reward,
    List<String>? mediaType,
    List<String>? mediaUrl,
    List<String>? thumbnailUrl,
    List<int>? targetAge,
    String? targetGender,
    List<String>? targetInterest,
    List<String>? targetPurchaseHistory,
    bool? canRespond,
    bool? canForward,
    bool? canRequestReward,
    bool? canUse,
    DateTime? expiresAt,
    bool? isCoupon,
    Map<String, dynamic>? couponData,
    String? placeId,
  }) {
    return PostInstanceModel(
      instanceId: instanceId ?? this.instanceId,
      postId: postId ?? this.postId,
      markerId: markerId ?? this.markerId,
      userId: userId ?? this.userId,
      collectedAt: collectedAt ?? this.collectedAt,
      collectedLocation: collectedLocation ?? this.collectedLocation,
      usedAt: usedAt ?? this.usedAt,
      usedLocation: usedLocation ?? this.usedLocation,
      usedNote: usedNote ?? this.usedNote,
      isUsed: isUsed ?? this.isUsed,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      description: description ?? this.description,
      reward: reward ?? this.reward,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      targetAge: targetAge ?? this.targetAge,
      targetGender: targetGender ?? this.targetGender,
      targetInterest: targetInterest ?? this.targetInterest,
      targetPurchaseHistory: targetPurchaseHistory ?? this.targetPurchaseHistory,
      canRespond: canRespond ?? this.canRespond,
      canForward: canForward ?? this.canForward,
      canRequestReward: canRequestReward ?? this.canRequestReward,
      canUse: canUse ?? this.canUse,
      expiresAt: expiresAt ?? this.expiresAt,
      isCoupon: isCoupon ?? this.isCoupon,
      couponData: couponData ?? this.couponData,
      placeId: placeId ?? this.placeId,
    );
  }

  @override
  String toString() {
    return 'PostInstanceModel(instanceId: $instanceId, title: $title, userId: $userId, status: ${status.name})';
  }
}