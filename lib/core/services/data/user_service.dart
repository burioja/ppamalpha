import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ?ÑÏû¨ ?¨Ïö©??ID Í∞Ä?∏Ïò§Í∏?
  String? get currentUserId => _auth.currentUser?.uid;

  // ?¨Ïö©???ÑÎ°ú??Ïª¨Î†â??Ï∞∏Ï°∞
  DocumentReference<Map<String, dynamic>> get _userProfileDoc {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('profile')
        .doc('info');
  }

  // ?¨Ïö©???ÑÎ°ú??Í∞Ä?∏Ïò§Í∏?
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfile() {
    return _userProfileDoc.snapshots();
  }

  // ?¨Ïö©???ÑÎ°ú???ùÏÑ±/?ÖÎç∞?¥Ìä∏
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
    if (currentUserId == null) throw Exception('?¨Ïö©?êÍ? Î°úÍ∑∏?∏ÎêòÏßÄ ?äÏïò?µÎãà??');

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

    // createdAt???ÜÏúºÎ©?Ï∂îÍ?
    final doc = await _userProfileDoc.get();
    if (!doc.exists) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    await _userProfileDoc.set(updates, SetOptions(merge: true));
  }

  // ?¨Ïö©???âÎÑ§??Í∞Ä?∏Ïò§Í∏?
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

  // ?¨Ïö©??Í∂åÌïú Í∞Ä?∏Ïò§Í∏?(workplaces Ïª¨Î†â?òÏóê??
  Future<String?> getUserAuthority() async {
    try {
      final workplacesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('workplaces')
          .get();
      
      if (workplacesSnapshot.docs.isNotEmpty) {
        // Ï≤?Î≤àÏß∏ workplace??role??Î∞òÌôò
        return workplacesSnapshot.docs.first.data()['role'];
      }
      return 'User'; // Í∏∞Î≥∏Í∞?
    } catch (e) {
      return 'User';
    }
  }

  // ?¨Ïö©???µÍ≥Ñ Í∞Ä?∏Ïò§Í∏?
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      // ?§Ï?Ï§??µÍ≥Ñ
      final schedulesSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('schedules')
          .get();
      
      final totalSchedules = schedulesSnapshot.docs.length;
      final completedSchedules = schedulesSnapshot.docs
          .where((doc) => doc.data()['isCompleted'] == true)
          .length;
      
      // ?îÎ°ú????
      final followingSnapshot = await _firestore
          .collection('user_tracks')
          .doc(currentUserId)
          .collection('following')
          .get();
      
      final followingCount = followingSnapshot.docs.length;
      
      // Ïª§ÎÑ•????
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
