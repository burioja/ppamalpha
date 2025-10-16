import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// 포스트 통계 화면의 헬퍼 함수들
class PostStatisticsHelpers {
  // 전체 분석 데이터 가져오기
  static Future<Map<String, dynamic>?> getOverallAnalysisData(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return null;

      // 포스트 정보 가져오기
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      if (!postDoc.exists) return null;
      
      final postData = postDoc.data()!;
      final markers = postData['markers'] as List<dynamic>? ?? [];
      
      // 수집 기록 가져오기
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();
      
      final collections = collectionsSnapshot.docs.map((doc) => doc.data()).toList();
      
      // 마커별 수집 데이터
      final markerPerformance = <String, dynamic>{};
      final markersData = <Map<String, dynamic>>[];
      
      for (int i = 0; i < markers.length; i++) {
        final markerId = markers[i]['markerId'] as String? ?? 'marker_$i';
        final markerCollections = collections.where((c) => c['markerId'] == markerId).length;
        
        markersData.add({
          'markerId': markerId,
          'collected': markerCollections,
        });
      }
      
      markerPerformance['markers'] = markersData;
      
      // 시간별 데이터
      final timeData = _analyzeTimeData(collections);
      
      // 수집자 데이터
      final collectorData = _analyzeCollectorData(collections);
      
      return {
        'totalCollections': collections.length,
        'totalMarkers': markers.length,
        'uniqueCollectors': collectorData['totalCollectors'],
        'performance': markerPerformance,
        'timeData': timeData,
        'collectorData': collectorData,
      };
    } catch (e) {
      debugPrint('전체 분석 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 수집자 분석 데이터 가져오기
  static Future<Map<String, dynamic>?> getCollectorAnalysisData(String postId) async {
    try {
      // 수집 기록 가져오기
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();
      
      final collections = collectionsSnapshot.docs.map((doc) => doc.data()).toList();
      
      return _analyzeCollectorData(collections);
    } catch (e) {
      debugPrint('수집자 분석 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 시간 분석 데이터 가져오기
  static Future<Map<String, dynamic>?> getTimeAnalysisData(String postId) async {
    try {
      // 수집 기록 가져오기
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();
      
      final collections = collectionsSnapshot.docs.map((doc) => doc.data()).toList();
      
      return _analyzeTimeData(collections);
    } catch (e) {
      debugPrint('시간 분석 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 성과 분석 데이터 가져오기
  static Future<Map<String, dynamic>?> getPerformanceAnalysisData(String postId) async {
    try {
      // 포스트 정보 가져오기
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .get();
      
      if (!postDoc.exists) return null;
      
      final postData = postDoc.data()!;
      final markers = postData['markers'] as List<dynamic>? ?? [];
      
      // 수집 기록 가져오기
      final collectionsSnapshot = await FirebaseFirestore.instance
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();
      
      final collections = collectionsSnapshot.docs.map((doc) => doc.data()).toList();
      
      // 마커별 성과 데이터
      final markerPerformance = <String, dynamic>{};
      final markersData = <Map<String, dynamic>>[];
      
      for (int i = 0; i < markers.length; i++) {
        final markerId = markers[i]['markerId'] as String? ?? 'marker_$i';
        final markerCollections = collections.where((c) => c['markerId'] == markerId).length;
        
        markersData.add({
          'markerId': markerId,
          'collected': markerCollections,
        });
      }
      
      markerPerformance['markers'] = markersData;
      
      // 시간대별 효율성 계산
      final hourlyEfficiency = _calculateHourlyEfficiency(collections);
      markerPerformance['hourlyEfficiency'] = hourlyEfficiency;
      
      // 전체 효율성 계산
      final totalCollections = collections.length;
      final totalMarkers = markers.length;
      final efficiency = totalMarkers > 0 ? totalCollections / totalMarkers : 0.0;
      
      return {
        'totalCollections': totalCollections,
        'totalMarkers': totalMarkers,
        'efficiency': efficiency,
        'performance': markerPerformance,
      };
    } catch (e) {
      debugPrint('성과 분석 데이터 가져오기 실패: $e');
      return null;
    }
  }

  // 시간 데이터 분석
  static Map<String, dynamic> _analyzeTimeData(List<Map<String, dynamic>> collections) {
    final hourlyData = <String, int>{};
    final dailyData = <String, int>{};
    final monthlyData = <String, int>{};
    final weekdayData = <String, int>{};
    final weekendData = <String, int>{};
    
    for (final collection in collections) {
      final timestamp = collection['collectedAt'] as Timestamp?;
      if (timestamp == null) continue;
      
      final date = timestamp.toDate();
      final hour = date.hour.toString();
      final day = DateFormat('yyyy-MM-dd').format(date);
      final month = DateFormat('yyyy-MM').format(date);
      final weekday = date.weekday;
      
      // 시간별 데이터
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
      
      // 일별 데이터
      dailyData[day] = (dailyData[day] ?? 0) + 1;
      
      // 월별 데이터
      monthlyData[month] = (monthlyData[month] ?? 0) + 1;
      
      // 주중/주말 데이터
      if (weekday >= 1 && weekday <= 5) {
        weekdayData[hour] = (weekdayData[hour] ?? 0) + 1;
      } else {
        weekendData[hour] = (weekendData[hour] ?? 0) + 1;
      }
    }
    
    // 피크 시간 찾기
    String peakHour = 'N/A';
    int peakHourCollections = 0;
    if (hourlyData.isNotEmpty) {
      final maxEntry = hourlyData.entries.reduce((a, b) => a.value > b.value ? a : b);
      peakHour = '${maxEntry.key}시';
      peakHourCollections = maxEntry.value;
    }
    
    // 일평균 수집 계산
    final avgDailyCollections = dailyData.isNotEmpty ? 
        dailyData.values.reduce((a, b) => a + b) / dailyData.length : 0.0;
    
    // 주말 비율 계산
    final totalWeekday = weekdayData.values.fold(0, (sum, count) => sum + count);
    final totalWeekend = weekendData.values.fold(0, (sum, count) => sum + count);
    final weekendRatio = (totalWeekday + totalWeekend) > 0 ? 
        totalWeekend / (totalWeekday + totalWeekend) : 0.0;
    
    return {
      'hourly': hourlyData,
      'daily': dailyData,
      'monthly': monthlyData,
      'weekday': weekdayData,
      'weekend': weekendData,
      'peakHour': peakHour,
      'peakHourCollections': peakHourCollections,
      'avgDailyCollections': avgDailyCollections,
      'weekendRatio': weekendRatio,
      'totalCollections': collections.length,
    };
  }

  // 수집자 데이터 분석
  static Map<String, dynamic> _analyzeCollectorData(List<Map<String, dynamic>> collections) {
    final collectorCounts = <String, int>{};
    final collectorNames = <String, String>{};
    
    for (final collection in collections) {
      final userId = collection['userId'] as String?;
      if (userId == null) continue;
      
      collectorCounts[userId] = (collectorCounts[userId] ?? 0) + 1;
      
      // 사용자 이름 가져오기 (캐시)
      if (!collectorNames.containsKey(userId)) {
        collectorNames[userId] = 'User_${userId.substring(0, 8)}';
      }
    }
    
    // 상위 수집자 목록
    final sortedCollectors = collectorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topCollectors = sortedCollectors.take(10).map((entry) {
      return {
        'userId': entry.key,
        'name': collectorNames[entry.key] ?? 'Unknown',
        'count': entry.value,
      };
    }).toList();
    
    // 수집 분포 계산
    final distribution = <String, int>{};
    for (final count in collectorCounts.values) {
      String range;
      if (count == 1) {
        range = '1회';
      } else if (count <= 3) {
        range = '2-3회';
      } else if (count <= 5) {
        range = '4-5회';
      } else if (count <= 10) {
        range = '6-10회';
      } else {
        range = '10회+';
      }
      distribution[range] = (distribution[range] ?? 0) + 1;
    }
    
    // 신규 vs 기존 사용자 구분 (간단한 휴리스틱)
    final totalCollectors = collectorCounts.length;
    final newUsers = (totalCollectors * 0.3).round(); // 30%를 신규로 가정
    final returningUsers = totalCollectors - newUsers;
    
    return {
      'totalCollectors': totalCollectors,
      'newUsers': newUsers,
      'returningUsers': returningUsers,
      'topCollectors': topCollectors,
      'distribution': distribution,
      'totalCollections': collections.length,
    };
  }

  // 시간대별 효율성 계산
  static Map<String, dynamic> _calculateHourlyEfficiency(List<Map<String, dynamic>> collections) {
    final hourlyData = <String, int>{};
    
    for (final collection in collections) {
      final timestamp = collection['collectedAt'] as Timestamp?;
      if (timestamp == null) continue;
      
      final hour = timestamp.toDate().hour.toString();
      hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
    }
    
    // 효율성 계산 (해당 시간대 수집 수 / 전체 수집 수)
    final totalCollections = collections.length;
    final hourlyEfficiency = <String, double>{};
    
    for (int hour = 0; hour < 24; hour++) {
      final hourStr = hour.toString();
      final count = hourlyData[hourStr] ?? 0;
      hourlyEfficiency[hourStr] = totalCollections > 0 ? count / totalCollections : 0.0;
    }
    
    return hourlyEfficiency;
  }

  // 날짜 범위 파싱
  static Map<String, DateTime> parseDateRange(String range) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;
    
    switch (range) {
      case '7일':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '30일':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '90일':
        startDate = now.subtract(const Duration(days: 90));
        break;
      case '1년':
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = now.subtract(const Duration(days: 30));
    }
    
    return {
      'start': startDate,
      'end': endDate,
    };
  }

  // 통계 요약 텍스트 생성
  static String generateSummaryText(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return '데이터가 없습니다.';
    }
    
    final totalCollections = (data['totalCollections'] as num?)?.toInt() ?? 0;
    final totalMarkers = (data['totalMarkers'] as num?)?.toInt() ?? 0;
    final uniqueCollectors = (data['uniqueCollectors'] as num?)?.toInt() ?? 0;
    
    if (totalCollections == 0) {
      return '아직 수집된 포스트가 없습니다.';
    }
    
    final avgPerMarker = totalMarkers > 0 ? (totalCollections / totalMarkers).toStringAsFixed(1) : '0.0';
    final avgPerCollector = uniqueCollectors > 0 ? (totalCollections / uniqueCollectors).toStringAsFixed(1) : '0.0';
    
    return '총 ${totalCollections}회 수집, ${totalMarkers}개 마커, ${uniqueCollectors}명의 수집자. '
           '마커당 평균 ${avgPerMarker}회, 수집자당 평균 ${avgPerCollector}회 수집.';
  }

  // 성과 등급 계산
  static String calculatePerformanceGrade(double efficiency) {
    if (efficiency >= 0.8) return 'A+';
    if (efficiency >= 0.7) return 'A';
    if (efficiency >= 0.6) return 'B+';
    if (efficiency >= 0.5) return 'B';
    if (efficiency >= 0.4) return 'C+';
    if (efficiency >= 0.3) return 'C';
    if (efficiency >= 0.2) return 'D';
    return 'F';
  }

  // 성과 색상 계산
  static Color getPerformanceColor(double efficiency) {
    if (efficiency >= 0.8) return Colors.green;
    if (efficiency >= 0.6) return Colors.blue;
    if (efficiency >= 0.4) return Colors.orange;
    if (efficiency >= 0.2) return Colors.red;
    return Colors.grey;
  }

  // 트렌드 방향 계산
  static String calculateTrendDirection(List<double> values) {
    if (values.length < 2) return 'stable';
    
    final recent = values.length >= 3 
        ? values.sublist(values.length - 3).reduce((a, b) => a + b) / 3
        : values.reduce((a, b) => a + b) / values.length;
    final earlier = values.take(values.length - 3).reduce((a, b) => a + b) / (values.length - 3);
    
    if (recent > earlier * 1.1) return 'up';
    if (recent < earlier * 0.9) return 'down';
    return 'stable';
  }

  // 데이터 유효성 검사
  static bool isValidData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return false;
    
    final totalCollections = (data['totalCollections'] as num?)?.toInt() ?? 0;
    return totalCollections > 0;
  }

  // 에러 메시지 생성
  static String getErrorMessage(dynamic error) {
    if (error.toString().contains('permission')) {
      return '권한이 없습니다.';
    } else if (error.toString().contains('network')) {
      return '네트워크 연결을 확인해주세요.';
    } else if (error.toString().contains('timeout')) {
      return '요청 시간이 초과되었습니다.';
    } else {
      return '데이터를 가져오는 중 오류가 발생했습니다.';
    }
  }

  // 로딩 상태 관리
  static Widget buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('데이터를 불러오는 중...'),
        ],
      ),
    );
  }

  // 에러 위젯
  static Widget buildErrorWidget(String message, VoidCallback? onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            '오류 발생',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }
}

