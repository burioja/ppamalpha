import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../external/osm_fog_service.dart';
import '../../../../core/services/location/nominatim_service.dart';
import '../../../../utils/tile_utils.dart';
import '../../../../core/models/map/fog_level.dart';

/// Fog of War 비즈니스 로직 서비스
/// 
/// **책임**: Fog 계산, 위치 기반 영역 생성
/// **원칙**: 순수 비즈니스 로직만, Firebase 호출 최소화
class FogService {
  // ==================== Fog 재구성 ====================

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

    debugPrint('🌫️ Fog of War 재구성 시작');
    debugPrint('📍 현재 위치: ${currentPosition.latitude}, ${currentPosition.longitude}');
    debugPrint('🏠 집 위치: ${homeLocation?.latitude}, ${homeLocation?.longitude}');
    debugPrint('💼 근무지 개수: ${workLocations.length}');

    // 현재 위치
    ringCircles.add(OSMFogService.createRingCircle(currentPosition));

    // 집 위치
    if (homeLocation != null) {
      allPositions.add(homeLocation);
      ringCircles.add(OSMFogService.createRingCircle(homeLocation));
      debugPrint('✅ 집 위치 추가됨');
    }

    // 일터 위치들
    for (int i = 0; i < workLocations.length; i++) {
      final workLocation = workLocations[i];
      allPositions.add(workLocation);
      ringCircles.add(OSMFogService.createRingCircle(workLocation));
      debugPrint('✅ 근무지 $i 추가됨: ${workLocation.latitude}, ${workLocation.longitude}');
    }

    debugPrint('🎯 총 밝은 영역 개수: ${allPositions.length}');
    debugPrint('✅ Fog of War 재구성 완료');

    return (allPositions, ringCircles);
  }

  // ==================== 위치 로드 ====================

  /// 사용자 위치들(집, 일터) 로드
  /// 
  /// Returns: (homeLocation, workLocations) 튜플
  static Future<(LatLng?, List<LatLng>)> loadUserLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 미로그인');
        return (null, <LatLng>[]);
      }

      // Firestore에서 사용자 데이터 조회
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint('❌ 사용자 문서 없음');
        return (null, <LatLng>[]);
      }

      final userData = userDoc.data();
      LatLng? homeLocation;
      final workLocations = <LatLng>[];

      // ===== 집 주소 로드 =====
      homeLocation = await _loadHomeLocation(userData);

      // ===== 근무지 로드 =====
      workLocations.addAll(await _loadWorkLocations(userData));

      debugPrint('✅ 사용자 위치 로드 완료: 집=${homeLocation != null}, 근무지=${workLocations.length}개');
      return (homeLocation, workLocations);
    } catch (e) {
      debugPrint('❌ 사용자 위치 로드 실패: $e');
      return (null, <LatLng>[]);
    }
  }

  /// 집 주소 로드
  static Future<LatLng?> _loadHomeLocation(Map<String, dynamic>? userData) async {
    if (userData == null) return null;

    // 저장된 GeoPoint 사용 (우선)
    final homeLocationGeo = userData['homeLocation'] as GeoPoint?;
    final secondAddress = userData['secondAddress'] as String?;

    if (homeLocationGeo != null) {
      debugPrint('✅ 집주소 좌표 로드: ${homeLocationGeo.latitude}, ${homeLocationGeo.longitude}');
      if (secondAddress != null && secondAddress.isNotEmpty) {
        debugPrint('   상세주소: $secondAddress');
      }
      return LatLng(homeLocationGeo.latitude, homeLocationGeo.longitude);
    }

    // 구버전: 주소 문자열 geocoding
    final address = userData['address'] as String?;
    if (address != null && address.isNotEmpty) {
      debugPrint('⚠️ 집주소 좌표 미저장 (구버전 데이터)');
      debugPrint('   주소: $address');
      
      final homeCoords = await NominatimService.geocode(address);
      if (homeCoords != null) {
        debugPrint('✅ geocoding 성공: ${homeCoords.latitude}, ${homeCoords.longitude}');
        return homeCoords;
      } else {
        debugPrint('❌ geocoding 실패');
      }
    }

    return null;
  }

  /// 근무지 로드
  static Future<List<LatLng>> _loadWorkLocations(Map<String, dynamic>? userData) async {
    if (userData == null) return [];

    final workLocations = <LatLng>[];
    
    // workplaces 컬렉션에서 로드
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final workplacesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workplaces')
          .get();

      debugPrint('📍 등록된 근무지 수: ${workplacesSnapshot.docs.length}');

      for (final doc in workplacesSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as GeoPoint?;
        
        if (location != null) {
          final workLoc = LatLng(location.latitude, location.longitude);
          workLocations.add(workLoc);
          debugPrint('✅ 근무지 로드: ${location.latitude}, ${location.longitude}');
          
          final name = data['name'] as String?;
          if (name != null && name.isNotEmpty) {
            debugPrint('   이름: $name');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ 근무지 로드 실패: $e');
    }

    return workLocations;
  }

  // ==================== 회색 영역 계산 ====================

  /// 이전 위치 기반 회색 영역(Level 2) 폴리곤 생성
  /// 
  /// [previousPosition]: 이전 위치
  /// Returns: 회색 영역 폴리곤 리스트
  static List<Polygon> buildGrayAreaFromPreviousPosition(LatLng? previousPosition) {
    if (previousPosition == null) return [];

    final grayPolygons = <Polygon>[];
    
    // 타일 ID 계산
    final tileId = TileUtils.getKm1TileId(
      previousPosition.latitude,
      previousPosition.longitude,
    );

    // 타일 경계 계산
    final bounds = TileUtils.getTileBounds(tileId);

    // 폴리곤 생성
    final points = [
      LatLng(bounds['south']!, bounds['west']!),
      LatLng(bounds['north']!, bounds['west']!),
      LatLng(bounds['north']!, bounds['east']!),
      LatLng(bounds['south']!, bounds['east']!),
    ];

    grayPolygons.add(Polygon(
      points: points,
      color: const Color(0x55888888), // 반투명 회색
      borderStrokeWidth: 0,
    ));

    debugPrint('🟦 회색 영역 생성: $tileId');
    return grayPolygons;
  }

  // ==================== Fog Level 계산 ====================

  /// 특정 위치의 Fog Level 계산
  /// 
  /// [position]: 확인할 위치
  /// [level1Centers]: Level 1 중심점들 (현재, 집, 일터)
  /// [level2TileIds]: Level 2 타일 ID들 (30일 방문)
  /// 
  /// Returns: FogLevel (none, level1, level2)
  static FogLevel calculateFogLevel({
    required LatLng position,
    required List<LatLng> level1Centers,
    required Set<String> level2TileIds,
  }) {
    // Level 1 확인 (1km 반경)
    for (final center in level1Centers) {
      if (_isWithinRadius(position, center, 1000)) {
        return FogLevel.clear;
      }
    }

    // Level 2 확인 (타일 기반)
    final tileId = TileUtils.getKm1TileId(
      position.latitude,
      position.longitude,
    );
    
    if (level2TileIds.contains(tileId)) {
      return FogLevel.gray;
    }

    return FogLevel.black;
  }

  /// 두 좌표 간 거리가 반경 내인지 확인
  static bool _isWithinRadius(LatLng point1, LatLng point2, double radiusMeters) {
    const earthRadius = 6371000; // 지구 반경 (미터)
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distance = earthRadius * c;

    return distance <= radiusMeters;
  }

  // ==================== 타일 ID 계산 ====================

  /// 여러 위치의 타일 ID들 계산
  static Set<String> calculateTileIds(List<LatLng> positions) {
    return positions.map((pos) {
      return TileUtils.getKm1TileId(pos.latitude, pos.longitude);
    }).toSet();
  }

  /// 단일 위치의 타일 ID 계산
  static String calculateTileId(LatLng position) {
    return TileUtils.getKm1TileId(position.latitude, position.longitude);
  }

  // ==================== 행동 제한 체크 ====================

  /// 롱프레스(포스트 배포) 가능 여부 체크
  /// 
  /// Level 1 (clear) 영역에서만 포스트 배포 가능
  static bool canLongPress(FogLevel level) {
    return level == FogLevel.clear;
  }

  /// 포스트 수령 가능 여부 체크
  /// 
  /// Level 1 (clear) 영역에서만 포스트 수령 가능
  static bool canCollectPost(FogLevel level) {
    return level == FogLevel.clear;
  }
}

