import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeploymentStatisticsDashboardScreen extends StatefulWidget {
  const DeploymentStatisticsDashboardScreen({super.key});

  @override
  State<DeploymentStatisticsDashboardScreen> createState() =>
      _DeploymentStatisticsDashboardScreenState();
}

class _DeploymentStatisticsDashboardScreenState
    extends State<DeploymentStatisticsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = true;
  String? _error;

  // 통계 데이터
  int _totalPosts = 0;
  int _activePosts = 0;
  int _deletedPosts = 0;
  int _totalRewards = 0;
  Map<String, int> _storePostCounts = {};
  Map<String, int> _timelineDeployments = {};
  Map<String, int> _timelineCollections = {};
  Map<String, int> _timelineRewards = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _totalRewards = 0; // 초기화
    });

    try {
      // 1. 내 포스트 조회
      final postsQuery = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: _currentUserId)
          .get();

      final posts = postsQuery.docs;
      _totalPosts = posts.length;

      // status 필드 확인 (PostStatus enum 사용)
      _activePosts = posts.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'deployed' || status == 'draft';
      }).length;
      _deletedPosts = posts.where((doc) {
        final status = doc.data()['status'] as String?;
        return status == 'deleted';
      }).length;

      // 2. 스토어별/날짜별 집계
      final storeCount = <String, int>{};
      final timelineDeploy = <String, int>{};
      final timelineReward = <String, int>{};
      final postIds = <String>[];

      for (final doc in posts) {
        final data = doc.data();
        postIds.add(doc.id);

        // 스토어별 집계
        final placeId = data['placeId'] as String?;
        if (placeId != null) {
          storeCount[placeId] = (storeCount[placeId] ?? 0) + 1;
        }

        // 생성 날짜별 배포 집계
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null) {
          final dateKey = DateFormat('yyyy-MM-dd').format(createdAt);
          timelineDeploy[dateKey] = (timelineDeploy[dateKey] ?? 0) + 1;

          // 날짜별 리워드 집계
          final reward = data['reward'] as int? ?? 0;
          _totalRewards += reward;
          timelineReward[dateKey] = (timelineReward[dateKey] ?? 0) + reward;
        }
      }

      // 3. 내 모든 포스트에 대한 수집 데이터를 한번에 조회 (최적화)
      final timelineCollect = <String, int>{};

      if (postIds.isNotEmpty) {
        // postId별로 수집 데이터 조회 (배치 처리)
        for (final postId in postIds) {
          final collectionsQuery = await _firestore
              .collection('post_collections')
              .where('postId', isEqualTo: postId)
              .get();

          for (final collectionDoc in collectionsQuery.docs) {
            final collectionData = collectionDoc.data();
            final collectedAt = (collectionData['collectedAt'] as Timestamp?)?.toDate();

            if (collectedAt != null) {
              final dateKey = DateFormat('yyyy-MM-dd').format(collectedAt);
              timelineCollect[dateKey] = (timelineCollect[dateKey] ?? 0) + 1;
            }
          }
        }
      }

      setState(() {
        _storePostCounts = storeCount;
        _timelineDeployments = timelineDeploy;
        _timelineCollections = timelineCollect;
        _timelineRewards = timelineReward;
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _buildDashboard(),
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

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 전체 통계 요약
            _buildOverallStats(),
            const SizedBox(height: 24),

            // 스토어별 포스트 개수 (파이 차트)
            if (_storePostCounts.isNotEmpty) ...[
              _buildStoreDistributionChart(),
              const SizedBox(height: 24),
            ],

            // 시계열별 배포/수집 (선 그래프)
            if (_timelineDeployments.isNotEmpty) ...[
              _buildTimelineChart(),
              const SizedBox(height: 24),
            ],

            // 시계열별 리워드 (막대 그래프)
            if (_timelineRewards.isNotEmpty) ...[
              _buildRewardTimelineChart(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '전체 통계',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.article,
                label: '총 포스트',
                value: '$_totalPosts개',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: '활성',
                value: '$_activePosts개',
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.delete,
                label: '삭제',
                value: '$_deletedPosts개',
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                label: '총 리워드',
                value: '${NumberFormat('#,###').format(_totalRewards)}원',
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDistributionChart() {
    final sections = _storePostCounts.entries.take(5).map((entry) {
      final total = _storePostCounts.values.reduce((a, b) => a + b);
      final percentage = (entry.value / total * 100).toStringAsFixed(1);

      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '$percentage%',
        color: _getColorForIndex(_storePostCounts.keys.toList().indexOf(entry.key)),
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '스토어별 포스트 분포',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineChart() {
    final sortedDates = _timelineDeployments.keys.toList()..sort();
    final deploySpots = <FlSpot>[];
    final collectSpots = <FlSpot>[];

    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      deploySpots.add(FlSpot(i.toDouble(), (_timelineDeployments[date] ?? 0).toDouble()));
      collectSpots.add(FlSpot(i.toDouble(), (_timelineCollections[date] ?? 0).toDouble()));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시계열별 배포/수집 추이',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: deploySpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    LineChartBarData(
                      spots: collectSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.3),
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
                          if (index >= 0 && index < sortedDates.length) {
                            final date = DateTime.parse(sortedDates[index]);
                            return Text(
                              DateFormat('MM/dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.blue, '배포'),
                const SizedBox(width: 16),
                _buildLegend(Colors.green, '수집'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardTimelineChart() {
    final sortedDates = _timelineRewards.keys.toList()..sort();
    final barGroups = <BarChartGroupData>[];

    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (_timelineRewards[date] ?? 0).toDouble(),
              color: Colors.orange,
              width: 16,
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
              '시계열별 리워드 지급',
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
                          if (index >= 0 && index < sortedDates.length) {
                            final date = DateTime.parse(sortedDates[index]);
                            return Text(
                              DateFormat('MM/dd').format(date),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
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

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    return colors[index % colors.length];
  }
}
