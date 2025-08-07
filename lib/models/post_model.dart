import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class PostModel {
  // 필수 메타데이터
  final String flyerId;
  final String creatorId;
  final String creatorName;
  final GeoPoint location;
  final int radius; // 노출 반경 (m)
  final DateTime createdAt;
  final DateTime expiresAt;
  final int reward; // 리워드 금액
  
  // 타겟팅 조건
  final List<int> targetAge; // [20, 30] 등 범위
  final String targetGender; // male / female / all
  final List<String> targetInterest; // ["패션", "뷰티"] 등
  final List<String> targetPurchaseHistory; // ["화장품", "치킨"]
  
  // 광고 콘텐츠
  final List<String> mediaType; // text / image / audio
  final List<String> mediaUrl; // 파일 링크 (1~2개 조합 가능)
  final String title;
  final String description;
  
  // 사용자 행동 조건
  final bool canRespond;
  final bool canForward;
  final bool canRequestReward;
  final bool canUse;
  
  // 마커 관련
  final String markerId;
  final bool isActive;
  final bool isCollected;
  final String? collectedBy;
  final DateTime? collectedAt;

  PostModel({
    required this.flyerId,
    required this.creatorId,
    required this.creatorName,
    required this.location,
    required this.radius,
    required this.createdAt,
    required this.expiresAt,
    required this.reward,
    required this.targetAge,
    required this.targetGender,
    required this.targetInterest,
    required this.targetPurchaseHistory,
    required this.mediaType,
    required this.mediaUrl,
    required this.title,
    required this.description,
    required this.canRespond,
    required this.canForward,
    required this.canRequestReward,
    required this.canUse,
    String? markerId,
    this.isActive = true,
    this.isCollected = false,
    this.collectedBy,
    this.collectedAt,
  }) : markerId = markerId ?? '${creatorId}_$flyerId';

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return PostModel(
      flyerId: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      radius: data['radius'] ?? 1000,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      reward: data['reward'] ?? 0,
      targetAge: List<int>.from(data['targetAge'] ?? [20, 30]),
      targetGender: data['targetGender'] ?? 'all',
      targetInterest: List<String>.from(data['targetInterest'] ?? []),
      targetPurchaseHistory: List<String>.from(data['targetPurchaseHistory'] ?? []),
      mediaType: List<String>.from(data['mediaType'] ?? ['text']),
      mediaUrl: List<String>.from(data['mediaUrl'] ?? []),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      canRespond: data['canRespond'] ?? false,
      canForward: data['canForward'] ?? false,
      canRequestReward: data['canRequestReward'] ?? true,
      canUse: data['canUse'] ?? false,
      markerId: data['markerId'] ?? '${data['creatorId']}_${doc.id}',
      isActive: data['isActive'] ?? true,
      isCollected: data['isCollected'] ?? false,
      collectedBy: data['collectedBy'],
      collectedAt: data['collectedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
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
      'title': title,
      'description': description,
      'canRespond': canRespond,
      'canForward': canForward,
      'canRequestReward': canRequestReward,
      'canUse': canUse,
      'markerId': markerId,
      'isActive': isActive,
      'isCollected': isCollected,
      'collectedBy': collectedBy,
      'collectedAt': collectedAt != null ? Timestamp.fromDate(collectedAt!) : null,
    };
  }

  // Meilisearch용 데이터 구조
  Map<String, dynamic> toMeilisearch() {
    return {
      'id': flyerId,
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

  PostModel copyWith({
    String? flyerId,
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
    String? title,
    String? description,
    bool? canRespond,
    bool? canForward,
    bool? canRequestReward,
    bool? canUse,
    String? markerId,
    bool? isActive,
    bool? isCollected,
    String? collectedBy,
    DateTime? collectedAt,
  }) {
    return PostModel(
      flyerId: flyerId ?? this.flyerId,
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
      title: title ?? this.title,
      description: description ?? this.description,
      canRespond: canRespond ?? this.canRespond,
      canForward: canForward ?? this.canForward,
      canRequestReward: canRequestReward ?? this.canRequestReward,
      canUse: canUse ?? this.canUse,
      markerId: markerId ?? this.markerId,
      isActive: isActive ?? this.isActive,
      isCollected: isCollected ?? this.isCollected,
      collectedBy: collectedBy ?? this.collectedBy,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }
} 