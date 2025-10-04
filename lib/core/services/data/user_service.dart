import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ?�재 ?�용??ID 가?�오�?
  String? get currentUserId => _auth.currentUser?.uid;

  // ?�용???�로??컬렉??참조
  DocumentReference<Map<String, dynamic>> get _userProfileDoc {
    return _firestore
        .collection('users')
        .doc(currentUserId);
  }

  // ?�용???�로??가?�오�?
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfile() {
    return _userProfileDoc.snapshots();
  }

  // ?�용???�로???�성/?�데?�트
  Future<String?> updateUserProfile({
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
    if (currentUserId == null) throw Exception('?�용?��? 로그?�되지 ?�았?�니??');

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (nickname != null) updates['nickname'] = nickname;
    if (address != null) updates['address'] = address;
    if (secondAddress != null) updates['secondAddress'] = secondAddress;
    if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
    if (email != null) updates['email'] = email;
    if (profileImageUrl != null) {
      updates['profileImageUrl'] = profileImageUrl;
      print('🔥 UserService: Updating profileImageUrl to: $profileImageUrl');
      print('🔥 UserService: Document path: users/$currentUserId');
    }
    if (account != null) updates['account'] = account;
    if (gender != null) updates['gender'] = gender;
    if (birth != null) updates['birth'] = birth;

    // createdAt???�으�?추�?
    final doc = await _userProfileDoc.get();
    if (!doc.exists) {
      updates['createdAt'] = FieldValue.serverTimestamp();
      print('🔥 UserService: Creating new document');
    }

    await _userProfileDoc.set(updates, SetOptions(merge: true));

    // 업데이트 후 바로 확인
    if (profileImageUrl != null) {
      final verifyDoc = await _userProfileDoc.get();
      final savedUrl = verifyDoc.data()?['profileImageUrl'];
      print('🔥 UserService: Verified saved URL: $savedUrl');
      return savedUrl;
    }
    return null;
  }

  // ?�용???�네??가?�오�?
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

  // ?�용??권한 가?�오�?(workplaces 컬렉?�에??
  Future<String?> getUserAuthority() async {
    try {
      final workplacesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('workplaces')
          .get();
      
      if (workplacesSnapshot.docs.isNotEmpty) {
        // �?번째 workplace??role??반환
        return workplacesSnapshot.docs.first.data()['role'];
      }
      return 'User'; // 기본�?
    } catch (e) {
      return 'User';
    }
  }

  // ?�용???�계 가?�오�?
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      // ?��?�??�계
      final schedulesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('schedules')
          .get();
      
      final totalSchedules = schedulesSnapshot.docs.length;
      final completedSchedules = schedulesSnapshot.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;
      
      // ?�로????
      final followingSnapshot = await _firestore
          .collection('user_tracks')
          .doc(currentUserId)
          .collection('following')
          .get();
      
      final followingCount = followingSnapshot.docs.length;
      
      // 커넥????
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
