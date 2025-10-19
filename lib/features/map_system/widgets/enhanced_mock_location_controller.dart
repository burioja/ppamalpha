import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// 향상된 Mock 위치 컨트롤러
/// 
/// **기능**:
/// - Mock 모드 활성화/비활성화
/// - 방향키로 위치 이동 (약 25m씩)
/// - 직접 좌표 입력
/// - 위치 변경 콜백
/// - 표시/숨김 제어
class EnhancedMockLocationController extends StatefulWidget {
  final LatLng? currentPosition;
  final bool isMockModeEnabled;
  final bool isVisible;
  final Function(LatLng) onPositionChanged;
  final VoidCallback? onClose;
  
  const EnhancedMockLocationController({
    super.key,
    this.currentPosition,
    required this.isMockModeEnabled,
    required this.isVisible,
    required this.onPositionChanged,
    this.onClose,
  });

  @override
  State<EnhancedMockLocationController> createState() => 
      _EnhancedMockLocationControllerState();
}

class _EnhancedMockLocationControllerState 
    extends State<EnhancedMockLocationController> {
  LatLng? _mockPosition;

  @override
  void initState() {
    super.initState();
    _mockPosition = widget.currentPosition;
  }

  @override
  void didUpdateWidget(EnhancedMockLocationController oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mock 모드가 활성화되고 위치가 변경되면 업데이트
    if (widget.isMockModeEnabled && 
        widget.currentPosition != _mockPosition) {
      _mockPosition = widget.currentPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mock 모드가 꺼져있거나 숨김 상태면 표시 안함
    if (!widget.isMockModeEnabled || !widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 80,
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
            // 헤더
            _buildHeader(),
            // 방향키 컨트롤
            _buildDirectionControls(),
            // 위치 정보 표시
            if (_mockPosition != null) _buildPositionInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            onTap: widget.onClose,
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionControls() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 위쪽 화살표
          _buildArrowButton(Icons.keyboard_arrow_up, 'up', 40, 30),
          const SizedBox(height: 2),
          // 좌우 + 중앙
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildArrowButton(Icons.keyboard_arrow_left, 'left', 30, 30),
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
                child: const Icon(
                  Icons.my_location,
                  color: Colors.purple,
                  size: 16,
                ),
              ),
              const SizedBox(width: 2),
              _buildArrowButton(Icons.keyboard_arrow_right, 'right', 30, 30),
            ],
          ),
          const SizedBox(height: 2),
          // 아래쪽 화살표
          _buildArrowButton(Icons.keyboard_arrow_down, 'down', 40, 30),
        ],
      ),
    );
  }

  Widget _buildArrowButton(
    IconData icon,
    String direction,
    double width,
    double height,
  ) {
    return GestureDetector(
      onTap: () => _moveMockPosition(direction),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Icon(icon, color: Colors.grey),
      ),
    );
  }

  Widget _buildPositionInfo() {
    return GestureDetector(
      onTap: _showPositionInputDialog,
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
    );
  }

  void _moveMockPosition(String direction) {
    if (_mockPosition == null) return;

    const double moveDistance = 0.000225; // 약 25m 이동
    LatLng newPosition;

    switch (direction) {
      case 'up':
        newPosition = LatLng(
          _mockPosition!.latitude + moveDistance,
          _mockPosition!.longitude,
        );
        break;
      case 'down':
        newPosition = LatLng(
          _mockPosition!.latitude - moveDistance,
          _mockPosition!.longitude,
        );
        break;
      case 'left':
        newPosition = LatLng(
          _mockPosition!.latitude,
          _mockPosition!.longitude - moveDistance,
        );
        break;
      case 'right':
        newPosition = LatLng(
          _mockPosition!.latitude,
          _mockPosition!.longitude + moveDistance,
        );
        break;
      default:
        return;
    }

    setState(() {
      _mockPosition = newPosition;
    });

    widget.onPositionChanged(newPosition);
  }

  Future<void> _showPositionInputDialog() async {
    final latController = TextEditingController(
      text: _mockPosition?.latitude.toStringAsFixed(6) ?? '',
    );
    final lngController = TextEditingController(
      text: _mockPosition?.longitude.toStringAsFixed(6) ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mock 위치 직접 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: '위도 (Latitude)',
                hintText: '37.5665',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: '경도 (Longitude)',
                hintText: '126.9780',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '예시: 서울시청 (37.5665, 126.9780)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result == true) {
      final lat = double.tryParse(latController.text);
      final lng = double.tryParse(lngController.text);

      if (lat != null && lng != null) {
        // 위도/경도 유효성 검사
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          final newPosition = LatLng(lat, lng);
          setState(() {
            _mockPosition = newPosition;
          });
          widget.onPositionChanged(newPosition);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('올바른 좌표 범위를 입력해주세요'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    }

    latController.dispose();
    lngController.dispose();
  }
}

