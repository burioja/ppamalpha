import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/place_statistics_service.dart';

class PlaceStatisticsScreen extends StatefulWidget {
  final PlaceModel place;

  const PlaceStatisticsScreen({super.key, required this.place});

  @override
  State<PlaceStatisticsScreen> createState() => _PlaceStatisticsScreenState();
}

class _PlaceStatisticsScreenState extends State<PlaceStatisticsScreen> with SingleTickerProviderStateMixin {
  final PlaceStatisticsService _statisticsService = PlaceStatisticsService();
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _timeAnalytics;
  Map<String, dynamic>? _collectorAnalytics;
  Map<String, dynamic>? _performanceAnalytics;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _statisticsService.getPlaceStatistics(widget.place.id),
        _statisticsService.getTimeAnalytics(widget.place.id),
        _statisticsService.getCollectorAnalytics(widget.place.id),
        _statisticsService.getPerformanceAnalytics(widget.place.id),
      ]);

      setState(() {
        _statistics = results[0];
        _timeAnalytics = results[1];
        _collectorAnalytics = results[2];
        _performanceAnalytics = results[3];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이스 통계'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '새로고침',
          ),
        ],
        bottom: _isLoading || _error != null ? null : TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '기본', icon: Icon(Icons.dashboard, size: 20)),
            Tab(text: '포스트 비교', icon: Icon(Icons.compare_arrows, size: 20)),
            Tab(text: '수집자', icon: Icon(Icons.people, size: 20)),
            Tab(text: '시간', icon: Icon(Icons.schedule, size: 20)),
            Tab(text: '성과', icon: Icon(Icons.analytics, size: 20)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _statistics == null
                  ? const Center(child: Text('통계 데이터가 없습니다'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBasicStatisticsTab(),
                        _buildPostComparisonTab(),
                        _buildCollectorAnalysisTab(),
                        _buildTimeAnalysisTab(),
                        _buildPerformanceAnalysisTab(),
                      ],
                    ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            '통계를 불러오는데 실패했습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? '',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadStatistics,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: 기본 통계 ====================
  Widget _buildBasicStatisticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPlaceInfo(),
        const SizedBox(height: 24),
        _buildOverviewCards(),
        const SizedBox(height: 24),
        _buildCollectionRateCard(),
        const SizedBox(height: 24),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildPlaceInfo() {
    final place = _statistics!['place'] as Map<String, dynamic>;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, size: 28, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['name'] ?? '플레이스 이름 없음',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      if (place['address'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          place['address'],
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalPosts = _statistics!['totalPosts'] as int;
    final totalCollected = _statistics!['totalCollected'] as int;
    final totalDeployments = _statistics!['totalDeployments'] as int;
    final collectionRate = (_statistics!['collectionRate'] as double) * 100;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '배포된 포스트',
                '$totalPosts',
                Icons.post_add,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '총 배포 횟수',
                '$totalDeployments',
                Icons.map_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '총 수집',
                '$totalCollected',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '수집률',
                '${collectionRate.toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionRateCard() {
    final collectionRate = (_statistics!['collectionRate'] as double) * 100;
    final usageRate = (_statistics!['usageRate'] as double) * 100;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수집 및 사용 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressBar('수집률', collectionRate, Colors.blue),
            const SizedBox(height: 12),
            _buildProgressBar('사용률', usageRate, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final collections = _statistics!['collections'] as List<dynamic>;
    final recentCollections = collections.take(5).toList();

    if (recentCollections.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '아직 수집 활동이 없습니다',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
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
              '최근 수집 활동',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...recentCollections.map((collection) {
              final collectedAt = (collection['collectedAt'] as Timestamp).toDate();
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('수집 완료'),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(collectedAt)),
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 2: 포스트 비교 ====================
  Widget _buildPostComparisonTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPostRankingCard(),
        const SizedBox(height: 24),
        _buildPostPerformanceChart(),
      ],
    );
  }

  Widget _buildPostRankingCard() {
    final postStats = _statistics!['postStatistics'] as List<dynamic>;

    if (postStats.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '배포된 포스트가 없습니다',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
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
              '포스트별 성과',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...postStats.asMap().entries.map((entry) {
              final index = entry.key;
              final stat = entry.value;
              final post = stat['post'] as PostModel;
              final collectionRate = (stat['collectionRate'] as double) * 100;
              final collected = stat['collected'] as int;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getPerformanceColor(collectionRate),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('수집: $collected건'),
                  trailing: Text(
                    '${collectionRate.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getPerformanceColor(collectionRate),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPostPerformanceChart() {
    final postStats = _statistics!['postStatistics'] as List<dynamic>;

    if (postStats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '포스트별 수집률 비교',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: postStats.asMap().entries.map((entry) {
                    final index = entry.key;
                    final stat = entry.value;
                    final collectionRate = (stat['collectionRate'] as double) * 100;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: collectionRate,
                          color: _getPerformanceColor(collectionRate),
                          width: 20,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('P${value.toInt() + 1}');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 70) return Colors.green;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  // ==================== TAB 3: 수집자 분석 ====================
  Widget _buildCollectorAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCollectorOverview(),
        const SizedBox(height: 24),
        _buildTopCollectors(),
      ],
    );
  }

  Widget _buildCollectorOverview() {
    final collectors = _collectorAnalytics!;
    final uniqueCount = collectors['uniqueCount'] as int;
    final totalCollections = collectors['totalCollections'] as int;
    final averagePerUser = collectors['averagePerUser'] as double;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '고유 수집자',
            '$uniqueCount명',
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '평균 수집',
            '${averagePerUser.toStringAsFixed(1)}건',
            Icons.bar_chart,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCollectors() {
    final collectors = _collectorAnalytics!;
    final topCollectors = collectors['topCollectors'] as List<dynamic>;

    if (topCollectors.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '수집자가 없습니다',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
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
              '상위 수집자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...topCollectors.asMap().entries.map((entry) {
              final index = entry.key;
              final collector = entry.value;
              final userId = collector['userId'] as String;
              final count = collector['count'] as int;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text('수집자 $userId'),
                trailing: Text(
                  '$count건',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey[400]!;
    if (index == 2) return Colors.brown[300]!;
    return Colors.blue;
  }

  // ==================== TAB 4: 시간 분석 ====================
  Widget _buildTimeAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHourlyChart(),
        const SizedBox(height: 24),
        _buildWeekdayChart(),
        const SizedBox(height: 24),
        _buildMonthlyTrend(),
      ],
    );
  }

  Widget _buildHourlyChart() {
    final hourlyRate = _timeAnalytics!['hourlyRate'] as Map<String, dynamic>;

    if (hourlyRate.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시간대별 수집 패턴',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}시');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(24, (hour) {
                        final count = hourlyRate[hour.toString()] as int? ?? 0;
                        return FlSpot(hour.toDouble(), count.toDouble());
                      }),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayChart() {
    final weekdayVsWeekend = _timeAnalytics!['weekdayVsWeekend'] as Map<String, dynamic>;
    final weekdayCount = weekdayVsWeekend['weekday'] as int;
    final weekendCount = weekdayVsWeekend['weekend'] as int;

    if (weekdayCount == 0 && weekendCount == 0) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '평일 vs 주말',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('평일', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        '$weekdayCount건',
                        style: const TextStyle(fontSize: 24, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text('주말', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        '$weekendCount건',
                        style: const TextStyle(fontSize: 24, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrend() {
    final monthlyTrend = _timeAnalytics!['monthlyTrend'] as Map<String, dynamic>;

    if (monthlyTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '월별 수집 트렌드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...monthlyTrend.entries.map((entry) {
              return ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: Text(entry.key),
                trailing: Text(
                  '${entry.value}건',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 5: 성과 분석 ====================
  Widget _buildPerformanceAnalysisTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPerformanceOverview(),
        const SizedBox(height: 24),
        _buildTopPerformers(),
        const SizedBox(height: 24),
        _buildLowPerformers(),
      ],
    );
  }

  Widget _buildPerformanceOverview() {
    final averageROI = (_performanceAnalytics!['averageROI'] as double) * 100;
    final efficiency = (_performanceAnalytics!['efficiency'] as double) * 100;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '평균 ROI',
            '${averageROI.toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '효율성',
            '${efficiency.toStringAsFixed(1)}%',
            Icons.speed,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildTopPerformers() {
    final topPerformers = _performanceAnalytics!['topPerformers'] as List<dynamic>;

    if (topPerformers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  '상위 성과 포스트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topPerformers.map((stat) {
              final post = stat['post'] as PostModel;
              final collectionRate = (stat['collectionRate'] as double) * 100;

              return ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text(post.title),
                trailing: Text(
                  '${collectionRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLowPerformers() {
    final lowPerformers = _performanceAnalytics!['lowPerformers'] as List<dynamic>;

    if (lowPerformers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  '개선이 필요한 포스트',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...lowPerformers.map((stat) {
              final post = stat['post'] as PostModel;
              final collectionRate = (stat['collectionRate'] as double) * 100;

              return ListTile(
                leading: const Icon(Icons.trending_down, color: Colors.red),
                title: Text(post.title),
                trailing: Text(
                  '${collectionRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
