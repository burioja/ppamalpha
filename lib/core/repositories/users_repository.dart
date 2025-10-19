import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user/user_model.dart';
import '../models/user/user_points_model.dart';

/// 사용자 데이터 저장소
/// 
/// **책임**: Firebase 사용자 데이터 통신
class UsersRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UsersRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==================== 조회 ====================

  /// 사용자 정보 조회
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      print('❌ 사용자 조회 실패: $e');
      return null;
    }
  }

  /// 현재 사용자 정보 스트리밍
  Stream<UserModel?> streamCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    });
  }

  /// 사용자 포인트 조회
  Future<UserPointsModel?> getUserPoints(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('points')
          .doc('current')
          .get();
      
      if (!doc.exists) return null;
      return UserPointsModel.fromFirestore(doc);
    } catch (e) {
      print('❌ 포인트 조회 실패: $e');
      return null;
    }
  }

  /// 사용자 포인트 스트리밍
  Stream<UserPointsModel?> streamUserPoints(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('points')
        .doc('current')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserPointsModel.fromFirestore(doc);
    });
  }

  // ==================== 업데이트 ====================

  /// 사용자 정보 업데이트
  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update(data);
      
      return true;
    } catch (e) {
      print('❌ 사용자 업데이트 실패: $e');
      return false;
    }
  }

  /// 사용자 프로필 이미지 업데이트
  Future<bool> updateProfileImage(String userId, String imageUrl) async {
    return await updateUser(userId, {'profileImageUrl': imageUrl});
  }

  /// 사용자 타입 업데이트
  Future<bool> updateUserType(String userId, UserType userType) async {
    return await updateUser(userId, {'userType': userType.toString()});
  }

  // ==================== 포인트 ====================

  /// 포인트 증가
  Future<bool> addPoints(String userId, int amount) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('points')
          .doc('current')
          .update({
        'totalPoints': FieldValue.increment(amount),
      });
      
      return true;
    } catch (e) {
      print('❌ 포인트 증가 실패: $e');
      return false;
    }
  }

  /// 포인트 감소
  Future<bool> deductPoints(String userId, int amount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final pointsRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('points')
            .doc('current');

        final snapshot = await transaction.get(pointsRef);
        
        if (!snapshot.exists) {
          throw Exception('포인트 정보를 찾을 수 없습니다');
        }

        final currentPoints = snapshot.data()?['totalPoints'] ?? 0;
        
        if (currentPoints < amount) {
          throw Exception('포인트가 부족합니다');
        }

        transaction.update(pointsRef, {
          'totalPoints': currentPoints - amount,
        });
      });
      
      return true;
    } catch (e) {
      print('❌ 포인트 차감 실패: $e');
      return false;
    }
  }

  // ==================== 위치 ====================

  /// 집 위치 업데이트
  Future<bool> updateHomeLocation(
    String userId,
    double latitude,
    double longitude,
  ) async {
    return await updateUser(userId, {
      'homeLocation': GeoPoint(latitude, longitude),
    });
  }

  /// 일터 추가
  Future<String?> addWorkplace({
    required String userId,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('workplaces')
          .add({
        'name': name,
        'location': GeoPoint(latitude, longitude),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      return docRef.id;
    } catch (e) {
      print('❌ 일터 추가 실패: $e');
      return null;
    }
  }

  /// 일터 목록 조회
  Stream<List<Map<String, dynamic>>> streamWorkplaces(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('workplaces')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}

