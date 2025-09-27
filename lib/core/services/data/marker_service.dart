import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/marker/marker_model.dart';
import '../../../utils/tile_utils.dart';

class MarkerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 마커 생성 (포스트 ID와 연결) - 통계 집계 포함
  static Future<String> createMarker({
    required String postId,
    required String title,
    required LatLng position,
    required int quantity,
    required String creatorId,
    required DateTime expiresAt,
  }) async {
    try {
      print('🚀 마커 생성 시작:');
      print('📋 Post ID: $postId');
      print('📝 제목: $title');
      print('📍 위치: ${position.latitude}, ${position.longitude}');
      print('📦 수량: $quantity');
      print('👤 생성자: $creatorId');
      print('⏰ 만료일: $expiresAt');

      // 타일 ID 계산
      final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
      print('🗺️ 타일 ID: $tileId');

      final markerData = {
        'postId': postId,
        'title': title,
        'location': GeoPoint(position.latitude, position.longitude),
        'totalQuantity': quantity, // 총 배포 수량
        'remainingQuantity': quantity, // 남은 수량
        'collectedQuantity': 0, // 수집된 수량
        'collectionRate': 0.0, // 수집률
        'creatorId': creatorId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'collectedBy': [], // 수령한 사용자 목록 초기화
        'tileId': tileId, // 타일 ID 저장
        // 호환성을 위해 기존 quantity 필드도 유지
        'quantity': quantity,
      };

      // 배치 트랜잭션으로 마커 생성 + 포스트 통계 업데이트
      final batch = _firestore.batch();

      // 1. 마커 생성
      final markerRef = _firestore.collection('markers').doc();
      batch.set(markerRef, markerData);
      print('📌 마커 문서 ID: ${markerRef.id}');

      // 2. 포스트 통계 업데이트
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'totalDeployments': FieldValue.increment(1),
        'totalDeployed': FieldValue.increment(quantity),
        'lastDeployedAt': FieldValue.serverTimestamp(),
      });
      print('📊 포스트 통계 업데이트 예약: $postId');

      await batch.commit();

      print('✅ 마커 생성 및 통계 업데이트 완료!');
      print('📋 Post ID: $postId');
      print('📌 Marker ID: ${markerRef.id}');
      print('🎯 [MARKER_CREATED] PostID: $postId | MarkerID: ${markerRef.id} | Title: $title');

      return markerRef.id;
    } catch (e) {
      print('❌ 마커 생성 실패: $e');
      rethrow;
    }
  }

  /// 반경 내 마커 조회
  static Stream<List<MarkerModel>> getMarkersInRadius({
    required LatLng center,
    required double radiusKm,
  }) {
    return _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
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

  /// 마커에서 포스트 수령 - 통계 집계 포함
  static Future<bool> collectPostFromMarker({
    required String markerId,
    required String userId,
  }) async {
    try {
      final docRef = _firestore.collection('markers').doc(markerId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }

        final data = doc.data()!;
        final remainingQuantity = data['remainingQuantity'] ?? data['quantity'] ?? 0;
        final collectedQuantity = data['collectedQuantity'] ?? 0;
        final totalQuantity = data['totalQuantity'] ?? data['quantity'] ?? 0;
        final collectedBy = List<String>.from(data['collectedBy'] ?? []);
        final postId = data['postId'];

        if (collectedBy.contains(userId)) {
          throw Exception('이미 수령한 포스트입니다');
        }

        if (remainingQuantity <= 0) {
          throw Exception('수량이 부족합니다');
        }

        final newRemainingQuantity = remainingQuantity - 1;
        final newCollectedQuantity = collectedQuantity + 1;
        final newCollectionRate = totalQuantity > 0 ? newCollectedQuantity / totalQuantity : 0.0;
        collectedBy.add(userId);

        // 마커 수량 업데이트
        final markerUpdate = {
          'remainingQuantity': newRemainingQuantity,
          'collectedQuantity': newCollectedQuantity,
          'collectionRate': newCollectionRate,
          'collectedBy': collectedBy,
          'quantity': newRemainingQuantity, // 호환성 유지
        };

        if (newRemainingQuantity <= 0) {
          markerUpdate['isActive'] = false;
        }

        transaction.update(docRef, markerUpdate);

        // 포스트 통계 업데이트 (이미 PostInstanceService에서 처리하지만 직접 수령 시에도 업데이트)
        if (postId != null) {
          final postRef = _firestore.collection('posts').doc(postId);
          transaction.update(postRef, {
            'totalCollected': FieldValue.increment(1),
            'lastCollectedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 마커에서 포스트 수령 완료: $markerId, 사용자: $userId');
      return true;
    } catch (e) {
      print('❌ 마커에서 포스트 수령 실패: $e');
      return false;
    }
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
