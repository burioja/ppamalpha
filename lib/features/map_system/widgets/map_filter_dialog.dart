import 'package:flutter/material.dart';

/// 지도 필터 설정 다이얼로그
class MapFilterDialog extends StatefulWidget {
  final String selectedCategory;
  final double maxDistance;
  final int minReward;
  final bool isPremiumUser;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final Function(String) onCategoryChanged;
  final Function(int) onMinRewardChanged;

  const MapFilterDialog({
    Key? key,
    required this.selectedCategory,
    required this.maxDistance,
    required this.minReward,
    required this.isPremiumUser,
    required this.onReset,
    required this.onApply,
    required this.onCategoryChanged,
    required this.onMinRewardChanged,
  }) : super(key: key);

  @override
  State<MapFilterDialog> createState() => _MapFilterDialogState();

  /// 다이얼로그 표시 헬퍼 메서드
  static Future<void> show({
    required BuildContext context,
    required String selectedCategory,
    required double maxDistance,
    required int minReward,
    required bool isPremiumUser,
    required VoidCallback onReset,
    required VoidCallback onApply,
    required Function(String) onCategoryChanged,
    required Function(int) onMinRewardChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MapFilterDialog(
        selectedCategory: selectedCategory,
        maxDistance: maxDistance,
        minReward: minReward,
        isPremiumUser: isPremiumUser,
        onReset: onReset,
        onApply: onApply,
        onCategoryChanged: onCategoryChanged,
        onMinRewardChanged: onMinRewardChanged,
      ),
    );
  }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 포스트 타입 선택
                  _buildPostTypeSelector(),
                  
                  const SizedBox(height: 30),
                  
                  // 검색 반경 표시
                  _buildSearchRadiusDisplay(),
                  
                  const SizedBox(height: 30),
                  
                  // 최소 리워드 슬라이더
                  _buildMinRewardSlider(),
                  
                  const SizedBox(height: 30),
                  
                  // 정렬 옵션
                  _buildSortOptions(),
                ],
              ),
            ),
          ),
          
          // 하단 버튼들
          Padding(
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
                      widget.onCategoryChanged(_selectedCategory);
                      widget.onMinRewardChanged(_minReward);
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
                    child: const Text(
                      '적용',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTypeSelector() {
    return Row(
      children: [
        const Text('포스트 타입:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = 'all'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedCategory == 'all' ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '전체',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedCategory == 'all' ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = 'coupon'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedCategory == 'coupon' ? Colors.blue : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '쿠폰만',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedCategory == 'coupon' ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildSearchRadiusDisplay() {
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

  Widget _buildMinRewardSlider() {
    return Row(
      children: [
        const Text('최소 리워드:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_minReward}원',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _minReward.toDouble(),
                min: 0,
                max: 10000,
                divisions: 100,
                onChanged: (value) {
                  setState(() {
                    _minReward = value.toInt();
                  });
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
}

