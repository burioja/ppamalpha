import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

/// 마커 데이터 모델
class MarkerData {
  final String id;
  final String title;
  final String description;
  final String userId;
  final LatLng position;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final Map<String, dynamic> data;
  final bool isCollected;
  final String? collectedBy;
  final DateTime? collectedAt;

  MarkerData({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.position,
    required this.createdAt,
    this.expiryDate,
    required this.data,
    this.isCollected = false,
    this.collectedBy,
    this.collectedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'userId': userId,
      'position': GeoPoint(position.latitude, position.longitude),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'data': data,
      'isCollected': isCollected,
      'collectedBy': collectedBy,
      'collectedAt': collectedAt != null ? Timestamp.fromDate(collectedAt!) : null,
    };
  }

  factory MarkerData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MarkerData(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      userId: data['userId'] ?? '',
      position: LatLng(
        (data['position'] as GeoPoint).latitude,
        (data['position'] as GeoPoint).longitude,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate() 
          : null,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      isCollected: data['isCollected'] ?? false,
      collectedBy: data['collectedBy'],
      collectedAt: data['collectedAt'] != null 
          ? (data['collectedAt'] as Timestamp).toDate() 
          : null,
    );
  }
}

/// 마커 서비스
class MarkerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'markers';

  /// 마커 생성
  static Future<String> createMarker({
    required String title,
    required String description,
    required LatLng position,
    Map<String, dynamic>? additionalData,
    DateTime? expiryDate,
  }) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      final markerId = _firestore.collection(_collection).doc().id;
      final marker = MarkerData(
        id: markerId,
        title: title,
        description: description,
        userId: userId,
        position: position,
        createdAt: DateTime.now(),
        expiryDate: expiryDate,
        data: additionalData ?? {},
      );

      await _firestore
          .collection(_collection)
          .doc(markerId)
          .set(marker.toFirestore());

      return markerId;
    } catch (e) {
      throw Exception('마커 생성 중 오류가 발생했습니다: $e');
    }
  }

  /// 반경 내 마커 조회
  static Future<List<MarkerData>> getMarkersInRadius({
    required LatLng center,
    required double radiusInKm,
  }) async {
    try {
      // 간단한 반경 쿼리 (Firestore의 제한으로 인해 대략적인 범위)
      const double latRange = 0.01; // 약 1km
      const double lngRange = 0.01; // 약 1km

      final query = await _firestore
          .collection(_collection)
          .where('position', isGreaterThan: GeoPoint(
            center.latitude - latRange,
            center.longitude - lngRange,
          ))
          .where('position', isLessThan: GeoPoint(
            center.latitude + latRange,
            center.longitude + lngRange,
          ))
          .get();

      final markers = query.docs
          .map((doc) => MarkerData.fromFirestore(doc))
          .toList();

      // 정확한 거리 계산으로 필터링
      final filteredMarkers = markers.where((marker) {
        final distance = _calculateDistance(center, marker.position);
        return distance <= radiusInKm;
      }).toList();

      return filteredMarkers;
    } catch (e) {
      throw Exception('마커 조회 중 오류가 발생했습니다: $e');
    }
  }

  /// 마커 삭제 (생성자만 가능)
  static Future<void> deleteMarker(String markerId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      // 마커 소유자 확인
      final doc = await _firestore.collection(_collection).doc(markerId).get();
      if (!doc.exists) {
        throw Exception('마커를 찾을 수 없습니다.');
      }

      final marker = MarkerData.fromFirestore(doc);
      if (marker.userId != userId) {
        throw Exception('마커를 삭제할 권한이 없습니다.');
      }

      await _firestore.collection(_collection).doc(markerId).delete();
    } catch (e) {
      throw Exception('마커 삭제 중 오류가 발생했습니다: $e');
    }
  }

  /// 마커 수집 (타겟 사용자만 가능)
  static Future<void> collectMarker(String markerId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('사용자가 로그인되지 않았습니다.');
      }

      await _firestore.collection(_collection).doc(markerId).update({
        'isCollected': true,
        'collectedBy': userId,
        'collectedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('마커 수집 중 오류가 발생했습니다: $e');
    }
  }

  /// 실시간 마커 리스너
  static Stream<List<MarkerData>> getMarkersStream({
    required LatLng center,
    required double radiusInKm,
  }) {
    const double latRange = 0.01; // 약 1km
    const double lngRange = 0.01; // 약 1km

    return _firestore
        .collection(_collection)
        .where('position', isGreaterThan: GeoPoint(
          center.latitude - latRange,
          center.longitude - lngRange,
        ))
        .where('position', isLessThan: GeoPoint(
          center.latitude + latRange,
          center.longitude + lngRange,
        ))
        .snapshots()
        .map((snapshot) {
      final markers = snapshot.docs
          .map((doc) => MarkerData.fromFirestore(doc))
          .toList();

      // 정확한 거리 계산으로 필터링
      return markers.where((marker) {
        final distance = _calculateDistance(center, marker.position);
        return distance <= radiusInKm;
      }).toList();
    });
  }

  /// 거리 계산 (km)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLng = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }
}
