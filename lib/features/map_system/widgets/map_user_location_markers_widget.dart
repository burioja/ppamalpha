import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// 사용자 위치 마커 (집/일터) 위젯
class MapUserLocationMarkersWidget extends StatelessWidget {
  final LatLng? homeLocation;
  final List<LatLng> workLocations;

  const MapUserLocationMarkersWidget({
    super.key,
    this.homeLocation,
    required this.workLocations,
  });

  @override
  Widget build(BuildContext context) {
    return MarkerLayer(
      markers: [
        // 집 위치 마커
        if (homeLocation != null)
          Marker(
            point: homeLocation!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.home,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        // 일터 위치 마커들
        ...workLocations.map((workLocation) => Marker(
          point: workLocation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.work,
              color: Colors.white,
              size: 20,
            ),
          ),
        )),
      ],
    );
  }
}

