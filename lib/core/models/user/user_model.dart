import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType {
  normal,      // 일반사용자
  superSite,   // 수퍼사이트 유료구독
}

class UserModel {
  final String? id;
  final String? nickname;
  final String? address;
  final String? secondAddress;
  final GeoPoint? homeLocation;  // 집 좌표 (주소 geocoding 결과 저장)
  final String? phoneNumber;
  final String? email;
  final String? profileImageUrl;
  final String? account;
  final String? gender;
  final String? birth;
  final String? authority;
  final UserType userType;  // 사용자 타입 추가
  final String? workplaceId;  // 일터 플레이스 ID (단일값)
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    this.id,
    this.nickname,
    this.address,
    this.secondAddress,
    this.homeLocation,
    this.phoneNumber,
    this.email,
    this.profileImageUrl,
    this.account,
    this.gender,
    this.birth,
    this.authority,
    this.userType = UserType.normal,  // 기본값은 일반사용자
    this.workplaceId,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return UserModel();

    // 사용자 타입 파싱
    UserType userType = UserType.normal;
    if (data['userType'] != null) {
      switch (data['userType']) {
        case 'superSite':
          userType = UserType.superSite;
          break;
        case 'normal':
        default:
          userType = UserType.normal;
          break;
      }
    }

    return UserModel(
      id: doc.id,
      nickname: data['nickname'],
      address: data['address'],
      secondAddress: data['secondAddress'],
      homeLocation: data['homeLocation'],
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      profileImageUrl: data['profileImageUrl'],
      account: data['account'],
      gender: data['gender'],
      birth: data['birth'],
      authority: data['authority'],
      userType: userType,
      workplaceId: data['workplaceId'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'address': address,
      'secondAddress': secondAddress,
      'homeLocation': homeLocation,
      'phoneNumber': phoneNumber,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'account': account,
      'gender': gender,
      'birth': birth,
      'authority': authority,
      'userType': userType.name,  // 사용자 타입 추가
      'workplaceId': workplaceId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? nickname,
    String? address,
    String? secondAddress,
    GeoPoint? homeLocation,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
    String? account,
    String? gender,
    String? birth,
    String? authority,
    UserType? userType,
    String? workplaceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      address: address ?? this.address,
      secondAddress: secondAddress ?? this.secondAddress,
      homeLocation: homeLocation ?? this.homeLocation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      account: account ?? this.account,
      gender: gender ?? this.gender,
      birth: birth ?? this.birth,
      authority: authority ?? this.authority,
      userType: userType ?? this.userType,
      workplaceId: workplaceId ?? this.workplaceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 