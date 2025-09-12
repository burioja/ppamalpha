import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../utils/tile_utils.dart';
import 'nominatim_service.dart';

/// 타일 기반 방문 기록 관리 서비스
class VisitTileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'visits_tiles';

  /// 현재 위치의 타일 방문 기록 업데이트
  static Future<void> updateCurrentTileVisit(double latitude, double longitude) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final tileId = TileUtils.getTileId(latitude, longitude);
      final now = DateTime.now();
      
      // 30일 이전 데이터는 자동 삭제
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      
      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .collection('visited')
          .doc(tileId)
          .set({
        'tileId': tileId,
        'visitedAt': Timestamp.fromDate(now),
        'fogLevel': 1, // 밝은 영역
        'latitude': latitude,
        'longitude': longitude,
      });

      // 30일 이전 데이터 정리
      await _cleanupOldVisits(user.uid, thirtyDaysAgo);
      
      print('타일 방문 기록 업데이트: $tileId');
    } catch (e) {
      print('타일 방문 기록 업데이트 실패: $e');
    }
  }

  // FogLevel 1 타일 캐시
  static final Map<String, List<String>> _fogLevel1Cache = {};
  static final Map<String, DateTime> _fogLevel1CacheTimestamps = {};
  static const Duration _fogLevel1CacheExpiry = Duration(minutes: 10);
  
  /// FogLevel 1 타일 목록을 캐시와 함께 조회
  static Future<List<String>> getFogLevel1TileIdsCached(String userId) async {
    final cacheKey = userId;
    
    // 캐시 확인
    if (_fogLevel1Cache.containsKey(cacheKey) && 
        _fogLevel1CacheTimestamps[cacheKey]!.isAfter(DateTime.now().subtract(_fogLevel1CacheExpiry))) {
      print('🚀 FogLevel 1 타일 캐시 사용: $cacheKey');
      return _fogLevel1Cache[cacheKey]!;
    }
    
    try {
      print('🔄 FogLevel 1 타일 계산 중: $cacheKey');
      
      // Firestore에서 사용자의 방문 기록 조회
      final visitedTiles = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('visited')
          .get();
      
      final fogLevel1Tiles = <String>[];
      
      for (final doc in visitedTiles.docs) {
        final data = doc.data();
        final fogLevel = data['fogLevel'] as int?;
        
        if (fogLevel == 1) {
          fogLevel1Tiles.add(doc.id);
        }
      }
      
      // 캐시 저장
      _fogLevel1Cache[cacheKey] = fogLevel1Tiles;
      _fogLevel1CacheTimestamps[cacheKey] = DateTime.now();
      
      print('✅ FogLevel 1 타일 계산 완료: ${fogLevel1Tiles.length}개');
      return fogLevel1Tiles;
    } catch (e) {
      print('❌ FogLevel 1 타일 계산 실패: $e');
      return [];
    }
  }

  /// 주변 타일들의 Fog Level 조회
  static Future<Map<String, int>> getSurroundingTilesFogLevel(
    double latitude, 
    double longitude
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final tileIds = TileUtils.getSurroundingTiles(latitude, longitude);
      final fogLevels = <String, int>{};
      
      // 각 타일의 방문 기록 조회
      for (final tileId in tileIds) {
        final doc = await _firestore
            .collection(_collection)
            .doc(user.uid)
            .collection('visited')
            .doc(tileId)
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          final lastVisit = (data['visitedAt'] as Timestamp).toDate();
          final now = DateTime.now();
          final daysSinceVisit = now.difference(lastVisit).inDays;
          
          if (daysSinceVisit <= 7) {
            fogLevels[tileId] = 1; // 밝은 영역 (7일 이내)
          } else if (daysSinceVisit <= 30) {
            fogLevels[tileId] = 2; // 회색 영역 (30일 이내)
          } else {
            fogLevels[tileId] = 3; // 검은 영역 (30일 초과)
          }
        } else {
          fogLevels[tileId] = 3; // 방문 기록 없음 = 검은 영역
        }
      }
      
      return fogLevels;
    } catch (e) {
      print('타일 Fog Level 조회 실패: $e');
      return {};
    }
  }

  /// 30일 이전 방문 기록 정리
  static Future<void> _cleanupOldVisits(String userId, DateTime cutoffDate) async {
    try {
      final oldVisits = await _firestore
          .collection(_collection)
          .doc(userId)
          .collection('visited')
          .where('visitedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final batch = _firestore.batch();
      for (final doc in oldVisits.docs) {
        batch.delete(doc.reference);
      }
      
      if (oldVisits.docs.isNotEmpty) {
        await batch.commit();
        print('오래된 방문 기록 ${oldVisits.docs.length}개 정리 완료');
      }
    } catch (e) {
      print('오래된 방문 기록 정리 실패: $e');
    }
  }

  /// 특정 타일의 방문 기록 조회
  static Future<int> getTileFogLevel(String tileId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 3; // 로그인 안됨 = 검은 영역

      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .collection('visited')
          .doc(tileId)
          .get();
      
      if (!doc.exists) return 3; // 방문 기록 없음 = 검은 영역
      
      final data = doc.data()!;
      final lastVisit = (data['visitedAt'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceVisit = now.difference(lastVisit).inDays;
      
      if (daysSinceVisit <= 7) return 1; // 밝은 영역
      if (daysSinceVisit <= 30) return 2; // 회색 영역
      return 3; // 검은 영역
    } catch (e) {
      print('타일 Fog Level 조회 실패: $e');
      return 3; // 에러 시 검은 영역
    }
  }

  /// 특정 타일의 Fog Level 조회 (현재 위치, 집, 일터 고려)
  static Future<int> getFogLevelForTile(String tileId, {LatLng? currentPosition}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 3; // 로그인 안됨 = 검은 영역

      // 타일 중심점 계산
      final tileCenter = TileUtils.getTileCenter(tileId);
      
      // 1. 현재 위치 1km 반경 체크 (Level 1)
      if (currentPosition != null) {
        final distance = _calculateDistance(currentPosition, tileCenter);
        if (distance <= 1000) { // 1km
          return 1; // 밝은 영역
        }
      }

      // 2. 집 위치 1km 반경 체크 (Level 1)
      final homeLocation = await _getHomeLocation();
      if (homeLocation != null) {
        final distance = _calculateDistance(homeLocation, tileCenter);
        if (distance <= 1000) { // 1km
          return 1; // 밝은 영역
        }
      }

      // 3. 일터 위치들 1km 반경 체크 (Level 1)
      final workLocations = await _getWorkLocations();
      for (final workLocation in workLocations) {
        final distance = _calculateDistance(workLocation, tileCenter);
        if (distance <= 1000) { // 1km
          return 1; // 밝은 영역
        }
      }

      // 4. 과거 방문 기록 체크 (Level 2)
      final doc = await _firestore
          .collection(_collection)
          .doc(user.uid)
          .collection('visited')
          .doc(tileId)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final visitedAt = (data['visitedAt'] as Timestamp).toDate();
        final now = DateTime.now();
        final daysSinceVisit = now.difference(visitedAt).inDays;
        
        if (daysSinceVisit <= 30) {
          return 2; // 회색 영역 (30일 이내 방문)
        }
      }

      return 3; // 검은 영역 (방문하지 않은 지역)
    } catch (e) {
      print('Fog Level 조회 실패: $e');
      return 3; // 에러 시 검은 영역
    }
  }

  /// 현재 위치 가져오기
  static Future<LatLng?> _getCurrentPosition() async {
    try {
      // 실제로는 LocationService에서 가져와야 하지만, 
      // 여기서는 간단히 null 반환 (MapScreen에서 처리)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 집 위치 가져오기
  static Future<LatLng?> _getHomeLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final address = userData?['address'] as String?;
        
        if (address != null && address.isNotEmpty) {
          // 주소를 좌표로 변환 (NominatimService 사용)
          final coords = await _geocodeAddress(address);
          return coords;
        }
      }
      return null;
    } catch (e) {
      print('집 위치 조회 실패: $e');
      return null;
    }
  }

  /// 일터 위치들 가져오기
  static Future<List<LatLng>> _getWorkLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final workplaces = userData?['workplaces'] as List<dynamic>?;
        final workLocations = <LatLng>[];
        
        if (workplaces != null) {
          for (final workplace in workplaces) {
            final workplaceMap = workplace as Map<String, dynamic>?;
            final workplaceAddress = workplaceMap?['address'] as String?;
            
            if (workplaceAddress != null && workplaceAddress.isNotEmpty) {
              final coords = await _geocodeAddress(workplaceAddress);
              if (coords != null) {
                workLocations.add(coords);
              }
            }
          }
        }
        return workLocations;
      }
      return [];
    } catch (e) {
      print('일터 위치 조회 실패: $e');
      return [];
    }
  }

  /// 주소를 좌표로 변환
  static Future<LatLng?> _geocodeAddress(String address) async {
    try {
      // NominatimService 사용 (기존 코드와 동일)
      final coords = await NominatimService.geocode(address);
      return coords;
    } catch (e) {
      print('주소 변환 실패: $e');
      return null;
    }
  }

  /// 두 지점 간 거리 계산 (미터 단위)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    final distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
}
