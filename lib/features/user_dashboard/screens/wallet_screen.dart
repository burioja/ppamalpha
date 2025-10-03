import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data/points_service.dart';
import '../../../core/models/user/user_points_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  final PointsService _pointsService = PointsService();
  UserPointsModel? userPoints;
  List<Map<String, dynamic>> pointsHistory = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserPoints();
    _loadPointsHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _loadUserPoints() async {
    if (userId == null) return;

    try {
      final points = await _pointsService.getUserPoints(userId!);
      setState(() {
        userPoints = points;
      });
    } catch (e) {
      debugPrint('포인트 정보 로드 오류: $e');
    }
  }

  Future<void> _loadPointsHistory() async {
    if (userId == null) return;

    try {
      final history = await _pointsService.getPointsHistory(userId!);
      setState(() {
        pointsHistory = history;
      });
    } catch (e) {
      debugPrint('포인트 히스토리 로드 오류: $e');
    }
  }

  Widget _buildPointsTab() {
    if (userPoints == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 포인트 정보 카드
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(userPoints!.gradeColor),
                Color(userPoints!.gradeColor).withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '보유 포인트',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${userPoints!.formattedPoints}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      userPoints!.grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level ${userPoints!.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: userPoints!.levelProgress,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '다음 레벨까지 ${userPoints!.pointsToNextLevel}P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 포인트 충전 버튼 (기능 미구현)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('포인트 충전 기능은 곧 제공될 예정입니다')),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('포인트 충전'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.blue[600]!),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 포인트 히스토리
        Expanded(
          child: pointsHistory.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '포인트 사용 기록이 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: pointsHistory.length,
                  itemBuilder: (context, index) {
                    return _buildPointsHistoryItem(pointsHistory[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPointsStatisticsTab() {
    if (userPoints == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // 포인트 통계 계산
    final earnedPoints = pointsHistory
        .where((item) => item['type'] == 'earned')
        .fold<int>(0, (sum, item) => sum + (item['points'] as int));

    final usedPoints = pointsHistory
        .where((item) => item['type'] != 'earned')
        .fold<int>(0, (sum, item) => sum + (item['points'] as int));

    final totalTransactions = pointsHistory.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '포인트 통계',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 통계 카드들
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '획득 포인트',
                  '${_formatNumber(earnedPoints)}P',
                  Colors.green,
                  Icons.add_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '사용 포인트',
                  '${_formatNumber(usedPoints)}P',
                  Colors.red,
                  Icons.remove_circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '현재 포인트',
                  '${_formatNumber(userPoints!.totalPoints)}P',
                  Colors.blue,
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '총 거래',
                  '${_formatNumber(totalTransactions)}건',
                  Colors.purple,
                  Icons.swap_horiz,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 추가 정보
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '등급 정보',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('현재 등급', userPoints!.grade),
                  _buildInfoRow('레벨', 'Level ${userPoints!.level}'),
                  _buildInfoRow('다음 레벨까지', '${_formatNumber(userPoints!.pointsToNextLevel)}P'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 일별 포인트 누적 그래프
          if (pointsHistory.isNotEmpty) ...[
            _buildDailyPointsChart(),
            const SizedBox(height: 24),
          ],

          // 월별 포인트 그래프
          if (pointsHistory.isNotEmpty) ...[
            _buildMonthlyPointsChart(),
            const SizedBox(height: 24),
          ],

          // 요일별 포인트 그래프
          if (pointsHistory.isNotEmpty) ...[
            _buildWeekdayPointsChart(),
            const SizedBox(height: 24),
          ],

          // 획득 포인트 히스토그램
          if (pointsHistory.isNotEmpty) ...[
            _buildPointsHistogram(),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyPointsChart() {
    // 날짜별 누적 포인트 계산
    final Map<String, int> dailyPoints = {};

    for (final item in pointsHistory) {
      final timestamp = item['timestamp'] as DateTime;
      final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);
      final points = item['points'] as int;
      final isEarned = item['type'] == 'earned';

      dailyPoints[dateKey] = (dailyPoints[dateKey] ?? 0) + (isEarned ? points : -points);
    }

    final sortedDates = dailyPoints.keys.toList()..sort();
    final List<FlSpot> spots = [];
    int cumulative = 0;

    for (int i = 0; i < sortedDates.length; i++) {
      cumulative += dailyPoints[sortedDates[i]]!;
      spots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '일별 포인트 누적 추이',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value.toInt()),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (sortedDates.length / 5).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedDates.length) {
                            final date = DateTime.parse(sortedDates[index]);
                            return Text(
                              DateFormat('M/d').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyPointsChart() {
    // 월별 포인트 집계
    final Map<String, int> monthlyPoints = {};

    for (final item in pointsHistory) {
      final timestamp = item['timestamp'] as DateTime;
      final monthKey = DateFormat('yyyy-MM').format(timestamp);
      final points = item['points'] as int;
      final isEarned = item['type'] == 'earned';

      if (isEarned) {
        monthlyPoints[monthKey] = (monthlyPoints[monthKey] ?? 0) + points;
      }
    }

    final sortedMonths = monthlyPoints.keys.toList()..sort();
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < sortedMonths.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlyPoints[sortedMonths[i]]!.toDouble(),
              color: Colors.green,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 포인트 획득',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value.toInt()),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < sortedMonths.length) {
                            final date = DateTime.parse('${sortedMonths[index]}-01');
                            return Text(
                              DateFormat('yy/MM').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayPointsChart() {
    // 요일별 포인트 집계
    final Map<int, int> weekdayPoints = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

    for (final item in pointsHistory) {
      final timestamp = item['timestamp'] as DateTime;
      final weekday = timestamp.weekday; // 1=월요일, 7=일요일
      final points = item['points'] as int;
      final isEarned = item['type'] == 'earned';

      if (isEarned) {
        weekdayPoints[weekday] = (weekdayPoints[weekday]! + points);
      }
    }

    final List<BarChartGroupData> barGroups = [];
    for (int i = 1; i <= 7; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i - 1,
          barRods: [
            BarChartRodData(
              toY: weekdayPoints[i]!.toDouble(),
              color: Colors.orange,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '요일별 포인트 획득',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberFormat.compact().format(value.toInt()),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < 7) {
                            return Text(
                              weekdayNames[index],
                              style: const TextStyle(fontSize: 12),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsHistogram() {
    // 획득 포인트 분포 (히스토그램)
    final Map<String, int> distribution = {
      '0-100': 0,
      '100-500': 0,
      '500-1K': 0,
      '1K-5K': 0,
      '5K+': 0,
    };

    for (final item in pointsHistory) {
      final isEarned = item['type'] == 'earned';
      if (!isEarned) continue;

      final points = item['points'] as int;
      if (points < 100) {
        distribution['0-100'] = distribution['0-100']! + 1;
      } else if (points < 500) {
        distribution['100-500'] = distribution['100-500']! + 1;
      } else if (points < 1000) {
        distribution['500-1K'] = distribution['500-1K']! + 1;
      } else if (points < 5000) {
        distribution['1K-5K'] = distribution['1K-5K']! + 1;
      } else {
        distribution['5K+'] = distribution['5K+']! + 1;
      }
    }

    final categories = distribution.keys.toList();
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < categories.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: distribution[categories[i]]!.toDouble(),
              color: Colors.purple,
              width: 30,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '획득 포인트 분포',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '각 구간별 획득 건수',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < categories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                categories[index],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    return NumberFormat('#,###').format(number);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsHistoryItem(Map<String, dynamic> item) {
    final isEarned = item['type'] == 'earned';
    final points = item['points'] as int;
    final reason = item['reason'] as String;
    final timestamp = item['timestamp'] as DateTime;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEarned ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isEarned ? Icons.add : Icons.remove,
            color: isEarned ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          reason,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _formatDate(timestamp),
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Text(
          '${isEarned ? '+' : '-'}${points}P',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isEarned ? Colors.green : Colors.red,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지갑'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '포인트'),
            Tab(text: '포인트 통계'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 포인트 탭
          _buildPointsTab(),
          // 포인트 통계 탭
          _buildPointsStatisticsTab(),
        ],
      ),
    );
  }
} 