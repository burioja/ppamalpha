import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/external/osm_fog_service.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../services/location/nominatim_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/services/location/nominatim_service.dart';

/// Fog of War 관련 로직을 관리하는 컨트롤러
class FogController {
  /// 모든 위치를 기반으로 Fog of War 재구성
  /// 
  /// [currentPosition]: 현재 위치
  /// [homeLocation]: 집 위치
  /// [workLocations]: 일터 위치들
  /// 
  /// Returns: (allPositions, ringCircles) 튜플
  static (List<LatLng>, List<CircleMarker>) rebuildFogWithUserLocations({
    required LatLng currentPosition,
    LatLng? homeLocation,
    List<LatLng> workLocations = const [],
  }) {
    final allPositions = <LatLng>[currentPosition];
    final ringCircles = <CircleMarker>[];

    debugPrint('포그 오브 워 재구성 시작');
    debugPrint('현재 위치: ${currentPosition.latitude}, ${currentPosition.longitude}');
    debugPrint('집 위치: ${homeLocation?.latitude}, ${homeLocation?.longitude}');
    debugPrint('근무지 개수: ${workLocations.length}');

    // 현재 위치
    ringCircles.add(OSMFogService.createRingCircle(currentPosition));

    // 집 위치
    if (homeLocation != null) {
      allPositions.add(homeLocation);
      ringCircles.add(OSMFogService.createRingCircle(homeLocation));
      debugPrint('집 위치 추가됨');
    }

    // 일터 위치들
    for (int i = 0; i < workLocations.length; i++) {
      final workLocation = workLocations[i];
      allPositions.add(workLocation);
      ringCircles.add(OSMFogService.createRingCircle(workLocation));
      debugPrint('근무지 $i 추가됨: ${workLocation.latitude}, ${workLocation.longitude}');
    }

    debugPrint('총 밝은 영역 개수: ${allPositions.length}');
    debugPrint('포그 오브 워 재구성 완료');

    return (allPositions, ringCircles);
  }

  /// 사용자 위치들(집, 일터) 로드
  /// 
  /// Returns: (homeLocation, workLocations) 튜플
  static Future<(LatLng?, List<LatLng>)> loadUserLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return (null, []);

      // 사용자 프로필에서 집주소 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return (null, []);

      final userData = userDoc.data();
      LatLng? homeLocation;
      final workLocations = <LatLng>[];

      // ===== 집 주소 로드 =====
      final homeLocationGeo = userData?['homeLocation'] as GeoPoint?;
      final secondAddress = userData?['secondAddress'] as String?;

      if (homeLocationGeo != null) {
        // 저장된 GeoPoint 직접 사용
        debugPrint('✅ 집주소 좌표 로드: ${homeLocationGeo.latitude}, ${homeLocationGeo.longitude}');
        if (secondAddress != null && secondAddress.isNotEmpty) {
          debugPrint('   상세주소: $secondAddress');
        }
        homeLocation = LatLng(homeLocationGeo.latitude, homeLocationGeo.longitude);
      } else {
        // 구버전 데이터: 주소 문자열만 있는 경우
        final address = userData?['address'] as String?;
        debugPrint('⚠️ 집주소 좌표 미저장 (구버전 데이터)');
        debugPrint('   주소: $address');

        if (address != null && address.isNotEmpty) {
          final homeCoords = await NominatimService.geocode(address);
          if (homeCoords != null) {
            debugPrint('✅ geocoding 성공: ${homeCoords.latitude}, ${homeCoords.longitude}');
            homeLocation = homeCoords;
          } else {
            debugPrint('❌ geocoding 실패 - 프로필에서 주소를 다시 설정하세요');
          }
        } else {
          debugPrint('❌ 집주소 정보 없음');
        }
      }

      // ===== 일터 주소 로드 =====
      final workplaceId = userData?['workplaceId'] as String?;

      if (workplaceId != null && workplaceId.isNotEmpty) {
        debugPrint('📍 일터 로드 시도: $workplaceId');

        // places 컬렉션에서 일터 정보 가져오기
        final placeDoc = await FirebaseFirestore.instance
            .collection('places')
            .doc(workplaceId)
            .get();

        if (placeDoc.exists) {
          final placeData = placeDoc.data();
          final workLocation = placeData?['location'] as GeoPoint?;

          if (workLocation != null) {
            // 저장된 GeoPoint 직접 사용
            debugPrint('✅ 일터 좌표 로드: ${workLocation.latitude}, ${workLocation.longitude}');
            workLocations.add(LatLng(workLocation.latitude, workLocation.longitude));
          } else {
            // 구버전: 주소만 있는 경우 geocoding 시도
            final workAddress = placeData?['address'] as String?;
            debugPrint('⚠️ 일터 좌표 미저장 (구버전 데이터)');
            debugPrint('   주소: $workAddress');

            if (workAddress != null && workAddress.isNotEmpty) {
              final workCoords = await NominatimService.geocode(workAddress);
              if (workCoords != null) {
                debugPrint('✅ geocoding 성공: ${workCoords.latitude}, ${workCoords.longitude}');
                workLocations.add(workCoords);
              } else {
                debugPrint('❌ geocoding 실패');
              }
            }
          }
        } else {
          debugPrint('❌ 일터 정보 없음 (placeId: $workplaceId)');
        }
      } else {
        debugPrint('일터 미설정');
      }

      debugPrint('최종 일터 좌표 개수: ${workLocations.length}');
      return (homeLocation, workLocations);
    } catch (e) {
      debugPrint('사용자 위치 로드 실패: $e');
      return (null, []);
    }
  }

  /// 과거 방문 위치들 로드 및 회색 영역 생성
  /// 
  /// Returns: 회색 영역 폴리곤 리스트
  static Future<List<Polygon>> loadVisitedLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // 30일 이내 방문 기록 가져오기
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
        // 타일 ID에서 좌표 추출
        final position = _extractPositionFromTileId(tileId);
        if (position != null) {
          visitedPositions.add(position);
        }
      }

      debugPrint('과거 방문 위치 개수: ${visitedPositions.length}');
      
      // 회색 영역 생성
      return OSMFogService.createGrayAreas(visitedPositions);
    } catch (e) {
      debugPrint('방문 위치 로드 실패: $e');
      return [];
    }
  }

  /// 타일 ID에서 중심 좌표 추출
  static LatLng? _extractPositionFromTileId(String tileId) {
    try {
      // 타일 ID 형식: "lat_lng" (예: "37.5_126.9")
      final parts = tileId.split('_');
      if (parts.length == 2) {
        final lat = double.parse(parts[0]);
        final lng = double.parse(parts[1]);
        return LatLng(lat, lng);
      }
    } catch (e) {
      debugPrint('타일 ID 파싱 실패: $tileId, $e');
    }
    return null;
  }

  /// 현재 위치의 타일 방문 기록 업데이트
  static Future<void> updateCurrentTileVisit(LatLng position) async {
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    debugPrint('타일 방문 기록 업데이트: $tileId');
    await VisitTileService.updateCurrentTileVisit(tileId);
  }

  /// 이전 위치를 포함한 회색 영역 업데이트
  static Future<List<Polygon>> updateGrayAreasWithPreviousPosition(
    LatLng? previousPosition,
  ) async {
    if (previousPosition == null) {
      return await loadVisitedLocations();
    }

    try {
      final baseGrayAreas = await loadVisitedLocations();
      final previousGrayArea = OSMFogService.createGrayAreas([previousPosition]);
      
      return [...baseGrayAreas, ...previousGrayArea];
    } catch (e) {
      debugPrint('회색 영역 업데이트 실패: $e');
      return [];
    }
  }
}

