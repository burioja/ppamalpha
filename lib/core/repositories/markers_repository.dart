import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/marker/marker_model.dart';
import '../models/user/user_model.dart';
import '../constants/app_constants.dart';
import '../../utils/tile_utils.dart';
import '../datasources/firebase/markers_firebase_ds.dart';

/// 마커 데이터 저장소
/// 
/// **책임**: 마커 데이터 접근 로직 (Datasource 사용)
/// **원칙**: 
/// - UI/Provider와 완전 분리
/// - Datasource 인터페이스만 의존
/// - 비즈니스 로직 없음 (Service에서)
/// - 테스트 시 Mock Datasource 주입 가능
class MarkersRepository {
  final MarkersFirebaseDataSource _dataSource;

  MarkersRepository({MarkersFirebaseDataSource? dataSource})
      : _dataSource = dataSource ?? MarkersFirebaseDataSourceImpl();

  // ==================== 조회 (Read) ====================

  /// 특정 영역 내의 마커를 스트리밍
  /// 
  /// [bounds]: 조회할 지도 영역
  /// [userType]: 사용자 타입 (표시 거리 계산용)
  Stream<List<MarkerModel>> streamByBounds(
    LatLngBounds bounds,
    UserType userType,
  ) {
    // 영역의 타일 ID들 계산
    final tileIds = _getTileIdsInBounds(bounds);
    
    // Datasource를 통해 조회
    return _dataSource.streamByTileIds(tileIds);
  }

  /// 단일 마커 조회
  Future<MarkerModel?> getMarkerById(String markerId) async {
    return await _dataSource.getById(markerId);
  }

  /// 사용자가 생성한 마커 목록 스트리밍
  Stream<List<MarkerModel>> streamUserMarkers(String userId) {
    return _dataSource.streamByUserId(userId);
  }

  // ==================== 생성 (Create) ====================

  /// 마커 생성
  Future<String> createMarker(MarkerModel marker) async {
    return await _dataSource.create(marker.toFirestore());
  }

  // ==================== 업데이트 (Update) ====================

  /// 마커 수량 감소 (트랜잭션)
  Future<bool> decreaseQuantity(String markerId, int amount) async {
    try {
      await _dataSource.decreaseQuantity(markerId, amount);
      return true;
    } catch (e) {
      print('❌ Repository: 마커 수량 감소 실패: $e');
      return false;
    }
  }

  /// 마커 업데이트
  Future<bool> updateMarker(String markerId, Map<String, dynamic> data) async {
    try {
      await _dataSource.update(markerId, data);
      return true;
    } catch (e) {
      print('❌ Repository: 마커 업데이트 실패: $e');
      return false;
    }
  }

  // ==================== 삭제 (Delete) ====================

  /// 마커 삭제
  Future<bool> deleteMarker(String markerId) async {
    try {
      await _dataSource.delete(markerId);
      return true;
    } catch (e) {
      print('❌ Repository: 마커 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 배치 작업 ====================

  /// 여러 마커 일괄 수령 (배치 트랜잭션)
  Future<List<String>> collectMarkersBatch(
    List<String> markerIds,
    String userId,
  ) async {
    final successIds = <String>[];
    final firestore = FirebaseFirestore.instance;
    
    try {
      await firestore.runTransaction((transaction) async {
        for (final markerId in markerIds) {
          final docRef = firestore.collection('markers').doc(markerId);
          final snapshot = await transaction.get(docRef);
          
          if (!snapshot.exists) continue;
          
          final quantity = snapshot.data()?['quantity'] ?? 0;
          if (quantity <= 0) continue;
          
          transaction.update(docRef, {
            'quantity': quantity - 1,
          });
          
          // 수령 기록
          transaction.set(
            firestore
                .collection('markers')
                .doc(markerId)
                .collection('collections')
                .doc(),
            {
              'userId': userId,
              'collectedAt': FieldValue.serverTimestamp(),
            },
          );
          
          successIds.add(markerId);
        }
      });
    } catch (e) {
      print('❌ 배치 수령 실패: $e');
    }
    
    return successIds;
  }

  // ==================== 내부 헬퍼 ====================

  /// 지도 영역 내의 타일 ID 목록 계산
  List<String> _getTileIdsInBounds(LatLngBounds bounds) {
    final tileIds = <String>{};
    
    // 영역의 네 모서리 타일 ID 계산
    final swTile = TileUtils.getKm1TileId(
      bounds.south,
      bounds.west,
    );
    final neTile = TileUtils.getKm1TileId(
      bounds.north,
      bounds.east,
    );
    
    tileIds.add(swTile);
    tileIds.add(neTile);
    
    // 중앙 타일도 추가
    final centerLat = (bounds.north + bounds.south) / 2;
    final centerLng = (bounds.east + bounds.west) / 2;
    final centerTile = TileUtils.getKm1TileId(centerLat, centerLng);
    tileIds.add(centerTile);
    
    return tileIds.toList();
  }

  // ==================== 캐시 관리 ====================

  /// 캐시 무효화 (필요시 구현)
  void invalidateCache() {
    // TODO: 메모리 캐시 구현 시 여기서 초기화
  }
}

