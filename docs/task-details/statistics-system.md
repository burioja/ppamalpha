# 포스트 관련 통계 시스템

## 📋 과제 개요
**과제 ID**: TASK-008
**제목**: 포스트 관련 통계 시스템
**우선순위**: ⭐ 낮음
**담당자**: TBD
**상태**: 🔄 계획 중

## 🎯 요구사항 분석

### 사용자 요구사항
1. **내 포스트 통계**: 포스트가 마커를 통해 뿌려지면 내 포스트에서 통계 확인
2. **개별 포스트별 통계**: 각 포스트별 상세한 통계 정보 제공
3. **실시간 데이터**: 최신 수집/사용 현황을 실시간으로 확인
4. **시각적 표현**: 차트와 그래프를 통한 직관적인 데이터 표시

### 비즈니스 요구사항
- 포스트 성과 분석을 통한 컨텐츠 최적화
- 사용자 행동 패턴 분석으로 타겟팅 개선
- 마케팅 효과 측정 및 ROI 계산

## 🔍 현재 상태 분석

### 기존 구현사항
```dart
// lib/core/services/data/post_statistics_service.dart 분석 결과

✅ 구현 완료:
- PostStatisticsService: 포스트 통계 서비스
- getPostStatistics(): 포스트별 전체 통계
- getMarkerStatistics(): 마커별 상세 통계
- getCollectorAnalytics(): 수집자 분석
- getPostStatisticsStream(): 실시간 통계 스트림
- 시간대별/요일별 패턴 분석
- 수집률/사용률 계산

🔄 UI 연동 필요:
- 내 포스트 목록에서 통계 접근
- 통계 화면 UI 구현
- 차트 및 시각화 컴포넌트
- 통계 데이터 내보내기 기능
```

### 현재 통계 데이터 구조
```dart
// 포스트 통계 데이터 예시
{
  'template': { postId, title, reward, creatorId, creatorName },
  'deployments': [...], // 배포된 마커들
  'collections': [...], // 수집 기록들
  'totalDeployments': int,
  'totalQuantityDeployed': int,
  'totalCollected': int,
  'totalUsed': int,
  'collectionRate': double,
  'usageRate': double,
  'collectors': {
    'uniqueCount': int,
    'totalCollections': int,
    'averagePerUser': double,
    'topCollectors': [...]
  },
  'timePattern': {
    'hourly': {...}, // 시간대별 수집 패턴
    'daily': {...}   // 요일별 수집 패턴
  }
}
```

## ✅ 구현 계획

### Phase 1: 내 포스트 통계 접근점 추가
- [ ] 내 포스트 목록에 통계 버튼 추가
- [ ] 포스트 카드에 간단한 통계 요약 표시
- [ ] 통계 화면으로의 네비게이션 구현

### Phase 2: 포스트 통계 화면 구현
- [ ] 포스트별 상세 통계 화면
- [ ] 차트 및 그래프 컴포넌트
- [ ] 실시간 데이터 업데이트
- [ ] 반응형 디자인

### Phase 3: 고급 분석 기능
- [ ] 기간별 비교 분석
- [ ] 통계 데이터 내보내기
- [ ] 통계 알림 설정
- [ ] 성과 개선 제안

## 🛠 구현 상세

### 1. 내 포스트 목록 통계 연동

```dart
// 내 포스트 카드에 통계 요약 추가
class MyPostCard extends StatefulWidget {
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // 기존 포스트 정보
          _buildPostInfo(),

          // 통계 요약 섹션 추가
          _buildStatisticsSummary(),

          // 액션 버튼들
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatisticsSummary() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: PostStatisticsService().getPostStatisticsStream(widget.post.postId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              _buildStatItem(
                icon: Icons.launch,
                label: '배포',
                value: '${stats['totalDeployments'] ?? 0}',
                color: Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                icon: Icons.download,
                label: '수집',
                value: '${stats['totalCollections'] ?? 0}',
                color: Colors.green,
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                icon: Icons.shopping_cart,
                label: '사용',
                value: '${stats['totalUsed'] ?? 0}',
                color: Colors.orange,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _navigateToDetailedStats(),
                icon: const Icon(Icons.analytics),
                tooltip: '상세 통계',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color[600]),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color[600],
          ),
        ),
      ],
    );
  }

  void _navigateToDetailedStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostStatisticsScreen(post: widget.post),
      ),
    );
  }
}
```

### 2. 포스트 상세 통계 화면

```dart
class PostStatisticsScreen extends StatefulWidget {
  final PostModel post;

  const PostStatisticsScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostStatisticsScreen> createState() => _PostStatisticsScreenState();
}

class _PostStatisticsScreenState extends State<PostStatisticsScreen> {
  final PostStatisticsService _statsService = PostStatisticsService();
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _statsService.getPostStatistics(widget.post.postId);
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('통계 로드 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.post.title} 통계'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.file_download),
            tooltip: '통계 내보내기',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _statistics == null
              ? _buildErrorState()
              : _buildStatisticsContent(),
    );
  }

  Widget _buildStatisticsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 포스트 기본 정보
          _buildPostHeader(),
          const SizedBox(height: 24),

          // 주요 지표 카드들
          _buildMetricsOverview(),
          const SizedBox(height: 24),

          // 수집 트렌드 차트
          _buildCollectionTrend(),
          const SizedBox(height: 24),

          // 시간대별 패턴
          _buildTimePatterns(),
          const SizedBox(height: 24),

          // 수집자 분석
          _buildCollectorAnalysis(),
          const SizedBox(height: 24),

          // 배포 현황
          _buildDeploymentStatus(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    final template = _statistics!['template'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 포스트 썸네일
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: widget.post.thumbnailUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.post.thumbnailUrl.first,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(Icons.post_add, color: Colors.grey[400]),
            ),
            const SizedBox(width: 16),

            // 포스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '리워드: ${template['reward']}원',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '생성자: ${template['creatorName']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주요 지표',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '총 배포',
                value: '${_statistics!['totalDeployments']}',
                subtitle: '개 마커',
                icon: Icons.launch,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: '총 수량',
                value: '${_statistics!['totalQuantityDeployed']}',
                subtitle: '개 포스트',
                icon: Icons.inventory,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: '수집됨',
                value: '${_statistics!['totalCollected']}',
                subtitle: '${(_statistics!['collectionRate'] * 100).toStringAsFixed(1)}% 수집률',
                icon: Icons.download,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: '사용됨',
                value: '${_statistics!['totalUsed']}',
                subtitle: '${(_statistics!['usageRate'] * 100).toStringAsFixed(1)}% 사용률',
                icon: Icons.shopping_cart,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionTrend() {
    // 여기에 차트 라이브러리 (fl_chart 등) 사용하여 트렌드 차트 구현
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수집 트렌드',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              child: const Center(
                child: Text('수집 트렌드 차트\n(차트 라이브러리 구현 필요)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePatterns() {
    final timePattern = _statistics!['timePattern'];
    final hourlyData = timePattern['hourly'] as Map<String, dynamic>;
    final dailyData = timePattern['daily'] as Map<String, dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시간 패턴 분석',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 시간대별 패턴
            Text(
              '시간대별 수집 패턴',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            _buildHourlyPattern(hourlyData),

            const SizedBox(height: 16),

            // 요일별 패턴
            Text(
              '요일별 수집 패턴',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            _buildDailyPattern(dailyData),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyPattern(Map<String, dynamic> hourlyData) {
    return Container(
      height: 60,
      child: Row(
        children: List.generate(24, (hour) {
          final count = hourlyData[hour.toString()] ?? 0;
          final maxCount = hourlyData.values.isNotEmpty
              ? hourlyData.values.reduce((a, b) => a > b ? a : b)
              : 1;
          final ratio = count / maxCount;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.blue[300]?.withOpacity(ratio),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hour.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDailyPattern(Map<String, dynamic> dailyData) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];

    return Row(
      children: days.map((day) {
        final count = dailyData[day] ?? 0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollectorAnalysis() {
    final collectors = _statistics!['collectors'];
    final topCollectors = collectors['topCollectors'] as List<dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '수집자 분석',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 수집자 요약
            Row(
              children: [
                Expanded(
                  child: _buildCollectorSummaryItem(
                    '고유 수집자',
                    '${collectors['uniqueCount']}명',
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildCollectorSummaryItem(
                    '총 수집',
                    '${collectors['totalCollections']}회',
                    Icons.download,
                  ),
                ),
                Expanded(
                  child: _buildCollectorSummaryItem(
                    '평균 수집',
                    '${collectors['averagePerUser'].toStringAsFixed(1)}회',
                    Icons.analytics,
                  ),
                ),
              ],
            ),

            if (topCollectors.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '상위 수집자',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...topCollectors.take(5).map((collector) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                  ),
                  title: Text(
                    collector['userId'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${collector['count']}회',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollectorSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[600], size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDeploymentStatus() {
    final deployments = _statistics!['deployments'] as List<dynamic>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '배포 현황',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAllDeployments,
                  icon: const Icon(Icons.list, size: 16),
                  label: const Text('전체 보기'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (deployments.isEmpty)
              const Center(
                child: Text('배포된 마커가 없습니다.'),
              )
            else
              ...deployments.take(3).map((deployment) {
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on,
                    color: Colors.red[400],
                  ),
                  title: Text(
                    '마커 ${deployment['markerId']?.substring(0, 8) ?? 'Unknown'}...',
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    '수량: ${deployment['quantity']} | 생성: ${_formatDate(deployment['createdAt'])}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: deployment['status'] == 'active'
                          ? Colors.green[100]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      deployment['status'] ?? 'unknown',
                      style: TextStyle(
                        fontSize: 10,
                        color: deployment['status'] == 'active'
                            ? Colors.green[700]
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '통계를 불러올 수 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadStatistics,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _showAllDeployments() {
    // 전체 배포 목록 화면으로 이동
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('통계 내보내기'),
        content: const Text('통계 데이터를 CSV 파일로 내보내시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _exportStatistics();
            },
            child: const Text('내보내기'),
          ),
        ],
      ),
    );
  }

  void _exportStatistics() {
    // CSV 내보내기 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('통계 데이터를 내보내는 중...'),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final date = (timestamp as Timestamp).toDate();
      return '${date.month}/${date.day}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
```

## 📊 테스트 시나리오

### 시나리오 1: 내 포스트에서 통계 접근
1. 내 포스트 목록 화면 진입
2. 포스트 카드에 통계 요약 정보 표시 확인
3. 통계 버튼 클릭하여 상세 화면 이동

### 시나리오 2: 포스트 상세 통계 확인
1. 포스트 상세 통계 화면 진입
2. 주요 지표 (배포/수집/사용률) 확인
3. 시간 패턴 차트 확인
4. 수집자 분석 정보 확인

### 시나리오 3: 실시간 데이터 업데이트
1. 통계 화면 열어놓기
2. 다른 사용자가 포스트 수집
3. 실시간으로 통계 업데이트 확인

### 시나리오 4: 통계 데이터 내보내기
1. 통계 화면에서 내보내기 버튼 클릭
2. CSV 파일 생성 및 다운로드
3. 파일 내용 검증

## 📝 체크리스트

### 개발 단계
- [ ] 내 포스트 카드에 통계 요약 추가
- [ ] 포스트 상세 통계 화면 구현
- [ ] 차트 및 시각화 컴포넌트 추가
- [ ] 실시간 데이터 스트림 연동
- [ ] 통계 데이터 내보내기 기능

### 차트 라이브러리 통합
- [ ] fl_chart 패키지 추가
- [ ] 수집 트렌드 라인 차트
- [ ] 시간대별 막대 차트
- [ ] 수집률/사용률 도넛 차트

### 테스트 단계
- [ ] 다양한 데이터 시나리오 테스트
- [ ] 실시간 업데이트 테스트
- [ ] 성능 최적화 테스트
- [ ] 다양한 화면 크기 테스트

### 배포 단계
- [ ] 코드 리뷰 완료
- [ ] QA 검증 완료
- [ ] 프로덕션 배포

## 🚨 위험 요소 및 대응 방안

### 위험 요소
1. **데이터 로딩 성능**: 대량의 통계 데이터 로딩 시 성능 저하
2. **실시간 업데이트 부하**: 실시간 스트림으로 인한 리소스 사용량 증가
3. **차트 렌더링 복잡성**: 복잡한 차트로 인한 UI 지연

### 대응 방안
1. **데이터 페이지네이션**: 대량 데이터를 청크 단위로 로딩
2. **스트림 최적화**: 필요한 경우에만 실시간 업데이트 활성화
3. **차트 최적화**: 적절한 차트 라이브러리 사용 및 렌더링 최적화

## 📅 일정 계획

| 단계 | 작업 내용 | 예상 소요 시간 | 마감일 |
|------|-----------|---------------|--------|
| 분석 | 현재 상태 분석 완료 | 0.5일 | ✅ 완료 |
| UI 기초 | 통계 요약 및 상세 화면 구현 | 1.5일 | TBD |
| 차트 연동 | 차트 라이브러리 통합 및 시각화 | 1일 | TBD |
| 고급 기능 | 내보내기 및 고급 분석 기능 | 1일 | TBD |
| 테스트 | 통합 테스트 및 성능 최적화 | 0.5일 | TBD |

**총 예상 기간**: 4.5일

## 📦 필요한 패키지

```yaml
dependencies:
  # 차트 라이브러리
  fl_chart: ^0.64.0

  # CSV 내보내기
  csv: ^5.0.2

  # 파일 다운로드
  path_provider: ^2.1.1
  share_plus: ^7.2.1
```

---

*작성일: 2025-09-30*
*최종 수정일: 2025-09-30*