import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// 포스트 통계 화면의 차트 위젯들
class PostStatisticsCharts {
  // 마커 성과 차트
  static Widget buildMarkerPerformanceChart(Map<String, dynamic>? performanceData) {
    if (performanceData == null || performanceData.isEmpty) {
      return buildEmptyChart('마커 성과', '성과 데이터가 없습니다');
    }

    final markers = performanceData['markers'] as List<dynamic>? ?? [];
    if (markers.isEmpty) {
      return buildEmptyChart('마커 성과', '마커 데이터가 없습니다');
    }

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '마커별 수집 성과',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: markers.map((m) => (m['collected'] as num).toDouble()).reduce((a, b) => a > b ? a : b) + 10,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    // tooltipBgColor는 더 이상 지원되지 않음
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '마커 ${group.x}\n수집: ${rod.toY.toInt()}회',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'M${value.toInt()}',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: markers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final marker = entry.value;
                  final collected = (marker['collected'] as num).toDouble();
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: collected,
                        color: Colors.blue,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 시간별 차트
  static Widget buildHourlyChart(Map<String, dynamic>? timeData) {
    if (timeData == null || timeData.isEmpty) {
      return buildEmptyChart('시간별 수집', '시간 데이터가 없습니다');
    }

    final hourlyData = timeData['hourly'] as Map<String, dynamic>? ?? {};
    if (hourlyData.isEmpty) {
      return buildEmptyChart('시간별 수집', '시간별 데이터가 없습니다');
    }

    final spots = <FlSpot>[];
    hourlyData.forEach((hour, count) {
      spots.add(FlSpot(int.parse(hour).toDouble(), (count as num).toDouble()));
    });

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시간별 수집 패턴',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}시',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 일별 차트
  static Widget buildDailyChart(Map<String, dynamic>? timeData) {
    if (timeData == null || timeData.isEmpty) {
      return buildEmptyChart('일별 수집', '일별 데이터가 없습니다');
    }

    final dailyData = timeData['daily'] as Map<String, dynamic>? ?? {};
    if (dailyData.isEmpty) {
      return buildEmptyChart('일별 수집', '일별 데이터가 없습니다');
    }

    final spots = <FlSpot>[];
    int index = 0;
    dailyData.forEach((date, count) {
      spots.add(FlSpot(index.toDouble(), (count as num).toDouble()));
      index++;
    });

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '일별 수집 추이',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final dates = dailyData.keys.toList();
                        if (value.toInt() < dates.length) {
                          final date = DateTime.parse(dates[value.toInt()]);
                          return Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 상위 수집자 차트
  static Widget buildTopCollectorsChart(Map<String, dynamic>? collectorData) {
    if (collectorData == null || collectorData.isEmpty) {
      return buildEmptyChart('상위 수집자', '수집자 데이터가 없습니다');
    }

    final topCollectors = collectorData['topCollectors'] as List<dynamic>? ?? [];
    if (topCollectors.isEmpty) {
      return buildEmptyChart('상위 수집자', '수집자 데이터가 없습니다');
    }

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상위 수집자',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: topCollectors.map((c) => (c['count'] as num).toDouble()).reduce((a, b) => a > b ? a : b) + 5,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    // tooltipBgColor는 더 이상 지원되지 않음
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final collector = topCollectors[group.x];
                      return BarTooltipItem(
                        '${collector['name']}\n수집: ${rod.toY.toInt()}회',
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < topCollectors.length) {
                          final collector = topCollectors[value.toInt()];
                          final name = collector['name'] as String;
                          return Text(
                            name.length > 4 ? '${name.substring(0, 4)}...' : name,
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: topCollectors.asMap().entries.map((entry) {
                  final index = entry.key;
                  final collector = entry.value;
                  final count = (collector['count'] as num).toDouble();
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: Colors.orange,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 신규 vs 기존 사용자 차트
  static Widget buildNewVsReturningChart(Map<String, dynamic>? collectorData) {
    if (collectorData == null || collectorData.isEmpty) {
      return buildEmptyChart('신규 vs 기존 사용자', '사용자 데이터가 없습니다');
    }

    final newUsers = (collectorData['newUsers'] as num?)?.toDouble() ?? 0;
    final returningUsers = (collectorData['returningUsers'] as num?)?.toDouble() ?? 0;

    if (newUsers == 0 && returningUsers == 0) {
      return buildEmptyChart('신규 vs 기존 사용자', '사용자 데이터가 없습니다');
    }

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '신규 vs 기존 사용자',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.blue,
                    value: newUsers,
                    title: '신규\n${newUsers.toInt()}명',
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.green,
                    value: returningUsers,
                    title: '기존\n${returningUsers.toInt()}명',
                    radius: 100,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 수집자 분포 차트
  static Widget buildCollectorDistributionChart(Map<String, dynamic>? collectorData) {
    if (collectorData == null || collectorData.isEmpty) {
      return buildEmptyChart('수집자 분포', '분포 데이터가 없습니다');
    }

    final distribution = collectorData['distribution'] as Map<String, dynamic>? ?? {};
    if (distribution.isEmpty) {
      return buildEmptyChart('수집자 분포', '분포 데이터가 없습니다');
    }

    final spots = <FlSpot>[];
    distribution.forEach((range, count) {
      final rangeValue = range.split('-')[0].trim();
      spots.add(FlSpot(double.parse(rangeValue), (count as num).toDouble()));
    });

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '수집자 분포',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: distribution.values.map((v) => (v as num).toDouble()).reduce((a, b) => a > b ? a : b) + 5,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    // tooltipBgColor는 더 이상 지원되지 않음
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final ranges = distribution.keys.toList();
                      if (group.x.toInt() < ranges.length) {
                        return BarTooltipItem(
                          '${ranges[group.x.toInt()]}\n${rod.toY.toInt()}명',
                          const TextStyle(color: Colors.white),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final ranges = distribution.keys.toList();
                        if (value.toInt() < ranges.length) {
                          return Text(
                            ranges[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: distribution.keys.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final range = entry.value;
                  final count = (distribution[range] as num).toDouble();
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: Colors.purple,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 월별 트렌드 차트
  static Widget buildMonthlyTrendChart(Map<String, dynamic>? timeData) {
    if (timeData == null || timeData.isEmpty) {
      return buildEmptyChart('월별 트렌드', '월별 데이터가 없습니다');
    }

    final monthlyData = timeData['monthly'] as Map<String, dynamic>? ?? {};
    if (monthlyData.isEmpty) {
      return buildEmptyChart('월별 트렌드', '월별 데이터가 없습니다');
    }

    final spots = <FlSpot>[];
    int index = 0;
    monthlyData.forEach((month, count) {
      spots.add(FlSpot(index.toDouble(), (count as num).toDouble()));
      index++;
    });

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월별 수집 트렌드',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final months = monthlyData.keys.toList();
                        if (value.toInt() < months.length) {
                          return Text(
                            months[value.toInt()],
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.indigo,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.indigo.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 주중 vs 주말 차트
  static Widget buildWeekdayVsWeekendChart(Map<String, dynamic>? timeData) {
    if (timeData == null || timeData.isEmpty) {
      return buildEmptyChart('주중 vs 주말', '시간 데이터가 없습니다');
    }

    final weekdayData = timeData['weekday'] as Map<String, dynamic>? ?? {};
    final weekendData = timeData['weekend'] as Map<String, dynamic>? ?? {};

    if (weekdayData.isEmpty && weekendData.isEmpty) {
      return buildEmptyChart('주중 vs 주말', '시간 데이터가 없습니다');
    }

    final weekdaySpots = <FlSpot>[];
    final weekendSpots = <FlSpot>[];

    for (int hour = 0; hour < 24; hour++) {
      weekdaySpots.add(FlSpot(hour.toDouble(), (weekdayData[hour.toString()] as num?)?.toDouble() ?? 0));
      weekendSpots.add(FlSpot(hour.toDouble(), (weekendData[hour.toString()] as num?)?.toDouble() ?? 0));
    }

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주중 vs 주말 패턴',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}시',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: weekdaySpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: weekendSpots,
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              buildLegend(Colors.blue, '주중'),
              const SizedBox(width: 20),
              buildLegend(Colors.red, '주말'),
            ],
          ),
        ],
      ),
    );
  }

  // 시간대별 효율성 차트
  static Widget buildHourlyEfficiencyChart(Map<String, dynamic>? performanceData) {
    if (performanceData == null || performanceData.isEmpty) {
      return buildEmptyChart('시간대별 효율성', '효율성 데이터가 없습니다');
    }

    final hourlyEfficiency = performanceData['hourlyEfficiency'] as Map<String, dynamic>? ?? {};
    if (hourlyEfficiency.isEmpty) {
      return buildEmptyChart('시간대별 효율성', '효율성 데이터가 없습니다');
    }

    final spots = <FlSpot>[];
    hourlyEfficiency.forEach((hour, efficiency) {
      spots.add(FlSpot(int.parse(hour).toDouble(), (efficiency as num).toDouble()));
    });

    return Container(
      height: 300,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '시간대별 효율성',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}시',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.teal,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.teal.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 빈 차트 위젯
  static Widget buildEmptyChart(String title, String message) {
    return Container(
      height: 300,
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
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
      ),
    );
  }

  // 범례 위젯
  static Widget buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

