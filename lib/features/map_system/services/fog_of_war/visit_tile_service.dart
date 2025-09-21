import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/map/fog_level.dart';

/// 방문 타일 관리 서비스
class VisitTileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 타일 방문 업데이트
  static Future<void> updateCurrentTileVisit(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final visitDoc = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .doc(tileId);

      await visitDoc.set({
        'tileId': tileId,
        'lastVisitTime': FieldValue.serverTimestamp(),
        'visitCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      print('타일 방문 업데이트 오류: $e');
    }
  }

  /// 특정 타일의 포그 레벨 가져오기 (과거 데이터 호환 폴백 포함)
  static Future<FogLevel> getFogLevelForTile(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) return FogLevel.black;

    Future<FogLevel> _fetch(String docId) async {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .doc(docId)
          .get(const GetOptions(source: Source.server));

      if (!snap.exists) return FogLevel.black;
      final data = snap.data()!;
      final ts = data['lastVisitTime'] as Timestamp?;
      final t = ts?.toDate();

      if (t == null) {
        final cnt = (data['visitCount'] as num?)?.toInt() ?? 0;
        return cnt > 0 ? FogLevel.gray : FogLevel.black;
      }
      final d = DateTime.now().difference(t).inDays;
      return d <= 30 ? FogLevel.gray : FogLevel.black;
    }

    try {
      print('🔍 포그레벨 조회: $tileId');
      
      // 1차: 현재 스킴 ID (1km 근사 그리드)
      final primary = await _fetch(tileId);
      print('  - 1차 조회 결과: $primary');
      if (primary != FogLevel.black) return primary;

      // 2차: 과거 스킴 ID로 폴백 (Web Mercator XYZ)
      final latLng = _centerFromAnyTileId(tileId);
      final legacyId = _xyz18Id(latLng.latitude, latLng.longitude);
      print('  - 변환된 좌표: ${latLng.latitude}, ${latLng.longitude}');
      print('  - 과거 스킴 ID: $legacyId');
      
      if (legacyId != null && legacyId != tileId) {
        final legacy = await _fetch(legacyId);
        print('  - 2차 조회 결과: $legacy');
        if (legacy != FogLevel.black) return legacy;
      }

      print('  - 최종 결과: $FogLevel.black');
      return FogLevel.black;
    } catch (e) {
      print('포그 레벨 조회 오류: $e');
      return FogLevel.black;
    }
  }

  /// tileId를 중심좌표로 환산 (현재 스킴이 km1deg라 가정)
  static LatLng _centerFromAnyTileId(String tileId) {
    if (tileId.startsWith('tile_')) {
      // 1km 근사 그리드 형식: tile_lat_lng
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
    
    // Web Mercator XYZ 형식: x_y_z
    final parts = tileId.split('_');
    if (parts.length == 3) {
      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      final z = int.tryParse(parts[2]);
      if (x != null && y != null && z != null) {
        final lat = _tileYToLatitude(y, z);
        final lng = _tileXToLongitude(x, z);
        return LatLng(lat, lng);
      }
    }
    
    return LatLng(0, 0); // 안전장치
  }

  /// Web Mercator XYZ 18레벨 타일 ID 생성
  static String? _xyz18Id(double lat, double lng) {
    try {
      final x = _longitudeToTileX(lng, 18);
      final y = _latitudeToTileY(lat, 18);
      return '${x}_${y}_18';
    } catch (_) {
      return null;
    }
  }

  /// Web Mercator 변환 함수들
  static int _longitudeToTileX(double longitude, int zoomLevel) {
    return ((longitude + 180.0) / 360.0 * pow(2.0, zoomLevel)).floor();
  }

  static int _latitudeToTileY(double latitude, int zoomLevel) {
    final clampedLat = latitude.clamp(-85.0511, 85.0511);
    final latRad = clampedLat * pi / 180.0;
    final y = (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0;
    return (y * pow(2.0, zoomLevel)).floor();
  }

  static double _tileXToLongitude(int tileX, int zoomLevel) {
    return tileX / pow(2.0, zoomLevel) * 360.0 - 180.0;
  }

  static double _tileYToLatitude(int tileY, int zoomLevel) {
    final n = pi - 2.0 * pi * tileY / pow(2.0, zoomLevel);
    final latitude = 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
    return latitude.clamp(-85.0511, 85.0511);
  }

  /// 포그 레벨 1 타일 ID 목록 가져오기 (캐시됨)
  static Future<List<String>> getFogLevel1TileIdsCached(String userId) async {
    try {
      final thirtyDaysAgo = Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)));
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: thirtyDaysAgo) // 30일 이내 방문
          .get(const GetOptions(source: Source.server)); // 서버 강제

      print('🔍 포그레벨 1 타일 조회: ${snapshot.docs.length}개');
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('포그 레벨 1 타일 목록 조회 오류: $e');
      return [];
    }
  }

  /// 주변 타일들의 포그 레벨 가져오기
  static Future<Map<String, FogLevel>> getSurroundingTilesFogLevel(
    List<String> tileIds,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final Map<String, FogLevel> fogLevels = {};

      // 배치로 조회하여 성능 최적화
      const int batchSize = 10;
      for (int i = 0; i < tileIds.length; i += batchSize) {
        final batch = tileIds.skip(i).take(batchSize).toList();

        final futures = batch.map((tileId) async {
          final fogLevel = await getFogLevelForTile(tileId);
          return MapEntry(tileId, fogLevel);
        });

        final results = await Future.wait(futures);
        for (final entry in results) {
          fogLevels[entry.key] = entry.value;
        }
      }

      return fogLevels;
    } catch (e) {
      print('주변 타일 포그 레벨 조회 오류: $e');
      return {};
    }
  }

  /// 방문한 모든 타일 위치 가져오기
  static Future<List<Map<String, dynamic>>> getVisitedTilePositions() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tileId': doc.id,
          'visitCount': data['visitCount'] ?? 0,
          'lastVisitTime': data['lastVisitTime'],
        };
      }).toList();
    } catch (e) {
      print('방문한 타일 위치 조회 오류: $e');
      return [];
    }
  }

  /// 특정 반경 내의 방문한 타일들 가져오기
  static Future<List<String>> getVisitedTilesInRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final visitedTiles = await getVisitedTilePositions();
      final List<String> tilesInRadius = [];

      for (final tile in visitedTiles) {
        final tileId = tile['tileId'] as String;

        // 타일 ID에서 위도/경도 추출 (타일 ID 형식에 따라 조정 필요)
        final parts = tileId.split('_');
        if (parts.length >= 2) {
          try {
            final tileLat = double.parse(parts[0]);
            final tileLng = double.parse(parts[1]);

            final distance = _calculateDistance(
              centerLat, centerLng, tileLat, tileLng,
            );

            if (distance <= radiusKm) {
              tilesInRadius.add(tileId);
            }
          } catch (e) {
            print('타일 좌표 파싱 오류: $e');
          }
        }
      }

      return tilesInRadius;
    } catch (e) {
      print('반경 내 방문 타일 조회 오류: $e');
      return [];
    }
  }

  /// 두 지점 간 거리 계산 (킬로미터)
  static double _calculateDistance(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const double earthRadius = 6371; // km

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
}