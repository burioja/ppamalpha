import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/external/osm_fog_service.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/models/map/fog_level.dart';
import '../services/fog_of_war/visit_tile_service.dart';

/// Fog of War 시스템 전체를 관리하는 Handler
/// 
/// map_screen.dart에서 분리한 Fog 관련 모든 기능
class MapFogHandler {
  // Fog of War 상태
  List<Polygon> grayPolygons = [];
  List<CircleMarker> ringCircles = [];
  Set<String> currentFogLevel1TileIds = {};
  DateTime? fogLevel1CacheTimestamp;
  Map<String, int> tileFogLevels = {};
  Set<String> lastFogLevel1Tiles = {};
  
  static const Duration fogLevel1CacheExpiry = Duration(minutes: 5);

  /// Fog of War 재구성
  void rebuildFogWithUserLocations({
    required LatLng currentPosition,
    LatLng? homeLocation,
    required List<LatLng> workLocations,
  }) {
    final allPositions = <LatLng>[currentPosition];
    final newRingCircles = <CircleMarker>[];

    debugPrint('포그 오브 워 재구성 시작');
    debugPrint('현재 위치: ${currentPosition.latitude}, ${currentPosition.longitude}');
    debugPrint('집 위치: ${homeLocation?.latitude}, ${homeLocation?.longitude}');
    debugPrint('근무지 개수: ${workLocations.length}');

    // 현재 위치
    newRingCircles.add(OSMFogService.createRingCircle(currentPosition));

    // 집 위치
    if (homeLocation != null) {
      allPositions.add(homeLocation);
      newRingCircles.add(OSMFogService.createRingCircle(homeLocation));
      debugPrint('집 위치 추가됨');
    }

    // 일터 위치들
    for (int i = 0; i < workLocations.length; i++) {
      final workLocation = workLocations[i];
      allPositions.add(workLocation);
      newRingCircles.add(OSMFogService.createRingCircle(workLocation));
      debugPrint('근무지 $i 추가됨: ${workLocation.latitude}, ${workLocation.longitude}');
    }

    debugPrint('총 밝은 영역 개수: ${allPositions.length}');
    ringCircles = newRingCircles;
    debugPrint('포그 오브 워 재구성 완료');
  }

  /// 사용자 위치들 (집/일터) 로드
  Future<(LatLng?, List<LatLng>)> loadUserLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return (null, <LatLng>[]);

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return (null, <LatLng>[]);

      final userData = userDoc.data();
      LatLng? homeLocation;
      final workLocations = <LatLng>[];

      // ===== 집 주소 로드 =====
      final homeLocationGeo = userData?['homeLocation'] as GeoPoint?;
      final secondAddress = userData?['secondAddress'] as String?;

      if (homeLocationGeo != null) {
        debugPrint('✅ 집주소 좌표 로드: ${homeLocationGeo.latitude}, ${homeLocationGeo.longitude}');
        if (secondAddress != null && secondAddress.isNotEmpty) {
          debugPrint('   상세주소: $secondAddress');
        }
        homeLocation = LatLng(homeLocationGeo.latitude, homeLocationGeo.longitude);
      } else {
        final address = userData?['address'] as String?;
        debugPrint('⚠️ 집주소 좌표 미저장 (구버전 데이터)');
        debugPrint('   주소: $address');

        if (address != null && address.isNotEmpty) {
          final homeCoords = await NominatimService.geocode(address);
          if (homeCoords != null) {
            debugPrint('✅ geocoding 성공: ${homeCoords.latitude}, ${homeCoords.longitude}');
            homeLocation = homeCoords;
          } else {
            debugPrint('❌ geocoding 실패');
          }
        }
      }

      // ===== 일터 주소 로드 =====
      final workplaceId = userData?['workplaceId'] as String?;

      if (workplaceId != null && workplaceId.isNotEmpty) {
        debugPrint('📍 일터 로드 시도: $workplaceId');

        final placeDoc = await FirebaseFirestore.instance
            .collection('places')
            .doc(workplaceId)
            .get();

        if (placeDoc.exists) {
          final placeData = placeDoc.data();
          final workLocation = placeData?['location'] as GeoPoint?;

          if (workLocation != null) {
            debugPrint('✅ 일터 좌표 로드: ${workLocation.latitude}, ${workLocation.longitude}');
            workLocations.add(LatLng(workLocation.latitude, workLocation.longitude));
          } else {
            final workAddress = placeData?['address'] as String?;
            debugPrint('⚠️ 일터 좌표 미저장 (구버전 데이터)');

            if (workAddress != null && workAddress.isNotEmpty) {
              final workCoords = await NominatimService.geocode(workAddress);
              if (workCoords != null) {
                debugPrint('✅ geocoding 성공');
                workLocations.add(workCoords);
              }
            }
          }
        }
      }

      debugPrint('최종 일터 좌표 개수: ${workLocations.length}');
      return (homeLocation, workLocations);
    } catch (e) {
      debugPrint('사용자 위치 로드 실패: $e');
      return (null, <LatLng>[]);
    }
  }

  /// 과거 방문 위치 로드
  Future<void> loadVisitedLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final visitedTiles = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final visitedPositions = <LatLng>[];
      
      for (final doc in visitedTiles.docs) {
        final tileId = doc.id;
        final position = _extractPositionFromTileId(tileId);
        if (position != null) {
          visitedPositions.add(position);
        }
      }

      debugPrint('과거 방문 위치 개수: ${visitedPositions.length}');
      grayPolygons = OSMFogService.createGrayAreas(visitedPositions);
    } catch (e) {
      debugPrint('방문 위치 로드 실패: $e');
    }
  }

  /// 타일 ID에서 좌표 추출
  LatLng? _extractPositionFromTileId(String tileId) {
    try {
      if (tileId.startsWith('tile_')) {
        final parts = tileId.split('_');
        if (parts.length == 3) {
          final tileLat = int.tryParse(parts[1]);
          final tileLng = int.tryParse(parts[2]);
          if (tileLat != null && tileLng != null) {
            const double tileSize = 0.009;
            return LatLng(
              tileLat * tileSize + (tileSize / 2),
              tileLng * tileSize + (tileSize / 2),
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('타일 ID에서 좌표 추출 실패: $e');
      return null;
    }
  }

  /// 이전 위치를 포함한 회색 영역 업데이트
  Future<void> updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
    if (previousPosition == null) {
      await loadVisitedLocations();
      return;
    }

    try {
      await loadVisitedLocations();
      final previousGrayArea = OSMFogService.createGrayAreas([previousPosition]);
      grayPolygons = [...grayPolygons, ...previousGrayArea];
    } catch (e) {
      debugPrint('회색 영역 업데이트 실패: $e');
    }
  }

  /// 로컬 Fog Level 1 타일 설정
  void setLevel1TileLocally(String tileId) {
    currentFogLevel1TileIds.add(tileId);
    fogLevel1CacheTimestamp = DateTime.now();
  }

  /// Fog Level 1 캐시 초기화
  void clearFogLevel1Cache() {
    currentFogLevel1TileIds.clear();
    fogLevel1CacheTimestamp = null;
  }

  /// 만료된 캐시 확인 및 초기화
  void checkAndClearExpiredFogLevel1Cache() {
    if (fogLevel1CacheTimestamp != null) {
      final elapsed = DateTime.now().difference(fogLevel1CacheTimestamp!);
      if (elapsed > fogLevel1CacheExpiry) {
        clearFogLevel1Cache();
      }
    }
  }

  /// Fog Level 1 캐시 타임스탬프 업데이트
  void updateFogLevel1CacheTimestamp() {
    fogLevel1CacheTimestamp = DateTime.now();
  }

  /// 현재 위치의 Fog Level 1 타일들 계산
  Future<Set<String>> getCurrentFogLevel1Tiles(LatLng center) async {
    try {
      checkAndClearExpiredFogLevel1Cache();
      
      final surroundingTiles = TileUtils.getKm1SurroundingTiles(center.latitude, center.longitude);
      final fogLevel1Tiles = <String>{};
      
      debugPrint('🔍 Fog Level 1+2 타일 계산 시작:');
      debugPrint('  - 중심 위치: ${center.latitude}, ${center.longitude}');
      debugPrint('  - 주변 타일 개수: ${surroundingTiles.length}');
      debugPrint('  - 로컬 캐시 타일 개수: ${currentFogLevel1TileIds.length}');
      
      for (final tileId in surroundingTiles) {
        final tileCenter = TileUtils.getKm1TileCenter(tileId);
        final distToCenterKm = _calculateDistanceKm(center, tileCenter);
        
        final tileBounds = TileUtils.getKm1TileBounds(tileId);
        final tileRadiusKm = _calculateTileRadiusKm(tileBounds);
        
        debugPrint('  - 타일 $tileId: 중심거리 ${distToCenterKm.toStringAsFixed(2)}km');
        
        if (distToCenterKm <= (1.0 + tileRadiusKm)) {
          fogLevel1Tiles.add(tileId);
          debugPrint('    ✅ 1km 이내 - Fog Level 1');
          if (!currentFogLevel1TileIds.contains(tileId)) {
            currentFogLevel1TileIds.add(tileId);
          }
        } else {
          final fogLevel = await VisitTileService.getFogLevelForTile(tileId);
          debugPrint('    🔍 1km 밖 - Fog Level: $fogLevel');
          
          if (fogLevel == FogLevel.clear || fogLevel == FogLevel.gray) {
            fogLevel1Tiles.add(tileId);
            if (!currentFogLevel1TileIds.contains(tileId)) {
              currentFogLevel1TileIds.add(tileId);
            }
          } else {
            if (currentFogLevel1TileIds.contains(tileId)) {
              currentFogLevel1TileIds.remove(tileId);
              debugPrint('    🗑️ 로컬 캐시에서 제거: $tileId');
            }
          }
        }
      }

      debugPrint('🔍 최종 Fog Level 1+2 타일 개수: ${fogLevel1Tiles.length}');
      return fogLevel1Tiles;
    } catch (e) {
      debugPrint('❌ Fog Level 1 타일 계산 실패: $e');
      return {};
    }
  }

  /// 거리 계산 (km)
  double _calculateDistanceKm(LatLng from, LatLng to) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);

    final a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        from.latitude.toRadians().cos() *
        to.latitude.toRadians().cos() *
        (dLng / 2).sin() *
        (dLng / 2).sin();

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// 타일 반지름 계산 (km)
  double _calculateTileRadiusKm(Map<String, double> tileBounds) {
    final latDiff = tileBounds['north']! - tileBounds['south']!;
    final lngDiff = tileBounds['east']! - tileBounds['west']!;
    final diagonal = sqrt(latDiff * latDiff + lngDiff * lngDiff);
    return (diagonal / 2.0) * 111.0;
  }

  double _toRadians(double degree) => degree * pi / 180;
}

// Extension methods
extension on double {
  double toRadians() => this * pi / 180;
  double sin() => math.sin(this);
  double cos() => math.cos(this);
}

double atan2(double y, double x) => math.atan2(y, x);
double sqrt(double x) => math.sqrt(x);
const pi = math.pi;

