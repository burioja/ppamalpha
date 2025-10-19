import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/marker/marker_model.dart';

/// 마커 Firebase Datasource
/// 
/// **책임**: Firebase SDK 직접 호출만 담당
/// **원칙**: 
/// - 비즈니스 로직 없음
/// - 순수 CRUD만
/// - Repository에서만 호출됨
abstract class MarkersFirebaseDataSource {
  Stream<List<MarkerModel>> streamByTileIds(List<String> tileIds);
  Future<MarkerModel?> getById(String markerId);
  Future<String> create(Map<String, dynamic> data);
  Future<void> update(String markerId, Map<String, dynamic> data);
  Future<void> delete(String markerId);
  Future<void> decreaseQuantity(String markerId, int amount);
  Stream<List<MarkerModel>> streamByUserId(String userId);
}

/// 마커 Firebase Datasource 구현
class MarkersFirebaseDataSourceImpl implements MarkersFirebaseDataSource {
  final FirebaseFirestore _firestore;

  MarkersFirebaseDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<MarkerModel>> streamByTileIds(List<String> tileIds) {
    if (tileIds.isEmpty) {
      return Stream.value([]);
    }

    Query query = _firestore.collection('markers');
    
    // whereIn은 최대 10개까지
    if (tileIds.length <= 10) {
      query = query.where('tileId', whereIn: tileIds);
    } else {
      query = query.where('tileId', whereIn: tileIds.take(10).toList());
    }
    
    query = query.where('quantity', isGreaterThan: 0);
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MarkerModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<MarkerModel?> getById(String markerId) async {
    try {
      final doc = await _firestore
          .collection('markers')
          .doc(markerId)
          .get();
      
      if (!doc.exists) return null;
      return MarkerModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Datasource: 마커 조회 실패: $e');
      rethrow;
    }
  }

  @override
  Stream<List<MarkerModel>> streamByUserId(String userId) {
    return _firestore
        .collection('markers')
        .where('creatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MarkerModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<String> create(Map<String, dynamic> data) async {
    try {
      final docRef = await _firestore
          .collection('markers')
          .add(data);
      
      return docRef.id;
    } catch (e) {
      print('❌ Datasource: 마커 생성 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> update(String markerId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('markers')
          .doc(markerId)
          .update(data);
    } catch (e) {
      print('❌ Datasource: 마커 업데이트 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> delete(String markerId) async {
    try {
      await _firestore
          .collection('markers')
          .doc(markerId)
          .delete();
    } catch (e) {
      print('❌ Datasource: 마커 삭제 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> decreaseQuantity(String markerId, int amount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection('markers').doc(markerId);
        final snapshot = await transaction.get(docRef);
        
        if (!snapshot.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }
        
        final currentQuantity = snapshot.data()?['quantity'] ?? 0;
        final newQuantity = currentQuantity - amount;
        
        if (newQuantity < 0) {
          throw Exception('수량이 부족합니다');
        }
        
        transaction.update(docRef, {'quantity': newQuantity});
      });
    } catch (e) {
      print('❌ Datasource: 수량 감소 실패: $e');
      rethrow;
    }
  }
}

