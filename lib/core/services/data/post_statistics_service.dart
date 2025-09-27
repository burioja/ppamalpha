import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/post/post_model.dart';
import '../../models/post/post_instance_model_simple.dart';

/// 포스트 통계 집계 및 조회 서비스
class PostStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 특정 포스트의 전체 통계 조회
  Future<Map<String, dynamic>> getPostStatistics(String postId) async {
    try {
      debugPrint('📊 PostStatisticsService.getPostStatistics 시작: postId=$postId');

      // 1. 템플릿 기본 정보
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      final post = PostModel.fromFirestore(postDoc);

      // 2. 이 템플릿으로 생성한 모든 마커
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      // 3. 이 템플릿으로 수집된 모든 기록 (post_collections 사용)
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final collections = collectionsQuery.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      // 4. 통계 계산
      final deployments = markersQuery.docs.map((doc) => doc.data()).toList();
      final totalQuantityDeployed = deployments.fold<int>(
        0,
        (sum, marker) => sum + ((marker['totalQuantity'] ?? marker['quantity']) as int? ?? 0),
      );
      final totalCollected = collections.length;
      final totalUsed = collections.where((collection) => collection['status'] == 'USED').length;
      final collectionRate = totalQuantityDeployed > 0 ? totalCollected / totalQuantityDeployed : 0.0;
      final usageRate = totalCollected > 0 ? totalUsed / totalCollected : 0.0;

      // 5. 수집자 분석
      final uniqueCollectors = <String>{};
      final collectionsByUser = <String, int>{};

      for (final collection in collections) {
        final userId = collection['userId'] as String;
        uniqueCollectors.add(userId);
        collectionsByUser[userId] = (collectionsByUser[userId] ?? 0) + 1;
      }

      final topCollectors = collectionsByUser.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 6. 시간대별 패턴 분석
      final collectionsByHour = <int, int>{};
      final collectionsByDay = <String, int>{};

      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final hour = collectedAt.hour;
        collectionsByHour[hour] = (collectionsByHour[hour] ?? 0) + 1;

        final dayOfWeek = _getDayOfWeekKorean(collectedAt.weekday);
        collectionsByDay[dayOfWeek] = (collectionsByDay[dayOfWeek] ?? 0) + 1;
      }

      final result = {
        'template': {
          'postId': post.postId,
          'title': post.title,
          'reward': post.reward,
          'creatorId': post.creatorId,
          'creatorName': post.creatorName,
        },
        'deployments': deployments,
        'collections': collections,

        // 기본 통계
        'totalDeployments': markersQuery.size,
        'totalQuantityDeployed': totalQuantityDeployed,
        'totalCollected': totalCollected,
        'totalUsed': totalUsed,
        'collectionRate': collectionRate,
        'usageRate': usageRate,

        // 수집자 분석
        'collectors': {
          'uniqueCount': uniqueCollectors.length,
          'totalCollections': totalCollected,
          'averagePerUser': uniqueCollectors.isNotEmpty ? totalCollected / uniqueCollectors.length : 0.0,
          'topCollectors': topCollectors.take(5).map((entry) => {
            'userId': '***${entry.key.substring(entry.key.length > 3 ? entry.key.length - 3 : 0)}', // 익명화
            'count': entry.value,
          }).toList(),
        },

        // 시간 패턴
        'timePattern': {
          'hourly': collectionsByHour,
          'daily': collectionsByDay,
        },
      };

      debugPrint('📈 포스트 통계 조회 완료: 배포=${markersQuery.size}, 수집=$totalCollected');
      return result;

    } catch (e) {
      debugPrint('❌ getPostStatistics 오류: $e');
      throw Exception('통계 조회 실패: $e');
    }
  }

  /// 마커별 상세 통계 조회
  Future<Map<String, dynamic>> getMarkerStatistics(String markerId) async {
    try {
      debugPrint('🎯 PostStatisticsService.getMarkerStatistics 시작: markerId=$markerId');

      // 1. 마커 정보
      final markerDoc = await _firestore.collection('markers').doc(markerId).get();
      if (!markerDoc.exists) {
        throw Exception('마커를 찾을 수 없습니다.');
      }

      final markerData = markerDoc.data()!;

      // 2. 이 마커로 수집된 기록들 (post_collections)
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('markerId', isEqualTo: markerId)
          .get();

      final collections = collectionsQuery.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      // 3. 통계 계산
      final collectedCount = collections.length;
      final usedCount = collections.where((collection) => collection['status'] == 'USED').length;

      // 날짜별 수집 패턴
      final collectionsByDate = <String, int>{};
      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final dateKey = '${collectedAt.year}-${collectedAt.month.toString().padLeft(2, '0')}-${collectedAt.day.toString().padLeft(2, '0')}';
        collectionsByDate[dateKey] = (collectionsByDate[dateKey] ?? 0) + 1;
      }

      // 사용자별 수집 패턴
      final collectionsByUser = <String, int>{};
      for (final collection in collections) {
        final userId = collection['userId'] as String;
        collectionsByUser[userId] = (collectionsByUser[userId] ?? 0) + 1;
      }

      final result = {
        'marker': markerData,
        'collections': collections,

        // 기본 통계
        'collectedCount': collectedCount,
        'usedCount': usedCount,
        'usageRate': collectedCount > 0 ? usedCount / collectedCount : 0.0,

        // 패턴 분석
        'collectionsByDate': collectionsByDate,
        'collectionsByUser': collectionsByUser.map((key, value) => MapEntry(
          '***${key.substring(key.length > 3 ? key.length - 3 : 0)}', // 익명화
          value,
        )),
      };

      debugPrint('📊 마커 통계 조회 완료: 수집=$collectedCount, 사용=$usedCount');
      return result;

    } catch (e) {
      debugPrint('❌ getMarkerStatistics 오류: $e');
      throw Exception('마커 통계 조회 실패: $e');
    }
  }

  /// 사용자별 수집 패턴 분석 (창작자 관점)
  Future<Map<String, dynamic>> getCollectorAnalytics(String creatorId) async {
    try {
      debugPrint('👤 PostStatisticsService.getCollectorAnalytics 시작: creatorId=$creatorId');

      // 1. 내 모든 템플릿
      final myPostsQuery = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: creatorId)
          .get();

      if (myPostsQuery.docs.isEmpty) {
        return {
          'uniqueCollectors': [],
          'topCollectors': [],
          'collectionsByRegion': {},
          'collectionTrends': {},
        };
      }

      final postIds = myPostsQuery.docs.map((doc) => doc.id).toList();

      // 2. 내 템플릿들로 수집된 모든 기록 (post_collections)
      final allCollectionsQueries = await Future.wait(
        postIds.map((postId) => _firestore
            .collection('post_collections')
            .where('postId', isEqualTo: postId)
            .get()
        ),
      );

      final allCollections = <Map<String, dynamic>>[];
      for (final query in allCollectionsQueries) {
        allCollections.addAll(
          query.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }),
        );
      }

      // 3. 수집자 분석
      final uniqueCollectors = <String>{};
      final collectorCounts = <String, int>{};

      for (final collection in allCollections) {
        final userId = collection['userId'] as String;
        uniqueCollectors.add(userId);
        collectorCounts[userId] = (collectorCounts[userId] ?? 0) + 1;
      }

      final topCollectors = collectorCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 4. 시간 트렌드 분석
      final collectionTrends = <String, int>{};
      for (final collection in allCollections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final monthKey = '${collectedAt.year}-${collectedAt.month.toString().padLeft(2, '0')}';
        collectionTrends[monthKey] = (collectionTrends[monthKey] ?? 0) + 1;
      }

      final result = {
        // 수집자 분석
        'uniqueCollectors': uniqueCollectors.length,
        'totalCollections': allCollections.length,
        'topCollectors': topCollectors.take(10).map((entry) => {
          'userId': '***${entry.key.substring(entry.key.length > 3 ? entry.key.length - 3 : 0)}', // 익명화
          'count': entry.value,
        }).toList(),

        // 시간 트렌드
        'collectionTrends': collectionTrends,

        // 요약 정보
        'summary': {
          'totalPosts': postIds.length,
          'totalCollections': allCollections.length,
          'averageCollectionsPerPost': postIds.isNotEmpty ? allCollections.length / postIds.length : 0.0,
          'averageCollectionsPerUser': uniqueCollectors.isNotEmpty ? allCollections.length / uniqueCollectors.length : 0.0,
        },
      };

      debugPrint('📈 수집자 분석 완료: 고유 수집자=${uniqueCollectors.length}, 총 수집=${allCollections.length}');
      return result;

    } catch (e) {
      debugPrint('❌ getCollectorAnalytics 오류: $e');
      throw Exception('수집자 분석 실패: $e');
    }
  }

  /// 실시간 포스트 통계 스트림 (post_collections 사용)
  Stream<Map<String, dynamic>> getPostStatisticsStream(String postId) {
    return _firestore
        .collection('post_collections')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .asyncMap((snapshot) async {
      // 실시간 통계 계산
      final collections = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();

      return {
        'totalCollections': collections.length,
        'totalUsed': collections.where((c) => c['status'] == 'USED').length,
        'recentCollections': collections
            .where((c) {
              final collectedAt = (c['collectedAt'] as Timestamp).toDate();
              return DateTime.now().difference(collectedAt).inHours < 24;
            })
            .length,
        'lastUpdated': DateTime.now(),
      };
    });
  }

  String _getDayOfWeekKorean(int weekday) {
    const days = ['', '월', '화', '수', '목', '금', '토', '일'];
    return days[weekday];
  }
}