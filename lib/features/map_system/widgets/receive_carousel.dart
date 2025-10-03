import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/receipt_item.dart';

class ReceiveCarousel extends StatefulWidget {
  final List<ReceiptItem> items;
  final Function(String markerId) onConfirmTap;

  const ReceiveCarousel({
    Key? key,
    required this.items,
    required this.onConfirmTap,
  }) : super(key: key);

  @override
  _ReceiveCarouselState createState() => _ReceiveCarouselState();
}

class _ReceiveCarouselState extends State<ReceiveCarousel> {
  late PageController _pageController;
  final Set<String> _confirmedMarkerIds = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // 이미 확인된 마커가 있을 경우 초기화
    for (var item in widget.items) {
      if (item.confirmed) {
        _confirmedMarkerIds.add(item.markerId);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '받은 포스트 확인',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // 캐러셀
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isConfirmed = _confirmedMarkerIds.contains(item.markerId);
                  
                  return _buildCarouselPage(item, isConfirmed);
                },
              ),
            ),
            
            // 페이지 인디케이터
            if (widget.items.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.items.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pageController.hasClients && 
                               _pageController.page?.round() == index
                            ? Colors.blue
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black,
                      ),
                      child: Text('나중에 확인하기'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmedMarkerIds.length == widget.items.length
                          ? () => Navigator.of(context).pop()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('모두 확인 완료'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselPage(ReceiptItem item, bool isConfirmed) {
    return GestureDetector(
      onTap: () => _confirmPost(item.markerId),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Stack(
          children: [
            // 포스트 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  );
                },
              ),
            ),
            
            // 오버레이
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            
            // 상태 배지
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmed ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConfirmed ? '미션달성' : '미션 중',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            
            // 터치 안내
            if (!isConfirmed)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '터치하여 확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPost(String markerId) async {
    if (_confirmedMarkerIds.contains(markerId)) return;

    try {
      await widget.onConfirmTap(markerId);
      setState(() {
        _confirmedMarkerIds.add(markerId);
      });
    } catch (e) {
      print('마커 확인 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 확인에 실패했습니다: $e')),
      );
    }
  }
}
