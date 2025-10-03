import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';

class MyPostsStatisticsDashboardScreen extends StatefulWidget {
  const MyPostsStatisticsDashboardScreen({super.key});

  @override
  State<MyPostsStatisticsDashboardScreen> createState() =>
      _MyPostsStatisticsDashboardScreenState();
}

class _MyPostsStatisticsDashboardScreenState
    extends State<MyPostsStatisticsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = true;
  String? _error;

  // 통계 데이터
  List<PostModel> _allPosts = [];
  List<PostModel> _draftPosts = [];
  List<PostModel> _deployedPosts = [];
  List<PostModel> _deletedPosts = [];
  Map<String, int> _monthlyPostCreation = {};
  Map<String, dynamic> _performanceSummary = {};

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
    });

    try {
      // 1. 내 모든 포스트 조회
      final postsQuery = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      final allPosts = postsQuery.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();

      // 2. 상태별 분류
      final draftPosts = allPosts
          .where((post) => post.status == PostStatus.DRAFT)
          .toList();
      final deployedPosts =
          allPosts.where((post) => post.status == PostStatus.DEPLOYED).toList();
      final deletedPosts =
          allPosts.where((post) => post.status == PostStatus.DELETED).toList();

      // 3. 월별 생성 추이
      final monthlyCreation = <String, int>{};
      for (final post in allPosts) {
        final monthKey = DateFormat('yyyy-MM').format(post.createdAt);
        monthlyCreation[monthKey] = (monthlyCreation[monthKey] ?? 0) + 1;
      }

      // 4. 배포된 포스트의 성과 분석
      final performanceSummary = await _calculatePerformanceSummary(
          deployedPosts.map((p) => p.postId).toList());

      setState(() {
        _allPosts = allPosts;
        _draftPosts = draftPosts;
        _deployedPosts = deployedPosts;
        _deletedPosts = deletedPosts;
        _monthlyPostCreation = monthlyCreation;
        _performanceSummary = performanceSummary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _calculatePerformanceSummary(
      List<String> postIds) async {
    if (postIds.isEmpty) {
      return {
        'totalCollections': 0,
        'averageCollectionRate': 0.0,
        'topPosts': <Map<String, dynamic>>[],
      };
    }

    int totalCollections = 0;
    final postPerformance = <String, Map<String, dynamic>>{};

    for (final postId in postIds) {
      // 마커 정보
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      final totalQuantity = markersQuery.docs.fold<int>(
        0,
        (sum, doc) {
          final data = doc.data();
          return sum +
              ((data['totalQuantity'] ?? data['quantity']) as int? ?? 0);
        },
      );

      // 수집 정보
      final collectionsQuery = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final collected = collectionsQuery.size;
      totalCollections += collected;

      final collectionRate =
          totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      postPerformance[postId] = {
        'postId': postId,
        'totalQuantity': totalQuantity,
        'collected': collected,
        'collectionRate': collectionRate,
      };
    }

    // Top 5 성공적인 포스트
    final sortedPosts = postPerformance.values.toList()
      ..sort((a, b) =>
          (b['collectionRate'] as double).compareTo(a['collectionRate']));

    final topPosts = sortedPosts.take(5).map((data) {
      try {
        final post = _deployedPosts.firstWhere(
          (p) => p.postId == data['postId'],
        );
        return {
          'title': post.title,
          'collectionRate': data['collectionRate'],
          'collected': data['collected'],
          'totalQuantity': data['totalQuantity'],
        };
      } catch (e) {
        // 포스트를 찾을 수 없는 경우 기본값 반환
        return {
          'title': '알 수 없음',
          'collectionRate': data['collectionRate'],
          'collected': data['collected'],
          'totalQuantity': data['totalQuantity'],
        };
      }
    }).toList();

    final averageRate = postPerformance.isNotEmpty
        ? postPerformance.values
                .map((p) => p['collectionRate'] as double)
                .reduce((a, b) => a + b) /
            postPerformance.length
        : 0.0;

    return {
      'totalCollections': totalCollections,
      'averageCollectionRate': averageRate,
      'topPosts': topPosts,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 포스트 통계'),
        backgroundColor: Colors.blue[700],
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
            // 1. 전체 개요 (4개 카드)
            _buildOverviewCards(),
            const SizedBox(height: 24),

            // 2. 포스트 현황 파이 차트
            _buildStatusPieChart(),
            const SizedBox(height: 24),

            // 3. 월별 포스트 생성 추이
            if (_monthlyPostCreation.isNotEmpty) ...[
              _buildMonthlyTrendChart(),
              const SizedBox(height: 24),
            ],

            // 4. 배포 전 포스트 목록
            _buildDraftPostsList(),
            const SizedBox(height: 24),

            // 5. 리워드 통계
            _buildRewardStatistics(),
            const SizedBox(height: 24),

            // 6. 성과 요약 (배포된 포스트)
            if (_deployedPosts.isNotEmpty) ...[
              _buildPerformanceSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '전체 개요',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.article,
                label: '총 포스트',
                value: '${_allPosts.length}개',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.edit_note,
                label: '배포 전',
                value: '${_draftPosts.length}개',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.rocket_launch,
                label: '배포됨',
                value: '${_deployedPosts.length}개',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.delete,
                label: '삭제됨',
                value: '${_deletedPosts.length}개',
                color: Colors.red,
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

  Widget _buildStatusPieChart() {
    final total = _allPosts.length;
    if (total == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '포스트 현황',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '아직 포스트가 없습니다',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final sections = [
      if (_draftPosts.isNotEmpty)
        PieChartSectionData(
          value: _draftPosts.length.toDouble(),
          title:
              '${(_draftPosts.length / total * 100).toStringAsFixed(0)}%\n배포 전',
          color: Colors.orange,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (_deployedPosts.isNotEmpty)
        PieChartSectionData(
          value: _deployedPosts.length.toDouble(),
          title:
              '${(_deployedPosts.length / total * 100).toStringAsFixed(0)}%\n배포됨',
          color: Colors.green,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (_deletedPosts.isNotEmpty)
        PieChartSectionData(
          value: _deletedPosts.length.toDouble(),
          title:
              '${(_deletedPosts.length / total * 100).toStringAsFixed(0)}%\n삭제',
          color: Colors.red,
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '포스트 현황',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyTrendChart() {
    final sortedMonths = _monthlyPostCreation.keys.toList()..sort();
    final barGroups = <BarChartGroupData>[];

    for (var i = 0; i < sortedMonths.length; i++) {
      final month = sortedMonths[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (_monthlyPostCreation[month] ?? 0).toDouble(),
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
              '월별 포스트 생성 추이',
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
                          final index = value.toInt();
                          if (index >= 0 && index < sortedMonths.length) {
                            final month = sortedMonths[index];
                            return Text(
                              month.substring(5),
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

  Widget _buildDraftPostsList() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '배포 전 포스트 목록',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_draftPosts.length}개',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_draftPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '배포 전 포스트가 없습니다',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _draftPosts.length > 10 ? 10 : _draftPosts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final post = _draftPosts[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note, color: Colors.orange),
                    ),
                    title: Text(
                      post.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '리워드: ${NumberFormat('#,###').format(post.reward)}원 • ${DateFormat('yyyy-MM-dd').format(post.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/post-detail',
                        arguments: {
                          'post': post,
                          'isEditable': true,
                        },
                      );
                    },
                  );
                },
              ),
            if (_draftPosts.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '외 ${_draftPosts.length - 10}개',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardStatistics() {
    final totalDraftReward = _draftPosts.fold<int>(
      0,
      (sum, post) => sum + post.reward,
    );
    final totalDeployedReward = _deployedPosts.fold<int>(
      0,
      (sum, post) => sum + post.reward,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '리워드 통계',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildRewardCard(
                    label: '배포 전 예상 비용',
                    value: NumberFormat('#,###').format(totalDraftReward),
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRewardCard(
                    label: '배포된 최대 비용',
                    value: NumberFormat('#,###').format(totalDeployedReward),
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRewardCard(
              label: '총 예상 최대 비용',
              value: NumberFormat('#,###')
                  .format(totalDraftReward + totalDeployedReward),
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value원',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    final summary = _performanceSummary;
    final totalCollections = summary['totalCollections'] as int? ?? 0;
    final averageRate = summary['averageCollectionRate'] as double? ?? 0.0;
    final topPosts =
        summary['topPosts'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '성과 요약 (배포된 포스트)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.download,
                    label: '총 수집',
                    value: '${NumberFormat('#,###').format(totalCollections)}건',
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    label: '평균 수집률',
                    value: '${averageRate.toStringAsFixed(1)}%',
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            if (topPosts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Top 5 성공 포스트',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...topPosts.asMap().entries.map((entry) {
                final index = entry.key;
                final post = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${post['collected']}/${post['totalQuantity']} 수집',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(post['collectionRate'] as double).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
