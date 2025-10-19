import 'package:flutter/material.dart';

/// 받은편지함 필터 섹션 위젯
class InboxFilterSection extends StatelessWidget {
  final String statusFilter;
  final String periodFilter;
  final String sortBy;
  final String sortOrder;
  final Function(String) onStatusChanged;
  final Function(String) onPeriodChanged;
  final Function(String) onSortByChanged;
  final Function(String) onSortOrderChanged;
  final VoidCallback onReset;

  const InboxFilterSection({
    super.key,
    required this.statusFilter,
    required this.periodFilter,
    required this.sortBy,
    required this.sortOrder,
    required this.onStatusChanged,
    required this.onPeriodChanged,
    required this.onSortByChanged,
    required this.onSortOrderChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '필터',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('초기화'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 상태 필터
          _buildSection(
            title: '상태',
            child: Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('전체', 'all', statusFilter, onStatusChanged),
                _buildFilterChip('활성', 'active', statusFilter, onStatusChanged),
                _buildFilterChip('비활성', 'inactive', statusFilter, onStatusChanged),
                _buildFilterChip('삭제됨', 'deleted', statusFilter, onStatusChanged),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 기간 필터
          _buildSection(
            title: '기간',
            child: Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('전체', 'all', periodFilter, onPeriodChanged),
                _buildFilterChip('오늘', 'today', periodFilter, onPeriodChanged),
                _buildFilterChip('이번 주', 'week', periodFilter, onPeriodChanged),
                _buildFilterChip('이번 달', 'month', periodFilter, onPeriodChanged),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 정렬
          _buildSection(
            title: '정렬',
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: sortBy,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'createdAt', child: Text('생성일')),
                      DropdownMenuItem(value: 'title', child: Text('제목')),
                      DropdownMenuItem(value: 'reward', child: Text('보상')),
                      DropdownMenuItem(value: 'expiresAt', child: Text('만료일')),
                    ],
                    onChanged: (value) {
                      if (value != null) onSortByChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    onSortOrderChanged(sortOrder == 'asc' ? 'desc' : 'asc');
                  },
                  icon: Icon(
                    sortOrder == 'asc'
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    Function(String) onTap,
  ) {
    final isSelected = currentValue == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(value),
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
    );
  }
}

