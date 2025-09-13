import 'package:flutter/material.dart';

/// 지도 필터 위젯
class MapFilterWidget extends StatefulWidget {
  final bool showFilter;
  final String selectedCategory;
  final double maxDistance;
  final int minReward;
  final bool showCouponsOnly;
  final bool showMyPostsOnly;
  final bool isPremiumUser;
  final Function(String)? onCategoryChanged;
  final Function(double)? onDistanceChanged;
  final Function(int)? onMinRewardChanged;
  final Function(bool)? onCouponsOnlyChanged;
  final Function(bool)? onMyPostsOnlyChanged;
  final VoidCallback? onToggleFilter;

  const MapFilterWidget({
    super.key,
    required this.showFilter,
    required this.selectedCategory,
    required this.maxDistance,
    required this.minReward,
    required this.showCouponsOnly,
    required this.showMyPostsOnly,
    required this.isPremiumUser,
    this.onCategoryChanged,
    this.onDistanceChanged,
    this.onMinRewardChanged,
    this.onCouponsOnlyChanged,
    this.onMyPostsOnlyChanged,
    this.onToggleFilter,
  });

  @override
  State<MapFilterWidget> createState() => _MapFilterWidgetState();
}

class _MapFilterWidgetState extends State<MapFilterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.showFilter) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(MapFilterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFilter != oldWidget.showFilter) {
      if (widget.showFilter) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 필터 토글 버튼
        Positioned(
          top: 100,
          left: 16,
          child: FloatingActionButton.small(
            heroTag: "filter_toggle",
            onPressed: widget.onToggleFilter,
            backgroundColor: widget.showFilter
                ? Colors.blue
                : Colors.white,
            child: Icon(
              Icons.filter_list,
              color: widget.showFilter
                  ? Colors.white
                  : Colors.blue,
            ),
          ),
        ),

        // 필터 패널
        if (widget.showFilter)
          SlideTransition(
            position: _slideAnimation,
            child: _buildFilterPanel(context),
          ),
      ],
    );
  }

  Widget _buildFilterPanel(BuildContext context) {
    return Positioned(
      top: 60,
      left: 16,
      child: Container(
        width: 300,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '필터',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onToggleFilter,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 필터 옵션들
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 카테고리 선택
                  _buildCategoryFilter(),
                  const SizedBox(height: 16),

                  // 거리 설정
                  _buildDistanceFilter(),
                  const SizedBox(height: 16),

                  // 최소 보상 설정
                  _buildMinRewardFilter(),
                  const SizedBox(height: 16),

                  // 체크박스 옵션들
                  _buildCheckboxOptions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildCategoryChip('all', '전체'),
            _buildCategoryChip('delivery', '배달'),
            _buildCategoryChip('pickup', '픽업'),
            _buildCategoryChip('service', '서비스'),
            _buildCategoryChip('coupon', '쿠폰'),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String value, String label) {
    final isSelected = widget.selectedCategory == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => widget.onCategoryChanged?.call(value),
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildDistanceFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최대 거리',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.maxDistance.toStringAsFixed(1)}km',
              style: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: widget.maxDistance,
          min: 0.1,
          max: widget.isPremiumUser ? 5.0 : 1.0,
          divisions: widget.isPremiumUser ? 49 : 9,
          onChanged: widget.onDistanceChanged,
          activeColor: Colors.blue,
        ),
        if (!widget.isPremiumUser)
          const Text(
            '프리미엄 멤버십으로 최대 5km까지!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange,
            ),
          ),
      ],
    );
  }

  Widget _buildMinRewardFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '최소 보상',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.minReward}원',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: widget.minReward.toDouble(),
          min: 0,
          max: 50000,
          divisions: 50,
          onChanged: (value) => widget.onMinRewardChanged?.call(value.toInt()),
          activeColor: Colors.green,
        ),
      ],
    );
  }

  Widget _buildCheckboxOptions() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('쿠폰만 보기'),
          value: widget.showCouponsOnly,
          onChanged: widget.onCouponsOnlyChanged,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('내 게시물만 보기'),
          value: widget.showMyPostsOnly,
          onChanged: widget.onMyPostsOnlyChanged,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}