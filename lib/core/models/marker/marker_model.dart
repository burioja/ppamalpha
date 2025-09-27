import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// 마커 모델 - 포스트에 접근하는 연결고리
class MarkerModel {
  final String markerId;
  final String postId; // 연결된 포스트 ID
  final String title; // 마커 제목 (간단한 정보)
  final LatLng position; // 마커 위치
  final int quantity; // 수량
  final int? reward; // 리워드 금액 (배포 시점 고정, 기존 마커 호환성을 위해 옵셔널)
  final String creatorId; // 마커 생성자
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final List<String> collectedBy; // 수령한 사용자 ID 목록

  MarkerModel({
    required this.markerId,
    required this.postId,
    required this.title,
    required this.position,
    required this.quantity,
    this.reward, // ✅ 옵셔널로 변경
    required this.creatorId,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    this.collectedBy = const [],
  });

  /// Firestore에서 마커 생성
  factory MarkerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final location = data['location'] as GeoPoint;
    
    // reward 안전 파싱 (기존 마커 호환성)
    final rawReward = data['reward'];
    int? parsedReward;
    if (rawReward != null) {
      parsedReward = switch (rawReward) {
        int v => v,
        double v => v.toInt(),
        num v => v.toInt(),
        String v => int.tryParse(v),
        _ => null,
      };
    }
    
    return MarkerModel(
      markerId: doc.id,
      postId: data['postId'] ?? '',
      title: data['title'] ?? '',
      position: LatLng(location.latitude, location.longitude),
      quantity: data['quantity'] ?? 0,
      reward: parsedReward, // ✅ null 허용
      creatorId: data['creatorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      collectedBy: List<String>.from(data['collectedBy'] ?? []),
    );
  }

  /// Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    final data = {
      'postId': postId,
      'title': title,
      'location': GeoPoint(position.latitude, position.longitude),
      'quantity': quantity,
      'creatorId': creatorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'collectedBy': collectedBy,
    };
    
    if (reward != null) { // ✅ null이 아닐 때만 저장
      data['reward'] = reward;
    }
    
    return data;
  }

  /// 마커 복사 (수량 변경)
  MarkerModel copyWith({
    String? markerId,
    String? postId,
    String? title,
    LatLng? position,
    int? quantity,
    int? reward,
    String? creatorId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    List<String>? collectedBy,
  }) {
    return MarkerModel(
      markerId: markerId ?? this.markerId,
      postId: postId ?? this.postId,
      title: title ?? this.title,
      position: position ?? this.position,
      quantity: quantity ?? this.quantity,
      reward: reward ?? this.reward, // ✅ null 허용
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      collectedBy: collectedBy ?? this.collectedBy,
    );
  }
}
