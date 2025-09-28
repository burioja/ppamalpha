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
import '../../../../core/constants/app_constants.dart';

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

/// 마커 서비스 (Map System 전용)
class MapMarkerService {
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
          final locationData = data['location'] as GeoPoint?;
          
          // location이 null인 마커는 건너뛰기
          if (locationData == null) {
            print('⚠️ location이 null인 마커 건너뛰기: ${doc.id}');
          continue;
        }
        
          final position = LatLng(
            locationData.latitude,
            locationData.longitude,
          );
          
          // 거리 필터링
          bool withinRadius = false;
          for (final center in [location, ...additionalCenters]) {
            final distanceInM = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            final radiusInM = radiusInKm * 1000; // km를 m로 변환
            if (distanceInM <= radiusInM) {
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
            data: Map<String, dynamic>.from(data['data'] ?? {})
              ..['reward'] = data['reward']  // ✅ reward 추가
              ..['isSuperMarker'] = data['isSuperMarker'],  // ✅ isSuperMarker 추가
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
  
  /// 모든 마커 가져오기 (일반 + 슈퍼포스트 통합 조회)
  static Future<List<MapMarkerData>> getMarkers({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    Map<String, dynamic> filters = const {},
    int pageSize = 300,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // markers 컬렉션에서 직접 조회 (서버 필터 추가)
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: now)     // ✅ 만료 제외 (서버 필터)
          .orderBy('expiresAt')                        // ✅ 범위 필드 먼저 정렬
          .limit(pageSize)                             // 200~300 권장
          .get();

      final markers = <MapMarkerData>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final locationData = data['location'] as GeoPoint?;
          
          // location이 null인 마커는 건너뛰기
          if (locationData == null) {
            print('⚠️ location이 null인 마커 건너뛰기: ${doc.id}');
            continue;
          }
          
          final position = LatLng(
            locationData.latitude,
            locationData.longitude,
          );
          
          // 거리 필터링
          bool withinRadius = false;
          for (final center in [location, ...additionalCenters]) {
            final distanceInM = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            final radiusInM = radiusInKm * 1000; // km를 m로 변환
            if (distanceInM <= radiusInM) {
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
            final distanceInM = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            if (distanceInM <= 1000) { // 1km 이내
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
            data: Map<String, dynamic>.from(data['data'] ?? {})
              ..['quantity'] = quantity
              ..['reward'] = data['reward']  // ✅ reward 추가
              ..['isSuperMarker'] = data['isSuperMarker'],  // ✅ isSuperMarker 추가
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

  /// 슈퍼마커만 가져오기 (서버 필터 사용)
  static Future<List<MapMarkerData>> getSuperMarkers({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    int pageSize = 150,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 슈퍼마커만 조회 (서버 필터 사용)
      final now = Timestamp.now();
      final snapshot = await _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isSuperMarker', isEqualTo: true) // ✅ 서버 필터
          .where('expiresAt', isGreaterThan: now)
          .orderBy('expiresAt')
          .limit(pageSize)
          .get();

      final markers = <MapMarkerData>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final locationData = data['location'] as GeoPoint?;
          
          if (locationData == null) continue;
          
          final position = LatLng(
            locationData.latitude,
            locationData.longitude,
          );
          
          // 거리 필터링
          bool withinRadius = false;
          for (final center in [location, ...additionalCenters]) {
            final distanceInM = _calculateDistance(
              center.latitude, center.longitude,
              position.latitude, position.longitude,
            );
            final radiusInM = radiusInKm * 1000;
            if (distanceInM <= radiusInM) {
              withinRadius = true;
              break;
            }
          }
          
          if (!withinRadius) continue;
          
          // 수량 확인
          final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) continue;
          
          // 마커 데이터 생성
          final marker = MapMarkerData(
            id: doc.id,
            title: data['title'] ?? '',
            description: '',
            userId: data['creatorId'] ?? '',
            position: position,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            expiryDate: (data['expiresAt'] as Timestamp).toDate(),
            data: Map<String, dynamic>.from(data['data'] ?? {})
              ..['quantity'] = quantity
              ..['reward'] = data['reward']  // ✅ reward 추가
              ..['isSuperMarker'] = data['isSuperMarker'],  // ✅ isSuperMarker 추가
            isCollected: false,
            type: MarkerType.superPost, // ✅ 슈퍼포스트 타입
          );
          
          markers.add(marker);
        } catch (e) {
          print('슈퍼마커 변환 오류: $e');
          continue;
        }
      }
      
      return markers;
    } catch (e) {
      print('슈퍼마커 조회 오류: $e');
      return [];
    }
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
    // ✅ 옵셔널 안전 파싱 함수
    int? parseNullableInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }
    
    return MarkerModel(
      markerId: markerData.id,
      postId: markerData.data['postId'] ?? markerData.id, // ✅ data에서 postId 가져오기
      title: markerData.title,
      position: markerData.position,
      quantity: (markerData.data['quantity'] as num?)?.toInt() ?? 1,
      reward: parseNullableInt(markerData.data['reward']), // ✅ 옵셔널 파싱
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
    int? reward, // ✅ 옵셔널로 변경 (호환성 유지)
    DateTime? expiresAt,
  }) async {
    try {
      print('🚀 Map 마커 생성 시작:');
      print('📋 Post ID: $postId');
      print('📝 제목: $title');
      print('👤 생성자: $creatorId');
      print('📍 위치: ${position.latitude}, ${position.longitude}');
      print('📦 수량: $quantity');
      print('⏰ 만료일: $expiresAt');

      final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
      
      final now = DateTime.now();
      final markerData = <String, dynamic>{
        'title': title,
        'creatorId': creatorId,
        'location': GeoPoint(position.latitude, position.longitude),
        'postId': postId, // ✅ top-level에만 저장 (중복 제거)
        'createdAt': Timestamp.fromDate(now),                 // ✅ 즉시 쿼리 통과
        'createdAtServer': FieldValue.serverTimestamp(),      // (옵션) 보정용
        'expiresAt': expiresAt != null 
            ? Timestamp.fromDate(expiresAt) 
            : Timestamp.fromDate(now.add(const Duration(hours: 24))), // ✅ null 방지
        'isActive': true,
        'quantity': quantity, // ✅ 수량 정보를 최상위 레벨에 저장
        'tileId': tileId,
      };

      // ✅ nullable promotion 이슈 피하려고 로컬 변수로 받아서 체크
      final r = reward;
      if (r != null) {
        markerData['reward'] = r;
      }

      final docRef = await _firestore.collection('markers').add(markerData);

      print('✅ Map 마커 생성 완료!');
      print('📋 Post ID: $postId');
      print('📌 Marker ID: ${docRef.id}');
      print('💰 Reward: ${reward ?? 0}원');
      print('🎯 [MAP_MARKER_CREATED] PostID: $postId | MarkerID: ${docRef.id} | Title: $title');

      return docRef.id;
    } catch (e) {
      print('❌ Map 마커 생성 실패:');
      print('📋 Post ID: $postId');
      print('💥 Error: $e');
      print('🚨 [MAP_MARKER_FAILED] PostID: $postId | Error: $e');
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