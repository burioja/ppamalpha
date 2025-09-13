import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 포인트 모델
class UserPointsModel {
  final String userId;
  final int totalPoints;
  final DateTime createdAt;
  final DateTime lastUpdated;

  const UserPointsModel({
    required this.userId,
    required this.totalPoints,
    required this.createdAt,
    required this.lastUpdated,
  });

  /// Firestore 문서에서 UserPointsModel 생성
  factory UserPointsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return UserPointsModel(
      userId: doc.id, // 문서 ID가 userId
      totalPoints: data['totalPoints'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  /// Map에서 UserPointsModel 생성
  factory UserPointsModel.fromMap(Map<String, dynamic> data, {String? userId}) {
    return UserPointsModel(
      userId: userId ?? data['userId'] ?? '',
      totalPoints: data['totalPoints'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  /// Firestore 저장용 Map 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalPoints': totalPoints,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// 포인트가 있는지 확인
  bool get hasPoints => totalPoints > 0;

  /// 포인트를 천 단위로 포맷 (예: 1,234)
  String get formattedPoints {
    return totalPoints.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  /// 포인트 레벨 계산 (1000포인트당 1레벨)
  int get level => (totalPoints / 1000).floor() + 1;

  /// 다음 레벨까지 필요한 포인트
  int get pointsToNextLevel {
    final nextLevelPoints = level * 1000;
    return nextLevelPoints - totalPoints;
  }

  /// 현재 레벨에서의 진행률 (0.0 ~ 1.0)
  double get levelProgress {
    final currentLevelBase = (level - 1) * 1000;
    final progressInLevel = totalPoints - currentLevelBase;
    return progressInLevel / 1000.0;
  }

  /// 포인트 등급 반환
  String get grade {
    if (totalPoints >= 50000) return 'DIAMOND';
    if (totalPoints >= 20000) return 'PLATINUM';
    if (totalPoints >= 10000) return 'GOLD';
    if (totalPoints >= 5000) return 'SILVER';
    if (totalPoints >= 1000) return 'BRONZE';
    return 'ROOKIE';
  }

  /// 등급 색상 (Material Design Colors)
  int get gradeColor {
    switch (grade) {
      case 'DIAMOND':
        return 0xFF00BCD4; // Cyan
      case 'PLATINUM':
        return 0xFF9E9E9E; // Grey
      case 'GOLD':
        return 0xFFFFD700; // Gold
      case 'SILVER':
        return 0xFFC0C0C0; // Silver
      case 'BRONZE':
        return 0xFFCD7F32; // Bronze
      case 'ROOKIE':
      default:
        return 0xFF795548; // Brown
    }
  }

  /// 마지막 업데이트 시간 (예: "2시간 전")
  String get lastUpdatedTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${lastUpdated.month}/${lastUpdated.day}';
    }
  }

  @override
  String toString() {
    return 'UserPointsModel(userId: $userId, totalPoints: $totalPoints, grade: $grade)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPointsModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  /// 복사본 생성
  UserPointsModel copyWith({
    String? userId,
    int? totalPoints,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return UserPointsModel(
      userId: userId ?? this.userId,
      totalPoints: totalPoints ?? this.totalPoints,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// 포인트 추가
  UserPointsModel addPoints(int points) {
    return copyWith(
      totalPoints: totalPoints + points,
      lastUpdated: DateTime.now(),
    );
  }

  /// 포인트 차감 (음수 방지)
  UserPointsModel subtractPoints(int points) {
    return copyWith(
      totalPoints: (totalPoints - points).clamp(0, double.infinity).toInt(),
      lastUpdated: DateTime.now(),
    );
  }
}