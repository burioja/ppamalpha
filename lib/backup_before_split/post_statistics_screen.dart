import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_statistics_service.dart';

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
  Map<String, dynamic>? _storeDistribution;  // Phase 5: 스토어별 분포
  Map<String, dynamic>? _couponAnalytics;  // Phase 2-F: 쿠폰 통계
  Map<String, dynamic>? _imageViewAnalytics;  // Phase 2-G: 이미지 뷰 통계
  Map<String, dynamic>? _recallAnalytics;  // Phase 4: 회수 통계
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // 기본/수집자/시간/위치/성과/쿠폰/회수
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
      // 모든 통계를 병렬로 로드
      final results = await Future.wait([
        _statisticsService.getPostStatistics(widget.post.postId),
        _statisticsService.getCollectorDetails(widget.post.postId),
        _statisticsService.getTimeAnalytics(widget.post.postId),
        _statisticsService.getLocationAnalytics(widget.post.postId),
        _statisticsService.getPerformanceAnalytics(widget.post.postId),
        _statisticsService.getPredictiveAnalytics(widget.post.postId),
        _statisticsService.getStoreDistribution(widget.post.postId),  // Phase 5: 스토어별 분포
        _statisticsService.getCouponAnalytics(widget.post.postId),  // Phase 2-F: 쿠폰 통계
        _statisticsService.getImageViewAnalytics(widget.post.postId),  // Phase 2-G: 이미지 뷰 통계
        _statisticsService.getRecallAnalytics(widget.post.postId),  // Phase 4: 회수 통계
      ]);

      setState(() {
        _statistics = results[0];
        _collectorDetails = results[1];
        _timeAnalytics = results[2];
        _locationAnalytics = results[3];
        _performanceAnalytics = results[4];
        _predictiveAnalytics = results[5];
        _storeDistribution = results[6];  // Phase 5: 스토어별 분포
        _couponAnalytics = results[7];  // Phase 2-F: 쿠폰 통계
        _imageViewAnalytics = results[8];  // Phase 2-G: 이미지 뷰 통계
        _recallAnalytics = results[9];  // Phase 4: 회수 통계
        _isLoading = false;

        // 배포 정보 디버깅
        print('\n📊 [통계 로드 완료] 포스트 ID: ${widget.post.postId}');
        if (_statistics != null && _statistics!['deployments'] != null) {
          final deployments = _statistics!['deployments'] as List;
          print('✅ deployments 필드 존재: ${deployments.length}개');
          if (deployments.isNotEmpty) {
            print('📦 첫 번째 배포 데이터 샘플:');
            print('   ${deployments.first}');
          }
        } else {
          print('⚠️ deployments 필드가 없거나 null입니다');
          if (_statistics != null) {
            print('   _statistics 키 목록: ${_statistics!.keys.toList()}');
          }
        }
        print('');
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
        backgroundColor: Colors.blue[700],
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
        bottom: _isLoading || _error != null ? null : TabBar(
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
              : _statistics == null
                  ? const Center(child: Text('통계 데이터가 없습니다'))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBasicStatisticsTab(),
                        _buildCollectorAnalysisTab(),
                        _buildTimeAnalysisTab(),
                        _buildLocationAnalysisTab(),
                        _buildPerformanceAnalysisTab(),
                        _buildCouponAnalysisTab(),
                        _buildRecallAnalysisTab(),
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
  Widget _buildBasicStatisticsTab() {
    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스트 정보 헤더
            _buildPostHeader(),
            const SizedBox(height: 24),

            // 배포 위치 지도
            if (_statistics!['deployments'] != null && (_statistics!['deployments'] as List).isNotEmpty)
              ...[
                _buildDeploymentMap(),
                const SizedBox(height: 24),
              ],

            // 전체 통계 (개선된 KPI 포함)
            _buildEnhancedStatistics(),
            const SizedBox(height: 24),

            // Phase 5: 스토어별 분포 파이차트
            if (_storeDistribution != null && _storeDistribution!['distribution'] != null && (_storeDistribution!['distribution'] as Map).isNotEmpty)
              ...[
                _buildStoreDistributionChart(),
                const SizedBox(height: 24),
              ],

            // 예측 분석 (Phase 2-E)
            if (_predictiveAnalytics != null && _predictiveAnalytics!.isNotEmpty)
              ...[
                _buildPredictiveAnalysis(),
                const SizedBox(height: 24),
              ],

            // 시간대별 수집 패턴
            _buildHourlyChart(),
            const SizedBox(height: 24),

            // 요일별 수집 패턴
            _buildDailyChart(),
            const SizedBox(height: 24),

            // 마커별 성과 비교 (막대 그래프)
            if (_statistics!['deployments'] != null && (_statistics!['deployments'] as List).length > 1)
              ...[
                _buildMarkerPerformanceChart(),
                const SizedBox(height: 24),
              ],

            // 비효율 마커 알림 (Phase 2-E)
            if (_statistics!['deployments'] != null)
              ...[
                _buildInefficientMarkersAlert(),
                const SizedBox(height: 24),
              ],

            // 마커별 상세 정보
            _buildMarkersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final template = _statistics!['template'] as Map<String, dynamic>;
    final isDeleted = template['isDeleted'] ?? false;  // Phase 5: 삭제 상태 확인

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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template['title'] ?? '(제목 없음)',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isDeleted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '삭제됨',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildDeploymentMap() {
    final deployments = _statistics!['deployments'] as List;
    final markers = <Marker>[];

    print('\n🗺️ [배포 위치 지도] 시작');
    print('📊 총 배포 데이터 수: ${deployments.length}');

    // 위도/경도 범위 계산 (자동 줌)
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;

    for (int i = 0; i < deployments.length; i++) {
      final deployment = deployments[i] as Map<String, dynamic>;
      // Firestore에는 'location' 필드로 저장됨 (GeoPoint)
      final location = deployment['location'];

      if (location == null) {
        print('⚠️ 배포 #$i: location이 null');
        print('   deployment 키 목록: ${deployment.keys.toList()}');
        continue;
      }

      // GeoPoint 타입인 경우와 Map 타입인 경우 모두 처리
      double? lat;
      double? lng;

      if (location is GeoPoint) {
        lat = location.latitude;
        lng = location.longitude;
      } else if (location is Map) {
        lat = (location['latitude'] ?? location['_latitude']) as double?;
        lng = (location['longitude'] ?? location['_longitude']) as double?;
      }

      if (lat == null || lng == null) {
        print('⚠️ 배포 #$i: 좌표 데이터 없음 (lat: $lat, lng: $lng)');
        continue;
      }

      print('✅ 배포 #$i: 위치 (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})');

      // 범위 업데이트
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;

      // 수집률 계산
      final totalQuantity = deployment['totalQuantity'] ?? deployment['quantity'] ?? 0;
      final remainingQuantity = deployment['remainingQuantity'] ?? totalQuantity;
      final collected = totalQuantity - remainingQuantity;
      final collectionRate = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      // 색상 결정
      Color markerColor;
      if (collectionRate >= 80) {
        markerColor = Colors.green;
      } else if (collectionRate >= 50) {
        markerColor = Colors.orange;
      } else {
        markerColor = Colors.red;
      }

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('마커 #${i + 1}'),
                  content: Text(
                    '수집률: ${collectionRate.toStringAsFixed(1)}%\n'
                    '수집: $collected / $totalQuantity',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                  ],
                ),
              );
            },
            child: Icon(
              Icons.location_on,
              size: 40,
              color: markerColor,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 마커가 없는 경우 안내 메시지 표시
    if (markers.isEmpty) {
      print('⚠️ 마커가 없어서 지도를 표시하지 않습니다');
      print('🗺️ [배포 위치 지도] 완료\n');

      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '배포 위치 지도',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        '배포 위치 정보가 없습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
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

    // 중심점 계산 (마커가 있는 경우에만)
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // 유효성 검증
    if (!centerLat.isFinite || !centerLng.isFinite ||
        centerLat < -90 || centerLat > 90 ||
        centerLng < -180 || centerLng > 180) {
      print('❌ 잘못된 중심점 좌표: ($centerLat, $centerLng)');
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '배포 위치 지도',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        '지도 좌표 오류',
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '좌표: ($centerLat, $centerLng)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

    print('📍 지도 중심점: (${centerLat.toStringAsFixed(4)}, ${centerLng.toStringAsFixed(4)})');
    print('📌 마커 개수: ${markers.length}');
    print('🗺️ [배포 위치 지도] 완료\n');

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '배포 위치 지도',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMapLegend(Colors.green, '80%+'),
                const SizedBox(width: 12),
                _buildMapLegend(Colors.orange, '50-79%'),
                const SizedBox(width: 12),
                _buildMapLegend(Colors.red, '50% 미만'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLng),
                  initialZoom: 16.0, // 배포 위치를 더 자세히 볼 수 있도록 줌 레벨 증가
                  minZoom: 5.0,
                  maxZoom: 18.0,
                ),
                children: [
                  // OSM 기반 CartoDB Voyager 타일 (라벨 없음)
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.ppamalpha.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildEnhancedStatistics() {
    final totalDeployments = _statistics!['totalDeployments'] as int;
    final totalQuantity = _statistics!['totalQuantityDeployed'] as int;
    final totalCollected = _statistics!['totalCollected'] as int;
    final collectionRate = (_statistics!['collectionRate'] as double) * 100;
    final usageRate = (_statistics!['usageRate'] as double) * 100;

    // 추가 KPI 계산
    final collectors = _statistics!['collectors'] as Map<String, dynamic>;
    final uniqueCollectors = collectors['uniqueCount'] as int;
    final avgPerUser = collectors['averagePerUser'] as double;
    final repeatRate = uniqueCollectors > 0 ? ((totalCollected - uniqueCollectors) / totalCollected * 100) : 0.0;
    final rewardPerCollector = uniqueCollectors > 0
        ? (_statistics!['template']['reward'] as int) / uniqueCollectors
        : 0.0;

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
                value: '${NumberFormat('#,###').format(totalDeployments)}회',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.inventory_2,
                label: '배포 수량',
                value: '${NumberFormat('#,###').format(totalQuantity)}개',
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
                value: '${NumberFormat('#,###').format(totalCollected)}건',
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
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                label: '수집 인원',
                value: '${NumberFormat('#,###').format(uniqueCollectors)}명',
                color: Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.repeat,
                label: '반복률',
                value: '${repeatRate.toStringAsFixed(1)}%',
                color: Colors.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.person,
                label: '1인당 수집',
                value: '${avgPerUser.toStringAsFixed(1)}개',
                color: Colors.pink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                label: '1인당 비용',
                value: '${NumberFormat('#,###').format(rewardPerCollector.toInt())}원',
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMarkerPerformanceChart() {
    final deployments = _statistics!['deployments'] as List;
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < deployments.length; i++) {
      final deployment = deployments[i] as Map<String, dynamic>;
      final totalQuantity = deployment['totalQuantity'] ?? deployment['quantity'] ?? 0;
      final remainingQuantity = deployment['remainingQuantity'] ?? totalQuantity;
      final collected = totalQuantity - remainingQuantity;
      final collectionRate = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: collectionRate,
              color: collectionRate >= 80
                  ? Colors.green
                  : collectionRate >= 50
                      ? Colors.orange
                      : Colors.red,
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
              '마커별 수집률 비교',
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
                            '${value.toInt()}%',
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
                  maxY: 100,
                ),
              ),
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
    final hourlyData = timePattern['hourly'];

    if (hourlyData == null || (hourlyData is Map && hourlyData.isEmpty)) {
      return _buildEmptyChart('시간대별 수집 패턴', '아직 수집 데이터가 없습니다');
    }

    // Convert to Map<String, int> if needed
    Map<String, int> hourlyMap = {};
    if (hourlyData is Map) {
      hourlyData.forEach((key, value) {
        hourlyMap[key.toString()] = (value as num).toInt();
      });
    }

    // 0-23시 데이터 생성
    final List<BarChartGroupData> barGroups = [];
    for (int hour = 0; hour < 24; hour++) {
      final count = hourlyMap[hour.toString()] ?? 0;
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
    final dailyData = timePattern['daily'];

    if (dailyData == null || (dailyData is Map && dailyData.isEmpty)) {
      return _buildEmptyChart('요일별 수집 패턴', '아직 수집 데이터가 없습니다');
    }

    // Convert to Map<String, int> if needed
    Map<String, int> dailyMap = {};
    if (dailyData is Map) {
      dailyData.forEach((key, value) {
        dailyMap[key.toString()] = (value as num).toInt();
      });
    }

    final days = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    final List<FlSpot> spots = [];

    for (int i = 0; i < days.length; i++) {
      final count = dailyMap[days[i]] ?? 0;
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

  // ===== 새로운 탭 메서드들 =====

  // Tab 2: 수집자 분석
  Widget _buildCollectorAnalysisTab() {
    if (_collectorDetails == null || _collectorDetails!.isEmpty) {
      return const Center(child: Text('수집자 데이터가 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 수집자 Top 10
            _buildTopCollectorsChart(),
            const SizedBox(height: 24),

            // 2. 신규 vs 재방문
            _buildNewVsReturningChart(),
            const SizedBox(height: 24),

            // 3. 수집자 분포
            _buildCollectorDistributionChart(),
            const SizedBox(height: 24),

            // 4. 수집자 리스트 테이블
            _buildCollectorListTable(),
          ],
        ),
      ),
    );
  }

  // Tab 3: 시간 분석
  Widget _buildTimeAnalysisTab() {
    if (_timeAnalytics == null || _timeAnalytics!.isEmpty) {
      return const Center(child: Text('시간 분석 데이터가 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 6. 월별 수집 추이
            _buildMonthlyTrendChart(),
            const SizedBox(height: 24),

            // 7. 주말 vs 평일
            _buildWeekdayVsWeekendChart(),
            const SizedBox(height: 24),

            // 9. 시간대별 효율성
            _buildHourlyEfficiencyChart(),
          ],
        ),
      ),
    );
  }

  // Tab 4: 위치 분석
  Widget _buildLocationAnalysisTab() {
    if (_locationAnalytics == null || _locationAnalytics!.isEmpty) {
      return const Center(child: Text('위치 분석 데이터가 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 10. 마커 간 거리 정보
            _buildMarkerDistanceInfo(),
            const SizedBox(height: 24),

            // 배포 위치 지도 (재사용)
            if (_statistics!['deployments'] != null && (_statistics!['deployments'] as List).isNotEmpty)
              _buildDeploymentMap(),
          ],
        ),
      ),
    );
  }

  // Tab 5: 성과 분석
  Widget _buildPerformanceAnalysisTab() {
    if (_performanceAnalytics == null || _performanceAnalytics!.isEmpty) {
      return const Center(child: Text('성과 분석 데이터가 없습니다'));
    }

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 13. ROI 분석
            _buildROIAnalysis(),
            const SizedBox(height: 24),

            // 14. 시간대별 ROI
            _buildHourlyROIChart(),
            const SizedBox(height: 24),

            // 16. 마커 효율성 스코어보드
            _buildMarkerEfficiencyScoreboard(),
          ],
        ),
      ),
    );
  }

  // ===== Phase 2-A: 수집자 분석 위젯들 =====

  Widget _buildTopCollectorsChart() {
    final topCollectors = (_collectorDetails!['topCollectors'] as List?) ?? [];
    if (topCollectors.isEmpty) {
      return _buildEmptyChart('수집자 Top 10', '수집자 데이터가 없습니다');
    }

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < topCollectors.length && i < 10; i++) {
      final collector = topCollectors[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (collector['count'] as int).toDouble(),
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
              '수집자 Top 10',
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

  Widget _buildNewVsReturningChart() {
    final newVsReturning = _collectorDetails!['newVsReturning'] as Map<String, dynamic>?;
    if (newVsReturning == null) {
      return _buildEmptyChart('신규 vs 재방문 수집자', '데이터가 없습니다');
    }

    final newCollectors = newVsReturning['1회'] as int? ?? 0;
    final returning = newVsReturning['재방문'] as int? ?? 0;
    final total = newCollectors + returning;

    if (total == 0) {
      return _buildEmptyChart('신규 vs 재방문 수집자', '데이터가 없습니다');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '신규 vs 재방문 수집자',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: newCollectors.toDouble(),
                      title: '${(newCollectors / total * 100).toStringAsFixed(0)}%\n신규',
                      color: Colors.blue,
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: returning.toDouble(),
                      title: '${(returning / total * 100).toStringAsFixed(0)}%\n재방문',
                      color: Colors.green,
                      radius: 100,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.blue, '신규'),
                const SizedBox(width: 16),
                _buildLegend(Colors.green, '재방문'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorDistributionChart() {
    final distribution = _collectorDetails!['distribution'] as Map<String, dynamic>?;
    if (distribution == null) {
      return _buildEmptyChart('수집자 분포', '데이터가 없습니다');
    }

    final labels = ['1회', '2-5회', '6-10회', '10회+'];
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < labels.length; i++) {
      final count = distribution[labels[i]] as int? ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.orange,
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
              '수집 횟수별 분포',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
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
                          if (index >= 0 && index < labels.length) {
                            return Text(
                              labels[index],
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

  Widget _buildCollectorListTable() {
    final topCollectors = (_collectorDetails!['topCollectors'] as List?) ?? [];
    if (topCollectors.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '수집자 리스트',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                '수집자 데이터가 없습니다',
                style: TextStyle(color: Colors.grey[500]),
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
              '수집자 리스트 Top 10',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topCollectors.length > 10 ? 10 : topCollectors.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final collector = topCollectors[index];
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  title: Text('수집자 ${collector['userId']}'),
                  subtitle: Text(
                    '첫 수집: ${DateFormat('yyyy-MM-dd').format(collector['firstCollected'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${collector['count']}회',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== Phase 2-B: 시간 분석 위젯들 =====

  Widget _buildMonthlyTrendChart() {
    final monthlyTrend = _timeAnalytics!['monthlyTrend'] as Map<String, dynamic>?;
    if (monthlyTrend == null || monthlyTrend.isEmpty) {
      return _buildEmptyChart('월별 수집 추이', '데이터가 없습니다');
    }

    final sortedMonths = monthlyTrend.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedMonths.length; i++) {
      final count = monthlyTrend[sortedMonths[i]] as int;
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
              '월별 수집 추이',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
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
                            return Text(
                              sortedMonths[index].substring(5),
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

  Widget _buildWeekdayVsWeekendChart() {
    final weekdayVsWeekend = _timeAnalytics!['weekdayVsWeekend'] as Map<String, dynamic>?;
    if (weekdayVsWeekend == null) {
      return _buildEmptyChart('주말 vs 평일 비교', '데이터가 없습니다');
    }

    final weekday = weekdayVsWeekend['weekday'] as int? ?? 0;
    final weekend = weekdayVsWeekend['weekend'] as int? ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주말 vs 평일 수집 비교',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: weekday.toDouble(),
                          color: Colors.blue,
                          width: 60,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: weekend.toDouble(),
                          color: Colors.orange,
                          width: 60,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
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
                          if (value.toInt() == 0) {
                            return const Text('평일', style: TextStyle(fontSize: 12));
                          } else if (value.toInt() == 1) {
                            return const Text('주말', style: TextStyle(fontSize: 12));
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

  Widget _buildHourlyEfficiencyChart() {
    final hourlyRate = _timeAnalytics!['hourlyRate'] as Map<String, dynamic>?;
    if (hourlyRate == null || hourlyRate.isEmpty) {
      return _buildEmptyChart('시간대별 효율성', '데이터가 없습니다');
    }

    final barGroups = <BarChartGroupData>[];
    for (int hour = 0; hour < 24; hour++) {
      final count = hourlyRate[hour.toString()] as int? ?? hourlyRate[hour] as int? ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.green,
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
              '시간대별 수집 효율성',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
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

  // ===== Phase 2-C: 위치 분석 위젯들 =====

  Widget _buildMarkerDistanceInfo() {
    final totalMarkers = _locationAnalytics!['totalMarkers'] as int? ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '배포 위치 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              icon: Icons.location_on,
              label: '총 마커 수',
              value: '$totalMarkers개',
              color: Colors.purple,
            ),
            const SizedBox(height: 12),
            Text(
              '아래 지도에서 각 마커의 위치와 성과를 확인할 수 있습니다.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Phase 2-D: 성과 분석 위젯들 =====

  Widget _buildROIAnalysis() {
    final roi = _performanceAnalytics!['roi'] as double? ?? 0.0;
    final totalRewardPaid = _performanceAnalytics!['totalRewardPaid'] as int? ?? 0;
    final collectionRate = _performanceAnalytics!['collectionRate'] as double? ?? 0.0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ROI 분석',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    label: 'ROI',
                    value: '${roi.toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: '지급된 리워드',
                    value: '${NumberFormat('#,###').format(totalRewardPaid)}원',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.percent,
              label: '수집률',
              value: '${collectionRate.toStringAsFixed(1)}%',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyROIChart() {
    final hourlyROI = _performanceAnalytics!['hourlyROI'] as Map<String, dynamic>?;
    if (hourlyROI == null || hourlyROI.isEmpty) {
      return _buildEmptyChart('시간대별 ROI', '데이터가 없습니다');
    }

    final barGroups = <BarChartGroupData>[];
    for (int hour = 0; hour < 24; hour++) {
      final count = hourlyROI[hour.toString()] as int? ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.amber,
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
              '시간대별 수집 성과',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
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

  Widget _buildMarkerEfficiencyScoreboard() {
    final deployments = _statistics!['deployments'] as List<dynamic>?;
    if (deployments == null || deployments.isEmpty) {
      return _buildEmptyChart('마커 효율성 스코어보드', '데이터가 없습니다');
    }

    final markerScores = <Map<String, dynamic>>[];

    for (int i = 0; i < deployments.length; i++) {
      final deployment = deployments[i] as Map<String, dynamic>;
      final totalQuantity = deployment['totalQuantity'] ?? deployment['quantity'] ?? 0;
      final remainingQuantity = deployment['remainingQuantity'] ?? totalQuantity;
      final collected = totalQuantity - remainingQuantity;
      final collectionRate = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      markerScores.add({
        'index': i + 1,
        'collectionRate': collectionRate,
        'collected': collected,
        'totalQuantity': totalQuantity,
      });
    }

    // 수집률 순으로 정렬
    markerScores.sort((a, b) => (b['collectionRate'] as double).compareTo(a['collectionRate']));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '마커 효율성 스코어보드',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...markerScores.take(10).map((score) {
              final rate = score['collectionRate'] as double;
              final color = rate >= 80 ? Colors.green : rate >= 50 ? Colors.orange : Colors.red;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#${score['index']}',
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
                            '마커 #${score['index']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${score['collected']}/${score['totalQuantity']} 수집',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===== Phase 2-E: 예측 & 인사이트 위젯들 =====

  Widget _buildPredictiveAnalysis() {
    final estimatedCompletion = _predictiveAnalytics!['estimatedCompletion'] as String?;
    final dailyRate = _predictiveAnalytics!['dailyRate'] as double? ?? 0.0;
    final daysToComplete = _predictiveAnalytics!['daysToComplete'] as int?;
    final remaining = _predictiveAnalytics!['remaining'] as int? ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '수집 완료 예측',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (estimatedCompletion != null) ...[
              _buildPredictionItem(
                Icons.calendar_today,
                '예상 완료일',
                DateFormat('yyyy-MM-dd').format(DateTime.parse(estimatedCompletion)),
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildPredictionItem(
                Icons.hourglass_empty,
                '남은 기간',
                daysToComplete != null ? '$daysToComplete일' : '계산 중',
                Colors.orange,
              ),
            ] else ...[
              Text(
                '수집 데이터가 부족하여 예측할 수 없습니다',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 12),
            _buildPredictionItem(
              Icons.speed,
              '일일 수집률',
              '${dailyRate.toStringAsFixed(1)}개/일',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildPredictionItem(
              Icons.pending_actions,
              '남은 수량',
              '$remaining개',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionItem(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInefficientMarkersAlert() {
    final deployments = _statistics!['deployments'] as List<dynamic>?;
    if (deployments == null || deployments.isEmpty) {
      return const SizedBox.shrink();
    }

    final inefficientMarkers = <Map<String, dynamic>>[];

    for (int i = 0; i < deployments.length; i++) {
      final deployment = deployments[i] as Map<String, dynamic>;
      final totalQuantity = deployment['totalQuantity'] ?? deployment['quantity'] ?? 0;
      final remainingQuantity = deployment['remainingQuantity'] ?? totalQuantity;
      final collected = totalQuantity - remainingQuantity;
      final collectionRate = totalQuantity > 0 ? (collected / totalQuantity) * 100 : 0.0;

      if (collectionRate < 20) {
        inefficientMarkers.add({
          'index': i + 1,
          'collectionRate': collectionRate,
          'collected': collected,
          'totalQuantity': totalQuantity,
        });
      }
    }

    if (inefficientMarkers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                const Text(
                  '비효율 마커 알림',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '수집률이 20% 미만인 마커가 ${inefficientMarkers.length}개 있습니다.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...inefficientMarkers.map((marker) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '마커 #${marker['index']} - ${marker['collected']}/${marker['totalQuantity']} 수집',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${(marker['collectionRate'] as double).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
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

  Widget _buildStoreDistributionChart() {
    if (_storeDistribution == null || _storeDistribution!['distribution'] == null) {
      return const SizedBox.shrink();
    }

    final distribution = _storeDistribution!['distribution'] as Map<String, dynamic>;
    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];

    final total = distribution.values.fold(0, (sum, count) => sum + (count as int));
    final sections = <PieChartSectionData>[];
    int colorIndex = 0;

    distribution.forEach((storeName, count) {
      final percentage = (count as int) / total * 100;
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          color: colors[colorIndex % colors.length],
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '스토어별 분포',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 범례
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: distribution.entries.map((entry) {
                final color = colors[distribution.keys.toList().indexOf(entry.key) % colors.length];
                final percentage = (entry.value as int) / total * 100;
                return _buildLegend(
                  color,
                  '${entry.key}: ${entry.value}건 (${percentage.toStringAsFixed(1)}%)',
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 6: 쿠폰 분석
  Widget _buildCouponAnalysisTab() {
    if (_couponAnalytics == null || _couponAnalytics!.isEmpty) {
      return const Center(child: Text('쿠폰 통계를 불러오는 중...'));
    }

    // 쿠폰이 아닌 포스트인 경우
    if (_couponAnalytics!['isCoupon'] == false) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '이 포스트는 쿠폰이 아닙니다',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final totalCollections = _couponAnalytics!['totalCollections'] ?? 0;
    final totalCouponUsed = _couponAnalytics!['totalCouponUsed'] ?? 0;
    final usageRate = _couponAnalytics!['usageRate'] ?? 0.0;
    final uniqueCollectors = _couponAnalytics!['uniqueCollectors'] ?? 0;
    final repeatedCollectors = _couponAnalytics!['repeatedCollectors'] ?? 0;
    final hourlyUsage = _couponAnalytics!['hourlyUsage'] as Map<String, dynamic>? ?? {};
    final dailyUsage = _couponAnalytics!['dailyUsage'] as Map<String, dynamic>? ?? {};
    final avgUsagePerCollector = _couponAnalytics!['averageUsagePerCollector'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 쿠폰 사용률 KPI 카드
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.card_giftcard,
                    label: '총 수집',
                    value: '$totalCollections건',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    label: '쿠폰 사용',
                    value: '$totalCouponUsed건',
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
                    icon: Icons.trending_up,
                    label: '사용률',
                    value: '${usageRate.toStringAsFixed(1)}%',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.person,
                    label: '한번 주운 포스트',
                    value: '$uniqueCollectors명',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 수집자 분석
            const Text(
              '수집자 분석',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('한번 주운 포스트 (Unique)', style: TextStyle(fontSize: 14)),
                        Text('$uniqueCollectors명', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('재수집 사용자 (2번 이상)', style: TextStyle(fontSize: 14)),
                        Text('$repeatedCollectors명', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('평균 사용 횟수 (사용자당)', style: TextStyle(fontSize: 14)),
                        Text('${avgUsagePerCollector.toStringAsFixed(1)}회', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 이미지 확대 조회율
            if (_imageViewAnalytics != null && _imageViewAnalytics!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '사진 확대 조회',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.image_search,
                              label: '확대 조회',
                              value: '${_imageViewAnalytics!['imageViewedCount'] ?? 0}건',
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.trending_up,
                              label: '확대 조회율',
                              value: '${(_imageViewAnalytics!['imageViewRate'] ?? 0.0).toStringAsFixed(1)}%',
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '포스트를 수집한 사용자 중 이미지를 확대하여 본 비율입니다.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tab 7: 회수 분석
  Widget _buildRecallAnalysisTab() {
    if (_recallAnalytics == null || _recallAnalytics!.isEmpty) {
      return const Center(child: Text('회수 통계를 불러오는 중...'));
    }

    final isRecalled = _recallAnalytics!['isRecalled'] ?? false;
    final recallRate = _recallAnalytics!['recallRate'] ?? 0.0;
    final totalMarkers = _recallAnalytics!['totalMarkers'] ?? 0;
    final recalledMarkers = _recallAnalytics!['recalledMarkers'] ?? 0;
    final recallReasons = _recallAnalytics!['recallReasons'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 회수 상태 배너
            if (isRecalled) ...[
              Card(
                elevation: 2,
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이 포스트는 회수되었습니다',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                            if (_recallAnalytics!['postRecallReason'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '사유: ${_recallAnalytics!['postRecallReason']}',
                                style: TextStyle(fontSize: 14, color: Colors.orange[800]),
                              ),
                            ],
                            if (_recallAnalytics!['postRecallDays'] != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '생성 후 ${_recallAnalytics!['postRecallDays']}일 경과 시점에 회수됨',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
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
                          '이 포스트는 정상 운영 중입니다',
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
              const SizedBox(height: 24),
            ],

            // 회수율 KPI
            const Text(
              '회수 통계',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.location_on,
                    label: '총 마커',
                    value: '$totalMarkers개',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.restore,
                    label: '회수된 마커',
                    value: '$recalledMarkers개',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatCard(
              icon: Icons.percent,
              label: '회수율',
              value: '${recallRate.toStringAsFixed(1)}%',
              color: recallRate > 50 ? Colors.red : recallRate > 20 ? Colors.orange : Colors.green,
            ),
            const SizedBox(height: 24),

            // 회수 사유별 분석
            if (recallReasons.isNotEmpty) ...[
              const Text(
                '회수 사유 분석',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildRecallReasonsPieChart(recallReasons),
              const SizedBox(height: 24),
            ],

            // 회수 시점 분포
            if (_recallAnalytics!['recallTimings'] != null) ...[
              const Text(
                '회수 시점 분포',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildRecallTimingsChart(_recallAnalytics!['recallTimings'] as Map<dynamic, dynamic>),
              const SizedBox(height: 24),
            ],

            // 평균 회수 기간
            if (_recallAnalytics!['averageRecallDays'] != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.indigo, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '평균 회수 기간',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_recallAnalytics!['averageRecallDays'] as double).toStringAsFixed(1)}일',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecallReasonsPieChart(Map<String, dynamic> reasons) {
    final colors = [Colors.red, Colors.orange, Colors.amber, Colors.blue, Colors.purple];
    final sections = <PieChartSectionData>[];
    final total = reasons.values.fold<int>(0, (sum, count) => sum + (count as int));

    int colorIndex = 0;
    reasons.forEach((reason, count) {
      final percentage = (count as int) / total * 100;
      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: '${percentage.toStringAsFixed(0)}%',
          color: colors[colorIndex % colors.length],
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      colorIndex++;
    });

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: reasons.entries.map((entry) {
                final color = colors[reasons.keys.toList().indexOf(entry.key) % colors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ${entry.value}건', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecallTimingsChart(Map<dynamic, dynamic> timings) {
    final barGroups = <BarChartGroupData>[];
    final sortedKeys = timings.keys.toList()..sort();

    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final count = timings[key] as int;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.deepOrange,
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
              '생성 후 경과 기간별 회수 건수',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                          if (index >= 0 && index < sortedKeys.length) {
                            final weekNum = sortedKeys[index] as int;
                            return Text(
                              '${weekNum}주',
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