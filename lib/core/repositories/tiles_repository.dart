import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/map/fog_level.dart';

import '../datasources/firebase/tiles_firebase_ds.dart';

/// 타일 데이터 저장소
/// 
/// **책임**: 타일 데이터 접근 로직
/// **TODO**: Datasource 완전 전환 필요
class TilesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TilesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==================== 방문 기록 ====================

  /// 타일 방문 기록 업데이트 (Idempotent)
  /// 
  /// [tileId]: 방문한 타일 ID
  /// Returns: 성공 여부
  Future<bool> updateVisit(String tileId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ 사용자가 로그인되지 않음');
        return false;
      }

      final visitRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles')
          .doc(tileId);

      // 이미 기록이 있는지 확인
      final doc = await visitRef.get();
      
      if (!doc.exists) {
        // 새로운 방문 기록
        await visitRef.set({
          'tileId': tileId,
          'firstVisitedAt': FieldValue.serverTimestamp(),
          'lastVisitedAt': FieldValue.serverTimestamp(),
          'visitCount': 1,
        });
      } else {
        // 기존 방문 기록 업데이트
        await visitRef.update({
          'lastVisitedAt': FieldValue.serverTimestamp(),
          'visitCount': FieldValue.increment(1),
        });
      }

      return true;
    } catch (e) {
      print('❌ 타일 방문 기록 실패: $e');
      return false;
    }
  }

  /// 최근 30일 방문한 타일 ID 목록 조회
  /// 
  /// Returns: 타일 ID 목록
  Future<Set<String>> getVisitedTilesLast30Days() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles')
          .where('lastVisitedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('❌ 방문 타일 조회 실패: $e');
      return {};
    }
  }

  /// 모든 방문한 타일 ID 조회 (Level 1용)
  /// 
  /// Returns: 타일 ID 목록
  Future<Set<String>> getAllVisitedTiles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('❌ 전체 방문 타일 조회 실패: $e');
      return {};
    }
  }

  // ==================== 타일 메타데이터 ====================

  /// 특정 타일의 방문 정보 조회
  /// 
  /// [tileId]: 타일 ID
  /// Returns: 방문 정보 맵 (visitCount, firstVisitedAt, lastVisitedAt)
  Future<Map<String, dynamic>?> getTileVisitInfo(String tileId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles')
          .doc(tileId)
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      print('❌ 타일 정보 조회 실패: $e');
      return null;
    }
  }

  // ==================== 배치 작업 ====================

  /// 여러 타일 일괄 방문 기록
  /// 
  /// [tileIds]: 타일 ID 목록
  Future<void> batchUpdateVisits(List<String> tileIds) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final batch = _firestore.batch();
      final collectionRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles');

      for (final tileId in tileIds) {
        final docRef = collectionRef.doc(tileId);
        batch.set(
          docRef,
          {
            'tileId': tileId,
            'lastVisitedAt': FieldValue.serverTimestamp(),
            'visitCount': FieldValue.increment(1),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } catch (e) {
      print('❌ 배치 타일 방문 기록 실패: $e');
    }
  }

  // ==================== 프리패치 ====================

  /// 타일 프리패치 (다음 이동 예상 타일)
  /// 
  /// [tileIds]: 프리패치할 타일 ID 목록
  Future<Map<String, bool>> prefetchTiles(List<String> tileIds) async {
    final result = <String, bool>{};

    try {
      final user = _auth.currentUser;
      if (user == null) return result;

      final collectionRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles');

      // 배치로 존재 여부 확인
      for (final tileId in tileIds) {
        final doc = await collectionRef.doc(tileId).get();
        result[tileId] = doc.exists;
      }

      return result;
    } catch (e) {
      print('❌ 타일 프리패치 실패: $e');
      return result;
    }
  }

  // ==================== 정리 ====================

  /// 오래된 방문 기록 삭제 (90일 이상)
  Future<int> evictOldTiles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visitedTiles')
          .where('lastVisitedAt', isLessThan: ninetyDaysAgo)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ 오래된 타일 정리 실패: $e');
      return 0;
    }
  }
}

