import 'package:flutter/material.dart';

/// 필터 관리 Handler
/// 
/// 포스트 필터링 관련 모든 상태와 로직
class MapFilterHandler {
  // 필터 상태
  bool showFilter = false;
  String selectedCategory = 'all';
  double maxDistance = 1000.0;
  int minReward = 0;
  bool showCouponsOnly = false;
  bool showMyPostsOnly = false;
  bool showUrgentOnly = false;
  bool showVerifiedOnly = false;
  bool showUnverifiedOnly = false;
  bool isPremiumUser = false;

  /// 필터 초기화
  void resetFilters() {
    selectedCategory = 'all';
    maxDistance = isPremiumUser ? 3000.0 : 1000.0;
    minReward = 0;
    showCouponsOnly = false;
    showMyPostsOnly = false;
    showUrgentOnly = false;
    showVerifiedOnly = false;
    showUnverifiedOnly = false;
  }

  /// Premium 상태 설정
  void setPremiumStatus(bool isPremium) {
    isPremiumUser = isPremium;
    maxDistance = isPremium ? 3000.0 : 1000.0;
  }

  /// 필터 맵 생성 (서버 전송용)
  Map<String, dynamic> getFiltersMap() {
    return {
      'showCouponsOnly': showCouponsOnly,
      'myPostsOnly': showMyPostsOnly,
      'minReward': minReward,
      'showUrgentOnly': showUrgentOnly,
      'showVerifiedOnly': showVerifiedOnly,
      'showUnverifiedOnly': showUnverifiedOnly,
    };
  }

  /// 필터 활성화 여부 확인
  bool get hasActiveFilters {
    return showCouponsOnly ||
        showMyPostsOnly ||
        minReward > 0 ||
        showUrgentOnly ||
        showVerifiedOnly ||
        showUnverifiedOnly ||
        selectedCategory != 'all';
  }

  /// 필터 개수 카운트
  int get activeFilterCount {
    int count = 0;
    if (showCouponsOnly) count++;
    if (showMyPostsOnly) count++;
    if (minReward > 0) count++;
    if (showUrgentOnly) count++;
    if (showVerifiedOnly) count++;
    if (showUnverifiedOnly) count++;
    if (selectedCategory != 'all') count++;
    return count;
  }
}

/// 필터 칩 빌더 위젯
class FilterChipBuilder extends StatelessWidget {
  final String label;
  final bool selected;
  final Function(bool) onSelected;
  final Color selectedColor;
  final IconData? icon;

  const FilterChipBuilder({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.selectedColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey[700],
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: selectedColor,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? selectedColor : Colors.grey[300]!,
          width: 1.5,
        ),
      ),
    );
  }
}

