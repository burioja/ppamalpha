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

  // ✅ 미사용 함수들 삭제됨 (_centerFromAnyTileId, _getKm1TileSizeForLatitude, Web Mercator 변환 함수들)

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

  // ✅ 미사용 함수들 삭제됨 (getVisitedTilePositions, getVisitedTilesInRadius, _calculateDistance, _degreesToRadians)
}