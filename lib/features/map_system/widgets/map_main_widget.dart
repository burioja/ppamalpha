import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/models/post/post_model.dart';
import '../handlers/map_fog_handler.dart';
import '../handlers/map_marker_handler.dart';
import '../handlers/map_post_handler.dart';
import '../handlers/map_location_handler.dart';
import '../handlers/map_filter_handler.dart';
import '../handlers/map_ui_helper.dart';

/// 메인 지도 위젯
class MapMainWidget extends StatelessWidget {
  final MapController mapController;
  final LatLng? currentPosition;
  final double currentZoom;
  final List<MarkerModel> markers;
  final List<PostModel> posts;
  final bool isLoading;
  final String? errorMessage;
  final bool isPremiumUser;
  final String userType;
  final LatLng? longPressedLatLng;
  final bool isMockModeEnabled;
  final LatLng? mockPosition;
  final bool isMockControllerVisible;
  final List<CircleMarker> ringCircles;
  final List<Polygon> grayPolygons;
  final LatLng? homeLocation;
  final List<LatLng> workLocations;
  final int currentWorkplaceIndex;
  final int receivablePostCount;
  
  // Handler 인스턴스들
  final MapFogHandler fogHandler;
  final MapMarkerHandler markerHandler;
  final MapPostHandler postHandler;
  final MapLocationHandler locationHandler;
  final MapFilterHandler filterHandler;
  
  // 콜백 함수들
  final VoidCallback onMapReady;
  final Function(MapEvent) onMapMoved;
  final Function(TapPosition, LatLng) onTap;
  final Function(TapPosition, LatLng) onLongPress;
  final Function(TapPosition, LatLng) onSecondaryTapDown;
  final VoidCallback onFilterPressed;
  final VoidCallback onHomePressed;
  final VoidCallback onWorkplacePressed;
  final VoidCallback onReceivePressed;
  final VoidCallback onMockToggle;
  final Function(LatLng) onMockPositionSet;
  final Function(String) onMockMove;

  const MapMainWidget({
    super.key,
    required this.mapController,
    required this.currentPosition,
    required this.currentZoom,
    required this.markers,
    required this.posts,
    required this.isLoading,
    this.errorMessage,
    required this.isPremiumUser,
    required this.userType,
    this.longPressedLatLng,
    required this.isMockModeEnabled,
    this.mockPosition,
    required this.isMockControllerVisible,
    required this.ringCircles,
    required this.grayPolygons,
    this.homeLocation,
    required this.workLocations,
    required this.currentWorkplaceIndex,
    required this.receivablePostCount,
    required this.fogHandler,
    required this.markerHandler,
    required this.postHandler,
    required this.locationHandler,
    required this.filterHandler,
    required this.onMapReady,
    required this.onMapMoved,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTapDown,
    required this.onFilterPressed,
    required this.onHomePressed,
    required this.onWorkplacePressed,
    required this.onReceivePressed,
    required this.onMockToggle,
    required this.onMockPositionSet,
    required this.onMockMove,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 메인 지도
          _buildMainMap(context),
          
          // 오버레이들
          _buildOverlays(context),
          
          // 플로팅 액션 버튼들
          _buildFloatingActionButtons(context),
          
          // 로딩/에러 표시
          if (isLoading) _buildLoadingOverlay(),
          if (errorMessage != null) _buildErrorOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainMap(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) => onSecondaryTapDown(
        TapPosition(details.globalPosition, details.localPosition),
        _calculatePositionFromTap(context, details.globalPosition),
      ),
      child: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: currentPosition ?? const LatLng(37.5665, 126.9780),
          initialZoom: currentZoom,
          minZoom: 14.0,
          maxZoom: 17.0,
          onMapReady: onMapReady,
          onMapEvent: onMapMoved,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
        children: [
          // 타일 레이어
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ppamalpha',
          ),
          
          // 포그 오브 워 오버레이
          _buildFogOverlay(),
          
          // 마커 레이어
          _buildMarkerLayer(),
        ],
      ),
    );
  }

  Widget _buildOverlays(BuildContext context) {
    return Stack(
      children: [
        // 롱프레스 위치 표시
        if (longPressedLatLng != null)
          Positioned(
            left: 50,
            bottom: 100,
            child: _buildLongPressIndicator(),
          ),
        
        // Mock 컨트롤러
        if (isMockControllerVisible)
          _buildMockController(context),
      ],
    );
  }

  Widget _buildFloatingActionButtons(BuildContext context) {
    return Stack(
      children: [
        // 필터 버튼 (좌상단)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: _buildFilterButton(),
        ),
        
        // 집 버튼 (우상단)
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: _buildHomeButton(),
        ),
        
        // 일터 버튼 (집 버튼 아래)
        if (workLocations.isNotEmpty)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: _buildWorkplaceButton(),
          ),
        
        // 수령 버튼 (우하단)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 100,
          right: 16,
          child: _buildReceiveButton(),
        ),
        
        // Mock 토글 버튼 (좌하단)
        Positioned(
          bottom: MediaQuery.of(context).padding.bottom + 100,
          left: 16,
          child: _buildMockToggleButton(),
        ),
      ],
    );
  }

  Widget _buildFogOverlay() {
    return PolygonLayer(
      polygons: grayPolygons,
    );
  }

  Widget _buildMarkerLayer() {
    return MarkerLayer(
      markers: markers.map((marker) => Marker(
        point: marker.position,
        child: _buildMarkerWidget(marker),
      )).toList(),
    );
  }

  Widget _buildMarkerWidget(MarkerModel marker) {
    return GestureDetector(
      onTap: () => _onMarkerTap(marker),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildLongPressIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            '선택된 위치: ${longPressedLatLng!.latitude.toStringAsFixed(4)}, ${longPressedLatLng!.longitude.toStringAsFixed(4)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMockController(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mock 위치 컨트롤러', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Mock 위치 표시
            if (mockPosition != null)
              Text('위치: ${mockPosition!.latitude.toStringAsFixed(4)}, ${mockPosition!.longitude.toStringAsFixed(4)}'),
            
            const SizedBox(height: 12),
            
            // 방향 버튼들
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMockMoveButton('북', 'up'),
                _buildMockMoveButton('남', 'down'),
                _buildMockMoveButton('동', 'right'),
                _buildMockMoveButton('서', 'left'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockMoveButton(String label, String direction) {
    return ElevatedButton(
      onPressed: () => onMockMove(direction),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }

  Widget _buildFilterButton() {
    return FloatingActionButton.small(
      onPressed: onFilterPressed,
      backgroundColor: Colors.white,
      child: const Icon(Icons.filter_list, color: Colors.blue),
    );
  }

  Widget _buildHomeButton() {
    return FloatingActionButton.small(
      onPressed: onHomePressed,
      backgroundColor: homeLocation != null ? Colors.green : Colors.grey,
      child: const Icon(Icons.home, color: Colors.white),
    );
  }

  Widget _buildWorkplaceButton() {
    return FloatingActionButton.small(
      onPressed: onWorkplacePressed,
      backgroundColor: workLocations.isNotEmpty ? Colors.orange : Colors.grey,
      child: Text(
        '${currentWorkplaceIndex + 1}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReceiveButton() {
    return FloatingActionButton(
      onPressed: receivablePostCount > 0 ? onReceivePressed : null,
      backgroundColor: receivablePostCount > 0 ? Colors.green : Colors.grey,
      child: Badge(
        label: Text('$receivablePostCount'),
        child: const Icon(Icons.receipt, color: Colors.white),
      ),
    );
  }

  Widget _buildMockToggleButton() {
    return FloatingActionButton.small(
      onPressed: onMockToggle,
      backgroundColor: isMockModeEnabled ? Colors.red : Colors.grey,
      child: const Icon(Icons.location_searching, color: Colors.white),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _onMarkerTap(MarkerModel marker) {
    // 마커 탭 처리 - 부모에서 처리하도록 콜백 사용
  }

  LatLng _calculatePositionFromTap(BuildContext context, Offset globalPosition) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final mapWidth = renderBox.size.width;
    final mapHeight = renderBox.size.height;
    final latRatio = localPosition.dy / mapHeight;
    final lngRatio = localPosition.dx / mapWidth;
    final lat = currentPosition!.latitude + (0.01 * (0.5 - latRatio));
    final lng = currentPosition!.longitude + (0.01 * (lngRatio - 0.5));
    return LatLng(lat, lng);
  }
}
