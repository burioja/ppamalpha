import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'post_statistics_charts.dart';

/// 포스트 통계 화면의 탭별 분석 위젯들
class PostStatisticsTabs {
  // 전체 분석 탭
  static Widget buildOverallAnalysisTab(Map<String, dynamic>? overallData) {
    if (overallData == null || overallData.isEmpty) {
      return buildEmptyTab('전체 분석', '분석 데이터가 없습니다');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약 카드들
          buildSummaryCards(overallData),
          const SizedBox(height: 24),
          
          // 마커 성과 차트
          PostStatisticsCharts.buildMarkerPerformanceChart(overallData['performance']),
          const SizedBox(height: 24),
          
          // 시간별 차트
          PostStatisticsCharts.buildHourlyChart(overallData['timeData']),
          const SizedBox(height: 24),
          
          // 일별 차트
          PostStatisticsCharts.buildDailyChart(overallData['timeData']),
          const SizedBox(height: 24),
          
          // 월별 트렌드 차트
          PostStatisticsCharts.buildMonthlyTrendChart(overallData['timeData']),
        ],
      ),
    );
  }

  // 수집자 분석 탭
  static Widget buildCollectorAnalysisTab(Map<String, dynamic>? collectorData) {
    if (collectorData == null || collectorData.isEmpty) {
      return buildEmptyTab('수집자 분석', '수집자 데이터가 없습니다');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수집자 요약 카드들
          buildCollectorSummaryCards(collectorData),
          const SizedBox(height: 24),
          
          // 상위 수집자 차트
          PostStatisticsCharts.buildTopCollectorsChart(collectorData),
          const SizedBox(height: 24),
          
          // 신규 vs 기존 사용자 차트
          PostStatisticsCharts.buildNewVsReturningChart(collectorData),
          const SizedBox(height: 24),
          
          // 수집자 분포 차트
          PostStatisticsCharts.buildCollectorDistributionChart(collectorData),
          const SizedBox(height: 24),
          
          // 수집자 상세 정보
          buildCollectorDetails(collectorData),
        ],
      ),
    );
  }

  // 시간 분석 탭
  static Widget buildTimeAnalysisTab(Map<String, dynamic>? timeData) {
    if (timeData == null || timeData.isEmpty) {
      return buildEmptyTab('시간 분석', '시간 데이터가 없습니다');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시간 요약 카드들
          buildTimeSummaryCards(timeData),
          const SizedBox(height: 24),
          
          // 시간별 차트
          PostStatisticsCharts.buildHourlyChart(timeData),
          const SizedBox(height: 24),
          
          // 주중 vs 주말 차트
          PostStatisticsCharts.buildWeekdayVsWeekendChart(timeData),
          const SizedBox(height: 24),
          
          // 시간대별 효율성 차트
          PostStatisticsCharts.buildHourlyEfficiencyChart(timeData),
          const SizedBox(height: 24),
          
          // 시간 패턴 분석
          buildTimePatternAnalysis(timeData),
        ],
      ),
    );
  }

  // 성과 분석 탭
  static Widget buildPerformanceAnalysisTab(Map<String, dynamic>? performanceData) {
    if (performanceData == null || performanceData.isEmpty) {
      return buildEmptyTab('성과 분석', '성과 데이터가 없습니다');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 성과 요약 카드들
          buildPerformanceSummaryCards(performanceData),
          const SizedBox(height: 24),
          
          // 마커 성과 차트
          PostStatisticsCharts.buildMarkerPerformanceChart(performanceData),
          const SizedBox(height: 24),
          
          // 시간대별 효율성 차트
          PostStatisticsCharts.buildHourlyEfficiencyChart(performanceData),
          const SizedBox(height: 24),
          
          // 성과 상세 분석
          buildPerformanceDetails(performanceData),
        ],
      ),
    );
  }

  // 요약 카드들
  static Widget buildSummaryCards(Map<String, dynamic> overallData) {
    final totalCollections = (overallData['totalCollections'] as num?)?.toInt() ?? 0;
    final totalMarkers = (overallData['totalMarkers'] as num?)?.toInt() ?? 0;
    final avgCollectionsPerMarker = totalMarkers > 0 ? (totalCollections / totalMarkers).toStringAsFixed(1) : '0.0';
    final uniqueCollectors = (overallData['uniqueCollectors'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            '총 수집',
            totalCollections.toString(),
            Icons.collections,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '총 마커',
            totalMarkers.toString(),
            Icons.location_on,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '평균 수집/마커',
            avgCollectionsPerMarker,
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '수집자 수',
            uniqueCollectors.toString(),
            Icons.people,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  // 수집자 요약 카드들
  static Widget buildCollectorSummaryCards(Map<String, dynamic> collectorData) {
    final totalCollectors = (collectorData['totalCollectors'] as num?)?.toInt() ?? 0;
    final newUsers = (collectorData['newUsers'] as num?)?.toInt() ?? 0;
    final returningUsers = (collectorData['returningUsers'] as num?)?.toInt() ?? 0;
    final avgCollectionsPerUser = totalCollectors > 0 ? 
        ((collectorData['totalCollections'] as num?)?.toDouble() ?? 0) / totalCollectors : 0.0;

    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            '총 수집자',
            totalCollectors.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '신규 사용자',
            newUsers.toString(),
            Icons.person_add,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '기존 사용자',
            returningUsers.toString(),
            Icons.person,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '평균 수집/사용자',
            avgCollectionsPerUser.toStringAsFixed(1),
            Icons.trending_up,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  // 시간 요약 카드들
  static Widget buildTimeSummaryCards(Map<String, dynamic> timeData) {
    final peakHour = timeData['peakHour'] as String? ?? 'N/A';
    final peakHourCollections = (timeData['peakHourCollections'] as num?)?.toInt() ?? 0;
    final avgDailyCollections = (timeData['avgDailyCollections'] as num?)?.toDouble() ?? 0.0;
    final weekendRatio = (timeData['weekendRatio'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            '피크 시간',
            peakHour,
            Icons.access_time,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '피크 시간 수집',
            peakHourCollections.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '일평균 수집',
            avgDailyCollections.toStringAsFixed(1),
            Icons.calendar_today,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '주말 비율',
            '${(weekendRatio * 100).toStringAsFixed(1)}%',
            Icons.weekend,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  // 성과 요약 카드들
  static Widget buildPerformanceSummaryCards(Map<String, dynamic> performanceData) {
    final totalCollections = (performanceData['totalCollections'] as num?)?.toInt() ?? 0;
    final totalMarkers = (performanceData['totalMarkers'] as num?)?.toInt() ?? 0;
    final collectionRate = totalMarkers > 0 ? 
        ((totalCollections / totalMarkers) * 100).toStringAsFixed(1) : '0.0';
    final efficiency = (performanceData['efficiency'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: buildSummaryCard(
            '총 수집',
            totalCollections.toString(),
            Icons.collections,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '수집률',
            '$collectionRate%',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '효율성',
            '${(efficiency * 100).toStringAsFixed(1)}%',
            Icons.speed,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: buildSummaryCard(
            '총 마커',
            totalMarkers.toString(),
            Icons.location_on,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  // 요약 카드
  static Widget buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 수집자 상세 정보
  static Widget buildCollectorDetails(Map<String, dynamic> collectorData) {
    final topCollectors = collectorData['topCollectors'] as List<dynamic>? ?? [];
    final distribution = collectorData['distribution'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '수집자 상세 정보',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 상위 수집자 목록
        if (topCollectors.isNotEmpty) ...[
          const Text(
            '상위 수집자',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...topCollectors.take(5).map((collector) {
            final name = collector['name'] as String? ?? 'Unknown';
            final count = (collector['count'] as num?)?.toInt() ?? 0;
            final percentage = collectorData['totalCollections'] != null ?
                ((count / (collectorData['totalCollections'] as num).toDouble()) * 100).toStringAsFixed(1) : '0.0';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '$count회 ($percentage%)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
        
        // 수집 분포
        if (distribution.isNotEmpty) ...[
          const Text(
            '수집 분포',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...distribution.entries.map((entry) {
            final range = entry.key;
            final count = (entry.value as num).toInt();
            final percentage = collectorData['totalCollectors'] != null ?
                ((count / (collectorData['totalCollectors'] as num).toDouble()) * 100).toStringAsFixed(1) : '0.0';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      range,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '$count명 ($percentage%)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  // 시간 패턴 분석
  static Widget buildTimePatternAnalysis(Map<String, dynamic> timeData) {
    final hourlyData = timeData['hourly'] as Map<String, dynamic>? ?? {};
    final weekdayData = timeData['weekday'] as Map<String, dynamic>? ?? {};
    final weekendData = timeData['weekend'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '시간 패턴 분석',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 시간대별 분석
        if (hourlyData.isNotEmpty) ...[
          const Text(
            '시간대별 분석',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...hourlyData.entries.take(5).map((entry) {
            final hour = entry.key;
            final count = (entry.value as num).toInt();
            final percentage = timeData['totalCollections'] != null ?
                ((count / (timeData['totalCollections'] as num).toDouble()) * 100).toStringAsFixed(1) : '0.0';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${hour}시',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '$count회 ($percentage%)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
        
        // 주중 vs 주말 비교
        if (weekdayData.isNotEmpty && weekendData.isNotEmpty) ...[
          const Text(
            '주중 vs 주말 비교',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '주중',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weekdayData.values.fold(0, (sum, count) => sum + (count as num).toInt())}회',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '주말',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${weekendData.values.fold(0, (sum, count) => sum + (count as num).toInt())}회',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 성과 상세 분석
  static Widget buildPerformanceDetails(Map<String, dynamic> performanceData) {
    final markers = performanceData['markers'] as List<dynamic>? ?? [];
    final hourlyEfficiency = performanceData['hourlyEfficiency'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성과 상세 분석',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // 마커별 성과
        if (markers.isNotEmpty) ...[
          const Text(
            '마커별 성과',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...markers.take(5).map((marker) {
            final markerId = marker['markerId'] as String? ?? 'Unknown';
            final collected = (marker['collected'] as num?)?.toInt() ?? 0;
            final percentage = performanceData['totalCollections'] != null ?
                ((collected / (performanceData['totalCollections'] as num).toDouble()) * 100).toStringAsFixed(1) : '0.0';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '마커 $markerId',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '$collected회 ($percentage%)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
        
        // 시간대별 효율성
        if (hourlyEfficiency.isNotEmpty) ...[
          const Text(
            '시간대별 효율성',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...hourlyEfficiency.entries.take(5).map((entry) {
            final hour = entry.key;
            final efficiency = (entry.value as num).toDouble();
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${hour}시',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${(efficiency * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ],
    );
  }

  // 빈 탭 위젯
  static Widget buildEmptyTab(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

