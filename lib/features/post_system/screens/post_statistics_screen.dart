import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_statistics_service.dart';

class PostStatisticsScreen extends StatefulWidget {
  final PostModel post;

  const PostStatisticsScreen({super.key, required this.post});

  @override
  State<PostStatisticsScreen> createState() => _PostStatisticsScreenState();
}

class _PostStatisticsScreenState extends State<PostStatisticsScreen> {
  final PostStatisticsService _statisticsService = PostStatisticsService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _statisticsService.getPostStatistics(widget.post.postId);
      setState(() {
        _statistics = stats;
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
        title: const Text('포스트 통계'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportToCSV,
            tooltip: 'CSV 내보내기',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _statistics == null
                  ? const Center(child: Text('통계 데이터가 없습니다'))
                  : _buildStatisticsView(),
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

  Widget _buildStatisticsView() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스트 정보 헤더
            _buildPostHeader(),
            const SizedBox(height: 24),

            // 전체 통계
            _buildOverallStatistics(),
            const SizedBox(height: 24),

            // 시간대별 수집 패턴
            _buildHourlyChart(),
            const SizedBox(height: 24),

            // 요일별 수집 패턴
            _buildDailyChart(),
            const SizedBox(height: 24),

            // 마커별 상세 정보
            _buildMarkersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final template = _statistics!['template'] as Map<String, dynamic>;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template['title'] ?? '(제목 없음)',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '보상: ${NumberFormat('#,###').format(template['reward'])}원',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildOverallStatistics() {
    final totalDeployments = _statistics!['totalDeployments'] as int;
    final totalQuantity = _statistics!['totalQuantityDeployed'] as int;
    final totalCollected = _statistics!['totalCollected'] as int;
    final collectionRate = (_statistics!['collectionRate'] as double) * 100;
    final usageRate = (_statistics!['usageRate'] as double) * 100;

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
                icon: Icons.rocket_launch,
                label: '총 배포',
                value: '$totalDeployments회',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.inventory_2,
                label: '배포 수량',
                value: '${totalQuantity}개',
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
                icon: Icons.download,
                label: '총 수집',
                value: '${totalCollected}건',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.percent,
                label: '수집률',
                value: '${collectionRate.toStringAsFixed(1)}%',
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          icon: Icons.check_circle,
          label: '사용률 (수집 대비)',
          value: '${usageRate.toStringAsFixed(1)}%',
          color: Colors.teal,
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
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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

  Widget _buildHourlyChart() {
    final timePattern = _statistics!['timePattern'] as Map<String, dynamic>;
    final hourlyData = timePattern['hourly'] as Map<String, dynamic>;

    if (hourlyData.isEmpty) {
      return _buildEmptyChart('시간대별 수집 패턴', '아직 수집 데이터가 없습니다');
    }

    // 0-23시 데이터 생성
    final List<BarChartGroupData> barGroups = [];
    for (int hour = 0; hour < 24; hour++) {
      final count = hourlyData[hour.toString()] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
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
            const Text(
              '시간대별 수집 패턴',
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart() {
    final timePattern = _statistics!['timePattern'] as Map<String, dynamic>;
    final dailyData = timePattern['daily'] as Map<String, dynamic>;

    if (dailyData.isEmpty) {
      return _buildEmptyChart('요일별 수집 패턴', '아직 수집 데이터가 없습니다');
    }

    final days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final List<FlSpot> spots = [];

    for (int i = 0; i < days.length; i++) {
      final count = dailyData[days[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), count.toDouble()));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '요일별 수집 패턴',
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
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.3),
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

  Widget _buildEmptyChart(String title, String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkersList() {
    final deployments = _statistics!['deployments'] as List<dynamic>;

    if (deployments.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '마커별 상세 정보',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '아직 배포된 마커가 없습니다',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ],
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
              '마커별 상세 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...deployments.asMap().entries.map((entry) {
              final index = entry.key;
              final marker = entry.value as Map<String, dynamic>;
              return _buildMarkerCard(index + 1, marker);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerCard(int index, Map<String, dynamic> marker) {
    final totalQuantity = marker['totalQuantity'] ?? marker['quantity'] ?? 0;
    final remainingQuantity = marker['remainingQuantity'] ?? totalQuantity;
    final collectedQuantity = totalQuantity - remainingQuantity;
    final collectionRate = totalQuantity > 0 ? (collectedQuantity / totalQuantity) * 100 : 0.0;

    final createdAt = (marker['createdAt'] as dynamic);
    final createdDate = createdAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate())
        : '알 수 없음';

    final expiresAt = (marker['expiresAt'] as dynamic);
    final expiresDate = expiresAt != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(expiresAt.toDate())
        : '알 수 없음';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '마커 #$index',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$collectedQuantity/$totalQuantity',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${collectionRate.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMarkerInfoRow(Icons.calendar_today, '배포일', createdDate),
          _buildMarkerInfoRow(Icons.access_time, '만료일', expiresDate),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: collectionRate / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              collectionRate >= 80
                  ? Colors.green
                  : collectionRate >= 50
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _exportToCSV() {
    if (_statistics == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('통계 데이터가 없습니다')),
      );
      return;
    }

    // TODO: CSV 내보내기 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV 내보내기 기능은 곧 제공될 예정입니다')),
    );
  }
}