import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_filter_provider.dart';
import '../widgets/map_filter_dialog.dart';

/// 지도 상단 필터 바 위젯
class MapFilterBarWidget extends StatelessWidget {
  final bool showMyPostsOnly;
  final bool showCouponsOnly;
  final VoidCallback onUpdateMarkers;
  final VoidCallback onShowFilterDialog;
  final Function(bool) onMyPostsChanged;
  final Function(bool) onCouponsChanged;

  const MapFilterBarWidget({
    super.key,
    required this.showMyPostsOnly,
    required this.showCouponsOnly,
    required this.onUpdateMarkers,
    required this.onShowFilterDialog,
    required this.onMyPostsChanged,
    required this.onCouponsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Consumer<MapFilterProvider>(
          builder: (context, filterProvider, child) {
            return Row(
              children: [
                // 필터 아이콘
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: IconButton(
                    onPressed: onShowFilterDialog,
                    icon: const Icon(Icons.filter_list, color: Colors.grey),
                    iconSize: 20,
                  ),
                ),
                // 필터 버튼들
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          icon: Icons.person,
                          label: '내 포스트',
                          isSelected: showMyPostsOnly,
                          onTap: () {
                            onMyPostsChanged(!showMyPostsOnly);
                            onUpdateMarkers();
                          },
                        ),
                        _buildFilterChip(
                          icon: Icons.card_giftcard,
                          label: '쿠폰',
                          isSelected: showCouponsOnly,
                          onTap: () {
                            onCouponsChanged(!showCouponsOnly);
                            onUpdateMarkers();
                          },
                        ),
                        _buildFilterChip(
                          icon: Icons.access_time,
                          label: '마감임박',
                          isSelected: filterProvider.showUrgentOnly,
                          onTap: () {
                            filterProvider.setUrgentOnly(!filterProvider.showUrgentOnly);
                            if (filterProvider.showUrgentOnly) {
                              // 다른 필터들 해제 로직은 상위에서 처리
                            }
                            onUpdateMarkers();
                          },
                        ),
                        _buildFilterChip(
                          icon: Icons.verified,
                          label: '인증',
                          isSelected: filterProvider.showVerifiedOnly,
                          onTap: () {
                            filterProvider.setVerifiedOnly(!filterProvider.showVerifiedOnly);
                            onUpdateMarkers();
                          },
                        ),
                        _buildFilterChip(
                          icon: Icons.work_outline,
                          label: '미인증',
                          isSelected: filterProvider.showUnverifiedOnly,
                          onTap: () {
                            filterProvider.setUnverifiedOnly(!filterProvider.showUnverifiedOnly);
                            onUpdateMarkers();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // 추가 옵션 버튼
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      // TODO: 추가 옵션 구현
                    },
                    icon: Icon(
                      Icons.more_horiz,
                      color: Colors.purple[600],
                    ),
                    iconSize: 20,
                  ),
                ),
                // 필터 초기화 버튼
                Container(
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {
                      filterProvider.resetFilters();
                      onUpdateMarkers();
                    },
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    iconSize: 18,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected 
              ? Border.all(color: Colors.blue[300]!, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.blue[600] : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue[600] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

