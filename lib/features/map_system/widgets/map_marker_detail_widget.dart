import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../../core/models/marker/marker_model.dart';

/// 마커 상세 정보 위젯
class MapMarkerDetailWidget extends StatefulWidget {
  final MarkerModel marker;
  final LatLng currentPosition;
  final String? currentUserId;
  final VoidCallback onCollect;
  final VoidCallback onRemove;

  const MapMarkerDetailWidget({
    super.key,
    required this.marker,
    required this.currentPosition,
    this.currentUserId,
    required this.onCollect,
    required this.onRemove,
  });

  @override
  State<MapMarkerDetailWidget> createState() => _MapMarkerDetailWidgetState();
}

class _MapMarkerDetailWidgetState extends State<MapMarkerDetailWidget> {
  String imageUrl = '';
  String description = '';
  int reward = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  Future<void> _loadPostData() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.marker.postId)
          .get();

      if (postDoc.exists) {
        final postData = postDoc.data()!;
        final mediaUrls = postData['mediaUrl'] as List<dynamic>?;
        
        setState(() {
          if (mediaUrls != null && mediaUrls.isNotEmpty) {
            imageUrl = mediaUrls.first as String;
          }
          description = postData['description'] as String? ?? '';
          reward = postData['reward'] as int? ?? 0;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('포스트 정보 조회 실패: $e');
      setState(() => isLoading = false);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 미터
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(point1.latitude)) *
        math.cos(_degreesToRadians(point2.latitude)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance(widget.currentPosition, widget.marker.position);
    final isWithinRange = distance <= 200;
    final isOwner = widget.currentUserId != null && 
                    widget.marker.creatorId == widget.currentUserId;

    if (isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 거리가 멀면 스낵바 표시
    if (!isWithinRange) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${distance.toStringAsFixed(0)}m 떨어져 있습니다. 200m 이내로 접근해주세요.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.marker.title.replaceAll(' 관련 포스트', '').replaceAll('관련 포스트', ''),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 설명
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 이미지 (배지 오버레이 포함)
                  if (imageUrl.isNotEmpty)
                    _buildImageWithBadges(isWithinRange, isOwner)
                  else if (description.isEmpty)
                    _buildPlaceholder(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 하단 버튼
          _buildActionButtons(isOwner, isWithinRange),
        ],
      ),
    );
  }

  Widget _buildImageWithBadges(bool isWithinRange, bool isOwner) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ),
        
        // 배지들
        Positioned(
          top: 12,
          left: 12,
          child: Row(
            children: [
              _buildStatusBadge(isWithinRange),
              const SizedBox(width: 8),
              _buildQuantityBadge(),
            ],
          ),
        ),
        
        if (isOwner)
          Positioned(
            top: 12,
            right: 12,
            child: _buildOwnerBadge(),
          ),
        
        if (reward > 0)
          Positioned(
            bottom: 12,
            left: 12,
            child: _buildRewardBadge(),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(bool isWithinRange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isWithinRange ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        isWithinRange ? '수령 가능' : '범위 밖',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQuantityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.marker.quantity > 0 ? Colors.blue : Colors.red,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '${widget.marker.quantity}개 남음',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOwnerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        '내 포스트',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRewardBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '+${reward}포인트',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.card_giftcard,
          size: 64,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isOwner, bool isWithinRange) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('닫기'),
            ),
          ),
          
          if (isOwner) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onRemove();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '회수하기',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else if (isWithinRange && widget.marker.quantity > 0) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onCollect();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '수령하기 (${widget.marker.quantity}개)',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else if (widget.marker.quantity <= 0) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '수량 소진',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 마커 상세 정보를 표시하는 헬퍼 함수
void showMapMarkerDetail({
  required BuildContext context,
  required MarkerModel marker,
  required LatLng currentPosition,
  String? currentUserId,
  required VoidCallback onCollect,
  required VoidCallback onRemove,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MapMarkerDetailWidget(
      marker: marker,
      currentPosition: currentPosition,
      currentUserId: currentUserId,
      onCollect: onCollect,
      onRemove: onRemove,
    ),
  );
}

// Extension methods
extension on double {
  double toRadians() => this * 3.14159265359 / 180;
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}

