import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// 지도 위치 이동 버튼들 (집/일터/현재위치)
class MapLocationButtonsWidget extends StatelessWidget {
  final LatLng? homeLocation;
  final List<LatLng> workLocations;
  final VoidCallback? onMoveToHome;
  final VoidCallback? onMoveToWorkplace;
  final VoidCallback? onMoveToCurrentLocation;

  const MapLocationButtonsWidget({
    super.key,
    this.homeLocation,
    required this.workLocations,
    this.onMoveToHome,
    this.onMoveToWorkplace,
    this.onMoveToCurrentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 16,
      child: Column(
        children: [
          // 집 버튼
          Container(
            margin: const EdgeInsets.only(bottom: 8),
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
            child: IconButton(
              onPressed: homeLocation != null ? onMoveToHome : null,
              icon: Icon(
                Icons.home,
                color: homeLocation != null ? Colors.green : Colors.grey,
              ),
              iconSize: 24,
            ),
          ),
          // 일터 버튼
          Container(
            margin: const EdgeInsets.only(bottom: 8),
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
            child: IconButton(
              onPressed: workLocations.isNotEmpty ? onMoveToWorkplace : null,
              icon: Icon(
                Icons.work,
                color: workLocations.isNotEmpty ? Colors.orange : Colors.grey,
              ),
              iconSize: 24,
            ),
          ),
          // 현재 위치 버튼
          Container(
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
            child: IconButton(
              onPressed: onMoveToCurrentLocation,
              icon: const Icon(Icons.my_location, color: Colors.blue),
              iconSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

