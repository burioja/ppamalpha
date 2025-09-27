import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 데이터 정리 서비스 (관리자용)
class CleanupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 존재하지 않는 포스트를 참조하는 마커들 찾기 및 정리
  Future<Map<String, dynamic>> cleanupOrphanedMarkers({bool dryRun = true}) async {
    try {
      debugPrint('🧹 CleanupService: 고아 마커 정리 시작 (dryRun: $dryRun)');

      // 1. 모든 마커 조회
      final markersSnapshot = await _firestore.collection('markers').get();
      debugPrint('📊 총 마커 개수: ${markersSnapshot.docs.length}');

      if (markersSnapshot.docs.isEmpty) {
        return {
          'status': 'no_markers',
          'message': '마커가 없습니다.',
          'orphaned_count': 0,
        };
      }

      // 2. 고아 마커 찾기
      final orphanedMarkers = <String, Map<String, dynamic>>{};
      int checkedCount = 0;

      for (final markerDoc in markersSnapshot.docs) {
        final markerData = markerDoc.data();
        final postId = markerData['postId'] as String?;

        if (postId == null) {
          debugPrint('⚠️ postId가 없는 마커: ${markerDoc.id}');
          orphanedMarkers[markerDoc.id] = {
            'reason': 'missing_postId',
            'data': markerData,
          };
          continue;
        }

        // 해당 포스트가 존재하는지 확인
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (!postDoc.exists) {
          debugPrint('❌ 존재하지 않는 포스트를 참조하는 마커: ${markerDoc.id} -> $postId');
          orphanedMarkers[markerDoc.id] = {
            'reason': 'post_not_found',
            'postId': postId,
            'data': markerData,
          };
        }

        checkedCount++;
        if (checkedCount % 10 == 0) {
          debugPrint('📝 확인 진행: $checkedCount/${markersSnapshot.docs.length}');
        }
      }

      debugPrint('🔍 고아 마커 발견: ${orphanedMarkers.length}개');

      // 3. 실제 정리 (dryRun이 false인 경우에만)
      if (!dryRun && orphanedMarkers.isNotEmpty) {
        debugPrint('🗑️ 고아 마커 삭제 시작...');

        final batch = _firestore.batch();
        for (final markerId in orphanedMarkers.keys) {
          batch.delete(_firestore.collection('markers').doc(markerId));
        }

        await batch.commit();
        debugPrint('✅ 고아 마커 삭제 완료: ${orphanedMarkers.length}개');
      }

      return {
        'status': 'success',
        'dry_run': dryRun,
        'total_markers': markersSnapshot.docs.length,
        'orphaned_count': orphanedMarkers.length,
        'orphaned_markers': orphanedMarkers,
        'message': dryRun
          ? '${orphanedMarkers.length}개의 고아 마커를 발견했습니다 (삭제하지 않음)'
          : '${orphanedMarkers.length}개의 고아 마커를 삭제했습니다.',
      };

    } catch (e) {
      debugPrint('❌ CleanupService 오류: $e');
      return {
        'status': 'error',
        'message': '정리 작업 실패: $e',
      };
    }
  }

  /// 특정 포스트 ID를 참조하는 모든 마커 찾기
  Future<List<Map<String, dynamic>>> findMarkersForPost(String postId) async {
    try {
      final markersSnapshot = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      return markersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

    } catch (e) {
      debugPrint('❌ findMarkersForPost 오류: $e');
      return [];
    }
  }

  /// Firebase 컬렉션 상태 요약
  Future<Map<String, dynamic>> getCollectionsSummary() async {
    try {
      final collections = ['posts', 'markers', 'post_collections', 'users', 'user_points'];
      final summary = <String, dynamic>{};

      for (final collectionName in collections) {
        try {
          final snapshot = await _firestore.collection(collectionName).limit(1).get();
          summary[collectionName] = {
            'exists': snapshot.docs.isNotEmpty,
            'sample_doc_id': snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null,
          };
        } catch (e) {
          summary[collectionName] = {
            'exists': false,
            'error': e.toString(),
          };
        }
      }

      return summary;
    } catch (e) {
      debugPrint('❌ getCollectionsSummary 오류: $e');
      return {'error': e.toString()};
    }
  }
}