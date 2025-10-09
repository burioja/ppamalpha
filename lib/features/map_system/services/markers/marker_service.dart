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
          
          // 🔥 수량이 0인 마커는 건너뛰기 (이미 isActive가 false로 설정됨)
          final remainingQuantity = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
          if (remainingQuantity <= 0) {
            print('⚠️ 수량이 0인 마커 건너뛰기: ${doc.id}');
            continue;
          }
          
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
    int pageSize = 1000, // 제한 증가 (영역 내에서만 조회하므로)
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('🔴 [MARKER_DEBUG] 사용자 미로그인');
        return [];
      }

      print('');
      print('🔵🔵🔵 ========== getMarkers() 시작 ========== 🔵🔵🔵');
      print('🔵 사용자 UID: ${user.uid}');
      print('🔵 중심 위치: ${location.latitude}, ${location.longitude}');
      print('🔵 검색 반경: ${radiusInKm}km');
      print('🔵 적용된 필터: $filters');
      print('🔵 myPostsOnly: ${filters['myPostsOnly']}');
      print('🔵 showCouponsOnly: ${filters['showCouponsOnly']}');
      print('🔵 minReward: ${filters['minReward']}');
      print('🔵 showUrgentOnly: ${filters['showUrgentOnly']}');

      // markers 컬렉션에서 직접 조회 (서버 필터 추가)
      final now = Timestamp.now();
      Query query = _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: now);     // ✅ 만료 제외 (서버 필터)

      // 서버사이드 필터링 적용
      if (filters['myPostsOnly'] == true && user != null) {
        query = query.where('creatorId', isEqualTo: user.uid);
        print('🔍 서버사이드 필터: 내 포스트만 조회 (creatorId: ${user.uid})');
      }

      if (filters['showCouponsOnly'] == true) {
        query = query.where('isCoupon', isEqualTo: true);
        print('🔍 서버사이드 필터: 쿠폰만 조회');
      }

      if (filters['minReward'] != null && filters['minReward'] > 0) {
        query = query.where('reward', isGreaterThanOrEqualTo: filters['minReward']);
        print('🔍 서버사이드 필터: 최소 리워드 ${filters['minReward']}원 이상');
      }

      if (filters['showUrgentOnly'] == true) {
        // 하루 남은 포스트만 필터링 (24시간 이내 만료)
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowTimestamp = Timestamp.fromDate(tomorrow);
        query = query.where('expiresAt', isLessThan: tomorrowTimestamp);
        print('🔍 서버사이드 필터: 마감임박 (24시간 이내 만료)');
      }

      final snapshot = await query
          .orderBy('expiresAt')                        // ✅ 범위 필드 먼저 정렬
          .limit(pageSize)                             // 제한 증가
          .get();

      print('🔵 Firebase 쿼리 결과: ${snapshot.docs.length}개 마커');

      // 필터링 통계 변수
      int totalCount = snapshot.docs.length;
      int recalledCount = 0;
      int noQuantityCount = 0;
      int noLocationCount = 0;
      int alreadyCollectedCount = 0;
      int outOfRangeCount = 0;
      int fogLevelFilteredCount = 0;
      int finalCount = 0;

      final markers = <MapMarkerData>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          // 🔥 회수된 마커는 건너뛰기
          final status = data['status'] as String?;
          if (status == 'RECALLED') {
            recalledCount++;
            continue;
          }

          // 🔥 수량이 0인 마커는 건너뛰기 (이미 isActive가 false로 설정됨)
          final remainingQuantity = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
          if (remainingQuantity <= 0) {
            noQuantityCount++;
            continue;
          }

          final locationData = data['location'] as GeoPoint?;

          // location이 null인 마커는 건너뛰기
          if (locationData == null) {
            noLocationCount++;
            continue;
          }

          // 현재 사용자가 이미 수령한 마커는 제외 (단, 내가 배포한 마커는 예외)
          final creatorId = data['creatorId'] as String?;
          if (creatorId != user.uid) {
            final collectedBy = List<String>.from(data['collectedBy'] ?? []);
            if (collectedBy.contains(user.uid)) {
              alreadyCollectedCount++;
              continue;
            }
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

          if (!withinRadius) {
            outOfRangeCount++;
            continue;
          }

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
            if (!fogLevel1Tiles.contains(tileId)) {
              fogLevelFilteredCount++;
              continue;
            }
          }

          // 수량 확인 - 수량이 0이면 마커 제외
          final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) {
            noQuantityCount++;
            continue;
          }

          // 마커 데이터 생성
          finalCount++;
          final marker = MapMarkerData(
            id: doc.id,
            title: data['title'] ?? '',
            description: '', // markers 컬렉션에는 description이 없음
            userId: data['creatorId'] ?? '',
            position: position,
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            expiryDate: (data['expiresAt'] as Timestamp).toDate(),
            data: Map<String, dynamic>.from(data)  // ✅ data 자체를 전달 (중첩 data 필드 아님!)
              ..['quantity'] = quantity
              ..['reward'] = data['reward']
              ..['isSuperMarker'] = data['isSuperMarker']
              ..['postId'] = data['postId'],  // ✅ postId 명시적으로 추가
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

      // 필터링 결과 요약
      print('');
      print('📊 ========== 필터링 결과 요약 ========== 📊');
      print('📊 총 쿼리된 마커: $totalCount개');
      print('📊 제외된 마커:');
      print('   - 회수됨 (RECALLED): $recalledCount개');
      print('   - 수량 소진: $noQuantityCount개');
      print('   - 위치 정보 없음: $noLocationCount개');
      print('   - 이미 수령함: $alreadyCollectedCount개');
      print('   - 거리 범위 밖: $outOfRangeCount개');
      print('   - 포그 레벨 필터링: $fogLevelFilteredCount개');
      print('📊 최종 반환 마커: $finalCount개');
      print('🔵🔵🔵 ========== getMarkers() 종료 ========== 🔵🔵🔵');
      print('');

      return markers;
    } catch (e) {
      print('❌ 마커 조회 오류: $e');
      return [];
    }
  }

  /// 슈퍼마커만 가져오기 (서버 필터 사용)
  static Future<List<MapMarkerData>> getSuperMarkers({
    required LatLng location,
    double radiusInKm = 1.0,
    List<LatLng> additionalCenters = const [],
    Map<String, dynamic> filters = const {},
    int pageSize = 500, // 제한 증가
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 슈퍼마커만 조회 (서버 필터 사용)
      final now = Timestamp.now();
      Query query = _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isSuperMarker', isEqualTo: true) // ✅ 서버 필터
          .where('expiresAt', isGreaterThan: now);

      // 서버사이드 필터링 적용 (슈퍼마커용)
      if (filters['myPostsOnly'] == true && user != null) {
        query = query.where('creatorId', isEqualTo: user.uid);
        print('🔍 슈퍼마커 서버사이드 필터: 내 포스트만 조회 (creatorId: ${user.uid})');
      }

      if (filters['showCouponsOnly'] == true) {
        query = query.where('isCoupon', isEqualTo: true);
        print('🔍 슈퍼마커 서버사이드 필터: 쿠폰만 조회');
      }

      if (filters['minReward'] != null && filters['minReward'] > 0) {
        query = query.where('reward', isGreaterThanOrEqualTo: filters['minReward']);
        print('🔍 슈퍼마커 서버사이드 필터: 최소 리워드 ${filters['minReward']}원 이상');
      }

      if (filters['showUrgentOnly'] == true) {
        // 하루 남은 포스트만 필터링 (24시간 이내 만료)
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final tomorrowTimestamp = Timestamp.fromDate(tomorrow);
        query = query.where('expiresAt', isLessThan: tomorrowTimestamp);
        print('🔍 슈퍼마커 서버사이드 필터: 마감임박 (24시간 이내 만료)');
      }

      final snapshot = await query
          .orderBy('expiresAt')
          .limit(pageSize)
          .get();

      final markers = <MapMarkerData>[];
      
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          // 🔥 회수된 슈퍼마커는 건너뛰기
          final status = data['status'] as String?;
          if (status == 'RECALLED') {
            print('🔴 회수된 슈퍼마커 건너뛰기: ${doc.id}');
            continue;
          }

          // 🔥 수량이 0인 슈퍼마커는 건너뛰기 (이미 isActive가 false로 설정됨)
          final remainingQuantity = (data['remainingQuantity'] as num?)?.toInt() ?? 0;
          if (remainingQuantity <= 0) {
            print('⚠️ 수량이 0인 슈퍼마커 건너뛰기: ${doc.id}');
            continue;
          }
          
          final locationData = data['location'] as GeoPoint?;
          
          if (locationData == null) continue;

          // 현재 사용자가 이미 수령한 마커는 제외 (단, 내가 배포한 마커는 예외)
          final creatorId = data['creatorId'] as String?;
          if (creatorId != user.uid) {
            final collectedBy = List<String>.from(data['collectedBy'] ?? []);
            if (collectedBy.contains(user.uid)) {
              print('🚫 이미 수령한 슈퍼마커 제외: ${doc.id}');
              continue;
            }
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
            data: Map<String, dynamic>.from(data)  // ✅ data 자체를 전달
              ..['quantity'] = quantity
              ..['reward'] = data['reward']
              ..['isSuperMarker'] = data['isSuperMarker']
              ..['postId'] = data['postId'],  // ✅ postId 명시적으로 추가
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
    // 🔍 타겟 마커 디버깅
    final isTargetMarker = markerData.id == 'TQTIS4RPfirWBK6qHoqu';

    if (isTargetMarker) {
      print('');
      print('🟠🟠🟠 [convertToMarkerModel] 타겟 마커 변환 시작 🟠🟠🟠');
      print('🟠 markerData.id: ${markerData.id}');
      print('🟠 markerData.data[\'postId\']: "${markerData.data['postId']}"');
      print('🟠 markerData.data[\'postId\'] == null: ${markerData.data['postId'] == null}');
      print('🟠 markerData.data 전체: ${markerData.data}');
    }

    // ✅ 옵셔널 안전 파싱 함수
    int? parseNullableInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    // ⚠️ postId 추출 로직 수정
    final postIdFromData = markerData.data['postId'] as String?;
    final finalPostId = postIdFromData ?? markerData.id;

    if (isTargetMarker) {
      print('🟠 postIdFromData: "$postIdFromData"');
      print('🟠 finalPostId (사용될 값): "$finalPostId"');
      print('🟠 폴백 사용됨: ${postIdFromData == null}');
    }

    // ✅ quantity와 remainingQuantity는 항상 동일하게 설정
    // 우선순위: remainingQuantity > quantity > 1 (기본값)
    final int quantityValue = (markerData.data['remainingQuantity'] as num?)?.toInt()
        ?? (markerData.data['quantity'] as num?)?.toInt()
        ?? 1;

    final result = MarkerModel(
      markerId: markerData.id,
      postId: finalPostId,
      title: markerData.title,
      position: markerData.position,
      quantity: quantityValue, // quantity와 remainingQuantity 동일
      // 🚀 Firebase 실제 데이터와 일치하는 새로운 필드들
      totalQuantity: (markerData.data['totalQuantity'] as num?)?.toInt() ?? quantityValue,
      remainingQuantity: quantityValue, // quantity와 remainingQuantity 동일
      collectedQuantity: (markerData.data['collectedQuantity'] as num?)?.toInt() ?? 0,
      collectionRate: (markerData.data['collectionRate'] as num?)?.toDouble() ?? 0.0,
      tileId: markerData.data['tileId'] as String? ?? '',
      s2_10: markerData.data['s2_10'] as String?,
      s2_12: markerData.data['s2_12'] as String?,
      fogLevel: (markerData.data['fogLevel'] as num?)?.toInt(),
      reward: parseNullableInt(markerData.data['reward']), // ✅ 옵셔널 파싱
      creatorId: markerData.userId,
      createdAt: markerData.createdAt,
      expiresAt: markerData.expiryDate ?? markerData.createdAt.add(const Duration(days: 30)),
      isActive: !markerData.isCollected,
      collectedBy: markerData.collectedBy != null ? [markerData.collectedBy!] : [],
    );

    if (isTargetMarker) {
      print('🟠 생성된 MarkerModel.postId: "${result.postId}"');
      print('🟠🟠🟠 [convertToMarkerModel] 타겟 마커 변환 완료 🟠🟠🟠');
      print('');
    }

    return result;
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

  // 수령 가능한 포스트 조회
  static Future<List<Map<String, dynamic>>> getReceivablePosts({
    required double lat,
    required double lng,
    required String uid,
    int radius = 100, // 미터 단위
  }) async {
    try {
      final callable = _functions.httpsCallable('queryReceivablePosts');
      final result = await callable.call({
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'uid': uid,
      });

      final data = result.data;
      if (data == null) {
        print('수령 가능 포스트 조회 결과가 null입니다');
        return [];
      }

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('수령 가능 포스트 조회 실패: $e');
      print('위치: lat=$lat, lng=$lng, radius=$radius, uid=$uid');
      
      // 에러 타입별 상세 로그
      if (e.toString().contains('unauthenticated')) {
        print('사용자 인증 오류');
      } else if (e.toString().contains('unavailable')) {
        print('Firebase Functions 서비스 불가');
      } else if (e.toString().contains('timeout')) {
        print('요청 시간 초과');
      }
      
      return [];
    }
  }
}