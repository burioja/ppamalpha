import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/post/post_model.dart';

/// 지도 메인 디스플레이 위젯
class MapDisplayWidget extends StatelessWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final double currentZoom;
  final List<Marker> currentMarkers;
  final List<Marker> userMarkers;
  final List<CircleMarker> ringCircles;
  final List<Polygon> fogPolygons;
  final List<Polygon> grayPolygons;
  final Function(LatLng)? onLongPress;
  final Function(LatLng)? onTap;
  final Function()? onPositionChanged;

  const MapDisplayWidget({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.currentZoom,
    required this.currentMarkers,
    required this.userMarkers,
    required this.ringCircles,
    required this.fogPolygons,
    required this.grayPolygons,
    this.onLongPress,
    this.onTap,
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: currentPosition ?? const LatLng(37.5665, 126.9780),
        initialZoom: currentZoom,
        minZoom: 10.0,
        maxZoom: 18.0,
        onLongPress: (tapPosition, point) => onLongPress?.call(point),
        onTap: (tapPosition, point) => onTap?.call(point),
        onPositionChanged: (position, hasGesture) => onPositionChanged?.call(),
      ),
      children: [
        // OSM 타일 레이어
        TileLayer(
          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.example.ppam',
        ),

        // 회색 폴리곤 (과거 방문 위치)
        if (grayPolygons.isNotEmpty)
          PolygonLayer(polygons: grayPolygons),

        // 검은 포그 폴리곤 (미방문 영역)
        if (fogPolygons.isNotEmpty)
          PolygonLayer(polygons: fogPolygons),

        // 링 원 레이어
        if (ringCircles.isNotEmpty)
          CircleLayer(circles: ringCircles),

        // 포스트 마커 레이어
        if (currentMarkers.isNotEmpty)
          MarkerLayer(markers: currentMarkers),

        // 사용자 마커 레이어
        if (userMarkers.isNotEmpty)
          MarkerLayer(markers: userMarkers),

        // 현재 위치 표시
        if (currentPosition != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPosition!,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}