import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/place/place_model.dart';

/// Place 관련 공통 로직을 관리하는 컨트롤러
class PlaceController {
  /// 플레이스 생성
  static Future<String> createPlace({
    required String creatorId,
    required String name,
    required String type,
    required String address,
    required LatLng location,
    String? description,
    List<String>? imageUrls,
    Map<String, dynamic>? operatingHours,
    String? phoneNumber,
    String? website,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final placeData = {
        'creatorId': creatorId,
        'name': name,
        'type': type,
        'address': address,
        'location': GeoPoint(location.latitude, location.longitude),
        'description': description ?? '',
        'imageUrls': imageUrls ?? [],
        'operatingHours': operatingHours ?? {},
        'phoneNumber': phoneNumber,
        'website': website,
        'metadata': metadata ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('places')
          .add(placeData);

      debugPrint('✅ 플레이스 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ 플레이스 생성 실패: $e');
      rethrow;
    }
  }

  /// 플레이스 수정
  static Future<void> updatePlace({
    required String placeId,
    String? name,
    String? type,
    String? address,
    LatLng? location,
    String? description,
    List<String>? imageUrls,
    Map<String, dynamic>? operatingHours,
    String? phoneNumber,
    String? website,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) updateData['name'] = name;
      if (type != null) updateData['type'] = type;
      if (address != null) updateData['address'] = address;
      if (location != null) {
        updateData['location'] = GeoPoint(location.latitude, location.longitude);
      }
      if (description != null) updateData['description'] = description;
      if (imageUrls != null) updateData['imageUrls'] = imageUrls;
      if (operatingHours != null) updateData['operatingHours'] = operatingHours;
      if (phoneNumber != null) updateData['phoneNumber'] = phoneNumber;
      if (website != null) updateData['website'] = website;

      await FirebaseFirestore.instance
          .collection('places')
          .doc(placeId)
          .update(updateData);

      debugPrint('✅ 플레이스 수정 완료: $placeId');
    } catch (e) {
      debugPrint('❌ 플레이스 수정 실패: $e');
      rethrow;
    }
  }

  /// 플레이스 삭제
  static Future<void> deletePlace(String placeId) async {
    try {
      await FirebaseFirestore.instance
          .collection('places')
          .doc(placeId)
          .delete();

      debugPrint('✅ 플레이스 삭제 완료: $placeId');
    } catch (e) {
      debugPrint('❌ 플레이스 삭제 실패: $e');
      rethrow;
    }
  }

  /// 플레이스 조회
  static Future<PlaceModel?> getPlace(String placeId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('places')
          .doc(placeId)
          .get();

      if (!doc.exists) return null;
      return PlaceModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ 플레이스 조회 실패: $e');
      return null;
    }
  }

  /// 사용자의 플레이스 목록 조회
  static Future<List<PlaceModel>> getUserPlaces(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('creatorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ 사용자 플레이스 조회 실패: $e');
      return [];
    }
  }

  /// 플레이스 유효성 검증
  static bool validatePlaceData({
    required String name,
    required String address,
  }) {
    if (name.trim().isEmpty) {
      debugPrint('❌ 플레이스 이름이 비어있습니다');
      return false;
    }

    if (address.trim().isEmpty) {
      debugPrint('❌ 주소가 비어있습니다');
      return false;
    }

    return true;
  }
}

