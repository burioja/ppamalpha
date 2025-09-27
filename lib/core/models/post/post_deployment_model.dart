import 'package:cloud_firestore/cloud_firestore.dart';

// 배포 상태 열거형
enum PostDeploymentStatus {
  ACTIVE,   // 활성 배포 (수집 가능)
  EXPIRED,  // 만료된 배포 (수집 불가)
  PAUSED,   // 일시 정지
  DELETED,  // 삭제된 배포
}

// 배포 상태 확장 메서드
extension PostDeploymentStatusExtension on PostDeploymentStatus {
  String get name {
    switch (this) {
      case PostDeploymentStatus.ACTIVE:
        return '활성';
      case PostDeploymentStatus.EXPIRED:
        return '만료됨';
      case PostDeploymentStatus.PAUSED:
        return '일시정지';
      case PostDeploymentStatus.DELETED:
        return '삭제됨';
    }
  }

  String get value {
    switch (this) {
      case PostDeploymentStatus.ACTIVE:
        return 'active';
      case PostDeploymentStatus.EXPIRED:
        return 'expired';
      case PostDeploymentStatus.PAUSED:
        return 'paused';
      case PostDeploymentStatus.DELETED:
        return 'deleted';
    }
  }

  static PostDeploymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return PostDeploymentStatus.ACTIVE;
      case 'expired':
        return PostDeploymentStatus.EXPIRED;
      case 'paused':
        return PostDeploymentStatus.PAUSED;
      case 'deleted':
        return PostDeploymentStatus.DELETED;
      default:
        return PostDeploymentStatus.ACTIVE;
    }
  }
}

/// 포스트 배포 모델
/// 마커를 뿌릴 때 설정되는 배포 관련 정보 (수량, 위치, 기간)
class PostDeploymentModel {
  // 기본 식별자
  final String deploymentId;
  final String templateId; // 원본 템플릿 참조
  final String creatorId;

  // 배포 위치 정보 (Map에서 설정)
  final GeoPoint location;
  final int radius; // 노출 반경 (m)

  // 배포 수량 정보 (Map에서 설정)
  final int totalQuantity; // 총 배포 수량
  final int remainingQuantity; // 남은 수량
  final int collectedQuantity; // 수집된 수량

  // 배포 기간 정보 (Map에서 설정)
  final DateTime startDate; // 배포 시작일
  final DateTime endDate; // 배포 종료일
  final DateTime deployedAt; // 실제 배포 시점

  // 배포 상태
  final PostDeploymentStatus status;

  // 마커 관련 (성능 최적화용)
  final String markerId; // 지도에 표시되는 마커 ID
  final String? tileId; // 포스트가 위치한 타일 ID
  final bool isSuperPost; // 슈퍼포스트 여부 (검은 영역에서도 표시)

  // S2 타일 ID (서버 사이드 필터링용)
  final String? s2_10; // S2 level 10 cell id (쿼리용)
  final String? s2_12; // S2 level 12 cell id (더 촘촘한 커버링용)

  // 필터링 필드 (서버 사이드 최적화)
  final String rewardType; // 'normal' | 'super'
  final int? fogLevel; // 포그레벨 (1: Clear, 2: Partial, 3: Dark)
  final String? tileId_fog1; // 포그레벨 1 타일 ID

  // 배포 통계
  final int viewCount; // 노출 횟수
  final double collectionRate; // 수집률 (수집된 수량 / 총 수량)

  PostDeploymentModel({
    required this.deploymentId,
    required this.templateId,
    required this.creatorId,
    required this.location,
    required this.radius,
    required this.totalQuantity,
    int? remainingQuantity,
    this.collectedQuantity = 0,
    required this.startDate,
    required this.endDate,
    required this.deployedAt,
    this.status = PostDeploymentStatus.ACTIVE,
    String? markerId,
    this.tileId,
    this.isSuperPost = false,
    this.s2_10,
    this.s2_12,
    this.rewardType = 'normal',
    this.fogLevel,
    this.tileId_fog1,
    this.viewCount = 0,
    double? collectionRate,
  })  : remainingQuantity = remainingQuantity ?? totalQuantity,
        markerId = markerId ?? '${creatorId}_${templateId}_$deploymentId',
        collectionRate = collectionRate ?? 0.0;

  factory PostDeploymentModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    String deploymentId = data['deploymentId'] ?? doc.id;
    if (deploymentId.isEmpty) {
      deploymentId = doc.id;
    }

    return PostDeploymentModel(
      deploymentId: deploymentId,
      templateId: data['templateId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      radius: data['radius'] ?? 1000,
      totalQuantity: data['totalQuantity'] ?? 1,
      remainingQuantity: data['remainingQuantity'],
      collectedQuantity: data['collectedQuantity'] ?? 0,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 7)),
      deployedAt: data['deployedAt'] != null
          ? (data['deployedAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: PostDeploymentStatusExtension.fromString(data['status'] ?? 'active'),
      markerId: data['markerId'],
      tileId: data['tileId'],
      isSuperPost: data['isSuperPost'] ?? false,
      s2_10: data['s2_10'],
      s2_12: data['s2_12'],
      rewardType: data['rewardType'] ?? 'normal',
      fogLevel: data['fogLevel'],
      tileId_fog1: data['tileId_fog1'],
      viewCount: data['viewCount'] ?? 0,
      collectionRate: (data['collectionRate'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deploymentId': deploymentId,
      'templateId': templateId,
      'creatorId': creatorId,
      'location': location,
      'radius': radius,
      'totalQuantity': totalQuantity,
      'remainingQuantity': remainingQuantity,
      'collectedQuantity': collectedQuantity,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'deployedAt': Timestamp.fromDate(deployedAt),
      'status': status.value,
      'markerId': markerId,
      'tileId': tileId,
      'isSuperPost': isSuperPost,
      's2_10': s2_10,
      's2_12': s2_12,
      'rewardType': rewardType,
      'fogLevel': fogLevel,
      'tileId_fog1': tileId_fog1,
      'viewCount': viewCount,
      'collectionRate': collectionRate,
    };
  }

  // 상태 확인 메서드들
  bool get isActive => status == PostDeploymentStatus.ACTIVE;
  bool get isExpired => status == PostDeploymentStatus.EXPIRED || DateTime.now().isAfter(endDate);
  bool get isAvailable => isActive && !isExpired && remainingQuantity > 0;
  bool get canCollect => isAvailable;

  // 수집 가능 여부 (위치 기반)
  bool isInRadius(GeoPoint userLocation) {
    final distance = _calculateDistance(
      location.latitude, location.longitude,
      userLocation.latitude, userLocation.longitude,
    );
    return distance <= radius;
  }

  // 수집 처리
  PostDeploymentModel collectOne() {
    if (!canCollect) {
      throw Exception('수집할 수 없는 상태입니다.');
    }

    final newCollectedQuantity = collectedQuantity + 1;
    final newRemainingQuantity = remainingQuantity - 1;
    final newCollectionRate = totalQuantity > 0 ? newCollectedQuantity / totalQuantity : 0.0;

    // 수량이 모두 소진되면 만료 처리
    final newStatus = newRemainingQuantity <= 0 ? PostDeploymentStatus.EXPIRED : status;

    return copyWith(
      collectedQuantity: newCollectedQuantity,
      remainingQuantity: newRemainingQuantity,
      collectionRate: newCollectionRate,
      status: newStatus,
    );
  }

  // 상태 업데이트 (만료 체크)
  PostDeploymentModel updateStatus() {
    if (DateTime.now().isAfter(endDate) && status == PostDeploymentStatus.ACTIVE) {
      return copyWith(status: PostDeploymentStatus.EXPIRED);
    }
    return this;
  }

  // 거리 계산 헬퍼 메서드
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = (dLat / 2).sin() * (dLat / 2).sin() +
        _degreesToRadians(lat1).cos() * _degreesToRadians(lat2).cos() *
        (dLon / 2).sin() * (dLon / 2).sin();
    final double c = 2 * a.sqrt().asin();

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  PostDeploymentModel copyWith({
    String? deploymentId,
    String? templateId,
    String? creatorId,
    GeoPoint? location,
    int? radius,
    int? totalQuantity,
    int? remainingQuantity,
    int? collectedQuantity,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? deployedAt,
    PostDeploymentStatus? status,
    String? markerId,
    String? tileId,
    bool? isSuperPost,
    String? s2_10,
    String? s2_12,
    String? rewardType,
    int? fogLevel,
    String? tileId_fog1,
    int? viewCount,
    double? collectionRate,
  }) {
    return PostDeploymentModel(
      deploymentId: deploymentId ?? this.deploymentId,
      templateId: templateId ?? this.templateId,
      creatorId: creatorId ?? this.creatorId,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      collectedQuantity: collectedQuantity ?? this.collectedQuantity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      deployedAt: deployedAt ?? this.deployedAt,
      status: status ?? this.status,
      markerId: markerId ?? this.markerId,
      tileId: tileId ?? this.tileId,
      isSuperPost: isSuperPost ?? this.isSuperPost,
      s2_10: s2_10 ?? this.s2_10,
      s2_12: s2_12 ?? this.s2_12,
      rewardType: rewardType ?? this.rewardType,
      fogLevel: fogLevel ?? this.fogLevel,
      tileId_fog1: tileId_fog1 ?? this.tileId_fog1,
      viewCount: viewCount ?? this.viewCount,
      collectionRate: collectionRate ?? this.collectionRate,
    );
  }

  @override
  String toString() {
    return 'PostDeploymentModel(deploymentId: $deploymentId, templateId: $templateId, quantity: $remainingQuantity/$totalQuantity, status: ${status.name})';
  }
}