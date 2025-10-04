import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../models/post/post_model.dart';

/// 포스트 통계 집계 및 조회 서비스
class PostStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 특정 포스트의 전체 통계 조회 (삭제된 포스트 포함 - Phase 5)
  Future<Map<String, dynamic>> getPostStatistics(String postId) async {
    try {
      debugPrint('📊 PostStatisticsService.getPostStatistics 시작: postId=$postId');

      // 1. 템플릿 기본 정보 (삭제된 포스트도 포함)
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트를 찾을 수 없습니다.');
      }

      final post = PostModel.fromFirestore(postDoc);
      final isDeleted = post.status == PostStatus.DELETED;

      // 2. 이 템플릿으로 생성한 모든 마커 (삭제된 포스트의 마커도 포함)
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
          'isDeleted': isDeleted,  // Phase 5: 삭제 상태 표시
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

  /// Phase 2-A: 수집자 상세 분석
  Future<Map<String, dynamic>> getCollectorDetails(String postId) async {
    try {
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final collections = collectionsQuery.docs.map((doc) => doc.data()).toList();

      // 수집자별 데이터
      final collectorData = <String, Map<String, dynamic>>{};

      for (final collection in collections) {
        final userId = collection['userId'] as String;
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();

        if (!collectorData.containsKey(userId)) {
          collectorData[userId] = {
            'userId': userId,
            'count': 0,
            'firstCollected': collectedAt,
            'lastCollected': collectedAt,
            'locations': <String>[],
          };
        }

        collectorData[userId]!['count'] = (collectorData[userId]!['count'] as int) + 1;

        if (collectedAt.isBefore(collectorData[userId]!['firstCollected'] as DateTime)) {
          collectorData[userId]!['firstCollected'] = collectedAt;
        }
        if (collectedAt.isAfter(collectorData[userId]!['lastCollected'] as DateTime)) {
          collectorData[userId]!['lastCollected'] = collectedAt;
        }
      }

      // Top 10 수집자
      final topCollectors = collectorData.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      // 수집 횟수별 분포
      final distribution = <String, int>{
        '1회': 0,
        '2-5회': 0,
        '6-10회': 0,
        '10회+': 0,
      };

      for (final collector in collectorData.values) {
        final count = collector['count'] as int;
        if (count == 1) {
          distribution['1회'] = (distribution['1회'] ?? 0) + 1;
        } else if (count <= 5) {
          distribution['2-5회'] = (distribution['2-5회'] ?? 0) + 1;
        } else if (count <= 10) {
          distribution['6-10회'] = (distribution['6-10회'] ?? 0) + 1;
        } else {
          distribution['10회+'] = (distribution['10회+'] ?? 0) + 1;
        }
      }

      return {
        'topCollectors': topCollectors.take(10).toList(),
        'distribution': distribution,
        'uniqueCollectors': collectorData.length,
        'totalCollections': collections.length,
        'newVsReturning': {
          '1회': distribution['1회'] ?? 0,
          '재방문': (distribution['2-5회'] ?? 0) + (distribution['6-10회'] ?? 0) + (distribution['10회+'] ?? 0),
        },
      };
    } catch (e) {
      debugPrint('❌ getCollectorDetails 오류: $e');
      return {};
    }
  }

  /// Phase 2-B: 시간 분석 심화
  Future<Map<String, dynamic>> getTimeAnalytics(String postId) async {
    try {
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final collections = collectionsQuery.docs.map((doc) => doc.data()).toList();

      // 월별 추이
      final monthlyTrend = <String, int>{};
      // 주말 vs 평일
      int weekdayCount = 0;
      int weekendCount = 0;
      // 시간대별 전환율 (여기서는 수집 건수로 대체)
      final hourlyRate = <int, int>{};

      for (final collection in collections) {
        final collectedAt = (collection['collectedAt'] as Timestamp).toDate();

        // 월별
        final monthKey = DateFormat('yyyy-MM').format(collectedAt);
        monthlyTrend[monthKey] = (monthlyTrend[monthKey] ?? 0) + 1;

        // 주말 vs 평일
        if (collectedAt.weekday >= 6) {
          weekendCount++;
        } else {
          weekdayCount++;
        }

        // 시간대별
        hourlyRate[collectedAt.hour] = (hourlyRate[collectedAt.hour] ?? 0) + 1;
      }

      // Convert Map<int, int> to Map<String, int> for type safety
      final hourlyRateMap = <String, int>{};
      hourlyRate.forEach((hour, count) {
        hourlyRateMap[hour.toString()] = count;
      });

      return {
        'monthlyTrend': monthlyTrend,
        'weekdayVsWeekend': {
          'weekday': weekdayCount,
          'weekend': weekendCount,
        },
        'hourlyRate': hourlyRateMap,
      };
    } catch (e) {
      debugPrint('❌ getTimeAnalytics 오류: $e');
      return {};
    }
  }

  /// Phase 2-C: 위치 분석
  Future<Map<String, dynamic>> getLocationAnalytics(String postId) async {
    try {
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final markers = markersQuery.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      // 마커 간 거리 매트릭스 (간단한 버전)
      final distances = <String, Map<String, double>>{};

      for (int i = 0; i < markers.length; i++) {
        final marker1 = markers[i];
        final pos1 = marker1['position'];
        if (pos1 == null) continue;

        final lat1 = (pos1['latitude'] ?? pos1['_latitude']) as double?;
        final lng1 = (pos1['longitude'] ?? pos1['_longitude']) as double?;
        if (lat1 == null || lng1 == null) continue;

        distances[marker1['id']] = {};

        for (int j = 0; j < markers.length; j++) {
          if (i == j) continue;

          final marker2 = markers[j];
          final pos2 = marker2['position'];
          if (pos2 == null) continue;

          final lat2 = (pos2['latitude'] ?? pos2['_latitude']) as double?;
          final lng2 = (pos2['longitude'] ?? pos2['_longitude']) as double?;
          if (lat2 == null || lng2 == null) continue;

          // 간단한 거리 계산 (Haversine 공식 간소화)
          final distance = _calculateDistance(lat1, lng1, lat2, lng2);
          distances[marker1['id']]![marker2['id']] = distance;
        }
      }

      return {
        'markerDistances': distances,
        'totalMarkers': markers.length,
      };
    } catch (e) {
      debugPrint('❌ getLocationAnalytics 오류: $e');
      return {};
    }
  }

  /// Phase 2-D: 성과 분석 (ROI 등)
  Future<Map<String, dynamic>> getPerformanceAnalytics(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return {};

      final post = PostModel.fromFirestore(postDoc);
      final reward = post.reward;

      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final totalQuantity = markersQuery.docs.fold<int>(
        0,
        (sum, doc) {
          final data = doc.data();
          return sum + ((data['totalQuantity'] ?? data['quantity']) as int? ?? 0);
        },
      );

      final collected = collectionsQuery.size;
      final collectionRate = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      // ROI 계산
      final totalRewardPaid = collected * reward;
      final roi = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      // 시간대별 ROI (시간대별 수집 건수)
      final hourlyROI = <int, int>{};
      for (final doc in collectionsQuery.docs) {
        final data = doc.data();
        final collectedAt = (data['collectedAt'] as Timestamp).toDate();
        hourlyROI[collectedAt.hour] = (hourlyROI[collectedAt.hour] ?? 0) + 1;
      }

      // Convert Map<int, int> to Map<String, int> for type safety
      final hourlyROIMap = <String, int>{};
      hourlyROI.forEach((hour, count) {
        hourlyROIMap[hour.toString()] = count;
      });

      return {
        'roi': roi,
        'totalRewardPaid': totalRewardPaid,
        'collectionRate': collectionRate,
        'hourlyROI': hourlyROIMap,
        'targetAchievement': collectionRate,
      };
    } catch (e) {
      debugPrint('❌ getPerformanceAnalytics 오류: $e');
      return {};
    }
  }

  /// 스토어별 분포 분석 (Phase 5)
  Future<Map<String, dynamic>> getStoreDistribution(String postId) async {
    try {
      debugPrint('🏪 PostStatisticsService.getStoreDistribution 시작: postId=$postId');

      // post_collections에서 storeId별로 집계
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final storeDistribution = <String, int>{};
      final storeNames = <String, String>{};

      for (final doc in collectionsQuery.docs) {
        final data = doc.data();
        final storeId = data['placeId'] as String?;

        if (storeId != null && storeId.isNotEmpty) {
          storeDistribution[storeId] = (storeDistribution[storeId] ?? 0) + 1;

          // 스토어 이름 가져오기 (캐시)
          if (!storeNames.containsKey(storeId)) {
            try {
              final placeDoc = await _firestore.collection('places').doc(storeId).get();
              if (placeDoc.exists) {
                storeNames[storeId] = placeDoc.data()?['name'] ?? '알 수 없는 스토어';
              } else {
                storeNames[storeId] = '알 수 없는 스토어';
              }
            } catch (e) {
              storeNames[storeId] = '알 수 없는 스토어';
            }
          }
        }
      }

      // 스토어명과 함께 분포 데이터 반환
      final result = <String, Map<String, dynamic>>{};
      storeDistribution.forEach((storeId, count) {
        result[storeId] = {
          'name': storeNames[storeId] ?? '알 수 없는 스토어',
          'count': count,
          'percentage': collectionsQuery.size > 0 ? (count / collectionsQuery.size * 100) : 0.0,
        };
      });

      debugPrint('📊 스토어별 분포 조회 완료: ${result.length}개 스토어');
      return {
        'distribution': result,
        'totalStores': result.length,
        'totalCollections': collectionsQuery.size,
      };

    } catch (e) {
      debugPrint('❌ getStoreDistribution 오류: $e');
      return {};
    }
  }

  /// Phase 2-E: 예측 분석
  Future<Map<String, dynamic>> getPredictiveAnalytics(String postId) async {
    try {
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      if (collectionsQuery.docs.isEmpty) {
        return {'estimatedCompletion': null, 'dailyRate': 0.0};
      }

      // Sort by collectedAt on client side to avoid Firebase index requirement
      final collections = collectionsQuery.docs.toList()
        ..sort((a, b) {
          final aTime = (a.data()['collectedAt'] as Timestamp).toDate();
          final bTime = (b.data()['collectedAt'] as Timestamp).toDate();
          return aTime.compareTo(bTime);
        });

      final firstCollection = (collections.first.data()['collectedAt'] as Timestamp).toDate();
      final lastCollection = (collections.last.data()['collectedAt'] as Timestamp).toDate();

      final daysPassed = lastCollection.difference(firstCollection).inDays + 1;
      final dailyRate = daysPassed > 0 ? collections.length / daysPassed : 0.0;

      // 마커 총 수량
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final totalQuantity = markersQuery.docs.fold<int>(
        0,
        (sum, doc) {
          final data = doc.data();
          return sum + ((data['totalQuantity'] ?? data['quantity']) as int? ?? 0);
        },
      );

      final remaining = totalQuantity - collections.length;
      final daysToComplete = dailyRate > 0 ? (remaining / dailyRate).ceil() : null;

      DateTime? estimatedCompletion;
      if (daysToComplete != null) {
        estimatedCompletion = DateTime.now().add(Duration(days: daysToComplete));
      }

      return {
        'estimatedCompletion': estimatedCompletion?.toIso8601String(),
        'dailyRate': dailyRate,
        'daysToComplete': daysToComplete,
        'remaining': remaining,
      };
    } catch (e) {
      debugPrint('❌ getPredictiveAnalytics 오류: $e');
      return {};
    }
  }

  /// 거리 계산 (Haversine 공식 간소화)
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = (dLat / 2).abs() * (dLat / 2).abs() +
        (lat1 * 3.14159 / 180).abs() * (lat2 * 3.14159 / 180).abs() *
        (dLng / 2).abs() * (dLng / 2).abs();

    final c = 2 * (a.abs() < 1 ? a : 1 - a);
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.14159 / 180;
  }
}