import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 타일 Firebase Datasource
/// 
/// **책임**: Firebase SDK 직접 호출만 담당
/// **원칙**: 순수 CRUD만, 비즈니스 로직 없음
abstract class TilesFirebaseDataSource {
  Future<void> setVisit(String userId, String tileId, Map<String, dynamic> data);
  Future<DocumentSnapshot> getVisit(String userId, String tileId);
  Stream<QuerySnapshot> streamVisits(String userId);
  Future<void> batchSetVisits(String userId, Map<String, Map<String, dynamic>> visits);
  Future<QuerySnapshot> getVisitsBefore(String userId, DateTime date);
  Future<void> deleteVisit(String userId, String tileId);
}

/// 타일 Firebase Datasource 구현
class TilesFirebaseDataSourceImpl implements TilesFirebaseDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TilesFirebaseDataSourceImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// 사용자 타일 컬렉션 참조
  CollectionReference<Map<String, dynamic>> _tilesCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('visitedTiles');
  }

  @override
  Future<void> setVisit(
    String userId,
    String tileId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _tilesCollection(userId)
          .doc(tileId)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      print('❌ Datasource: 타일 방문 기록 실패: $e');
      rethrow;
    }
  }

  @override
  Future<DocumentSnapshot> getVisit(String userId, String tileId) async {
    try {
      return await _tilesCollection(userId).doc(tileId).get();
    } catch (e) {
      print('❌ Datasource: 타일 조회 실패: $e');
      rethrow;
    }
  }

  @override
  Stream<QuerySnapshot> streamVisits(String userId) {
    return _tilesCollection(userId).snapshots();
  }

  @override
  Future<void> batchSetVisits(
    String userId,
    Map<String, Map<String, dynamic>> visits,
  ) async {
    try {
      final batch = _firestore.batch();
      final collection = _tilesCollection(userId);

      for (final entry in visits.entries) {
        final docRef = collection.doc(entry.key);
        batch.set(docRef, entry.value, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('❌ Datasource: 배치 타일 기록 실패: $e');
      rethrow;
    }
  }

  @override
  Future<QuerySnapshot> getVisitsBefore(String userId, DateTime date) async {
    try {
      return await _tilesCollection(userId)
          .where('lastVisitedAt', isLessThan: Timestamp.fromDate(date))
          .get();
    } catch (e) {
      print('❌ Datasource: 타일 조회 (날짜) 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteVisit(String userId, String tileId) async {
    try {
      await _tilesCollection(userId).doc(tileId).delete();
    } catch (e) {
      print('❌ Datasource: 타일 삭제 실패: $e');
      rethrow;
    }
  }
}

