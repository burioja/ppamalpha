import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String content;
  final GeoPoint location;
  final String address;
  final DateTime createdAt;
  final bool isActive;
  final bool isCollected;
  final String? collectedBy;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.location,
    required this.address,
    required this.createdAt,
    this.isActive = true,
    this.isCollected = false,
    this.collectedBy,
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      address: data['address'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      isCollected: data['isCollected'] ?? false,
      collectedBy: data['collectedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'content': content,
      'location': location,
      'address': address,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'isCollected': isCollected,
      'collectedBy': collectedBy,
    };
  }

  PostModel copyWith({
    String? id,
    String? userId,
    String? content,
    GeoPoint? location,
    String? address,
    DateTime? createdAt,
    bool? isActive,
    bool? isCollected,
    String? collectedBy,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      location: location ?? this.location,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isCollected: isCollected ?? this.isCollected,
      collectedBy: collectedBy ?? this.collectedBy,
    );
  }
} 