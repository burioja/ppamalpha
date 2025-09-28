import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../constants/app_constants.dart';

// 포스트 상태 열거형
enum PostStatus {
  DRAFT,     // 배포 대기 (수정 가능)
  DEPLOYED,  // 배포됨 (수정 불가, 만료 시 자동 삭제)
  DELETED,   // 삭제됨
}

// 포스트 상태 확장 메서드
extension PostStatusExtension on PostStatus {
  String get name {
    switch (this) {
      case PostStatus.DRAFT:
        return '배포 대기';
      case PostStatus.DEPLOYED:
        return '배포됨';
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

class PostModel {
  // 필수 메타데이터
  final String postId;
  final String creatorId;
  final String creatorName;
  final GeoPoint location;
  final int radius; // 노출 반경 (m)
  final DateTime createdAt;
  final DateTime expiresAt;
  final int reward; // 리워드 금액
  final int quantity; // 배포 수량
  final DateTime? updatedAt; // 수정일
  
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
  
  // 마커 관련
  final String markerId;
  final bool isActive;
  final bool isCollected;
  final String? collectedBy;
  final DateTime? collectedAt;
  final bool isDistributed; // 배포 여부 (true: 배포됨, false: 발행 전)
  final DateTime? distributedAt; // 배포 일시
  
  // 타일 관련 (성능 최적화용)
  final String? tileId; // 포스트가 위치한 타일 ID
  final bool? isSuperPost; // 슈퍼포스트 여부 (파생 저장, nullable 허용)
  
  // 계산된 슈퍼포스트 여부 (reward 기준)
  bool get computedIsSuper => reward >= AppConsts.superRewardThreshold;
  
  // S2 타일 ID (서버 사이드 필터링용)
  final String? s2_10; // S2 level 10 cell id (쿼리용)
  final String? s2_12; // S2 level 12 cell id (더 촘촘한 커버링용)
  
  // 필터링 필드 (서버 사이드 최적화)
  final String rewardType; // 'normal' | 'super'
  final int? fogLevel; // 포그레벨 (1: Clear, 2: Partial, 3: Dark)
  final String? tileId_fog1; // 포그레벨 1 타일 ID
  
  // 사용 관련
  final DateTime? usedAt; // 사용 일시
  final bool isUsedByCurrentUser; // 현재 사용자가 사용했는지 여부

  // 새로운 포스트 상태 관리 시스템
  final PostStatus status; // 포스트 상태
  final int? deployQuantity; // 배포 수량 (Map에서 설정)
  final GeoPoint? deployLocation; // 배포 위치 (Map에서 설정)
  final DateTime? deployStartDate; // 배포 시작일 (Map에서 설정)
  final DateTime? deployEndDate; // 배포 종료일 (Map에서 설정)
  final DocumentSnapshot? rawSnapshot; // 페이지네이션용 Firebase DocumentSnapshot

  // 쿠폰 시스템 (추후 구현)
  final bool isCoupon; // 쿠폰 여부
  final Map<String, dynamic>? couponData; // 쿠폰 정보 (JSON 형태)

  // 통계 추적 필드들 (기존)
  final int totalDeployed; // 총 배포 수량
  final int totalCollected; // 수집된 수량
  final int totalUsed; // 사용된 수량

  // 마커 배포 관련 통계 필드들 (새로 추가)
  final int totalDeployments; // 생성된 마커 수 (배포 횟수)
  final int totalInstances; // 생성된 인스턴스 수 (수집된 총 개수)
  final DateTime? lastDeployedAt; // 마지막 배포 시점
  final DateTime? lastCollectedAt; // 마지막 수집 시점

  PostModel({
    required this.postId,
    required this.creatorId,
    required this.creatorName,
    required this.location,
    required this.radius,
    required this.createdAt,
    required this.expiresAt,
    required this.reward,
    this.quantity = 1,
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
    String? markerId,
    this.isActive = true,
    this.isCollected = false,
    this.collectedBy,
    this.collectedAt,
    this.updatedAt,
    this.isDistributed = false,
    this.distributedAt,
    this.tileId,
    this.isSuperPost,
    this.s2_10,
    this.s2_12,
    this.rewardType = 'normal',
    this.fogLevel,
    this.tileId_fog1,
    this.usedAt,
    this.isUsedByCurrentUser = false,
    this.status = PostStatus.DRAFT,
    this.deployQuantity,
    this.deployLocation,
    this.deployStartDate,
    this.deployEndDate,
    this.rawSnapshot,
    this.isCoupon = false,
    this.couponData,
    this.totalDeployed = 0,
    this.totalCollected = 0,
    this.totalUsed = 0,
    this.totalDeployments = 0,
    this.totalInstances = 0,
    this.lastDeployedAt,
    this.lastCollectedAt,
  }) : markerId = markerId ?? '${creatorId}_$postId';

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
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };
    
    return PostModel(
      postId: postId, // 이제 항상 유효한 ID 보장
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      radius: data['radius'] ?? 1000,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      reward: parsedReward,
      quantity: data['quantity'] ?? 1,
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
      markerId: data['markerId'] ?? '${data['creatorId']}_${doc.id}',
      isActive: data['isActive'] ?? true,
      isCollected: data['isCollected'] ?? false,
      collectedBy: data['collectedBy'],
      collectedAt: data['collectedAt'] != null 
          ? (data['collectedAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isDistributed: data['isDistributed'] ?? false,
      distributedAt: data['distributedAt'] != null 
          ? (data['distributedAt'] as Timestamp).toDate()
          : null,
      tileId: data['tileId'],
      isSuperPost: data['isSuperPost'] as bool?,
      s2_10: data['s2_10'],
      s2_12: data['s2_12'],
      rewardType: data['rewardType'] ?? 'normal',
      fogLevel: data['fogLevel'],
      tileId_fog1: data['tileId_fog1'],
      usedAt: data['usedAt'] != null 
          ? (data['usedAt'] as Timestamp).toDate()
          : null,
      isUsedByCurrentUser: data['isUsedByCurrentUser'] ?? false,
      status: PostStatusExtension.fromString(data['status'] ?? 'draft'),
      deployQuantity: data['deployQuantity'],
      deployLocation: data['deployLocation'],
      deployStartDate: data['deployStartDate'] != null
          ? (data['deployStartDate'] as Timestamp).toDate()
          : null,
      deployEndDate: data['deployEndDate'] != null
          ? (data['deployEndDate'] as Timestamp).toDate()
          : null,
      rawSnapshot: doc, // DocumentSnapshot 저장
      isCoupon: data['isCoupon'] ?? false,
      couponData: data['couponData'],
      totalDeployed: data['totalDeployed'] ?? 0,
      totalCollected: data['totalCollected'] ?? 0,
      totalUsed: data['totalUsed'] ?? 0,
      totalDeployments: data['totalDeployments'] ?? 0,
      totalInstances: data['totalInstances'] ?? 0,
      lastDeployedAt: data['lastDeployedAt'] != null
          ? (data['lastDeployedAt'] as Timestamp).toDate()
          : null,
      lastCollectedAt: data['lastCollectedAt'] != null
          ? (data['lastCollectedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId, // postId 필드 추가
      'creatorId': creatorId,
      'creatorName': creatorName,
      'location': location,
      'radius': radius,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
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
      'markerId': markerId,
      'isActive': isActive,
      'isCollected': isCollected,
      'collectedBy': collectedBy,
      'collectedAt': collectedAt != null ? Timestamp.fromDate(collectedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isDistributed': isDistributed,
      'distributedAt': distributedAt != null ? Timestamp.fromDate(distributedAt!) : null,
      'tileId': tileId,
      'isSuperPost': isSuperPost,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'isUsedByCurrentUser': isUsedByCurrentUser,
      'status': status.value,
      'deployQuantity': deployQuantity,
      'deployLocation': deployLocation,
      'deployStartDate': deployStartDate != null ? Timestamp.fromDate(deployStartDate!) : null,
      'deployEndDate': deployEndDate != null ? Timestamp.fromDate(deployEndDate!) : null,
      'isCoupon': isCoupon,
      'couponData': couponData,
      'totalDeployed': totalDeployed,
      'totalCollected': totalCollected,
      'totalUsed': totalUsed,
      'totalDeployments': totalDeployments,
      'totalInstances': totalInstances,
      'lastDeployedAt': lastDeployedAt != null ? Timestamp.fromDate(lastDeployedAt!) : null,
      'lastCollectedAt': lastCollectedAt != null ? Timestamp.fromDate(lastCollectedAt!) : null,
    };
  }

  // Meilisearch용 데이터 구조
  Map<String, dynamic> toMeilisearch() {
    return {
      'id': postId,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'title': title,
      'targetAge': targetAge,
      'targetGender': targetGender,
      'targetInterest': targetInterest,
      'targetPurchaseHistory': targetPurchaseHistory,
      'reward': reward,
      'mediaType': mediaType,
      'creatorId': creatorId,
      'radius': radius,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
    };
  }

  // 조건 확인 메서드들
  bool isExpired() {
    return DateTime.now().isAfter(expiresAt);
  }

  // 새로운 상태 관리 메서드들
  bool get isDraft => status == PostStatus.DRAFT;
  bool get isDeployed => status == PostStatus.DEPLOYED;
  bool get canEdit => status == PostStatus.DRAFT; // 배포 대기 상태에서만 수정 가능
  bool get canDeploy => status == PostStatus.DRAFT; // DRAFT 상태에서만 배포 가능
  bool get canDelete => status == PostStatus.DRAFT || status == PostStatus.DEPLOYED;

  // 배포 관련 메서드들
  PostModel markAsDeployed({
    required int quantity,
    required GeoPoint location,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return copyWith(
      status: PostStatus.DEPLOYED,
      deployQuantity: quantity,
      deployLocation: location,
      deployStartDate: startDate ?? DateTime.now(),
      deployEndDate: endDate ?? expiresAt,
      distributedAt: DateTime.now(),
      isDistributed: true,
      totalDeployed: quantity,
    );
  }

  PostModel markAsExpired() {
    // 만료된 포스트는 자동으로 삭제됨 상태로 변경
    return copyWith(
      status: PostStatus.DELETED,
      isActive: false,
    );
  }

  PostModel markAsDeleted() {
    return copyWith(
      status: PostStatus.DELETED,
      isActive: false,
    );
  }

  // 자동 상태 업데이트 메서드
  PostModel updateStatus() {
    // 배포된 포스트가 배포 종료일을 넘었다면 삭제됨 상태로 변경
    if (status == PostStatus.DEPLOYED && deployEndDate != null && DateTime.now().isAfter(deployEndDate!)) {
      return markAsExpired(); // 배포 기간 종료 시 삭제됨 상태로 변경
    }
    return this;
  }

  bool isInRadius(GeoPoint userLocation) {
    final distance = _calculateDistance(
      location.latitude, location.longitude,
      userLocation.latitude, userLocation.longitude,
    );
    return distance <= radius;
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

  // 거리 계산 헬퍼 메서드
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(_degreesToRadians(lat1)) * math.sin(_degreesToRadians(lat2)) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // 포스트 사용 관련 메서드
  bool get isUsed => usedAt != null;

  bool get canBeUsed => canUse && !isUsed && !isUsedByCurrentUser && status == PostStatus.DEPLOYED && isActive;

  PostModel markAsUsed() {
    return copyWith(
      usedAt: DateTime.now(),
      isUsedByCurrentUser: true,
    );
  }

  PostModel updateUsageStatus({required bool isUsedByCurrentUser, DateTime? usedAt}) {
    return copyWith(
      isUsedByCurrentUser: isUsedByCurrentUser,
      usedAt: usedAt,
    );
  }

  PostModel copyWith({
    String? postId,
    String? creatorId,
    String? creatorName,
    GeoPoint? location,
    int? radius,
    DateTime? createdAt,
    DateTime? expiresAt,
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
    String? markerId,
    bool? isActive,
    bool? isCollected,
    String? collectedBy,
    DateTime? collectedAt,
    DateTime? updatedAt,
    bool? isDistributed,
    DateTime? distributedAt,
    String? tileId,
    bool? isSuperPost,
    DateTime? usedAt,
    bool? isUsedByCurrentUser,
    PostStatus? status,
    int? deployQuantity,
    GeoPoint? deployLocation,
    DateTime? deployStartDate,
    DateTime? deployEndDate,
    DocumentSnapshot? rawSnapshot,
    bool? isCoupon,
    Map<String, dynamic>? couponData,
    int? totalDeployed,
    int? totalCollected,
    int? totalUsed,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
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
      markerId: markerId ?? this.markerId,
      isActive: isActive ?? this.isActive,
      isCollected: isCollected ?? this.isCollected,
      collectedBy: collectedBy ?? this.collectedBy,
      collectedAt: collectedAt ?? this.collectedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDistributed: isDistributed ?? this.isDistributed,
      distributedAt: distributedAt ?? this.distributedAt,
      tileId: tileId ?? this.tileId,
      isSuperPost: isSuperPost ?? this.isSuperPost,
      usedAt: usedAt ?? this.usedAt,
      isUsedByCurrentUser: isUsedByCurrentUser ?? this.isUsedByCurrentUser,
      status: status ?? this.status,
      deployQuantity: deployQuantity ?? this.deployQuantity,
      deployLocation: deployLocation ?? this.deployLocation,
      deployStartDate: deployStartDate ?? this.deployStartDate,
      deployEndDate: deployEndDate ?? this.deployEndDate,
      rawSnapshot: rawSnapshot ?? this.rawSnapshot,
      isCoupon: isCoupon ?? this.isCoupon,
      couponData: couponData ?? this.couponData,
      totalDeployed: totalDeployed ?? this.totalDeployed,
      totalCollected: totalCollected ?? this.totalCollected,
      totalUsed: totalUsed ?? this.totalUsed,
    );
  }
} 