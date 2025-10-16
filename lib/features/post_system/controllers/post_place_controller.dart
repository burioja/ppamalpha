import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/place/place_model.dart';

/// PostPlaceScreen 관련 로직을 관리하는 컨트롤러
class PostPlaceController {
  /// 플레이스 목록 로드
  static Future<List<PlaceModel>> loadPlaces(String userId) async {
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
      debugPrint('❌ 플레이스 로드 실패: $e');
      return [];
    }
  }

  /// 플레이스 검색
  static List<PlaceModel> searchPlaces(List<PlaceModel> places, String query) {
    if (query.trim().isEmpty) return places;
    
    final lowerQuery = query.toLowerCase();
    return places.where((place) {
      return place.name.toLowerCase().contains(lowerQuery) ||
             place.address.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 플레이스 필터링 (타입별)
  static List<PlaceModel> filterByType(List<PlaceModel> places, String? type) {
    if (type == null || type == '전체') return places;
    return places.where((place) => place.type == type).toList();
  }
}

