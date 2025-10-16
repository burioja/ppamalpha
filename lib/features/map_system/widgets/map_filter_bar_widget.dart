import 'package:flutter/material.dart';

/// 지도 상단 필터 바 위젯
class MapFilterBarWidget extends StatelessWidget {
  final bool showMyPostsOnly;
  final bool showCouponsOnly;
  final bool showUrgentOnly;
  final bool showVerifiedOnly;
  final bool showUnverifiedOnly;
  final Function(bool) onMyPostsChanged;
  final Function(bool) onCouponsChanged;
  final Function(bool) onUrgentChanged;
  final Function(bool) onVerifiedChanged;
  final Function(bool) onUnverifiedChanged;

  const MapFilterBarWidget({
    super.key,
    required this.showMyPostsOnly,
    required this.showCouponsOnly,
    required this.showUrgentOnly,
    required this.showVerifiedOnly,
    required this.showUnverifiedOnly,
    required this.onMyPostsChanged,
    required this.onCouponsChanged,
    required this.onUrgentChanged,
    required this.onVerifiedChanged,
    required this.onUnverifiedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 필터 아이콘
            Icon(Icons.tune, color: Colors.blue[600], size: 18),
            const SizedBox(width: 8),
            
            // 필터 버튼들
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 내 포스트 필터
                    _buildFilterChip(
                      label: '내 포스트',
                      selected: showMyPostsOnly,
                      onSelected: onMyPostsChanged,
                      selectedColor: Colors.blue,
                      icon: Icons.person,
                    ),
                    const SizedBox(width: 6),
                    
                    // 쿠폰 필터
                    _buildFilterChip(
                      label: '쿠폰',
                      selected: showCouponsOnly,
                      onSelected: onCouponsChanged,
                      selectedColor: Colors.green,
                      icon: Icons.card_giftcard,
                    ),
                    const SizedBox(width: 6),
                    
                    // 마감임박 필터
                    _buildFilterChip(
                      label: '마감임박',
                      selected: showUrgentOnly,
                      onSelected: onUrgentChanged,
                      selectedColor: Colors.orange,
                      icon: Icons.timer,
                    ),
                    const SizedBox(width: 6),
                    
                    // 인증 필터
                    _buildFilterChip(
                      label: '인증',
                      selected: showVerifiedOnly,
                      onSelected: onVerifiedChanged,
                      selectedColor: Colors.purple,
                      icon: Icons.verified,
                    ),
                    const SizedBox(width: 6),
                    
                    // 미인증 필터
                    _buildFilterChip(
                      label: '미인증',
                      selected: showUnverifiedOnly,
                      onSelected: onUnverifiedChanged,
                      selectedColor: Colors.red,
                      icon: Icons.warning,
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required Color selectedColor,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

