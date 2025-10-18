import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_statistics_service.dart';
import '../widgets/post_statistics_charts.dart';
import '../widgets/post_statistics_tabs.dart';
import '../widgets/post_statistics_helpers.dart';

class PostStatisticsScreen extends StatefulWidget {
  final PostModel post;

  const PostStatisticsScreen({super.key, required this.post});

  @override
  State<PostStatisticsScreen> createState() => _PostStatisticsScreenState();
}

class _PostStatisticsScreenState extends State<PostStatisticsScreen> with SingleTickerProviderStateMixin {
  final PostStatisticsService _statisticsService = PostStatisticsService();
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _collectorDetails;
  Map<String, dynamic>? _timeAnalytics;
  Map<String, dynamic>? _locationAnalytics;
  Map<String, dynamic>? _performanceAnalytics;
  Map<String, dynamic>? _predictiveAnalytics;
  Map<String, dynamic>? _storeDistribution;
  Map<String, dynamic>? _couponAnalytics;
  Map<String, dynamic>? _imageViewAnalytics;
  Map<String, dynamic>? _recallAnalytics;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // TODO: PostStatisticsService 메소드들 구현 필요
      // final results = await Future.wait([
      //   _statisticsService.getOverallStatistics(widget.post.postId),
      //   _statisticsService.getCollectorDetails(widget.post.postId),
      //   _statisticsService.getTimeAnalytics(widget.post.postId),
      //   _statisticsService.getLocationAnalytics(widget.post.postId),
      //   _statisticsService.getPerformanceAnalytics(widget.post.postId),
      //   _statisticsService.getPredictiveAnalytics(widget.post.postId),
      //   _statisticsService.getStoreDistribution(widget.post.postId),
      //   _statisticsService.getCouponAnalytics(widget.post.postId),
      //   _statisticsService.getImageViewAnalytics(widget.post.postId),
      //   _statisticsService.getRecallAnalytics(widget.post.postId),
      // ]);
      
      final results = List.filled(10, <String, dynamic>{});

      setState(() {
        _statistics = results[0] as Map<String, dynamic>?;
        _collectorDetails = results[1] as Map<String, dynamic>?;
        _timeAnalytics = results[2] as Map<String, dynamic>?;
        _locationAnalytics = results[3] as Map<String, dynamic>?;
        _performanceAnalytics = results[4] as Map<String, dynamic>?;
        _predictiveAnalytics = results[5] as Map<String, dynamic>?;
        _storeDistribution = results[6] as Map<String, dynamic>?;
        _couponAnalytics = results[7] as Map<String, dynamic>?;
        _imageViewAnalytics = results[8] as Map<String, dynamic>?;
        _recallAnalytics = results[9] as Map<String, dynamic>?;
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.purple[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.post.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadStatistics,
              tooltip: '새로고침',
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              labelColor: Colors.blue[600],
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: '기본'),
                Tab(text: '수집자'),
                Tab(text: '시간'),
                Tab(text: '위치'),
                Tab(text: '성과'),
                Tab(text: '쿠폰'),
                Tab(text: '회수'),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return PostStatisticsHelpers.buildLoadingWidget();
    }

    if (_error != null) {
      return PostStatisticsHelpers.buildErrorWidget(
        PostStatisticsHelpers.getErrorMessage(_error!),
        _loadStatistics,
      );
    }

    return TabBarView(
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
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약 카드들
          _buildSummaryCards(),
          const SizedBox(height: 24),
          
          // 마커 성과 차트
          PostStatisticsCharts.buildMarkerPerformanceChart(_statistics?['performance']),
          const SizedBox(height: 24),
          
          // 시간별 차트
          PostStatisticsCharts.buildHourlyChart(_timeAnalytics),
          const SizedBox(height: 24),
          
          // 일별 차트
          PostStatisticsCharts.buildDailyChart(_timeAnalytics),
          const SizedBox(height: 24),
          
          // 월별 트렌드 차트
          PostStatisticsCharts.buildMonthlyTrendChart(_timeAnalytics),
        ],
      ),
    );
  }

  Widget _buildCollectorTab() {
    return PostStatisticsTabs.buildCollectorAnalysisTab(_collectorDetails);
  }

  Widget _buildTimeTab() {
    return PostStatisticsTabs.buildTimeAnalysisTab(_timeAnalytics);
  }

  Widget _buildLocationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '위치 분석',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_locationAnalytics != null) ...[
            _buildLocationSummary(),
            const SizedBox(height: 24),
            _buildLocationMap(),
          ] else
            PostStatisticsCharts.buildEmptyChart('위치 분석', '위치 데이터가 없습니다'),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return PostStatisticsTabs.buildPerformanceAnalysisTab(_performanceAnalytics);
  }

  Widget _buildCouponTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '쿠폰 분석',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_couponAnalytics != null) ...[
            _buildCouponSummary(),
            const SizedBox(height: 24),
            _buildCouponUsageChart(),
          ] else
            PostStatisticsCharts.buildEmptyChart('쿠폰 분석', '쿠폰 데이터가 없습니다'),
        ],
      ),
    );
  }

  Widget _buildRecallTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '회수 분석',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_recallAnalytics != null) ...[
            _buildRecallSummary(),
            const SizedBox(height: 24),
            _buildRecallChart(),
          ] else
            PostStatisticsCharts.buildEmptyChart('회수 분석', '회수 데이터가 없습니다'),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    if (_statistics == null) return const SizedBox.shrink();

    final totalCollections = (_statistics!['totalCollections'] as num?)?.toInt() ?? 0;
    final totalMarkers = (_statistics!['totalMarkers'] as num?)?.toInt() ?? 0;
    final avgCollectionsPerMarker = totalMarkers > 0 ? (totalCollections / totalMarkers).toStringAsFixed(1) : '0.0';
    final uniqueCollectors = (_statistics!['uniqueCollectors'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            '총 수집',
            totalCollections.toString(),
            Icons.collections,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            '총 마커',
            totalMarkers.toString(),
            Icons.location_on,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            '평균 수집/마커',
            avgCollectionsPerMarker,
            Icons.trending_up,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            '수집자 수',
            uniqueCollectors.toString(),
            Icons.people,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
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

  Widget _buildLocationSummary() {
    // 위치 분석 요약 구현
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
      child: const Text('위치 분석 요약'),
    );
  }

  Widget _buildLocationMap() {
    // 위치 맵 구현
    return Container(
      height: 300,
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
      child: const Center(
        child: Text('위치 맵'),
      ),
    );
  }

  Widget _buildCouponSummary() {
    // 쿠폰 분석 요약 구현
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
      child: const Text('쿠폰 분석 요약'),
    );
  }

  Widget _buildCouponUsageChart() {
    // 쿠폰 사용 차트 구현
    return Container(
      height: 300,
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
      child: const Center(
        child: Text('쿠폰 사용 차트'),
      ),
    );
  }

  Widget _buildRecallSummary() {
    // 회수 분석 요약 구현
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
      child: const Text('회수 분석 요약'),
    );
  }

  Widget _buildRecallChart() {
    // 회수 차트 구현
    return Container(
      height: 300,
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
      child: const Center(
        child: Text('회수 차트'),
      ),
    );
  }
}