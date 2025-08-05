import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String? id;
  final String? nickname;
  final String? address;
  final String? secondAddress;
  final String? phoneNumber;
  final String? email;
  final String? profileImageUrl;
  final String? account;
  final String? gender;
  final String? birth;
  final String? authority;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    this.id,
    this.nickname,
    this.address,
    this.secondAddress,
    this.phoneNumber,
    this.email,
    this.profileImageUrl,
    this.account,
    this.gender,
    this.birth,
    this.authority,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return UserModel();

    return UserModel(
      id: doc.id,
      nickname: data['nickname'],
      address: data['address'],
      secondAddress: data['secondAddress'],
      phoneNumber: data['phoneNumber'],
      email: data['email'],
      profileImageUrl: data['profileImageUrl'],
      account: data['account'],
      gender: data['gender'],
      birth: data['birth'],
      authority: data['authority'],
      createdAt: data['createdAt']?.toDate(),
      updatedAt: data['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'address': address,
      'secondAddress': secondAddress,
      'phoneNumber': phoneNumber,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'account': account,
      'gender': gender,
      'birth': birth,
      'authority': authority,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? id,
    String? nickname,
    String? address,
    String? secondAddress,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
    String? account,
    String? gender,
    String? birth,
    String? authority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      address: address ?? this.address,
      secondAddress: secondAddress ?? this.secondAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      account: account ?? this.account,
      gender: gender ?? this.gender,
      birth: birth ?? this.birth,
      authority: authority ?? this.authority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 