import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/post/post_model.dart';

/// 플레이스 통계 집계 및 조회 서비스
class PlaceStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 특정 플레이스의 전체 통계 조회
  Future<Map<String, dynamic>> getPlaceStatistics(String placeId) async {
    try {
      debugPrint('📊 PlaceStatisticsService.getPlaceStatistics 시작: placeId=$placeId');

      // 1. 플레이스 기본 정보
      final placeDoc = await _firestore.collection('places').doc(placeId).get();
      if (!placeDoc.exists) {
        throw Exception('플레이스를 찾을 수 없습니다.');
      }

      final placeData = placeDoc.data()!;

      // 2. 이 플레이스에 배포된 모든 마커
      final markersQuery = await _firestore
          .collection('markers')
          .where('placeId', isEqualTo: placeId)
          .get();

      if (markersQuery.docs.isEmpty) {
        return _getEmptyStatistics(placeData);
      }

      // 3. 마커들의 postId 수집
      final markerDocs = markersQuery.docs;
      final postIds = <String>{};
      final markersByPost = <String, List<Map<String, dynamic>>>{};

      for (final markerDoc in markerDocs) {
        final markerData = markerDoc.data();
        final postId = markerData['postId'] as String;
        postIds.add(postId);

        if (!markersByPost.containsKey(postId)) {
          markersByPost[postId] = [];
        }
        markersByPost[postId]!.add({'id': markerDoc.id, ...markerData});
      }

      // 4. 포스트 정보 가져오기
      final posts = <PostModel>[];
      for (final postId in postIds) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          posts.add(PostModel.fromFirestore(postDoc));
        }
      }

      // 5. 모든 수집 기록 가져오기
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

      // 6. 통계 계산
      final totalQuantityDeployed = markerDocs.fold<int>(
        0,
        (sum, marker) => sum + ((marker.data()['totalQuantity'] ?? marker.data()['quantity']) as int? ?? 0),
      );
      final totalCollected = allCollections.length;
      final totalUsed = allCollections.where((collection) => collection['status'] == 'USED').length;
      final collectionRate = totalQuantityDeployed > 0 ? totalCollected / totalQuantityDeployed : 0.0;
      final usageRate = totalCollected > 0 ? totalUsed / totalCollected : 0.0;

      // 7. 수집자 분석
      final uniqueCollectors = <String>{};
      final collectionsByUser = <String, int>{};

      for (final collection in allCollections) {
        final userId = collection['userId'] as String;
        uniqueCollectors.add(userId);
        collectionsByUser[userId] = (collectionsByUser[userId] ?? 0) + 1;
      }

      final topCollectors = collectionsByUser.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // 8. 시간대별 패턴 분석
      final collectionsByHour = <String, int>{};
      final collectionsByDay = <String, int>{};

      for (final collection in allCollections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final hour = collectedAt.hour;
        collectionsByHour[hour.toString()] = (collectionsByHour[hour.toString()] ?? 0) + 1;

        final dayOfWeek = _getDayOfWeekKorean(collectedAt.weekday);
        collectionsByDay[dayOfWeek] = (collectionsByDay[dayOfWeek] ?? 0) + 1;
      }

      // 9. 포스트별 통계
      final postStatistics = <Map<String, dynamic>>[];
      for (final post in posts) {
        final postCollections = allCollections.where((c) => c['postId'] == post.postId).toList();
        final postMarkers = markersByPost[post.postId] ?? [];
        final postQuantity = postMarkers.fold<int>(
          0,
          (sum, marker) => sum + ((marker['totalQuantity'] ?? marker['quantity']) as int? ?? 0),
        );

        postStatistics.add({
          'post': post,
          'markers': postMarkers.length,
          'totalQuantity': postQuantity,
          'collected': postCollections.length,
          'collectionRate': postQuantity > 0 ? postCollections.length / postQuantity : 0.0,
        });
      }

      // 수집률 기준 정렬
      postStatistics.sort((a, b) => (b['collectionRate'] as double).compareTo(a['collectionRate'] as double));

      final result = {
        'place': placeData,

        // 기본 통계
        'totalPosts': posts.length,
        'totalDeployments': markerDocs.length,
        'totalQuantityDeployed': totalQuantityDeployed,
        'totalCollected': totalCollected,
        'totalUsed': totalUsed,
        'collectionRate': collectionRate,
        'usageRate': usageRate,

        // 포스트별 통계
        'postStatistics': postStatistics,
        'topPerformingPost': postStatistics.isNotEmpty ? postStatistics.first : null,
        'worstPerformingPost': postStatistics.isNotEmpty ? postStatistics.last : null,

        // 수집자 분석
        'collectors': {
          'uniqueCount': uniqueCollectors.length,
          'totalCollections': totalCollected,
          'averagePerUser': uniqueCollectors.isNotEmpty ? totalCollected / uniqueCollectors.length : 0.0,
          'topCollectors': topCollectors.take(5).map((entry) => {
            'userId': '***${entry.key.substring(entry.key.length > 3 ? entry.key.length - 3 : 0)}',
            'count': entry.value,
          }).toList(),
        },

        // 시간 패턴
        'timePattern': {
          'hourly': collectionsByHour,
          'daily': collectionsByDay,
        },

        // 수집 기록
        'collections': allCollections,
      };

      debugPrint('📈 플레이스 통계 조회 완료: 포스트=${posts.length}, 배포=${markerDocs.length}, 수집=$totalCollected');
      return result;

    } catch (e) {
      debugPrint('❌ getPlaceStatistics 오류: $e');
      throw Exception('통계 조회 실패: $e');
    }
  }

  Map<String, dynamic> _getEmptyStatistics(Map<String, dynamic> placeData) {
    return {
      'place': placeData,
      'totalPosts': 0,
      'totalDeployments': 0,
      'totalQuantityDeployed': 0,
      'totalCollected': 0,
      'totalUsed': 0,
      'collectionRate': 0.0,
      'usageRate': 0.0,
      'postStatistics': [],
      'topPerformingPost': null,
      'worstPerformingPost': null,
      'collectors': {
        'uniqueCount': 0,
        'totalCollections': 0,
        'averagePerUser': 0.0,
        'topCollectors': [],
      },
      'timePattern': {
        'hourly': <String, int>{},
        'daily': <String, int>{},
      },
      'collections': [],
    };
  }

  String _getDayOfWeekKorean(int weekday) {
    const days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    return days[weekday - 1];
  }

  /// 시간 분석 (월별 트렌드, 요일/시간대 분석)
  Future<Map<String, dynamic>> getTimeAnalytics(String placeId) async {
    try {
      final stats = await getPlaceStatistics(placeId);
      final collections = stats['collections'] as List<Map<String, dynamic>>;

      if (collections.isEmpty) {
        return {
          'monthlyTrend': <String, int>{},
          'weekdayVsWeekend': {'weekday': 0, 'weekend': 0},
          'hourlyRate': <String, int>{},
        };
      }

      // 월별 트렌드
      final monthlyTrend = <String, int>{};
      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final monthKey = '${collectedAt.year}-${collectedAt.month.toString().padLeft(2, '0')}';
        monthlyTrend[monthKey] = (monthlyTrend[monthKey] ?? 0) + 1;
      }

      // 평일 vs 주말
      int weekdayCount = 0;
      int weekendCount = 0;
      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        if (collectedAt.weekday == 6 || collectedAt.weekday == 7) {
          weekendCount++;
        } else {
          weekdayCount++;
        }
      }

      // 시간대별 수집률
      final hourlyRate = <String, int>{};
      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
        final hour = collectedAt.hour.toString();
        hourlyRate[hour] = (hourlyRate[hour] ?? 0) + 1;
      }

      return {
        'monthlyTrend': monthlyTrend,
        'weekdayVsWeekend': {
          'weekday': weekdayCount,
          'weekend': weekendCount,
        },
        'hourlyRate': hourlyRate,
      };

    } catch (e) {
      debugPrint('❌ getTimeAnalytics 오류: $e');
      throw Exception('시간 분석 실패: $e');
    }
  }

  /// 수집자 분석
  Future<Map<String, dynamic>> getCollectorAnalytics(String placeId) async {
    try {
      final stats = await getPlaceStatistics(placeId);
      return stats['collectors'] as Map<String, dynamic>;

    } catch (e) {
      debugPrint('❌ getCollectorAnalytics 오류: $e');
      throw Exception('수집자 분석 실패: $e');
    }
  }

  /// 성과 분석 (ROI, 효율성)
  Future<Map<String, dynamic>> getPerformanceAnalytics(String placeId) async {
    try {
      final stats = await getPlaceStatistics(placeId);
      final postStats = stats['postStatistics'] as List<Map<String, dynamic>>;

      if (postStats.isEmpty) {
        return {
          'averageROI': 0.0,
          'topPerformers': [],
          'lowPerformers': [],
          'efficiency': 0.0,
        };
      }

      // 평균 ROI 계산
      final totalROI = postStats.fold<double>(
        0.0,
        (sum, stat) => sum + (stat['collectionRate'] as double),
      );
      final averageROI = totalROI / postStats.length;

      // 상위/하위 성과자
      final topPerformers = postStats.take(3).toList();
      final lowPerformers = postStats.reversed.take(3).toList();

      // 효율성: 총 수집 / 총 배포
      final efficiency = stats['collectionRate'] as double;

      return {
        'averageROI': averageROI,
        'topPerformers': topPerformers,
        'lowPerformers': lowPerformers,
        'efficiency': efficiency,
        'totalPosts': postStats.length,
      };

    } catch (e) {
      debugPrint('❌ getPerformanceAnalytics 오류: $e');
      throw Exception('성과 분석 실패: $e');
    }
  }
}
