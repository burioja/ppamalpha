import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// 마커 모델 - 포스트에 접근하는 연결고리
class MarkerModel {
  final String markerId;
  final String postId; // 연결된 포스트 ID
  final String title; // 마커 제목 (간단한 정보)
  final LatLng position; // 마커 위치
  final int quantity; // 수량
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
    
    return MarkerModel(
      markerId: doc.id,
      postId: data['postId'] ?? '',
      title: data['title'] ?? '',
      position: LatLng(location.latitude, location.longitude),
      quantity: data['quantity'] ?? 0,
      creatorId: data['creatorId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      collectedBy: List<String>.from(data['collectedBy'] ?? []),
    );
  }

  /// Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    return {
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
  }

  /// 마커 복사 (수량 변경)
  MarkerModel copyWith({
    String? markerId,
    String? postId,
    String? title,
    LatLng? position,
    int? quantity,
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
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      collectedBy: collectedBy ?? this.collectedBy,
    );
  }
}
