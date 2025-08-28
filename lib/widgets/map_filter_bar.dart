import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_filter_provider.dart';

/// 지도 필터링을 담당하는 상단 바 위젯
class MapFilterBar extends StatelessWidget {
  final VoidCallback? onFilterChanged;
  final bool showCouponsOnly;
  final bool showMyPostsOnly;
  final Function(bool) onCouponsOnlyChanged;
  final Function(bool) onMyPostsOnlyChanged;

  const MapFilterBar({
    super.key,
    this.onFilterChanged,
    required this.showCouponsOnly,
    required this.showMyPostsOnly,
    required this.onCouponsOnlyChanged,
    required this.onMyPostsOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MapFilterProvider>(
      builder: (context, filterProvider, child) {
        return Container(
          margin: const EdgeInsets.all(16.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 쿠폰만 보기 필터
              _buildFilterChip(
                label: '쿠폰만',
                isSelected: showCouponsOnly,
                onSelected: (selected) {
                  onCouponsOnlyChanged(selected);
                  onFilterChanged?.call();
                },
                icon: Icons.local_offer,
                selectedColor: Colors.orange,
              ),
              
              const SizedBox(width: 8.0),
              
              // 내 포스트만 보기 필터
              _buildFilterChip(
                label: '내 포스트',
                isSelected: showMyPostsOnly,
                onSelected: (selected) {
                  onMyPostsOnlyChanged(selected);
                  onFilterChanged?.call();
                },
                icon: Icons.person,
                selectedColor: Colors.blue,
              ),
              
              const SizedBox(width: 8.0),
              
              // 필터 초기화 버튼
              if (showCouponsOnly || showMyPostsOnly)
                _buildResetButton(context),
            ],
          ),
        );
      },
    );
  }

  /// 필터 칩 위젯 생성
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
    required IconData icon,
    required Color selectedColor,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16.0,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
          const SizedBox(width: 4.0),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[700],
              fontSize: 12.0,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.grey[100],
      selectedColor: selectedColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? selectedColor : Colors.grey[300]!,
        width: 1.0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  /// 필터 초기화 버튼
  Widget _buildResetButton(BuildContext context) {
    return InkWell(
      onTap: () {
        onCouponsOnlyChanged(false);
        onMyPostsOnlyChanged(false);
        onFilterChanged?.call();
        
        // 사용자에게 피드백 제공
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('필터가 초기화되었습니다'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Icon(
          Icons.refresh,
          size: 16.0,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

/// 확장된 필터 옵션을 제공하는 고급 필터 바
class MapAdvancedFilterBar extends StatefulWidget {
  final Map<String, dynamic> filterOptions;
  final Function(Map<String, dynamic>) onFiltersChanged;
  final VoidCallback? onFilterChanged;

  const MapAdvancedFilterBar({
    super.key,
    required this.filterOptions,
    required this.onFiltersChanged,
    this.onFilterChanged,
  });

  @override
  State<MapAdvancedFilterBar> createState() => _MapAdvancedFilterBarState();
}

class _MapAdvancedFilterBarState extends State<MapAdvancedFilterBar> {
  late Map<String, dynamic> _currentFilters;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _currentFilters = Map.from(widget.filterOptions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 기본 필터 바
        MapFilterBar(
          showCouponsOnly: _currentFilters['showCouponsOnly'] ?? false,
          showMyPostsOnly: _currentFilters['showMyPostsOnly'] ?? false,
          onCouponsOnlyChanged: (value) {
            setState(() {
              _currentFilters['showCouponsOnly'] = value;
            });
            _applyFilters();
          },
          onMyPostsOnlyChanged: (value) {
            setState(() {
              _currentFilters['showMyPostsOnly'] = value;
            });
            _applyFilters();
          },
          onFilterChanged: widget.onFilterChanged,
        ),
        
        // 확장/축소 버튼
        if (_hasAdvancedFilters)
          _buildExpandButton(),
        
        // 고급 필터 옵션들
        if (_isExpanded && _hasAdvancedFilters)
          _buildAdvancedFilters(),
      ],
    );
  }

  /// 확장/축소 버튼
  Widget _buildExpandButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1.0,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            icon: Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[600],
            ),
            label: Text(
              _isExpanded ? '필터 축소' : '고급 필터',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.0,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// 고급 필터 옵션들
  Widget _buildAdvancedFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 가격 범위 필터
          if (_currentFilters.containsKey('priceRange'))
            _buildPriceRangeFilter(),
          
          const SizedBox(height: 16.0),
          
          // 거리 범위 필터
          if (_currentFilters.containsKey('distanceRange'))
            _buildDistanceRangeFilter(),
          
          const SizedBox(height: 16.0),
          
          // 카테고리 필터
          if (_currentFilters.containsKey('categories'))
            _buildCategoryFilter(),
          
          const SizedBox(height: 16.0),
          
          // 필터 적용/초기화 버튼
          _buildFilterActionButtons(),
        ],
      ),
    );
  }

  /// 가격 범위 필터
  Widget _buildPriceRangeFilter() {
    final priceRange = _currentFilters['priceRange'] as List<int>? ?? [0, 100000];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '가격 범위',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8.0),
        RangeSlider(
          values: RangeValues(priceRange[0].toDouble(), priceRange[1].toDouble()),
          min: 0.0,
          max: 100000.0,
          divisions: 100,
          labels: RangeLabels(
            '${priceRange[0]}원',
            '${priceRange[1]}원',
          ),
          onChanged: (values) {
            setState(() {
              _currentFilters['priceRange'] = [
                values.start.round(),
                values.end.round(),
              ];
            });
          },
        ),
      ],
    );
  }

  /// 거리 범위 필터
  Widget _buildDistanceRangeFilter() {
    final distanceRange = _currentFilters['distanceRange'] as List<double>? ?? [0.0, 10.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '거리 범위',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8.0),
        RangeSlider(
          values: RangeValues(distanceRange[0], distanceRange[1]),
          min: 0.0,
          max: 10.0,
          divisions: 20,
          labels: RangeLabels(
            '${distanceRange[0].toStringAsFixed(1)}km',
            '${distanceRange[1].toStringAsFixed(1)}km',
          ),
          onChanged: (values) {
            setState(() {
              _currentFilters['distanceRange'] = [
                values.start,
                values.end,
              ];
            });
          },
        ),
      ],
    );
  }

  /// 카테고리 필터
  Widget _buildCategoryFilter() {
    final categories = _currentFilters['categories'] as List<String>? ?? [];
    final availableCategories = ['음식', '쇼핑', '엔터테인먼트', '서비스', '기타'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '카테고리',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8.0),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: availableCategories.map((category) {
            final isSelected = categories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    categories.add(category);
                  } else {
                    categories.remove(category);
                  }
                  _currentFilters['categories'] = List.from(categories);
                });
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.green[100],
              checkmarkColor: Colors.green[700],
              side: BorderSide(
                color: isSelected ? Colors.green[300]! : Colors.grey[300]!,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 필터 액션 버튼들
  Widget _buildFilterActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _resetFilters,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: Text(
              '초기화',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          child: ElevatedButton(
            onPressed: _applyFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text(
              '적용',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// 고급 필터가 있는지 확인
  bool get _hasAdvancedFilters {
    return _currentFilters.keys.any((key) => 
      key != 'showCouponsOnly' && key != 'showMyPostsOnly'
    );
  }

  /// 필터 적용
  void _applyFilters() {
    widget.onFiltersChanged(_currentFilters);
    widget.onFilterChanged?.call();
    
    // 사용자에게 피드백 제공
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('필터가 적용되었습니다'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 필터 초기화
  void _resetFilters() {
    setState(() {
      _currentFilters = {
        'showCouponsOnly': false,
        'showMyPostsOnly': false,
      };
    });
    _applyFilters();
  }
}
