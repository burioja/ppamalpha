import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackService {
  // Track ?Œë ˆ?´ìŠ¤ ê°œìˆ˜ ê°€?¸ì˜¤ê¸?(ëª¨ë“œë³??„í„°ë§?
  static Future<int> getTrackCount(String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      // print ¹® Á¦°ÅµÊ
      
      int modeCount = 0;
      for (var doc in trackSnapshot.docs) {
        final trackData = doc.data();
        final trackMode = trackData['mode'] ?? 'work'; // ê¸°ë³¸ê°’ì? work
        
        // print ¹® Á¦°ÅµÊ
        
        // ëª¨ë“œê°€ ?¼ì¹˜?˜ëŠ” ê²½ìš°ë§?ì¹´ìš´??
        if (trackMode == mode) {
          modeCount++;
        }
      }

      // print ¹® Á¦°ÅµÊ
      return modeCount;
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
      return 0;
    }
  }

  // ?Œë ˆ?´ìŠ¤ë¥??¸ë™?˜ê¸° (?¬ìš©?ì˜ ?Œë ˆ?´ìŠ¤ ?œë¸Œì»¬ë ‰?˜ì— ?±ë¡)
  static Future<bool> trackPlace(String placeId, String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following??ì¶”ê?
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

      // 2. ?¬ìš©?ì˜ ?Œë ˆ?´ìŠ¤ ?œë¸Œì»¬ë ‰?˜ì— ì¶”ê?
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .set({
        'mode': mode,
        'roleId': 'tracker',
        'roleName': '?¸ë˜ì»?,
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'permissions': ['view', 'track'],
      });

      // print ¹® Á¦°ÅµÊ
      return true;
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
      return false;
    }
  }

  // ?Œë ˆ?´ìŠ¤ ?¸ë™ ?´ì œ
  static Future<bool> untrackPlace(String placeId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following?ì„œ ?œê±°
      await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .doc(placeId)
          .delete();

      // 2. ?¬ìš©?ì˜ ?Œë ˆ?´ìŠ¤ ?œë¸Œì»¬ë ‰?˜ì—???œê±°
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .delete();

      // print ¹® Á¦°ÅµÊ
      return true;
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
      return false;
    }
  }

  // ?¹ì • ?Œë ˆ?´ìŠ¤ê°€ ?¸ë™ ì¤‘ì¸ì§€ ?•ì¸
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
      // print ¹® Á¦°ÅµÊ
      return false;
    }
  }
} 
