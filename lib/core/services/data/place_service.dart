import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/place/place_model.dart';

class PlaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'places';

  // 플레이스 생성
  Future<String> createPlace(PlaceModel place) async {
    try {
      // isVerified는 호출하는 곳에서 명시적으로 설정
      DocumentReference docRef = await _firestore.collection(_collection).add(place.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('플레이스 생성 실패: $e');
    }
  }

  // 플레이스 수정
  Future<void> updatePlace(String placeId, PlaceModel place) async {
    try {
      await _firestore.collection(_collection).doc(placeId).update(place.toFirestore());
    } catch (e) {
      throw Exception('플레이스 수정 실패: $e');
    }
  }

  // 플레이스 삭제
  Future<void> deletePlace(String placeId) async {
    try {
      await _firestore.collection(_collection).doc(placeId).delete();
    } catch (e) {
      throw Exception('플레이스 삭제 실패: $e');
    }
  }

  // 플레이스 조회 (ID로)
  Future<PlaceModel?> getPlaceById(String placeId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(placeId).get();
      if (doc.exists) {
        return PlaceModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('플레이스 조회 실패: $e');
    }
  }

  // getPlace 메서드 (getPlaceById의 별칭)
  Future<PlaceModel?> getPlace(String placeId) async {
    return await getPlaceById(placeId);
  }

  // 사용자가 생성한 플레이스 목록 조회
  Future<List<PlaceModel>> getPlacesByUser(String userId) async {
    try {
      // 인덱스 없이 작동하도록 쿼리 단순화
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('createdBy', isEqualTo: userId)
          .get();

      // 클라이언트에서 필터링 및 정렬
      List<PlaceModel> places = querySnapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .where((place) => place.isActive) // 활성 플레이스만 필터링
          .toList();
      
      // 생성일 기준으로 정렬 (최신순)
      places.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return places;
    } catch (e) {
      throw Exception('사용자 플레이스 조회 실패: $e');
    }
  }

  // 카테고리별 플레이스 조회
  Future<List<PlaceModel>> getPlacesByCategory(String category) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('카테고리별 플레이스 조회 실패: $e');
    }
  }

  // 위치 기반 플레이스 조회 (반경 내)
  Future<List<PlaceModel>> getPlacesByLocation(GeoPoint center, double radiusKm) async {
    try {
      // Firestore의 GeoPoint 쿼리 제한으로 인해 클라이언트에서 필터링
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      List<PlaceModel> places = querySnapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .where((place) => place.hasLocation)
          .where((place) => _isWithinRadius(center, place.location!, radiusKm))
          .toList();

      return places;
    } catch (e) {
      throw Exception('위치 기반 플레이스 조회 실패: $e');
    }
  }

  // 플레이스 검색 (이름, 설명 기반)
  Future<List<PlaceModel>> searchPlaces(String query) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      List<PlaceModel> places = querySnapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .where((place) =>
              place.name.toLowerCase().contains(query.toLowerCase()) ||
              place.description.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return places;
    } catch (e) {
      throw Exception('플레이스 검색 실패: $e');
    }
  }

  // 모든 활성 플레이스 조회
  Future<List<PlaceModel>> getAllActivePlaces() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('활성 플레이스 조회 실패: $e');
    }
  }

  // 플레이스 이미지 추가
  Future<void> addPlaceImage(String placeId, String imageUrl) async {
    try {
      await _firestore.collection(_collection).doc(placeId).update({
        'imageUrls': FieldValue.arrayUnion([imageUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('이미지 추가 실패: $e');
    }
  }

  // 플레이스 이미지 제거
  Future<void> removePlaceImage(String placeId, String imageUrl) async {
    try {
      await _firestore.collection(_collection).doc(placeId).update({
        'imageUrls': FieldValue.arrayRemove([imageUrl]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('이미지 제거 실패: $e');
    }
  }

  // 플레이스 활성화/비활성화
  Future<void> togglePlaceActive(String placeId, bool isActive) async {
    try {
      await _firestore.collection(_collection).doc(placeId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('플레이스 상태 변경 실패: $e');
    }
  }

  // 거리 계산 헬퍼 메서드
  bool _isWithinRadius(GeoPoint center, GeoPoint point, double radiusKm) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _degreesToRadians(point.latitude - center.latitude);
    final double dLon = _degreesToRadians(point.longitude - center.longitude);
    
    final double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _sin(_degreesToRadians(center.latitude)) * _sin(_degreesToRadians(point.latitude)) * 
        _sin(dLon / 2) * _sin(dLon / 2);
    final double c = 2 * _asin(_sqrt(a));
    
    final double distance = earthRadius * c;
    return distance <= radiusKm;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  double _sin(double x) => x < 0 ? -_sin(-x) : x;
  double _asin(double x) => x < 0 ? -_asin(-x) : x;
  double _sqrt(double x) => x < 0 ? double.nan : x;
}

