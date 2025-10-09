import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_statistics_service.dart';

/// 배포된 포스트의 통합 통계 대시보드
/// 개별 포스트 통계와 동일한 7개 탭 구조 (기본/수집자/시간/위치/성과/쿠폰/회수)
class DeploymentStatisticsDashboardScreen extends StatefulWidget {
  const DeploymentStatisticsDashboardScreen({super.key});

  @override
  State<DeploymentStatisticsDashboardScreen> createState() =>
      _DeploymentStatisticsDashboardScreenState();
}

class _DeploymentStatisticsDashboardScreenState
    extends State<DeploymentStatisticsDashboardScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostStatisticsService _statisticsService = PostStatisticsService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // 집계된 통계 데이터
  Map<String, dynamic>? _aggregatedStats;
  List<PostModel> _deployedPosts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadStatistics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. 내가 배포한 포스트만 조회 (DEPLOYED 상태)
      final postsQuery = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'deployed')
          .orderBy('deployedAt', descending: true)
          .get();

      final deployedPosts = postsQuery.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // 2. 각 포스트의 통계를 병렬로 조회
      final postIds = deployedPosts.map((p) => p.postId).toList();
      final List<Map<String, dynamic>> allPostStats = [];

      if (postIds.isNotEmpty) {
        final statsResults = await Future.wait(
          postIds.map((postId) => _statisticsService.getPostStatistics(postId)),
        );
        allPostStats.addAll(statsResults);
      }

      // 3. 통계 집계
      final aggregated = _aggregateStatistics(deployedPosts, allPostStats);

      setState(() {
        _deployedPosts = deployedPosts;
        _aggregatedStats = aggregated;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _aggregateStatistics(
    List<PostModel> posts,
    List<Map<String, dynamic>> postStats,
  ) {
    // 기본 집계
    int totalDeployedPosts = posts.length;

    // 배포 관련 집계
    int totalDeployments = 0;
    int totalQuantity = 0;
    int totalCollected = 0;
    int totalUsed = 0;

    // 수집자 집계
    Set<String> uniqueCollectors = {};
    Map<String, int> collectorCounts = {};

    // 시간 패턴 집계
    Map<int, int> hourlyCollections = {};
    Map<String, int> dailyCollections = {};
    Map<String, int> monthlyCollections = {};

    // 쿠폰 집계
    int couponPosts = posts.where((p) => p.isCoupon).length;

    // 리워드 집계
    int totalRewardBudget = posts.fold<int>(0, (sum, p) => sum + p.reward);

    for (final stat in postStats) {
      totalDeployments += stat['totalDeployments'] as int? ?? 0;
      totalQuantity += stat['totalQuantityDeployed'] as int? ?? 0;
      totalCollected += stat['totalCollected'] as int? ?? 0;
      totalUsed += stat['totalUsed'] as int? ?? 0;

      // 수집자 데이터
      final collectors = stat['collectors'] as Map<String, dynamic>?;
      if (collectors != null) {
        final collectionsList = stat['collections'] as List? ?? [];
        for (final collection in collectionsList) {
          final userId = collection['userId'] as String;
          uniqueCollectors.add(userId);
          collectorCounts[userId] = (collectorCounts[userId] ?? 0) + 1;
        }
      }

      // 시간 패턴
      final timePattern = stat['timePattern'] as Map<String, dynamic>?;
      if (timePattern != null) {
        final hourly = timePattern['hourly'] as Map?;
        if (hourly != null) {
          hourly.forEach((hour, count) {
            final h = int.tryParse(hour.toString()) ?? 0;
            hourlyCollections[h] = (hourlyCollections[h] ?? 0) + (count as int);
          });
        }

        final daily = timePattern['daily'] as Map?;
        if (daily != null) {
          daily.forEach((day, count) {
            dailyCollections[day.toString()] = (dailyCollections[day.toString()] ?? 0) + (count as int);
          });
        }
      }
    }

    // 수집률 및 사용률 계산
    final collectionRate = totalQuantity > 0 ? (totalCollected / totalQuantity) * 100 : 0.0;
    final usageRate = totalCollected > 0 ? (totalUsed / totalCollected) * 100 : 0.0;

    return {
      'totalDeployedPosts': totalDeployedPosts,
      'totalDeployments': totalDeployments,
      'totalQuantity': totalQuantity,
      'totalCollected': totalCollected,
      'totalUsed': totalUsed,
      'collectionRate': collectionRate,
      'usageRate': usageRate,
      'uniqueCollectors': uniqueCollectors.length,
      'collectorCounts': collectorCounts,
      'hourlyCollections': hourlyCollections,
      'dailyCollections': dailyCollections,
      'monthlyCollections': monthlyCollections,
      'totalRewardBudget': totalRewardBudget,
      'couponPosts': couponPosts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('배포 통계 대시보드'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '새로고침',
          ),
        ],
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: '기본', icon: Icon(Icons.dashboard, size: 20)),
                  Tab(text: '수집자', icon: Icon(Icons.people, size: 20)),
                  Tab(text: '시간', icon: Icon(Icons.schedule, size: 20)),
                  Tab(text: '위치', icon: Icon(Icons.map, size: 20)),
                  Tab(text: '성과', icon: Icon(Icons.analytics, size: 20)),
                  Tab(text: '쿠폰', icon: Icon(Icons.card_giftcard, size: 20)),
                  Tab(text: '회수', icon: Icon(Icons.restore, size: 20)),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _aggregatedStats == null
                  ? const Center(child: Text('통계 데이터가 없습니다'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBasicTab(),
                        _buildCollectorTab(),
                        _buildTimeTab(),
                        _buildLocationTab(),
                        _buildPerformanceTab(),
                        _buildCouponTab(),
                        _buildRecallTab(),
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

  // Tab 1: 기본 통계
  Widget _buildBasicTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '배포 개요',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.rocket_launch,
                    label: '배포된 포스트',
                    value: '${_aggregatedStats!['totalDeployedPosts']}개',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.location_on,
                    label: '총 마커',
                    value: '${NumberFormat('#,###').format(_aggregatedStats!['totalDeployments'])}개',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '수집 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_2,
                    label: '배포 수량',
                    value: '${NumberFormat('#,###').format(_aggregatedStats!['totalQuantity'])}개',
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.download,
                    label: '총 수집',
                    value: '${NumberFormat('#,###').format(_aggregatedStats!['totalCollected'])}건',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.percent,
                    label: '수집률',
                    value: '${_aggregatedStats!['collectionRate'].toStringAsFixed(1)}%',
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: '리워드 예산',
                    value: '${NumberFormat('#,###').format(_aggregatedStats!['totalRewardBudget'])}원',
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tab 2: 수집자 분석
  Widget _buildCollectorTab() {
    final uniqueCollectors = _aggregatedStats!['uniqueCollectors'] as int;
    final totalCollected = _aggregatedStats!['totalCollected'] as int;
    final avgPerCollector = uniqueCollectors > 0 ? totalCollected / uniqueCollectors : 0.0;

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수집자 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people,
                    label: '총 수집자',
                    value: '${NumberFormat('#,###').format(uniqueCollectors)}명',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.person,
                    label: '1인당 평균',
                    value: '${avgPerCollector.toStringAsFixed(1)}개',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildTopCollectorsChart(),
          ],
        ),
      ),
    );
  }

  // Tab 3: 시간 분석
  Widget _buildTimeTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시간대별 수집 패턴',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildHourlyChart(),
            const SizedBox(height: 24),
            const Text(
              '요일별 수집 패턴',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDailyChart(),
          ],
        ),
      ),
    );
  }

  // Tab 4: 위치 분석
  Widget _buildLocationTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '위치 분석',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '총 ${_aggregatedStats!['totalDeployedPosts']}개 포스트가 배포되었습니다',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 5: 성과 분석
  Widget _buildPerformanceTab() {
    final collectionRate = _aggregatedStats!['collectionRate'] as double;
    final totalRewardPaid = (_aggregatedStats!['totalUsed'] as int) *
        (_deployedPosts.isNotEmpty ? _deployedPosts[0].reward : 0);

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ROI 분석',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    label: '수집률',
                    value: '${collectionRate.toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: '지급 리워드',
                    value: '${NumberFormat('#,###').format(totalRewardPaid)}원',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tab 6: 쿠폰 분석
  Widget _buildCouponTab() {
    final couponPosts = _aggregatedStats!['couponPosts'] as int;

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '쿠폰 포스트',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.card_giftcard,
              label: '배포된 쿠폰 포스트',
              value: '$couponPosts개',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  // Tab 7: 회수 분석
  Widget _buildRecallTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '회수 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '배포 중인 포스트는 회수되지 않았습니다',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '회수된 포스트는 이 화면에 표시되지 않습니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCollectorsChart() {
    final collectorCounts = _aggregatedStats!['collectorCounts'] as Map<String, int>;
    final topCollectors = collectorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = topCollectors.take(10).toList();

    if (top10.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '아직 수집자가 없습니다',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      );
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < top10.length; i++) {
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: top10[i].value.toDouble(),
              color: Colors.blue,
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
              'Top 10 수집자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
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
                          return Text(
                            '#${value.toInt() + 1}',
                            style: const TextStyle(fontSize: 10),
                          );
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

  Widget _buildHourlyChart() {
    final hourlyData = _aggregatedStats!['hourlyCollections'] as Map<int, int>;
    final barGroups = <BarChartGroupData>[];

    for (int hour = 0; hour < 24; hour++) {
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: (hourlyData[hour] ?? 0).toDouble(),
              color: Colors.blue,
              width: 8,
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
                          final hour = value.toInt();
                          if (hour % 3 == 0) {
                            return Text(
                              '${hour}시',
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

  Widget _buildDailyChart() {
    final dailyData = _aggregatedStats!['dailyCollections'] as Map<String, int>;
    final days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final spots = <FlSpot>[];

    for (int i = 0; i < days.length; i++) {
      spots.add(FlSpot(i.toDouble(), (dailyData[days[i]] ?? 0).toDouble()));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                  ],
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
                          if (index >= 0 && index < days.length) {
                            return Text(
                              days[index].substring(0, 1),
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
}
