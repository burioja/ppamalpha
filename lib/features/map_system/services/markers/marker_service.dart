import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/marker/marker_model.dart';
import '../../../../core/models/post/post_model.dart';
import '../fog_of_war/visit_tile_service.dart';
import '../../../../core/models/map/fog_level.dart';
import '../../../../utils/tile_utils.dart';

/// 마커 타입 열거형
enum MarkerType {
  post,        // 일반 포스트
  superPost,   // 슈퍼포스트 (검은 영역에서도 표시)
  user,        // 사용자 마커
}

/// 마커 데이터 모델
class MapMarkerData {
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
  final MarkerType type; // 마커 타입 추가

  MapMarkerData({
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
    this.type = MarkerType.post, // 기본값은 일반 포스트
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
      'type': type.name,
    };
  }

  factory MapMarkerData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MapMarkerData(
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
      type: MarkerType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MarkerType.post,
      ),
    );
  }
}

/// 마커 서비스
class MarkerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// 마커 스트림 가져오기 (markers 컬렉션에서 직접 조회)
  static Stream<List<MapMarkerData>> getMarkersStream({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    Map<String, dynamic> filters = const {},
  }) {
    return _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final markers = <MapMarkerData>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final position = LatLng(
            (data['location'] as GeoPoint).latitude,
            (data['location'] as GeoPoint).longitude,
          );
          
          // 거리 필터링
          bool withinRadius = false;
          for (final center in [location, ...additionalCenters]) {
            final distance = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            if (distance <= radiusInKm * 1000) { // km를 m로 변환
              withinRadius = true;
              break;
            }
          }
          
          if (!withinRadius) continue;
          
          // 포그레벨 필터링 (1km 이내는 무조건 표시)
          final tileId = data['tileId'] as String? ?? TileUtils.getKm1TileId(position.latitude, position.longitude);
          
          // 1km 이내 마커는 포그레벨 체크 없이 무조건 표시
          bool shouldShow = false;
          for (final center in [location, ...additionalCenters]) {
            final distance = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            if (distance <= 1000) { // 1km 이내
              shouldShow = true;
              break;
            }
          }
          
          if (!shouldShow) {
            // 1km 밖의 마커는 포그레벨 체크
            final fogLevel1Tiles = await _getFogLevel1Tiles(location, radiusInKm);
            if (!fogLevel1Tiles.contains(tileId)) continue;
          }
          
          // 마커 데이터 생성
          final marker = MapMarkerData(
            id: doc.id,
            title: data['title'] ?? '',
            description: data['description'] ?? '',
            userId: data['userId'] ?? '',
            position: position,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            expiryDate: data['expiryDate'] != null 
                ? (data['expiryDate'] as Timestamp).toDate() 
                : null,
            data: Map<String, dynamic>.from(data['data'] ?? {}),
            isCollected: data['isCollected'] ?? false,
            type: MarkerType.post,
          );
          
          markers.add(marker);
        } catch (e) {
          print('마커 파싱 오류: $e');
        }
      }
      
      return markers;
    });
  }
  
  /// 일반 포스트 마커 가져오기 (markers 컬렉션에서 직접 조회)
  static Future<List<MapMarkerData>> getMarkers({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    Map<String, dynamic> filters = const {},
    int pageSize = 500,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // markers 컬렉션에서 직접 조회
      final snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .limit(pageSize)
          .get();

      final markers = <MapMarkerData>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final position = LatLng(
            (data['location'] as GeoPoint).latitude,
            (data['location'] as GeoPoint).longitude,
          );
          
          // 거리 필터링
          bool withinRadius = false;
          for (final center in [location, ...additionalCenters]) {
            final distance = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            if (distance <= radiusInKm * 1000) { // km를 m로 변환
              withinRadius = true;
              break;
            }
          }
          
          if (!withinRadius) continue;
          
          // 포그레벨 필터링 (1km 이내는 무조건 표시)
          final tileId = data['tileId'] as String? ?? TileUtils.getKm1TileId(position.latitude, position.longitude);
          
          // 1km 이내 마커는 포그레벨 체크 없이 무조건 표시
          bool shouldShow = false;
          for (final center in [location, ...additionalCenters]) {
            final distance = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            if (distance <= 1000) { // 1km 이내
              shouldShow = true;
              break;
            }
          }
          
          if (!shouldShow) {
            // 1km 밖의 마커는 포그레벨 체크
            final fogLevel1Tiles = await _getFogLevel1Tiles(location, radiusInKm);
            if (!fogLevel1Tiles.contains(tileId)) continue;
          }
          
          // 수량 확인 - 수량이 0이면 마커 제외
          final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) {
            print('수량 소진으로 마커 제외: ${data['title']} (수량: $quantity)');
            continue;
          }
          
          // 마커 데이터 생성
          final marker = MapMarkerData(
            id: doc.id,
            title: data['title'] ?? '',
            description: '', // markers 컬렉션에는 description이 없음
            userId: data['creatorId'] ?? '',
            position: position,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            expiryDate: (data['expiresAt'] as Timestamp).toDate(),
            data: Map<String, dynamic>.from(data['data'] ?? {})..['quantity'] = quantity,
            isCollected: false, // markers는 수령되지 않음
            collectedBy: null,
            collectedAt: null,
            type: MarkerType.post,
          );
          
          markers.add(marker);
        } catch (e) {
          print('마커 변환 오류: $e');
          continue;
        }
      }
      
      return markers;
    } catch (e) {
      print('마커 조회 오류: $e');
      return [];
    }
  }

  /// 슈퍼포스트 마커 가져오기 (마커는 슈퍼포스트가 없으므로 빈 리스트 반환)
  static Future<List<MapMarkerData>> getSuperPosts({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    int pageSize = 200,
  }) async {
    // 마커는 슈퍼포스트가 없으므로 빈 리스트 반환
    return [];
  }

  /// 포그레벨 1 타일 가져오기 (캐시 포함)
  static Future<List<String>> _getFogLevel1Tiles(LatLng location, double radiusInKm) async {
    try {
      final surroundingTiles = TileUtils.getKm1SurroundingTiles(location.latitude, location.longitude);
      final fogLevelMap = await VisitTileService.getSurroundingTilesFogLevel(surroundingTiles);
      
      // 포그레벨 1(gray 이상)인 타일들만 필터링
      final fogLevel1Tiles = fogLevelMap.entries
          .where((entry) => entry.value == FogLevel.gray)
          .map((entry) => entry.key)
          .toList();
      
      return fogLevel1Tiles;
    } catch (e) {
      print('❌ 포그레벨 1단계 타일 계산 실패: $e');
      return [];
    }
  }
  
  /// 거리 계산 (Haversine 공식)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * 
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }
  
  /// 도를 라디안으로 변환
  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// MarkerData를 MarkerModel로 변환
  static MarkerModel convertToMarkerModel(MapMarkerData markerData) {
    return MarkerModel(
      markerId: markerData.id,
      postId: markerData.id, // postId는 markerId와 동일하게 설정
      title: markerData.title,
      position: markerData.position,
      quantity: (markerData.data['quantity'] as num?)?.toInt() ?? 1,
      creatorId: markerData.userId,
      createdAt: markerData.createdAt,
      expiresAt: markerData.expiryDate ?? markerData.createdAt.add(const Duration(days: 30)),
      isActive: !markerData.isCollected,
      collectedBy: markerData.collectedBy != null ? [markerData.collectedBy!] : [],
    );
  }

  /// 마커 생성
  static Future<String> createMarker({
    required String postId,
    required String title,
    required String creatorId,
    required LatLng position,
    required int quantity,
    DateTime? expiresAt,
  }) async {
    try {
      final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
      
      final markerData = {
        'title': title,
        'creatorId': creatorId,
        'location': GeoPoint(position.latitude, position.longitude),
        'postId': postId,
        'createdAt': Timestamp.now(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt) : null,
        'isActive': true,
        'quantity': quantity, // 수량 정보를 최상위 레벨에 저장
        'data': {
          'postId': postId,
          'title': title,
          'quantity': quantity,
        },
        'tileId': tileId,
      };

      final docRef = await _firestore.collection('markers').add(markerData);
      print('✅ 마커 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ 마커 생성 실패: $e');
      rethrow;
    }
  }

  /// 마커 삭제 (회수)
  static Future<void> deleteMarker(String markerId) async {
    try {
      await _firestore.collection('markers').doc(markerId).delete();
      print('✅ 마커 삭제 완료: $markerId');
    } catch (e) {
      print('❌ 마커 삭제 실패: $e');
      rethrow;
    }
  }
}