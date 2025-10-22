import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/inbox_provider.dart';

/// 인박스 필터 섹션 위젯
class InboxFilterSection extends StatelessWidget {
  const InboxFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InboxProvider>(
      builder: (context, provider, child) {
        if (!provider.showFilters) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 필터 헤더
              Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.blue[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '필터 옵션',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: provider.resetFilters,
                    child: Text(
                      '초기화',
                      style: TextStyle(color: Colors.blue[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 상태 필터
              _buildFilterRow(
                '상태',
                provider.statusFilter,
                ['all', 'active', 'inactive', 'deleted'],
                ['전체', '활성', '비활성', '삭제됨'],
                provider.onStatusFilterChanged,
              ),
              const SizedBox(height: 12),
              
              // 기간 필터
              _buildFilterRow(
                '기간',
                provider.periodFilter,
                ['all', 'today', 'week', 'month'],
                ['전체', '오늘', '1주일', '1개월'],
                provider.onPeriodFilterChanged,
              ),
              const SizedBox(height: 12),
              
              // 정렬 기준
              _buildFilterRow(
                '정렬 기준',
                provider.sortBy,
                ['createdAt', 'title', 'reward', 'expiresAt'],
                ['생성일', '제목', '보상', '만료일'],
                provider.onSortByChanged,
              ),
              const SizedBox(height: 12),
              
              // 정렬 순서
              _buildFilterRow(
                '정렬 순서',
                provider.sortOrder,
                ['desc', 'asc'],
                ['내림차순', '오름차순'],
                provider.onSortOrderChanged,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 필터 행 빌더
  Widget _buildFilterRow(
    String label,
    String currentValue,
    List<String> values,
    List<String> labels,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: values.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;
            final isSelected = currentValue == value;
            
            return _buildFilterChip(
              labels[index],
              isSelected,
              () => onChanged(value),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 필터 칩
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}