import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackService {
  // Track ?�레?�스 개수 가?�오�?(모드�??�터�?
  static Future<int> getTrackCount(String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      // print �� ���ŵ�
      
      int modeCount = 0;
      for (var doc in trackSnapshot.docs) {
        final trackData = doc.data();
        final trackMode = trackData['mode'] ?? 'work'; // 기본값�? work
        
        // print �� ���ŵ�
        
        // 모드가 ?�치?�는 경우�?카운??
        if (trackMode == mode) {
          modeCount++;
        }
      }

      // print �� ���ŵ�
      return modeCount;
    } catch (e) {
      // print �� ���ŵ�
      return 0;
    }
  }

  // ?�레?�스�??�랙?�기 (?�용?�의 ?�레?�스 ?�브컬렉?�에 ?�록)
  static Future<bool> trackPlace(String placeId, String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following??추�?
      await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .doc(placeId)
          .set({
        'placeId': placeId,
        'mode': mode,
        'trackedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 2. ?�용?�의 ?�레?�스 ?�브컬렉?�에 추�?
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .set({
        'mode': mode,
        'roleId': 'tracker',
        'roleName': '?�래�?,
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'permissions': ['view', 'track'],
      });

      // print �� ���ŵ�
      return true;
    } catch (e) {
      // print �� ���ŵ�
      return false;
    }
  }

  // ?�레?�스 ?�랙 ?�제
  static Future<bool> untrackPlace(String placeId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following?�서 ?�거
      await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .doc(placeId)
          .delete();

      // 2. ?�용?�의 ?�레?�스 ?�브컬렉?�에???�거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .delete();

      // print �� ���ŵ�
      return true;
    } catch (e) {
      // print �� ���ŵ�
      return false;
    }
  }

  // ?�정 ?�레?�스가 ?�랙 중인지 ?�인
  static Future<bool> isTracked(String placeId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .doc(placeId)
          .get();

      return doc.exists;
    } catch (e) {
      // print �� ���ŵ�
      return false;
    }
  }
} 
