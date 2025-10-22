import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inbox_provider.dart';

/// 인박스 통계 탭 위젯
class InboxStatisticsTab extends StatelessWidget {
  const InboxStatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (!provider.statisticsLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.orange[50]!, Colors.white],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 전체 통계 카드
              _buildOverallStatsCard(provider),
              const SizedBox(height: 20),
              
              // 포스트 통계 섹션
              _buildPostStatsSection(provider),
              const SizedBox(height: 20),
              
              // 포인트 통계 섹션
              _buildPointStatsSection(provider),
              const SizedBox(height: 20),
              
              // 상세 통계 그리드
              _buildDetailedStatsGrid(provider),
            ],
          ),
        );
      },
    );
  }

  /// 전체 통계 카드
  Widget _buildOverallStatsCard(InboxProvider provider) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[400]!, Colors.red[400]!],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '전체 통계',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('배포 포스트', '${provider.totalDeployed}개', Icons.send),
              _buildStatItem('수집률', '${provider.collectionRate}%', Icons.trending_up),
              _buildStatItem('현재 포인트', '${provider.currentBalance}P', Icons.account_balance_wallet),
            ],
          ),
        ],
      ),
    );
  }

  /// 포스트 통계 섹션
  Widget _buildPostStatsSection(InboxProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.post_add, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '포스트 통계',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  '총 배포',
                  '${provider.totalDeployed}개',
                  Icons.send,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  '총 수집',
                  '${provider.totalCollections}회',
                  Icons.collections_bookmark,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  '총 조회',
                  '${provider.totalViews}회',
                  Icons.visibility,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  '수집률',
                  '${provider.collectionRate}%',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 포인트 통계 섹션
  Widget _buildPointStatsSection(InboxProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.green[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '포인트 통계',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  '총 지출',
                  '${provider.totalSpent}P',
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  '총 획득',
                  '${provider.totalEarned}P',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  '순수익',
                  '${provider.netBalance}P',
                  Icons.account_balance,
                  provider.netBalance >= 0 ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  '현재 잔액',
                  '${provider.currentBalance}P',
                  Icons.wallet,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 상세 통계 그리드
  Widget _buildDetailedStatsGrid(InboxProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, color: Colors.purple[600], size: 24),
              const SizedBox(width: 8),
              Text(
                '상세 통계',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildMiniStatCard('평균 수집률', '${provider.collectionRate}%', Icons.analytics, Colors.blue),
              _buildMiniStatCard('활성 포스트', '${provider.totalDeployed}개', Icons.send, Colors.green),
              _buildMiniStatCard('총 포인트', '${provider.currentBalance}P', Icons.account_balance_wallet, Colors.orange),
              _buildMiniStatCard('수집 횟수', '${provider.totalCollections}회', Icons.collections_bookmark, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  /// 통계 아이템
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// 상세 통계 카드
  Widget _buildDetailStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color[800],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 미니 통계 카드
  Widget _buildMiniStatCard(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color[50]!, color[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color[600], size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color[800],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}