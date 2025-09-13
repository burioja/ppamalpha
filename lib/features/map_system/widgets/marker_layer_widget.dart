import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/post/post_model.dart';

/// 마커 데이터 클래스
class MarkerData {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl;
  final int remainingAmount;
  final DateTime? expiryDate;
  final bool isUserMarker;

  MarkerData({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
    this.imageUrl,
    required this.remainingAmount,
    this.expiryDate,
    this.isUserMarker = false,
  });
}

/// 마커 레이어 위젯
class MarkerLayerWidget extends StatelessWidget {
  final List<MarkerData> markers;
  final List<MarkerData> userMarkers;
  final Function(MarkerData)? onMarkerTap;
  final Function(MarkerData)? onUserMarkerTap;
  final bool showUserMarkers;
  final bool showPostMarkers;

  const MarkerLayerWidget({
    super.key,
    this.markers = const [],
    this.userMarkers = const [],
    this.onMarkerTap,
    this.onUserMarkerTap,
    this.showUserMarkers = true,
    this.showPostMarkers = true,
  });

  @override
  Widget build(BuildContext context) {
    final allMarkers = <Marker>[];

    // 포스트 마커들 추가
    if (showPostMarkers) {
      for (final markerData in markers) {
        allMarkers.add(_buildPostMarker(markerData));
      }
    }

    // 사용자 마커들 추가
    if (showUserMarkers) {
      for (final userMarkerData in userMarkers) {
        allMarkers.add(_buildUserMarker(userMarkerData));
      }
    }

    if (allMarkers.isEmpty) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(markers: allMarkers);
  }

  /// 포스트 마커 생성
  Marker _buildPostMarker(MarkerData markerData) {
    return Marker(
      point: markerData.position,
      width: 120,
      height: 60,
      child: GestureDetector(
        onTap: () => onMarkerTap?.call(markerData),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                markerData.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    markerData.price,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    '잔여: ${markerData.remainingAmount}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
              if (markerData.expiryDate != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatExpiryDate(markerData.expiryDate!),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 7,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 사용자 마커 생성
  Marker _buildUserMarker(MarkerData userMarkerData) {
    return Marker(
      point: userMarkerData.position,
      width: 100,
      height: 50,
      child: GestureDetector(
        onTap: () => onUserMarkerTap?.call(userMarkerData),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_pin_circle,
                color: Colors.purple,
                size: 16,
              ),
              Text(
                userMarkerData.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  color: Colors.purple,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 만료일 포맷팅
  String _formatExpiryDate(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}일 남음';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 남음';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 남음';
    } else {
      return '만료됨';
    }
  }
}

/// 현재 위치 마커 위젯
class CurrentLocationMarker extends StatelessWidget {
  final LatLng position;
  final double accuracy;
  final bool showAccuracyCircle;

  const CurrentLocationMarker({
    super.key,
    required this.position,
    this.accuracy = 0,
    this.showAccuracyCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        Marker(
          point: position,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 임시 마커 위젯 (롱프레스 시 표시)
class TemporaryMarker extends StatelessWidget {
  final LatLng? position;
  final VoidCallback? onTap;

  const TemporaryMarker({
    super.key,
    this.position,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return const SizedBox.shrink();
    }

    return MarkerLayer(
      markers: [
        Marker(
          point: position!,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}