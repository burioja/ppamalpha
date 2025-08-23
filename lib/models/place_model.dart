import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name;
  final String description;
  final String? address;
  final GeoPoint? location;
  final String? category;
  final String? subCategory;
  final String? subSubCategory;
  final List<String> imageUrls;
  final Map<String, dynamic>? operatingHours;
  final Map<String, dynamic>? contactInfo;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final Map<String, dynamic>? originalData;

  PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    this.address,
    this.location,
    this.category,
    this.subCategory,
    this.subSubCategory,
    this.imageUrls = const [],
    this.operatingHours,
    this.contactInfo,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.originalData,
  });

  factory PlaceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return PlaceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      address: data['address'],
      location: data['location'],
      category: data['category'],
      subCategory: data['subCategory'],
      subSubCategory: data['subSubCategory'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      operatingHours: data['operatingHours'],
      contactInfo: data['contactInfo'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt']?.toDate(),
      isActive: data['isActive'] ?? true,
      originalData: data['originalData'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'location': location,
      'category': category,
      'subCategory': subCategory,
      'subSubCategory': subSubCategory,
      'imageUrls': imageUrls,
      'operatingHours': operatingHours,
      'contactInfo': contactInfo,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isActive': isActive,
      'originalData': originalData,
    };
  }

  PlaceModel copyWith({
    String? id,
    String? name,
    String? description,
    String? address,
    GeoPoint? location,
    String? category,
    String? subCategory,
    String? subSubCategory,
    List<String>? imageUrls,
    Map<String, dynamic>? operatingHours,
    Map<String, dynamic>? contactInfo,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    Map<String, dynamic>? originalData,
  }) {
    return PlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      location: location ?? this.location,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      subSubCategory: subSubCategory ?? this.subSubCategory,
      imageUrls: imageUrls ?? this.imageUrls,
      operatingHours: operatingHours ?? this.operatingHours,
      contactInfo: contactInfo ?? this.contactInfo,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      originalData: originalData ?? this.originalData,
    );
  }

  // 카테고리 전체 경로 반환
  String get fullCategoryPath {
    List<String> categories = [];
    if (category != null) categories.add(category!);
    if (subCategory != null) categories.add(subCategory!);
    if (subSubCategory != null) categories.add(subSubCategory!);
    return categories.join(' - ');
  }

  // 위치 정보가 있는지 확인
  bool get hasLocation => location != null;

  // 이미지가 있는지 확인
  bool get hasImages => imageUrls.isNotEmpty;

  // 운영 시간이 설정되어 있는지 확인
  bool get hasOperatingHours => operatingHours != null && operatingHours!.isNotEmpty;

  // 연락처 정보가 있는지 확인
  bool get hasContactInfo => contactInfo != null && contactInfo!.isNotEmpty;
}




