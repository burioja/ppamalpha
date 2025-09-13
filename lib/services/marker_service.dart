import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'visit_tile_service.dart';
import '../core/models/post/post_model.dart';

/// 마커 타입 열거형
enum MarkerType {
  post,        // 일반 포스트
  superPost,   // 슈퍼포스트 (검은 영역에서도 표시)
  user,        // 사용자 마커
}

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
  final MarkerType type; // 마커 타입 추가

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
  
  // 포그레벨 타일 캐시
  static final Map<String, List<String>> _fogLevelCache = {};
  static final Map<String, DateTime> _fogLevelCacheTimestamps = {};
  static const Duration _fogLevelCacheExpiry = Duration(minutes: 10);
  
  // 🚀 실시간 마커 스트림 (posts 컬렉션 기반) - 최적화됨
  static Stream<List<MarkerData>> getMarkersStream({
    required LatLng location,
    required double radiusInKm,
  }) {
    return _firestore
        .collection('posts')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .limit(100) // 🚀 쿼리 제한 추가 (최대 100개)
        .orderBy('createdAt', descending: true) // 🚀 최신 포스트 우선
        .snapshots()
        .asyncMap((snapshot) async {
      print('📊 Firestore에서 ${snapshot.docs.length}개 포스트 조회됨');
      
      // 포그레벨 1단계 타일들 계산 (캐싱 적용)
      final fogLevel1Tiles = await _getFogLevel1Tiles(location, radiusInKm);
      
      List<MarkerData> markers = [];
      int processedCount = 0;
      int filteredByDistance = 0;
      int filteredByFogLevel = 0;
      int superPostCount = 0;
      
      for (var doc in snapshot.docs) {
        processedCount++;
        final post = PostModel.fromFirestore(doc);
        
        // 슈퍼포스트는 거리와 포그레벨 무시
        final isSuperPost = post.reward >= 1000;
        if (isSuperPost) {
          superPostCount++;
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
      final fogLevelMap = await VisitTileService.getSurroundingTilesFogLevel(
        location.latitude, 
        location.longitude
      );
      
      // 포그레벨 1인 타일들만 필터링
      final fogLevel1Tiles = fogLevelMap.entries
          .where((entry) => entry.value == 1)
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
  // markers 컬렉션은 더 이상 사용하지 않음 - posts 컬렉션에서 직접 관리

  // markers 컬렉션 관련 메서드들은 더 이상 사용하지 않음
  // posts 컬렉션에서 직접 관리하므로 PostService를 사용하세요

}
