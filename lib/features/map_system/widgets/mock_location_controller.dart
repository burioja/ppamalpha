import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Mock 위치 변경을 위한 별도 위젯
/// 나중에 제거될 예정이므로 독립적으로 관리
class MockLocationController extends StatefulWidget {
  final LatLng? currentPosition;
  final Function(LatLng) onPositionChanged;

  const MockLocationController({
    super.key,
    this.currentPosition,
    required this.onPositionChanged,
  });

  @override
  State<MockLocationController> createState() => _MockLocationControllerState();
}

class _MockLocationControllerState extends State<MockLocationController> {
  LatLng? _mockPosition;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _mockPosition = widget.currentPosition;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();
    
    return Positioned(
      bottom: 100,
      left: 16,
      child: Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목과 닫기 버튼
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.purple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_searching, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  const Text(
                    'Mock 위치',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isVisible = false;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            // 화살표 컨트롤러
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  // 위쪽 화살표
                  GestureDetector(
                    onTap: () => _moveMockPosition('up'),
                    child: Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 좌우 화살표
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _moveMockPosition('left'),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Icon(Icons.keyboard_arrow_left, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // 중앙 위치 표시
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.purple, size: 16),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => _moveMockPosition('right'),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 아래쪽 화살표
                  GestureDetector(
                    onTap: () => _moveMockPosition('down'),
                    child: Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            // 현재 위치 정보
            if (_mockPosition != null)
              GestureDetector(
                onTap: _showMockPositionInputDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '위도: ${_mockPosition!.latitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 10, color: Colors.grey),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '경도: ${_mockPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 10, color: Colors.grey),
                        ],
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

  void _moveMockPosition(String direction) {
    if (_mockPosition == null) return;
    
    const double step = 0.001; // 약 100m 정도
    double newLat = _mockPosition!.latitude;
    double newLng = _mockPosition!.longitude;
    
    switch (direction) {
      case 'up':
        newLat += step;
        break;
      case 'down':
        newLat -= step;
        break;
      case 'left':
        newLng -= step;
        break;
      case 'right':
        newLng += step;
        break;
    }
    
    setState(() {
      _mockPosition = LatLng(newLat, newLng);
    });
    
    widget.onPositionChanged(_mockPosition!);
  }

  void _showMockPositionInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mock 위치 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: '위도',
                hintText: '37.5665',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                // TODO: 위도 입력 처리
              },
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: '경도',
                hintText: '126.9780',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                // TODO: 경도 입력 처리
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Mock 위치 적용
            },
            child: const Text('적용'),
          ),
        ],
      ),
    );
  }

  void show() {
    setState(() {
      _isVisible = true;
    });
  }

  void hide() {
    setState(() {
      _isVisible = false;
    });
  }
}
