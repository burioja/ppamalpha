import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/marker/marker_model.dart';

class MarkerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 마커 생성 (포스트 ID와 연결)
  static Future<String> createMarker({
    required String postId,
    required String title,
    required LatLng position,
    required int quantity,
    required String creatorId,
    required DateTime expiresAt,
  }) async {
    try {
      final markerData = {
        'postId': postId,
        'title': title,
        'location': GeoPoint(position.latitude, position.longitude),
        'quantity': quantity,
        'creatorId': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
      };

      final docRef = await _firestore.collection('markers').add(markerData);
      print('✅ 마커 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ 마커 생성 실패: $e');
      rethrow;
    }
  }

  /// 반경 내 마커 조회
  static Stream<List<MarkerModel>> getMarkersInRadius({
    required LatLng center,
    required double radiusKm,
    required int limit,
  }) {
    return _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final markers = <MarkerModel>[];
      
      for (final doc in snapshot.docs) {
        try {
          final marker = MarkerModel.fromFirestore(doc);
          
          // 거리 계산
          final distance = _calculateDistance(
            center.latitude, center.longitude,
            marker.position.latitude, marker.position.longitude,
          );
          
          // 반경 내에 있고 수량이 0보다 큰 마커만 포함
          if (distance <= radiusKm && marker.quantity > 0) {
            markers.add(marker);
          }
        } catch (e) {
          print('❌ 마커 파싱 실패: $e');
        }
      }
      
      // 거리순으로 정렬
      markers.sort((a, b) {
        final distanceA = _calculateDistance(
          center.latitude, center.longitude,
          a.position.latitude, a.position.longitude,
        );
        final distanceB = _calculateDistance(
          center.latitude, center.longitude,
          b.position.latitude, b.position.longitude,
        );
        return distanceA.compareTo(distanceB);
      });
      
      print('📍 반경 ${radiusKm}km 내 마커 ${markers.length}개 발견');
      return markers;
    });
  }

  /// 마커 수량 감소 (수령 시)
  static Future<bool> decreaseMarkerQuantity(String markerId) async {
    try {
      final docRef = _firestore.collection('markers').doc(markerId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }
        
        final currentQuantity = doc.data()?['quantity'] ?? 0;
        
        if (currentQuantity <= 0) {
          throw Exception('수량이 부족합니다');
        }
        
        final newQuantity = currentQuantity - 1;
        
        if (newQuantity <= 0) {
          // 수량이 0이 되면 마커 비활성화
          transaction.update(docRef, {
            'quantity': 0,
            'isActive': false,
          });
        } else {
          // 수량만 감소
          transaction.update(docRef, {
            'quantity': newQuantity,
          });
        }
      });
      
      print('✅ 마커 수량 감소 완료: $markerId');
      return true;
    } catch (e) {
      print('❌ 마커 수량 감소 실패: $e');
      return false;
    }
  }

  /// 마커 삭제
  static Future<void> deleteMarker(String markerId) async {
    try {
      await _firestore.collection('markers').doc(markerId).delete();
      print('✅ 마커 삭제 완료: $markerId');
    } catch (e) {
      print('❌ 마커 삭제 실패: $e');
      rethrow;
    }
  }

  /// 거리 계산 (Haversine 공식)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final dLat = (lat2 - lat1) * (math.pi / 180);
    final dLng = (lng2 - lng1) * (math.pi / 180);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
}
