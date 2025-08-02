import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackService {
  // Track 플레이스 개수 가져오기 (모드별 필터링)
  static Future<int> getTrackCount(String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      print('Track 개수 계산 - 문서 개수: ${trackSnapshot.docs.length}');
      
      int modeCount = 0;
      for (var doc in trackSnapshot.docs) {
        final trackData = doc.data();
        final trackMode = trackData['mode'] ?? 'work'; // 기본값은 work
        
        print('Track 문서 ID: ${doc.id}, 모드: $trackMode, 데이터: $trackData');
        
        // 모드가 일치하는 경우만 카운트
        if (trackMode == mode) {
          modeCount++;
        }
      }

      print('$mode 모드 Track 개수: $modeCount');
      return modeCount;
    } catch (e) {
      print('Track 개수 로드 오류: $e');
      return 0;
    }
  }

  // 플레이스를 트랙하기 (사용자의 플레이스 서브컬렉션에 등록)
  static Future<bool> trackPlace(String placeId, String mode) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following에 추가
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

      // 2. 사용자의 플레이스 서브컬렉션에 추가
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .set({
        'mode': mode,
        'roleId': 'tracker',
        'roleName': '트래커',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'permissions': ['view', 'track'],
      });

      print('플레이스 $placeId를 $mode 모드로 트랙했습니다.');
      return true;
    } catch (e) {
      print('플레이스 트랙 오류: $e');
      return false;
    }
  }

  // 플레이스 트랙 해제
  static Future<bool> untrackPlace(String placeId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 1. user_tracks/following에서 제거
      await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .doc(placeId)
          .delete();

      // 2. 사용자의 플레이스 서브컬렉션에서 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc(placeId)
          .delete();

      print('플레이스 $placeId 트랙을 해제했습니다.');
      return true;
    } catch (e) {
      print('플레이스 트랙 해제 오류: $e');
      return false;
    }
  }

  // 특정 플레이스가 트랙 중인지 확인
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
      print('트랙 상태 확인 오류: $e');
      return false;
    }
  }
} 