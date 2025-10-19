import 'package:flutter/material.dart';
import '../../../../core/models/post/post_model.dart';

/// 받은편지함 통계 탭
class InboxStatisticsTab extends StatelessWidget {
  final List<PostModel> posts;

  const InboxStatisticsTab({
    super.key,
    required this.posts,
  });

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '포스트 통계',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // 요약 카드
          _buildSummaryCards(stats),
          const SizedBox(height: 20),

          // 상세 통계
          _buildDetailStats(stats),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '총 포스트',
            '${stats['total']}개',
            Icons.article,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '활성',
            '${stats['active']}개',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '총 보상',
            '${stats['totalReward']}원',
            Icons.attach_money,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color[600], size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color[800],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStats(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatRow('총 포스트', '${stats['total']}개'),
            const Divider(),
            _buildStatRow('초안', '${stats['draft']}개'),
            _buildStatRow('배포됨', '${stats['deployed']}개'),
            _buildStatRow('활성', '${stats['active']}개'),
            _buildStatRow('만료됨', '${stats['expired']}개'),
            const Divider(),
            _buildStatRow('총 보상', '${stats['totalReward']}원'),
            _buildStatRow('평균 보상', '${stats['avgReward']}원'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateStats() {
    final now = DateTime.now();
    
    return {
      'total': posts.length,
      'draft': posts.where((p) => p.status == 'draft').length,
      'deployed': posts.where((p) => p.status == 'deployed').length,
      'active': posts.where((p) {
        final expiresAt = p.defaultExpiresAt;
        return expiresAt != null && expiresAt.isAfter(now);
      }).length,
      'expired': posts.where((p) {
        final expiresAt = p.defaultExpiresAt;
        return expiresAt != null && expiresAt.isBefore(now);
      }).length,
      'totalReward': posts.fold<int>(
        0,
        (sum, p) => sum + (p.reward ?? 0),
      ),
      'avgReward': posts.isEmpty
          ? 0
          : (posts.fold<int>(0, (sum, p) => sum + (p.reward ?? 0)) / posts.length).round(),
    };
  }
}

