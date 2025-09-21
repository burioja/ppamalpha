import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/marker/marker_model.dart';

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
    );
  }
}

/// 마커 서비스 (서버 사이드 필터링)
class MarkerService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // 캐시 관련
  static final Map<String, List<MapMarkerData>> _markerCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  
  // 🚀 서버 API를 통한 마커 조회
  static Future<List<MapMarkerData>> getMarkers({
    required LatLng location,
    required double radiusInKm,
    List<LatLng>? additionalCenters,
    Map<String, dynamic>? filters,
    int pageSize = 500,
    String? pageToken,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ 사용자가 로그인하지 않음');
        return [];
      }

      // 캐시 키 생성 (위치 기반)
      final cacheKey = _generateCacheKey(location, additionalCenters, filters);
      
      // 캐시 확인
      if (_markerCache.containsKey(cacheKey) && 
          _cacheTimestamps[cacheKey]!.isAfter(DateTime.now().subtract(_cacheExpiry))) {
        print('🚀 마커 캐시 사용: $cacheKey');
        return _markerCache[cacheKey]!;
      }

      print('🔍 서버에서 마커 조회 중...');
      
      // 검색 중심점들 구성
      final centers = <Map<String, double>>[
        {'lat': location.latitude, 'lng': location.longitude}
      ];
      
      if (additionalCenters != null) {
        for (final center in additionalCenters) {
          centers.add({'lat': center.latitude, 'lng': center.longitude});
        }
      }

      // 서버 API 호출
      final callable = _functions.httpsCallable('queryPosts');
      final result = await callable.call({
        'userId': user.uid,
        'centers': centers,
        'radiusKm': radiusInKm,
        'filters': filters ?? {},
        'pageSize': pageSize,
        'pageToken': pageToken,
      });

      final data = result.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      
      // MarkerData로 변환
      final markers = items.map((item) => _createMarkerDataFromServer(item)).toList();
      
      // 캐시 저장
      _markerCache[cacheKey] = markers;
      _cacheTimestamps[cacheKey] = DateTime.now();
      
      print('✅ 서버에서 ${markers.length}개 마커 조회 완료');
      return markers;
      
    } catch (e) {
      print('❌ 마커 조회 오류: $e');
      return [];
    }
  }
  
  // 🚀 슈퍼포스트 전용 조회
  static Future<List<MapMarkerData>> getSuperPosts({
    required LatLng location,
    required double radiusInKm,
    List<LatLng>? additionalCenters,
    int pageSize = 200,
    String? pageToken,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ 사용자가 로그인하지 않음');
        return [];
      }

      print('🔍 서버에서 슈퍼포스트 조회 중...');
      
      // 검색 중심점들 구성
      final centers = <Map<String, double>>[
        {'lat': location.latitude, 'lng': location.longitude}
      ];
      
      if (additionalCenters != null) {
        for (final center in additionalCenters) {
          centers.add({'lat': center.latitude, 'lng': center.longitude});
        }
      }

      // 슈퍼포스트 전용 API 호출
      final callable = _functions.httpsCallable('querySuperPosts');
      final result = await callable.call({
        'userId': user.uid,
        'centers': centers,
        'radiusKm': radiusInKm,
        'pageSize': pageSize,
        'pageToken': pageToken,
      });

      final data = result.data as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>;
      
      // MarkerData로 변환
      final markers = items.map((item) => _createMarkerDataFromServer(item, MarkerType.superPost)).toList();
      
      print('✅ 서버에서 ${markers.length}개 슈퍼포스트 조회 완료');
      return markers;
      
    } catch (e) {
      print('❌ 슈퍼포스트 조회 오류: $e');
      return [];
    }
  }
  
  // 서버 응답에서 MapMarkerData 생성
  static MapMarkerData _createMarkerDataFromServer(Map<String, dynamic> item, [MarkerType? type]) {
    final location = item['location'] as Map<String, dynamic>;
    final isSuperPost = item['isSuperPost'] == true || (item['reward'] as int? ?? 0) >= 1000;
    
    return MapMarkerData(
      id: item['postId'] ?? item['id'] ?? '',
      title: item['title'] ?? '',
      description: item['description'] ?? '',
      userId: item['creatorId'] ?? '',
      position: LatLng(
        location['latitude'] as double,
        location['longitude'] as double,
      ),
      createdAt: item['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(item['createdAt'])
          : DateTime.now(),
      expiryDate: item['expiresAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(item['expiresAt'])
          : null,
      data: item,
      isCollected: item['isCollected'] == true,
      collectedBy: item['collectedBy'],
      collectedAt: item['collectedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(item['collectedAt'])
          : null,
      type: type ?? (isSuperPost ? MarkerType.superPost : MarkerType.post),
    );
  }
  
  // 캐시 키 생성
  static String _generateCacheKey(
    LatLng location, 
    List<LatLng>? additionalCenters, 
    Map<String, dynamic>? filters
  ) {
    final lat = (location.latitude * 1000).round() / 1000; // 1km 그리드 스냅
    final lng = (location.longitude * 1000).round() / 1000;
    
    var key = 'markers:${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    
    if (additionalCenters != null && additionalCenters.isNotEmpty) {
      for (final center in additionalCenters) {
        final cLat = (center.latitude * 1000).round() / 1000;
        final cLng = (center.longitude * 1000).round() / 1000;
        key += '_${cLat.toStringAsFixed(3)}_${cLng.toStringAsFixed(3)}';
      }
    }
    
    if (filters != null && filters.isNotEmpty) {
      final filterKeys = filters.keys.toList()..sort();
      for (final filterKey in filterKeys) {
        key += '_$filterKey:${filters[filterKey]}';
      }
    }
    
    return key;
  }
  
  // MapMarkerData를 MarkerModel로 변환
  static MarkerModel convertToMarkerModel(MapMarkerData markerData) {
    return MarkerModel(
      markerId: markerData.id,
      postId: markerData.id,
      title: markerData.title,
      position: markerData.position,
      quantity: 1,
      creatorId: markerData.userId,
      createdAt: markerData.createdAt,
      expiresAt: markerData.expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      isActive: !markerData.isCollected,
      collectedBy: markerData.collectedBy != null ? [markerData.collectedBy!] : [],
    );
  }
  
  // 캐시 클리어
  static void clearCache() {
    _markerCache.clear();
    _cacheTimestamps.clear();
    print('🧹 마커 캐시 클리어됨');
  }
  
  // 특정 위치의 캐시만 클리어
  static void clearCacheForLocation(LatLng location) {
    final keysToRemove = <String>[];
    final lat = (location.latitude * 1000).round() / 1000;
    final lng = (location.longitude * 1000).round() / 1000;
    final locationKey = '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
    
    for (final key in _markerCache.keys) {
      if (key.contains(locationKey)) {
        keysToRemove.add(key);
      }
    }
    
    for (final key in keysToRemove) {
      _markerCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    print('🧹 위치별 캐시 클리어됨: ${keysToRemove.length}개');
  }
}

          markers.add(_createMarkerData(post, MarkerType.superPost));

          continue;

        }

        

        // 일반 포스트: 거리 확인

        final distance = _calculateDistance(

          location.latitude, location.longitude,

          post.location.latitude, post.location.longitude,

        );

        if (distance > radiusInKm * 1000) {

          filteredByDistance++;

          continue;

        }

        

        // 포그레벨 확인

        final tileId = post.tileId;

        if (tileId != null && fogLevel1Tiles.contains(tileId)) {

          markers.add(_createMarkerData(post, MarkerType.post));

        } else {

          filteredByFogLevel++;

        }

      }

      

      print('📈 마커 처리 통계:');

      print('  - 총 처리: $processedCount개');

      print('  - 슈퍼포스트: $superPostCount개');

      print('  - 거리로 필터링: $filteredByDistance개');

      print('  - 포그레벨로 필터링: $filteredByFogLevel개');

      print('  - 최종 마커: ${markers.length}개');

      

      return markers;

    });

  }

  

  // 마커 데이터 생성 헬퍼 메서드

  static MarkerData _createMarkerData(PostModel post, MarkerType type) {

    return MarkerData(

      id: post.postId,

      title: post.title,

      description: post.description,

      userId: post.creatorId,

      position: LatLng(post.location.latitude, post.location.longitude),

      createdAt: post.createdAt,

      expiryDate: post.expiresAt,

      data: post.toFirestore(),

      isCollected: post.isCollected,

      collectedBy: post.collectedBy,

      collectedAt: post.collectedAt,

      type: type,

    );

  }

  

  // 포그레벨 1단계 타일들 계산 (캐싱 적용)

  static Future<List<String>> _getFogLevel1Tiles(LatLng location, double radiusInKm) async {

    final cacheKey = '${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';

    

    // 캐시 확인

    if (_fogLevelCache.containsKey(cacheKey) && 

        _fogLevelCacheTimestamps[cacheKey]!.isAfter(DateTime.now().subtract(_fogLevelCacheExpiry))) {

      print('🚀 포그레벨 타일 캐시 사용: $cacheKey');

      return _fogLevelCache[cacheKey]!;

    }

    

    try {

      print('🔄 포그레벨 타일 계산 중: $cacheKey');

      // VisitTileService를 사용하여 포그레벨 1단계 타일 계산

      final surroundingTiles = TileUtils.getKm1SurroundingTiles(location.latitude, location.longitude);

      final fogLevelMap = await VisitTileService.getSurroundingTilesFogLevel(surroundingTiles);

      

      // 포그레벨 1(gray 이상)인 타일들만 필터링

      final fogLevel1Tiles = fogLevelMap.entries

          .where((entry) => entry.value == FogLevel.gray) // clear 체크 제거

          .map((entry) => entry.key)

          .toList();

      

      // 캐시 저장

      _fogLevelCache[cacheKey] = fogLevel1Tiles;

      _fogLevelCacheTimestamps[cacheKey] = DateTime.now();

      

      print('✅ 포그레벨 타일 계산 완료: ${fogLevel1Tiles.length}개');

      return fogLevel1Tiles;

    } catch (e) {

      print('❌ 포그레벨 1단계 타일 계산 실패: $e');

      return [];

    }

  }

  

  // 거리 계산

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {

    const double earthRadius = 6371000; // 지구 반지름 (미터)

    

    final double dLat = _degreesToRadians(lat2 - lat1);

    final double dLon = _degreesToRadians(lon2 - lon1);

    

    final double a = sin(dLat / 2) * sin(dLat / 2) +

        sin(_degreesToRadians(lat1)) * sin(_degreesToRadians(lat2)) * 

        sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    

    return earthRadius * c;

  }

  

  static double _degreesToRadians(double degrees) {

    return degrees * (pi / 180);

  }

  

  // MarkerData를 MarkerModel로 변환

  static MarkerModel convertToMarkerModel(MarkerData markerData) {

    return MarkerModel(

      markerId: markerData.id,

      postId: markerData.id, // MarkerData의 id가 postId와 동일

      title: markerData.title,

      position: markerData.position,

      quantity: 1, // 기본 수량 (실제로는 PostModel에서 가져와야 함)

      creatorId: markerData.userId,

      createdAt: markerData.createdAt,

      expiresAt: markerData.expiryDate ?? DateTime.now().add(const Duration(days: 30)),

      isActive: !markerData.isCollected,

      collectedBy: markerData.collectedBy != null ? [markerData.collectedBy!] : [],

    );

  }

  

  // markers 컬렉션은 더 이상 사용하지 않음 - posts 컬렉션에서 직접 관리



  // markers 컬렉션 관련 메서드들은 더 이상 사용하지 않음

  // posts 컬렉션에서 직접 관리하므로 PostService를 사용하세요



}

