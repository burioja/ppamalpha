import 'package:flutter/material.dart';

/// 지도 필터 다이얼로그 위젯
class MapFilterDialog extends StatefulWidget {
  final String selectedCategory;
  final double maxDistance;
  final int minReward;
  final bool isPremiumUser;
  final Function(String) onCategoryChanged;
  final Function(int) onMinRewardChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  const MapFilterDialog({
    super.key,
    required this.selectedCategory,
    required this.maxDistance,
    required this.minReward,
    required this.isPremiumUser,
    required this.onCategoryChanged,
    required this.onMinRewardChanged,
    required this.onReset,
    required this.onApply,
  });

  @override
  State<MapFilterDialog> createState() => _MapFilterDialogState();
}

class _MapFilterDialogState extends State<MapFilterDialog> {
  late String _selectedCategory;
  late int _minReward;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _minReward = widget.minReward;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 제목
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              '필터 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 필터 내용
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 포스트 타입 토글
                  _buildCategoryToggle(),
                  
                  const SizedBox(height: 30),
                  
                  // 검색 반경 표시
                  _buildDistanceDisplay(),
                  
                  const SizedBox(height: 30),
                  
                  // 최소 리워드 슬라이더
                  _buildRewardSlider(),
                  
                  const SizedBox(height: 30),
                  
                  // 정렬 옵션
                  _buildSortOptions(),
                ],
              ),
            ),
          ),
          
          // 하단 버튼들
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle() {
    return Row(
      children: [
        const Text('포스트 타입:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryButton('전체', 'all'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryButton('쿠폰만', 'coupon'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryButton(String label, String value) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = value);
        widget.onCategoryChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceDisplay() {
    return Row(
      children: [
        const Text('검색 반경:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isPremiumUser ? Colors.amber[50] : Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isPremiumUser ? Colors.amber[200]! : Colors.blue[200]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.maxDistance.toInt()}m',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isPremiumUser ? Colors.amber[800] : Colors.blue,
                ),
              ),
              if (widget.isPremiumUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRewardSlider() {
    return Row(
      children: [
        const Text('최소 리워드:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              Text(
                '$_minReward원',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _minReward.toDouble(),
                min: 0,
                max: 10000,
                divisions: 100,
                onChanged: (value) {
                  setState(() => _minReward = value.toInt());
                  widget.onMinRewardChanged(value.toInt());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Row(
      children: [
        const Text('정렬:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '가까운순',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '최신순',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onReset();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('초기화'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('적용'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 필터 다이얼로그를 표시하는 헬퍼 함수
void showMapFilterDialog({
  required BuildContext context,
  required String selectedCategory,
  required double maxDistance,
  required int minReward,
  required bool isPremiumUser,
  required Function(String) onCategoryChanged,
  required Function(int) onMinRewardChanged,
  required VoidCallback onReset,
  required VoidCallback onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MapFilterDialog(
      selectedCategory: selectedCategory,
      maxDistance: maxDistance,
      minReward: minReward,
      isPremiumUser: isPremiumUser,
      onCategoryChanged: onCategoryChanged,
      onMinRewardChanged: onMinRewardChanged,
      onReset: onReset,
      onApply: onApply,
    ),
  );
}

