import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/network_image_fallback_with_data.dart';
import 'dart:math' as math;

class MyPlacesScreen extends StatefulWidget {
  const MyPlacesScreen({super.key});

  @override
  State<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

class _MyPlacesScreenState extends State<MyPlacesScreen> {
  final PlaceService _placeService = PlaceService();
  final FirebaseService _firebaseService = FirebaseService();
  MapController? _mapController;

  List<PlaceModel> _myPlaces = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedPlaceId; // 선택된 플레이스 ID 추적
  LatLngBounds? _initialBounds; // 초기 지도 bounds
  LatLng? _currentPosition; // 현재 위치

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _loadMyPlaces();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      print('현재 위치 가져오기 실패: $e');
      // 실패 시 서울 기본값 사용
      if (mounted) {
        setState(() {
          _currentPosition = const LatLng(37.5665, 126.9780);
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMyPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _firebaseService.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      final places = await _placeService.getPlacesByUser(userId);

      if (mounted) {
        setState(() {
          _myPlaces = places;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '플레이스를 불러오는데 실패했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToPlaceDetail(PlaceModel place) {
    Navigator.pushNamed(
      context,
      AppRoutes.placeDetail,
      arguments: place.id,
    ).then((_) => _loadMyPlaces()); // Refresh on return
  }

  void _zoomToPlace(PlaceModel place) {
    if (_mapController != null && place.location != null) {
      _mapController!.move(
        LatLng(place.location!.latitude, place.location!.longitude),
        16.0, // 줌 레벨 16 (건물 수준에서 주변 맥락 확인 가능)
      );
    }
  }

  void _onPlaceTap(PlaceModel place) {
    if (_selectedPlaceId == place.id) {
      // 두번째 클릭 - 상세 페이지로 이동
      _navigateToPlaceDetail(place);
    } else {
      // 첫번째 클릭 - 선택 + 지도 줌인
      setState(() {
        _selectedPlaceId = place.id;
      });
      _zoomToPlace(place);
    }
  }

  void _resetMapToInitial() {
    if (_mapController != null && _initialBounds != null) {
      setState(() {
        _selectedPlaceId = null; // 선택 해제
      });
      _mapController!.fitCamera(
        CameraFit.bounds(
          bounds: _initialBounds!,
          padding: const EdgeInsets.all(80),
          maxZoom: 15.0,
        ),
      );
    }
  }

  void _navigateToCreatePlace() {
    Navigator.pushNamed(
      context,
      AppRoutes.createPlace,
    ).then((_) => _loadMyPlaces()); // Refresh on return
  }

  IconData _getCategoryIcon(String? category) {
    // 모든 플레이스 아이콘을 가방 아이콘으로 통일
    return Icons.work;
  }

  Future<void> _deletePlace(PlaceModel place) async {
    // 확인 다이얼로그 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('플레이스 삭제'),
        content: Text('${place.name}을(를) 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _placeService.deletePlace(place.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${place.name}이(가) 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyPlaces(); // 목록 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPlaceCard(PlaceModel place) {
    final isSelected = _selectedPlaceId == place.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isSelected ? 8 : 2, // 선택시 그림자 강조
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
          ? BorderSide(color: Colors.blue[700]!, width: 3) // 선택시 파란 테두리
          : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _onPlaceTap(place),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Place Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: place.imageUrls.isNotEmpty
                      ? buildNetworkImage(
                          place.thumbnailUrls.isNotEmpty
                              ? place.thumbnailUrls.first
                              : place.imageUrls.first,
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.work, size: 40, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              // Place Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Category Icon
                        if (place.category != null && place.category!.isNotEmpty) ...[
                          Icon(
                            _getCategoryIcon(place.category),
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Place Name
                        Expanded(
                          child: Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 삭제 버튼
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red[400],
                          onPressed: () => _deletePlace(place),
                          tooltip: '플레이스 삭제',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.address ?? '주소 없음',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // 활성 상태
                        Icon(
                          place.isActive ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: place.isActive ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.isActive ? '활성' : '비활성',
                          style: TextStyle(
                            fontSize: 12,
                            color: place.isActive ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 인증 상태
                        if (place.isVerified)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.verified, size: 12, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  '인증',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    // Get places with valid locations
    final placesWithLocations = _myPlaces
        .where((place) => place.location != null)
        .toList();

    // 화면 높이의 40% (2/5)
    final mapHeight = MediaQuery.of(context).size.height * 0.4;

    if (placesWithLocations.isEmpty) {
      return Container(
        height: mapHeight,
        color: Colors.grey[200],
        child: Center(
          child: Text(
            '위치 정보가 있는 플레이스가 없습니다',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    // Calculate bounds to fit all places
    double minLat = placesWithLocations
        .map((p) => p.location!.latitude)
        .reduce((a, b) => math.min(a, b));
    double maxLat = placesWithLocations
        .map((p) => p.location!.latitude)
        .reduce((a, b) => math.max(a, b));
    double minLng = placesWithLocations
        .map((p) => p.location!.longitude)
        .reduce((a, b) => math.min(a, b));
    double maxLng = placesWithLocations
        .map((p) => p.location!.longitude)
        .reduce((a, b) => math.max(a, b));

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    // 초기 상태 저장 (처음 한번만)
    _initialBounds ??= bounds;

    // 초기 중심점: 현재 위치 우선, 없으면 플레이스 중심
    final center = _currentPosition ?? LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    return SizedBox(
      height: mapHeight, // 화면 높이의 40%
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14.0,  // 시작 줌 레벨
              minZoom: 10.0,      // 최소 줌 레벨 (줌 아웃 한계)
              maxZoom: 17.0,      // 최대 줌 레벨 (줌 인 한계)
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // 회전만 비활성화
              ),
              onMapReady: () {
                // Auto-fit to bounds when map is ready
                if (_mapController != null) {
                  _mapController!.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(80), // 패딩 증가 (50 → 80)
                      maxZoom: 17.0, // 최대 줌 제한 (메인 맵스크린과 동일)
                    ),
                  );
                }
              },
            ),
            children: [
          // OSM 기반 CartoDB Voyager 타일 (라벨 없음) - 메인 맵스크린과 동일
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.ppamalpha.app',
            minZoom: 10.0,  // 타일 서버 최소 줌
            maxZoom: 17.0,  // 타일 서버 최대 줌
          ),
          MarkerLayer(
            markers: placesWithLocations.map((place) {
              return Marker(
                point: LatLng(
                  place.location!.latitude,
                  place.location!.longitude,
                ),
                width: 50, // 아이콘 크기만큼 (위치 고정)
                height: 50,
                child: Stack(
                  clipBehavior: Clip.none, // 레이블이 밖으로 나갈 수 있게
                  children: [
                    // 중앙: 마커 아이콘 (GPS 좌표의 정확한 위치)
                    Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue[700]!,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _getCategoryIcon(place.category),
                          color: Colors.blue[700],
                          size: 28,
                        ),
                      ),
                    ),
                    // 오른쪽: 플레이스 이름 레이블
                    Positioned(
                      left: 58, // 아이콘(50) + 여백(8)
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.blue[700]!,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            place.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
            ],
          ),
          // 초기 화면으로 버튼 (우측 상단)
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[700],
              elevation: 4,
              onPressed: _resetMapToInitial,
              child: const Icon(Icons.refresh, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('내 플레이스'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadMyPlaces,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _myPlaces.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '등록된 플레이스가 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreatePlace,
                            icon: const Icon(Icons.add),
                            label: const Text('플레이스 만들기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Top Map Widget - Fixed (does not scroll)
                        _buildMapWidget(),
                        const SizedBox(height: 8),
                        // Place List - Scrollable
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadMyPlaces,
                            child: ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '총 ${_myPlaces.length}개의 플레이스',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: _navigateToCreatePlace,
                                        icon: const Icon(Icons.add),
                                        label: const Text('새 플레이스'),
                                      ),
                                    ],
                                  ),
                                ),
                                ..._myPlaces.map((place) => _buildPlaceCard(place)),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: _myPlaces.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreatePlace,
              icon: const Icon(Icons.add),
              label: const Text('플레이스 추가'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
