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
  
  // 새로운 필드들
  final int price;
  final int amount;
  final int period;
  final String periodUnit;
  final String function;
  final String target;
  final int ageMin;
  final int ageMax;

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
    this.price = 0,
    this.amount = 0,
    this.period = 24,
    this.periodUnit = 'Hour',
    this.function = 'Using',
    this.target = '상관없음',
    this.ageMin = 20,
    this.ageMax = 30,
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
      price: data['price'] ?? 0,
      amount: data['amount'] ?? 0,
      period: data['period'] ?? 24,
      periodUnit: data['periodUnit'] ?? 'Hour',
      function: data['function'] ?? 'Using',
      target: data['target'] ?? '상관없음',
      ageMin: data['ageMin'] ?? 20,
      ageMax: data['ageMax'] ?? 30,
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
      'price': price,
      'amount': amount,
      'period': period,
      'periodUnit': periodUnit,
      'function': function,
      'target': target,
      'ageMin': ageMin,
      'ageMax': ageMax,
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
    int? price,
    int? amount,
    int? period,
    String? periodUnit,
    String? function,
    String? target,
    int? ageMin,
    int? ageMax,
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
      price: price ?? this.price,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      periodUnit: periodUnit ?? this.periodUnit,
      function: function ?? this.function,
      target: target ?? this.target,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
    );
  }
} 