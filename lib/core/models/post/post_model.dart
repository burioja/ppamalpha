import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';

// 포스트 상태 열거형
enum PostStatus {
  DRAFT,     // 배포 대기 (수정 가능)
  DEPLOYED,  // 배포됨 (수정 불가, 만료 시 자동 삭제)
  RECALLED,  // 회수됨 (재배포 불가)
  DELETED,   // 삭제됨
}

// 포스트 배포 타입 열거형
enum DeploymentType {
  STREET,      // 거리배포 - 마커 생성, 근접 수령
  MAILBOX,     // 우편함배포 - 집/일터 사용자 자동 수령
  BILLBOARD,   // 광고보드배포 - 광고보드 클릭 시 전체 수령
}

// 포스트 상태 확장 메서드
extension PostStatusExtension on PostStatus {
  String get name {
    switch (this) {
      case PostStatus.DRAFT:
        return '배포 대기';
      case PostStatus.DEPLOYED:
        return '배포됨';
      case PostStatus.RECALLED:
        return '회수됨';
      case PostStatus.DELETED:
        return '삭제됨';
    }
  }

  String get value {
    switch (this) {
      case PostStatus.DRAFT:
        return 'draft';
      case PostStatus.DEPLOYED:
        return 'deployed';
      case PostStatus.RECALLED:
        return 'recalled';
      case PostStatus.DELETED:
        return 'deleted';
    }
  }

  static PostStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return PostStatus.DRAFT;
      case 'deployed':
        return PostStatus.DEPLOYED;
      case 'recalled':
        return PostStatus.RECALLED;
      case 'deleted':
        return PostStatus.DELETED;
      // 기존 expired 데이터 호환성을 위해 deleted로 변환
      case 'expired':
        return PostStatus.DELETED;
      default:
        return PostStatus.DRAFT;
    }
  }
}

// 배포 타입 확장 메서드
extension DeploymentTypeExtension on DeploymentType {
  String get name {
    switch (this) {
      case DeploymentType.STREET:
        return '거리배포';
      case DeploymentType.MAILBOX:
        return '우편함배포';
      case DeploymentType.BILLBOARD:
        return '광고보드배포';
    }
  }

  String get value {
    switch (this) {
      case DeploymentType.STREET:
        return 'street';
      case DeploymentType.MAILBOX:
        return 'mailbox';
      case DeploymentType.BILLBOARD:
        return 'billboard';
    }
  }

  String get description {
    switch (this) {
      case DeploymentType.STREET:
        return '거리에 마커를 만들고 근접한 사용자가 수령';
      case DeploymentType.MAILBOX:
        return '집/일터가 선택 주소인 사용자가 자동 수령';
      case DeploymentType.BILLBOARD:
        return '광고보드 클릭 시 등록된 모든 포스트 수령';
    }
  }

  static DeploymentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'street':
        return DeploymentType.STREET;
      case 'mailbox':
        return DeploymentType.MAILBOX;
      case 'billboard':
        return DeploymentType.BILLBOARD;
      default:
        return DeploymentType.STREET; // 기본값
    }
  }
}

class PostModel {
  // 필수 메타데이터
  final String postId;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt;
  final DateTime? updatedAt; // 수정일
  final DateTime? deployedAt; // 배포일 (마커 배포 시각)
  final int reward; // 리워드 금액

  // 🚀 템플릿 기본 설정 (배포 시 사용할 기본값)
  final int defaultRadius; // 기본 노출 반경 (m) - 배포 시 사용
  final DateTime defaultExpiresAt; // 기본 만료일 - 배포 시 사용
  
  // 타겟팅 조건
  final List<int> targetAge; // [20, 30] 등 범위
  final String targetGender; // male / female / all
  final List<String> targetInterest; // ["패션", "뷰티"] 등
  final List<String> targetPurchaseHistory; // ["화장품", "치킨"]
  
  // 광고 콘텐츠
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
  
  // 플레이스 연동
  final String? placeId;

  // 계산된 슈퍼포스트 여부 (reward 기준)
  bool get computedIsSuper => reward >= AppConsts.superRewardThreshold;

  // 포스트 상태 관리 시스템 (템플릿용)
  final PostStatus status; // 포스트 상태 (DRAFT, PUBLISHED, DELETED)
  final DocumentSnapshot? rawSnapshot; // 페이지네이션용 Firebase DocumentSnapshot

  // 사용자 수집 관련 필드 (wallet_screen.dart에서 사용)
  final DateTime? collectedAt; // 사용자가 포스트를 수집한 시간
  final DateTime? expiresAt; // 포스트 만료 시간 (collectedAt 기준)

  // 쿠폰 시스템 (추후 구현)
  final bool isCoupon; // 쿠폰 여부
  final Map<String, dynamic>? couponData; // 쿠폰 정보 (JSON 형태)

  // 유튜브 링크 (홍보용)
  final String? youtubeUrl; // 유튜브 영상 URL

  // 회수 시스템 (Phase 4)
  final String? recallReason; // 회수 사유 (재고소진/프로모션종료/오류수정/기타)
  final DateTime? recalledAt; // 회수 시점

  // 배포자 인증 상태
  final bool isVerified; // 배포자가 인증된 사용자인지 여부

  // 휴지통 시스템
  final DateTime? deletedAt; // 휴지통으로 이동한 시각 (null이면 정상 상태)

  // 배포 방식
  final DeploymentType deploymentType; // 배포 타입 (거리/우편함/광고보드)

  PostModel({
    required this.postId,
    required this.creatorId,
    required this.creatorName,
    required this.createdAt,
    required this.reward,
    // 🚀 템플릿 기본 설정
    this.defaultRadius = 1000, // 기본 1km
    required this.defaultExpiresAt,
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
    this.updatedAt,
    this.deployedAt,
    this.status = PostStatus.DRAFT,
    this.rawSnapshot,
    this.collectedAt,
    this.expiresAt,
    this.isCoupon = false,
    this.couponData,
    this.youtubeUrl,
    this.recallReason,
    this.recalledAt,
    this.isVerified = false, // 기본값 false
    this.deletedAt, // 휴지통 시스템
    this.deploymentType = DeploymentType.STREET, // 기본값: 거리배포
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // postId 우선순위: Firebase 필드 > 문서 ID > 빈 문자열 방지
    String postId = data['postId'] ?? doc.id;
    if (postId.isEmpty) {
      postId = doc.id; // 문서 ID를 fallback으로 사용
    }

    // reward 안전 파싱 (int/double/String 혼재 대응)
    final rawReward = data['reward'];
    final int parsedReward = switch (rawReward) {
      int v => v,
      double v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    // 🚀 기존 데이터 호환성을 위한 필드 처리
    // location, radius는 기존 데이터에 있으면 defaultRadius로 사용
    final int defaultRadius = data['radius'] ?? data['defaultRadius'] ?? 1000;
    final DateTime defaultExpiresAt = data['expiresAt'] != null
        ? (data['expiresAt'] as Timestamp).toDate()
        : data['defaultExpiresAt'] != null
            ? (data['defaultExpiresAt'] as Timestamp).toDate()
            : DateTime.now().add(const Duration(days: 30));

    return PostModel(
      postId: postId, // 이제 항상 유효한 ID 보장
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      reward: parsedReward,
      // 🚀 템플릿 기본 설정
      defaultRadius: defaultRadius,
      defaultExpiresAt: defaultExpiresAt,
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
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      deployedAt: data['deployedAt'] != null
          ? (data['deployedAt'] as Timestamp).toDate()
          : null,
      status: PostStatusExtension.fromString(data['status'] ?? 'draft'),
      rawSnapshot: doc, // DocumentSnapshot 저장
      collectedAt: data['collectedAt'] != null
          ? (data['collectedAt'] as Timestamp).toDate()
          : null,
      expiresAt: data['expiresAt'] != null
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isCoupon: data['isCoupon'] ?? false,
      couponData: data['couponData'],
      youtubeUrl: data['youtubeUrl'],
      recallReason: data['recallReason'],
      recalledAt: data['recalledAt'] != null
          ? (data['recalledAt'] as Timestamp).toDate()
          : null,
      isVerified: data['isVerified'] ?? false,
      deletedAt: data['deletedAt'] != null
          ? (data['deletedAt'] as Timestamp).toDate()
          : null,
      deploymentType: DeploymentTypeExtension.fromString(data['deploymentType'] ?? 'street'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId, // postId 필드 추가
      'creatorId': creatorId,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'reward': reward,
      // 🚀 템플릿 기본 설정
      'defaultRadius': defaultRadius,
      'defaultExpiresAt': Timestamp.fromDate(defaultExpiresAt),
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
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'deployedAt': deployedAt != null ? Timestamp.fromDate(deployedAt!) : null,
      'status': status.value,
      'collectedAt': collectedAt != null ? Timestamp.fromDate(collectedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'isCoupon': isCoupon,
      'couponData': couponData,
      'youtubeUrl': youtubeUrl,
      'recallReason': recallReason,
      'recalledAt': recalledAt != null ? Timestamp.fromDate(recalledAt!) : null,
      'isVerified': isVerified,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deploymentType': deploymentType.value,
    };
  }

  // Meilisearch용 데이터 구조
  Map<String, dynamic> toMeilisearch() {
    return {
      'id': postId,
      'title': title,
      'targetAge': targetAge,
      'targetGender': targetGender,
      'targetInterest': targetInterest,
      'targetPurchaseHistory': targetPurchaseHistory,
      'reward': reward,
      'mediaType': mediaType,
      'creatorId': creatorId,
      'defaultRadius': defaultRadius,
      'defaultExpiresAt': defaultExpiresAt.millisecondsSinceEpoch,
    };
  }

  // 조건 확인 메서드들
  bool isExpired() {
    return DateTime.now().isAfter(defaultExpiresAt);
  }

  // 새로운 상태 관리 메서드들
  bool get isDraft => status == PostStatus.DRAFT;
  // 배포되었거나 회수된 포스트 모두 통계 분석 가능 (회수된 것도 과거 배포 이력이 있음)
  bool get isDeployed => status == PostStatus.DEPLOYED || status == PostStatus.RECALLED;
  bool get canEdit => status == PostStatus.DRAFT; // 배포 대기 상태에서만 수정 가능
  bool get canDeploy => status == PostStatus.DRAFT || status == PostStatus.DEPLOYED || status == PostStatus.RECALLED; // DRAFT, DEPLOYED, RECALLED 모두 배포 가능 (다회 배포 지원)
  bool get canDelete => status == PostStatus.DRAFT || status == PostStatus.DEPLOYED;

  // 🚀 간소화된 상태 관리 메서드들
  PostModel markAsPublished() {
    return copyWith(status: PostStatus.DEPLOYED);
  }

  PostModel markAsDeleted() {
    return copyWith(status: PostStatus.DELETED);
  }

  // 자동 상태 업데이트 메서드
  PostModel updateStatus() {
    // 기본 만료일을 넘었다면 삭제됨 상태로 변경
    if (DateTime.now().isAfter(defaultExpiresAt)) {
      return markAsDeleted();
    }
    return this;
  }

  bool matchesTargetConditions({
    required int userAge,
    required String userGender,
    required List<String> userInterests,
    required List<String> userPurchaseHistory,
  }) {
    // 나이 조건 확인
    if (userAge < targetAge[0] || userAge > targetAge[1]) return false;
    
    // 성별 조건 확인
    if (targetGender != 'all' && targetGender != userGender) return false;
    
    // 관심사 조건 확인 (하나라도 일치하면 OK)
    if (targetInterest.isNotEmpty) {
      bool hasMatchingInterest = false;
      for (String interest in targetInterest) {
        if (userInterests.contains(interest)) {
          hasMatchingInterest = true;
          break;
        }
      }
      if (!hasMatchingInterest) return false;
    }
    
    // 구매 이력 조건 확인 (하나라도 일치하면 OK)
    if (targetPurchaseHistory.isNotEmpty) {
      bool hasMatchingHistory = false;
      for (String history in targetPurchaseHistory) {
        if (userPurchaseHistory.contains(history)) {
          hasMatchingHistory = true;
          break;
        }
      }
      if (!hasMatchingHistory) return false;
    }
    
    return true;
  }


  // 🚀 간소화된 copyWith 메서드
  PostModel copyWith({
    String? postId,
    String? creatorId,
    String? creatorName,
    DateTime? createdAt,
    int? reward,
    int? defaultRadius,
    DateTime? defaultExpiresAt,
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
    DateTime? updatedAt,
    DateTime? deployedAt,
    PostStatus? status,
    DocumentSnapshot? rawSnapshot,
    DateTime? collectedAt,
    DateTime? expiresAt,
    bool? isCoupon,
    Map<String, dynamic>? couponData,
    String? youtubeUrl,
    String? recallReason,
    DateTime? recalledAt,
    bool? isVerified,
    DateTime? deletedAt,
    DeploymentType? deploymentType,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      reward: reward ?? this.reward,
      defaultRadius: defaultRadius ?? this.defaultRadius,
      defaultExpiresAt: defaultExpiresAt ?? this.defaultExpiresAt,
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
      updatedAt: updatedAt ?? this.updatedAt,
      deployedAt: deployedAt ?? this.deployedAt,
      status: status ?? this.status,
      rawSnapshot: rawSnapshot ?? this.rawSnapshot,
      collectedAt: collectedAt ?? this.collectedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isCoupon: isCoupon ?? this.isCoupon,
      couponData: couponData ?? this.couponData,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      recallReason: recallReason ?? this.recallReason,
      recalledAt: recalledAt ?? this.recalledAt,
      isVerified: isVerified ?? this.isVerified,
      deletedAt: deletedAt ?? this.deletedAt,
      deploymentType: deploymentType ?? this.deploymentType,
    );
  }
} 