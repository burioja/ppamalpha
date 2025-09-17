import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// 특정 타일의 포그 레벨 가져오기
  static Future<FogLevel> getFogLevelForTile(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) return FogLevel.black;

    try {
      final visitDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .doc(tileId)
          .get();

      if (!visitDoc.exists) {
        return FogLevel.black; // 방문하지 않은 타일
      }

      final data = visitDoc.data()!;
      final visitCount = data['visitCount'] as int? ?? 0;

      // 방문 횟수에 따른 포그 레벨 결정
      if (visitCount >= 10) {
        return FogLevel.clear; // 완전 개방
      } else if (visitCount >= 3) {
        return FogLevel.gray; // 부분 개방
      } else {
        return FogLevel.black; // 제한적 개방
      }
    } catch (e) {
      print('포그 레벨 조회 오류: $e');
      return FogLevel.black;
    }
  }

  /// 포그 레벨 1 타일 ID 목록 가져오기 (캐시됨)
  static Future<List<String>> getFogLevel1TileIdsCached(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('visited_tiles')
          .where('visitCount', isGreaterThanOrEqualTo: 1) // 1회 이상 방문하면 포그레벨 1
          .get();

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