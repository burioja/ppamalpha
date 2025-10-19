import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/place/place_model.dart';

/// 장소 데이터 저장소
/// 
/// **책임**: Firebase 장소 데이터 통신
class PlacesRepository {
  final FirebaseFirestore _firestore;

  PlacesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== 조회 ====================

  /// 장소 ID로 조회
  Future<PlaceModel?> getPlaceById(String placeId) async {
    try {
      final doc = await _firestore
          .collection('places')
          .doc(placeId)
          .get();
      
      if (!doc.exists) return null;
      return PlaceModel.fromFirestore(doc);
    } catch (e) {
      print('❌ 장소 조회 실패: $e');
      return null;
    }
  }

  /// 사용자 장소 목록 스트리밍
  Stream<List<PlaceModel>> streamUserPlaces(String userId) {
    return _firestore
        .collection('places')
        .where('creatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    });
  }

  /// 건물명으로 검색
  Stream<List<PlaceModel>> searchPlacesByName(String query) {
    return _firestore
        .collection('places')
        .where('buildingName', isGreaterThanOrEqualTo: query)
        .where('buildingName', isLessThanOrEqualTo: '$query\uf8ff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    });
  }

  // ==================== 생성 ====================

  /// 장소 생성
  Future<String> createPlace(PlaceModel place) async {
    try {
      final docRef = await _firestore
          .collection('places')
          .add(place.toFirestore());
      
      return docRef.id;
    } catch (e) {
      print('❌ 장소 생성 실패: $e');
      rethrow;
    }
  }

  // ==================== 업데이트 ====================

  /// 장소 정보 업데이트
  Future<bool> updatePlace(String placeId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('places')
          .doc(placeId)
          .update(data);
      
      return true;
    } catch (e) {
      print('❌ 장소 업데이트 실패: $e');
      return false;
    }
  }

  /// 장소 통계 업데이트
  Future<bool> updatePlaceStats(
    String placeId,
    Map<String, dynamic> stats,
  ) async {
    try {
      await _firestore
          .collection('places')
          .doc(placeId)
          .update({
        'statistics': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('❌ 장소 통계 업데이트 실패: $e');
      return false;
    }
  }

  // ==================== 삭제 ====================

  /// 장소 삭제
  Future<bool> deletePlace(String placeId) async {
    try {
      await _firestore
          .collection('places')
          .doc(placeId)
          .delete();
      
      return true;
    } catch (e) {
      print('❌ 장소 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 통계 ====================

  /// 장소 방문 횟수 증가
  Future<bool> incrementVisitCount(String placeId) async {
    try {
      await _firestore
          .collection('places')
          .doc(placeId)
          .update({
        'statistics.visitCount': FieldValue.increment(1),
        'statistics.lastVisitedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      print('❌ 방문 횟수 업데이트 실패: $e');
      return false;
    }
  }

  /// 인기 장소 목록 조회
  Future<List<PlaceModel>> getPopularPlaces({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('places')
          .orderBy('statistics.visitCount', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ 인기 장소 조회 실패: $e');
      return [];
    }
  }
}

