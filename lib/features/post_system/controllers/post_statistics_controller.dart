import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';

/// 포스트 통계 관련 로직을 관리하는 컨트롤러
class PostStatisticsController {
  /// 마커 통계 데이터 로드
  static Future<List<Map<String, dynamic>>> loadMarkerStatistics(String postId) async {
    try {
      final markersSnapshot = await FirebaseFirestore.instance
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      return markersSnapshot.docs
          .map((doc) => {...doc.data(), 'markerId': doc.id})
          .toList();
    } catch (e) {
      debugPrint('❌ 마커 통계 로드 실패: $e');
      return [];
    }
  }

  /// 수집자 통계 데이터 로드
  static Future<Map<String, dynamic>> loadCollectorStatistics(String postId) async {
    try {
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final collectors = <String, int>{};
      final timestamps = <DateTime>[];

      for (final doc in collectionsSnapshot.docs) {
        final data = doc.data();
        final collectorId = data['userId'] as String?;
        final timestamp = (data['collectedAt'] as Timestamp?)?.toDate();

        if (collectorId != null) {
          collectors[collectorId] = (collectors[collectorId] ?? 0) + 1;
        }
        if (timestamp != null) {
          timestamps.add(timestamp);
        }
      }

      return {
        'collectors': collectors,
        'timestamps': timestamps,
        'totalCollections': collectionsSnapshot.size,
      };
    } catch (e) {
      debugPrint('❌ 수집자 통계 로드 실패: $e');
      return {'collectors': {}, 'timestamps': [], 'totalCollections': 0};
    }
  }

  /// 시간대별 통계 계산
  static Map<int, int> calculateHourlyStatistics(List<DateTime> timestamps) {
    final hourlyData = <int, int>{};
    
    for (final timestamp in timestamps) {
      final hour = timestamp.hour;
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }

    return hourlyData;
  }

  /// 일별 통계 계산
  static Map<String, int> calculateDailyStatistics(List<DateTime> timestamps) {
    final dailyData = <String, int>{};
    
    for (final timestamp in timestamps) {
      final dateKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
      dailyData[dateKey] = (dailyData[dateKey] ?? 0) + 1;
    }

    return dailyData;
  }

  /// 요일별 통계 계산
  static Map<String, int> calculateWeekdayStatistics(List<DateTime> timestamps) {
    final weekdayData = <String, int>{
      '월': 0, '화': 0, '수': 0, '목': 0, '금': 0, '토': 0, '일': 0,
    };

    for (final timestamp in timestamps) {
      final weekday = ['월', '화', '수', '목', '금', '토', '일'][timestamp.weekday - 1];
      weekdayData[weekday] = (weekdayData[weekday] ?? 0) + 1;
    }

    return weekdayData;
  }

  /// ROI 계산
  static double calculateROI(PostModel post, int totalCollections) {
    final totalCost = (post.reward ?? 0) * (post.totalQuantity ?? 0);
    final actualCost = (post.reward ?? 0) * totalCollections;
    
    if (totalCost == 0) return 0.0;
    return ((totalCost - actualCost) / totalCost * 100);
  }

  /// 마커 효율성 점수 계산
  static double calculateMarkerEfficiency(Map<String, dynamic> marker) {
    final collected = marker['collectedCount'] ?? 0;
    final initial = marker['initialQuantity'] ?? 1;
    return (collected / initial * 100);
  }

  /// 탑 수집자 계산
  static List<MapEntry<String, int>> getTopCollectors(
    Map<String, int> collectors, {
    int limit = 10,
  }) {
    final entries = collectors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return entries.take(limit).toList();
  }

  /// 신규 vs 재방문 수집자 계산
  static Map<String, int> calculateNewVsReturning(Map<String, int> collectors) {
    int newCollectors = 0;
    int returningCollectors = 0;

    for (final count in collectors.values) {
      if (count == 1) {
        newCollectors++;
      } else {
        returningCollectors++;
      }
    }

    return {
      'new': newCollectors,
      'returning': returningCollectors,
    };
  }

  /// 통계 요약 데이터 생성
  static Map<String, dynamic> generateStatisticsSummary({
    required PostModel post,
    required List<Map<String, dynamic>> markers,
    required Map<String, dynamic> collectorData,
  }) {
    final totalCollections = collectorData['totalCollections'] as int;
    final collectors = collectorData['collectors'] as Map<String, int>;
    
    return {
      'totalDeployed': post.totalQuantity ?? 0,
      'totalCollected': totalCollections,
      'remainingQuantity': (post.totalQuantity ?? 0) - totalCollections,
      'totalMarkers': markers.length,
      'activeMarkers': markers.where((m) => (m['quantity'] ?? 0) > 0).length,
      'uniqueCollectors': collectors.length,
      'collectionRate': post.totalQuantity != null && post.totalQuantity! > 0
          ? (totalCollections / post.totalQuantity! * 100)
          : 0.0,
      'roi': calculateROI(post, totalCollections),
    };
  }
}

