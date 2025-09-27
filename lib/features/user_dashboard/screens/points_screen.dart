import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/data/points_service.dart';
import '../../../core/models/user/user_points_model.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> with SingleTickerProviderStateMixin {
  final PointsService _pointsService = PointsService();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  UserPointsModel? userPoints;
  List<Map<String, dynamic>> pointsHistory = [];
  late TabController _tabController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadUserPoints(),
        _loadPointsHistory(),
      ]);
    } catch (e) {
      debugPrint('데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPoints() async {
    if (userId == null) return;

    try {
      final points = await _pointsService.getUserPoints(userId!);
      if (mounted) {
        setState(() {
          userPoints = points;
        });
      }
    } catch (e) {
      debugPrint('포인트 정보 로드 오류: $e');
    }
  }

  Future<void> _loadPointsHistory() async {
    if (userId == null) return;

    try {
      final history = await _pointsService.getPointsHistory(userId!, limit: 50);
      if (mounted) {
        setState(() {
          pointsHistory = history;
        });
      }
    } catch (e) {
      debugPrint('포인트 히스토리 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('포인트'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 포인트 정보 카드
                _buildPointsInfoCard(),

                // 탭바
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).primaryColor,
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[600],
                    tabs: const [
                      Tab(text: '전체'),
                      Tab(text: '적립'),
                      Tab(text: '사용'),
                    ],
                  ),
                ),

                // 탭 내용
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHistoryTab(null), // 전체
                      _buildHistoryTab('earned'), // 적립
                      _buildHistoryTab('spent'), // 사용
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPointsInfoCard() {
    if (userPoints == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(userPoints!.gradeColor),
            Color(userPoints!.gradeColor).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(userPoints!.gradeColor).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${userPoints!.formattedPoints}P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userPoints!.grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Level ${userPoints!.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '다음 레벨까지 ${userPoints!.pointsToNextLevel}P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: userPoints!.levelProgress,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(String? filterType) {
    List<Map<String, dynamic>> filteredHistory = pointsHistory;

    if (filterType != null) {
      filteredHistory = pointsHistory
          .where((item) => item['type'] == filterType)
          .toList();
    }

    if (filteredHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              filterType == null
                  ? '포인트 기록이 없습니다'
                  : filterType == 'earned'
                      ? '포인트 적립 기록이 없습니다'
                      : '포인트 사용 기록이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '활동을 시작하면 포인트 기록이\n여기에 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredHistory.length,
        itemBuilder: (context, index) {
          return _buildPointsHistoryItem(filteredHistory[index]);
        },
      ),
    );
  }

  Widget _buildPointsHistoryItem(Map<String, dynamic> item) {
    final isEarned = item['type'] == 'earned';
    final points = item['points'] as int;
    final reason = item['reason'] as String;
    final timestamp = item['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isEarned ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            isEarned ? Icons.add_circle : Icons.remove_circle,
            color: isEarned ? Colors.green : Colors.red,
            size: 24,
          ),
        ),
        title: Text(
          reason,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatDateTime(timestamp),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isEarned ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${isEarned ? '+' : '-'}${points}P',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isEarned ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // 오늘
      return '오늘 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // 어제
      return '어제 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // 이번 주
      const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      return '${weekdays[dateTime.weekday % 7]}요일 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // 그 외
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
  }
}