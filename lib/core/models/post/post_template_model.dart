import 'package:cloud_firestore/cloud_firestore.dart';

// 포스트 템플릿 상태 열거형
enum PostTemplateStatus {
  ACTIVE,    // 활성 템플릿 (배포 가능)
  INACTIVE,  // 비활성 템플릿 (배포 불가)
  DELETED,   // 삭제된 템플릿
}

// 포스트 템플릿 상태 확장 메서드
extension PostTemplateStatusExtension on PostTemplateStatus {
  String get name {
    switch (this) {
      case PostTemplateStatus.ACTIVE:
        return '활성';
      case PostTemplateStatus.INACTIVE:
        return '비활성';
      case PostTemplateStatus.DELETED:
        return '삭제됨';
    }
  }

  String get value {
    switch (this) {
      case PostTemplateStatus.ACTIVE:
        return 'active';
      case PostTemplateStatus.INACTIVE:
        return 'inactive';
      case PostTemplateStatus.DELETED:
        return 'deleted';
    }
  }

  static PostTemplateStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return PostTemplateStatus.ACTIVE;
      case 'inactive':
        return PostTemplateStatus.INACTIVE;
      case 'deleted':
        return PostTemplateStatus.DELETED;
      default:
        return PostTemplateStatus.ACTIVE;
    }
  }
}

/// 포스트 템플릿 모델
/// 포스트의 기본 정보만 포함하며, 배포 시점에 수량/위치/기간이 결정됨
class PostTemplateModel {
  // 기본 메타데이터 (생성일만 포함, 만료일 제거)
  final String templateId;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt; // 템플릿 생성일만 유지
  final int reward; // 단가 (유일한 가격 정보)

  // 타겟팅 조건
  final List<int> targetAge; // [20, 30] 등 범위
  final String targetGender; // male / female / all
  final List<String> targetInterest; // ["패션", "뷰티"] 등
  final List<String> targetPurchaseHistory; // ["화장품", "치킨"]

  // 콘텐츠 정보
  final List<String> mediaType; // text / image / audio
  final List<String> mediaUrl; // 파일 링크 (1~2개 조합 가능)
  final List<String> thumbnailUrl; // 썸네일 이미지 링크
  final String title;
  final String description;

  // 사용자 행동 조건
  final bool canRespond;
  final bool canForward;
  final bool canRequestReward;
  final bool canUse;

  // 플레이스 연동 (옵션)
  final String? placeId;

  // 템플릿 상태 관리
  final PostTemplateStatus status;

  // 쿠폰 시스템 (추후 구현)
  final bool isCoupon;
  final Map<String, dynamic>? couponData;

  // 템플릿 통계 (배포 현황 추적)
  final int totalDeployments; // 총 배포 횟수
  final int totalInstances; // 총 생성된 인스턴스 수
  final DateTime? lastDeployedAt; // 마지막 배포 시점

  PostTemplateModel({
    required this.templateId,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    required this.reward,
    required this.targetAge,
    required this.targetGender,
    required this.targetInterest,
    required this.targetPurchaseHistory,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl = const [],
    required this.title,
    required this.description,
    required this.canRespond,
    required this.canForward,
    required this.canRequestReward,
    required this.canUse,
    this.placeId,
    this.status = PostTemplateStatus.ACTIVE,
    this.isCoupon = false,
    this.couponData,
    this.totalDeployments = 0,
    this.totalInstances = 0,
    this.lastDeployedAt,
  });

  factory PostTemplateModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String templateId = data['templateId'] ?? doc.id;
    if (templateId.isEmpty) {
      templateId = doc.id;
    }

    return PostTemplateModel(
      templateId: templateId,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reward: data['reward'] ?? 0,
      targetAge: List<int>.from(data['targetAge'] ?? [20, 30]),
      targetGender: data['targetGender'] ?? 'all',
      targetInterest: List<String>.from(data['targetInterest'] ?? []),
      targetPurchaseHistory: List<String>.from(data['targetPurchaseHistory'] ?? []),
      mediaType: List<String>.from(data['mediaType'] ?? ['text']),
      mediaUrl: List<String>.from(data['mediaUrl'] ?? []),
      thumbnailUrl: List<String>.from(data['thumbnailUrl'] ?? []),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      canRespond: data['canRespond'] ?? false,
      canForward: data['canForward'] ?? false,
      canRequestReward: data['canRequestReward'] ?? true,
      canUse: data['canUse'] ?? false,
      placeId: data['placeId'],
      status: PostTemplateStatusExtension.fromString(data['status'] ?? 'active'),
      isCoupon: data['isCoupon'] ?? false,
      couponData: data['couponData'],
      totalDeployments: data['totalDeployments'] ?? 0,
      totalInstances: data['totalInstances'] ?? 0,
      lastDeployedAt: data['lastDeployedAt'] != null
          ? (data['lastDeployedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'templateId': templateId,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'reward': reward,
      'targetAge': targetAge,
      'targetGender': targetGender,
      'targetInterest': targetInterest,
      'targetPurchaseHistory': targetPurchaseHistory,
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'canRespond': canRespond,
      'canForward': canForward,
      'canRequestReward': canRequestReward,
      'canUse': canUse,
      'placeId': placeId,
      'status': status.value,
      'isCoupon': isCoupon,
      'couponData': couponData,
      'totalDeployments': totalDeployments,
      'totalInstances': totalInstances,
      'lastDeployedAt': lastDeployedAt != null ? Timestamp.fromDate(lastDeployedAt!) : null,
    };
  }

  // 템플릿 상태 확인 메서드들
  bool get isActive => status == PostTemplateStatus.ACTIVE;
  bool get canDeploy => status == PostTemplateStatus.ACTIVE;
  bool get canEdit => status == PostTemplateStatus.ACTIVE || status == PostTemplateStatus.INACTIVE;

  // 템플릿 업데이트 메서드들
  PostTemplateModel markAsDeployed() {
    return copyWith(
      totalDeployments: totalDeployments + 1,
      lastDeployedAt: DateTime.now(),
    );
  }

  PostTemplateModel incrementInstances(int count) {
    return copyWith(
      totalInstances: totalInstances + count,
    );
  }

  PostTemplateModel updateStatus(PostTemplateStatus newStatus) {
    return copyWith(status: newStatus);
  }

  PostTemplateModel copyWith({
    String? templateId,
    String? creatorId,
    String? creatorName,
    DateTime? createdAt,
    int? reward,
    List<int>? targetAge,
    String? targetGender,
    List<String>? targetInterest,
    List<String>? targetPurchaseHistory,
    List<String>? mediaType,
    List<String>? mediaUrl,
    List<String>? thumbnailUrl,
    String? title,
    String? description,
    bool? canRespond,
    bool? canForward,
    bool? canRequestReward,
    bool? canUse,
    String? placeId,
    PostTemplateStatus? status,
    bool? isCoupon,
    Map<String, dynamic>? couponData,
    int? totalDeployments,
    int? totalInstances,
    DateTime? lastDeployedAt,
  }) {
    return PostTemplateModel(
      templateId: templateId ?? this.templateId,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      reward: reward ?? this.reward,
      targetAge: targetAge ?? this.targetAge,
      targetGender: targetGender ?? this.targetGender,
      targetInterest: targetInterest ?? this.targetInterest,
      targetPurchaseHistory: targetPurchaseHistory ?? this.targetPurchaseHistory,
      mediaType: mediaType ?? this.mediaType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      canRespond: canRespond ?? this.canRespond,
      canForward: canForward ?? this.canForward,
      canRequestReward: canRequestReward ?? this.canRequestReward,
      canUse: canUse ?? this.canUse,
      placeId: placeId ?? this.placeId,
      status: status ?? this.status,
      isCoupon: isCoupon ?? this.isCoupon,
      couponData: couponData ?? this.couponData,
      totalDeployments: totalDeployments ?? this.totalDeployments,
      totalInstances: totalInstances ?? this.totalInstances,
      lastDeployedAt: lastDeployedAt ?? this.lastDeployedAt,
    );
  }

  @override
  String toString() {
    return 'PostTemplateModel(templateId: $templateId, title: $title, reward: $reward, status: ${status.name})';
  }
}