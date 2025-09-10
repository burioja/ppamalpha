import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/tile_utils.dart';

/// 타일 기반 방문 기록 관리 서비스
class VisitTileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'visits';

  /// 현재 위치의 타일 방문 기록 업데이트
  static Future<void> updateCurrentTileVisit(double latitude, double longitude) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final tileId = TileUtils.getTileId(latitude, longitude);
      final now = DateTime.now();
      
      // 30일 이전 데이터는 자동 삭제
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .collection('tiles')
          .doc(tileId)
          .set({
        'tileId': tileId,
        'lastVisit': Timestamp.fromDate(now),
        'fogLevel': 1, // 밝은 영역
        'latitude': latitude,
        'longitude': longitude,
      });

      // 30일 이전 데이터 정리
      await _cleanupOldVisits(user.uid, thirtyDaysAgo);
      
      print('타일 방문 기록 업데이트: $tileId');
    } catch (e) {
      print('타일 방문 기록 업데이트 실패: $e');
    }
  }

  /// 주변 타일들의 Fog Level 조회
  static Future<Map<String, int>> getSurroundingTilesFogLevel(
    double latitude, 
    double longitude
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final tileIds = TileUtils.getSurroundingTiles(latitude, longitude);
      final fogLevels = <String, int>{};
      
      // 각 타일의 방문 기록 조회
      for (final tileId in tileIds) {
        final doc = await _firestore
            .collection(_collection)
            .doc(user.uid)
            .collection('tiles')
            .doc(tileId)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final lastVisit = (data['lastVisit'] as Timestamp).toDate();
          final now = DateTime.now();
          final daysSinceVisit = now.difference(lastVisit).inDays;
          
          if (daysSinceVisit <= 7) {
            fogLevels[tileId] = 1; // 밝은 영역 (7일 이내)
          } else if (daysSinceVisit <= 30) {
            fogLevels[tileId] = 2; // 회색 영역 (30일 이내)
          } else {
            fogLevels[tileId] = 3; // 검은 영역 (30일 초과)
          }
        } else {
          fogLevels[tileId] = 3; // 방문 기록 없음 = 검은 영역
        }
      }
      
      return fogLevels;
    } catch (e) {
      print('타일 Fog Level 조회 실패: $e');
      return {};
    }
  }

  /// 30일 이전 방문 기록 정리
  static Future<void> _cleanupOldVisits(String userId, DateTime cutoffDate) async {
    try {
      final oldVisits = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('tiles')
          .where('lastVisit', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldVisits.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldVisits.docs.isNotEmpty) {
        await batch.commit();
        print('오래된 방문 기록 ${oldVisits.docs.length}개 정리 완료');
      }
    } catch (e) {
      print('오래된 방문 기록 정리 실패: $e');
    }
  }

  /// 특정 타일의 방문 기록 조회
  static Future<int> getTileFogLevel(String tileId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 3; // 로그인 안됨 = 검은 영역

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .collection('tiles')
          .doc(tileId)
          .get();
      
      if (!doc.exists) return 3; // 방문 기록 없음 = 검은 영역
      
      final data = doc.data()!;
      final lastVisit = (data['lastVisit'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceVisit = now.difference(lastVisit).inDays;
      
      if (daysSinceVisit <= 7) return 1; // 밝은 영역
      if (daysSinceVisit <= 30) return 2; // 회색 영역
      return 3; // 검은 영역
    } catch (e) {
      print('타일 Fog Level 조회 실패: $e');
      return 3; // 에러 시 검은 영역
    }
  }

  /// 특정 타일의 Fog Level 조회 (동기 버전)
  static Future<int> getFogLevelForTile(String tileId) async {
    return await getTileFogLevel(tileId);
  }
}
