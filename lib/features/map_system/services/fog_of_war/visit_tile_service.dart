import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/models/map/fog_level.dart';

/// 방문 타일 관리 서비스 (안정형)
class VisitTileService {
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 문서 참조 헬퍼
  static DocumentReference<Map<String, dynamic>> _doc(String uid, String tileId) {
    return _fs.collection('users').doc(uid).collection('visited_tiles').doc(tileId);
  }

  /// A. 방문 업데이트 (idempotent)
  static Future<void> updateCurrentTileVisit(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _doc(user.uid, tileId).set({
        'tileId': tileId,
        'lastVisitTime': FieldValue.serverTimestamp(),
        'visitCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('🔥 updateCurrentTileVisit error: $e');
    }
  }

  /// A-2. 배치 방문 확정 업서트 (idempotent)
  /// 
  /// 직전 Level 1 타일들을 visited(30일)로 확정
  static Future<void> upsertVisitedTiles({
    required String userId,
    required List<String> tileIds,
  }) async {
    if (tileIds.isEmpty) return;

    try {
      final batch = _fs.batch();
      final col = _fs.collection('users').doc(userId).collection('visited_tiles');

      for (final tileId in tileIds) {
        final ref = col.doc(tileId);
        batch.set(ref, {
          'tileId': tileId,
          'lastVisitTime': FieldValue.serverTimestamp(),
          'visitCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('✅ 방문 확정: ${tileIds.length}개 타일 → Firestore 업서트 완료');
      debugPrint('📝 업서트된 타일들: ${tileIds.take(5).join(', ')}${tileIds.length > 5 ? '...' : ''}');
    } catch (e) {
      debugPrint('🔥 upsertVisitedTiles error: $e');
    }
  }

  /// B. 특정 타일의 포그 레벨 조회
  static Future<FogLevel> getFogLevelForTile(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) return FogLevel.black;

    try {
      // 🚩 서버 강제 읽기: Web 캐시/지연 회피
      final snap = await _doc(user.uid, tileId).get(const GetOptions(source: Source.server));
      if (!snap.exists) return FogLevel.black;

      final data = snap.data()!;
      final ts = data['lastVisitTime'] as Timestamp?;
      final lastVisit = ts?.toDate();

      // 🚩 serverTimestamp 전파 중(null) → 방문 카운트 있으면 임시 gray
      if (lastVisit == null) {
        final vc = (data['visitCount'] as num?)?.toInt() ?? 0;
        return vc > 0 ? FogLevel.gray : FogLevel.black;
      }

      final days = DateTime.now().difference(lastVisit).inDays;
      return (days <= 30) ? FogLevel.gray : FogLevel.black;
    } catch (e) {
      debugPrint('🔥 getFogLevelForTile error: $e');
      return FogLevel.black;
    }
  }

  /// tileId를 중심좌표로 환산 - 정확한 계산
  static LatLng _centerFromAnyTileId(String tileId) {
    if (tileId.startsWith('tile_')) {
      // 1km 정확한 그리드 형식: tile_lat_lng
      final parts = tileId.split('_');
      if (parts.length == 3) {
        final tileLat = int.tryParse(parts[1]);
        final tileLng = int.tryParse(parts[2]);
        if (tileLat != null && tileLng != null) {
          // 정확한 타일 크기 계산을 위해 대략적 중심점 사용
          const double approxTileSize = 0.009;
          final centerLat = tileLat * approxTileSize + (approxTileSize / 2);
          
          // 위도별 정확한 타일 크기 계산
          final actualTileSize = _getKm1TileSizeForLatitude(centerLat);
          
          return LatLng(
            tileLat * actualTileSize + (actualTileSize / 2),
            tileLng * actualTileSize + (actualTileSize / 2),
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

  /// 위도에 따른 실제 1km 거리 계산 (도 단위) - TileUtils와 동일한 로직
  static double _getKm1TileSizeForLatitude(double latitude) {
    const double earthRadius = 6371.0; // 지구 반지름 (km)
    const double degreesToRadians = 3.14159265359 / 180.0;
    
    // 위도에 따른 실제 1km 거리 (도 단위)
    final double latRad = latitude * degreesToRadians;
    final double metersPerDegree = earthRadius * 1000 * degreesToRadians * math.cos(latRad);
    return 1000.0 / metersPerDegree; // 1km를 도 단위로 변환
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
    return ((longitude + 180.0) / 360.0 * math.pow(2.0, zoomLevel)).floor();
  }

  static int _latitudeToTileY(double latitude, int zoomLevel) {
    final clampedLat = latitude.clamp(-85.0511, 85.0511);
    final latRad = clampedLat * math.pi / 180.0;
    final y = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0;
    return (y * math.pow(2.0, zoomLevel)).floor();
  }

  static double _tileXToLongitude(int tileX, int zoomLevel) {
    return tileX / math.pow(2.0, zoomLevel) * 360.0 - 180.0;
  }

  static double _tileYToLatitude(int tileY, int zoomLevel) {
    final n = math.pi - 2.0 * math.pi * tileY / math.pow(2.0, zoomLevel);
    final latitude = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return latitude.clamp(-85.0511, 85.0511);
  }

  /// C. 최근 30일 타일 id 목록 (회색 영역 소스)
  static Future<List<String>> getFogLevel1TileIdsCached() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final thirtyDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      final qs = await _fs
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .get(const GetOptions(source: Source.server)); // 🚩 서버 강제

      // lastVisitTime == null 인데 visitCount>0 인 문서가 있으면 임시 포함 (안정성↑)
      final ids = <String>[];
      for (final d in qs.docs) {
        final data = d.data();
        final ts = data['lastVisitTime'] as Timestamp?;
        final vc = (data['visitCount'] as num?)?.toInt() ?? 0;
        if (ts != null || vc > 0) {
          ids.add(d.id);
        }
      }
      return ids;
    } catch (e) {
      debugPrint('🔥 getFogLevel1TileIdsCached error: $e');
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
      final snapshot = await _fs
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

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}