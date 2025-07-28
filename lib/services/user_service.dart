import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 ID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 사용자 프로필 컬렉션 참조
  DocumentReference<Map<String, dynamic>> get _userProfileDoc {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('profile')
        .doc('info');
  }

  // 사용자 프로필 가져오기
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfile() {
    return _userProfileDoc.snapshots();
  }

  // 사용자 프로필 생성/업데이트
  Future<void> updateUserProfile({
    String? nickname,
    String? address,
    String? secondAddress,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
    String? account,
    String? gender,
    String? birth,
  }) async {
    if (currentUserId == null) throw Exception('사용자가 로그인되지 않았습니다.');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nickname != null) updates['nickname'] = nickname;
    if (address != null) updates['address'] = address;
    if (secondAddress != null) updates['secondAddress'] = secondAddress;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (email != null) updates['email'] = email;
    if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;
    if (account != null) updates['account'] = account;
    if (gender != null) updates['gender'] = gender;
    if (birth != null) updates['birth'] = birth;

    // createdAt이 없으면 추가
    final doc = await _userProfileDoc.get();
    if (!doc.exists) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    await _userProfileDoc.set(updates, SetOptions(merge: true));
  }

  // 사용자 닉네임 가져오기
  Future<String?> getNickname() async {
    try {
      final doc = await _userProfileDoc.get();
      if (doc.exists) {
        return doc.data()?['nickname'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 사용자 권한 가져오기 (workplaces 컬렉션에서)
  Future<String?> getUserAuthority() async {
    try {
      final workplacesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('workplaces')
          .get();
      
      if (workplacesSnapshot.docs.isNotEmpty) {
        // 첫 번째 workplace의 role을 반환
        return workplacesSnapshot.docs.first.data()['role'];
      }
      return 'User'; // 기본값
    } catch (e) {
      return 'User';
    }
  }

  // 사용자 통계 가져오기
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      // 스케줄 통계
      final schedulesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('schedules')
          .get();
      
      final totalSchedules = schedulesSnapshot.docs.length;
      final completedSchedules = schedulesSnapshot.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;
      
      // 팔로잉 수
      final followingSnapshot = await _firestore
          .collection('user_tracks')
          .doc(currentUserId)
          .collection('following')
          .get();
      
      final followingCount = followingSnapshot.docs.length;
      
      // 커넥션 수
      final connectionsSnapshot = await _firestore
          .collection('user_connections')
          .doc(currentUserId)
          .collection('connections')
          .get();
      
      final connectionsCount = connectionsSnapshot.docs.length;
      
      return {
        'totalSchedules': totalSchedules,
        'completedSchedules': completedSchedules,
        'followingCount': followingCount,
        'connectionsCount': connectionsCount,
      };
    } catch (e) {
      return {
        'totalSchedules': 0,
        'completedSchedules': 0,
        'followingCount': 0,
        'connectionsCount': 0,
      };
    }
  }
} 