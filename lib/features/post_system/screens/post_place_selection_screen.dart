import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../widgets/network_image_fallback_with_data.dart';
import 'dart:math' as math;

class PostPlaceSelectionScreen extends StatefulWidget {
  const PostPlaceSelectionScreen({super.key});

  @override
  State<PostPlaceSelectionScreen> createState() => _PostPlaceSelectionScreenState();
}

class _PostPlaceSelectionScreenState extends State<PostPlaceSelectionScreen> {
  final _placeService = PlaceService();
  MapController? _mapController;

  List<PlaceModel> _userPlaces = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedPlaceId; // 선택된 플레이스 ID 추적
  LatLngBounds? _initialBounds; // 초기 지도 bounds

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadUserPlaces();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = '로그인이 필요합니다';
          _isLoading = false;
        });
        return;
      }

      final places = await _placeService.getPlacesByUser(currentUser.uid);

      if (mounted) {
        setState(() {
          _userPlaces = places;
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
      // 두번째 클릭 - 포스트 생성 화면으로 이동
      _continueToPostCreation(place);
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
    Navigator.pushNamed(context, '/create-place').then((_) => _loadUserPlaces());
  }

  IconData _getCategoryIcon(String? category) {
    // 모든 플레이스 아이콘을 가방 아이콘으로 통일
    return Icons.work;
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
              // Arrow Icon
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapWidget() {
    // Get places with valid locations
    final placesWithLocations = _userPlaces
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

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // 초기 상태 저장 (처음 한번만)
    _initialBounds ??= bounds;

    return SizedBox(
      height: mapHeight, // 화면 높이의 40%
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.0,
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
                      maxZoom: 15.0, // 최대 줌 제한 (충분한 줌아웃 허용)
                    ),
                  );
                }
              },
            ),
            children: [
              // OSM 타일 레이어
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.ppam',
              ),
              MarkerLayer(
                markers: placesWithLocations.map((place) {
                  return Marker(
                    point: LatLng(
                      place.location!.latitude,
                      place.location!.longitude,
                    ),
                    width: 200, // 마커 + 레이블 공간
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // 마커 아이콘
                        Container(
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
                        const SizedBox(width: 8),
                        // 플레이스 이름 레이블
                        Flexible(
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
                              overflow: TextOverflow.ellipsis,
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
        title: const Text('플레이스 선택'),
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
                        onPressed: _loadUserPlaces,
                        icon: const Icon(Icons.refresh),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _userPlaces.isEmpty
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
                            onRefresh: _loadUserPlaces,
                            child: ListView(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '총 ${_userPlaces.length}개의 플레이스',
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
                                ..._userPlaces.map((place) => _buildPlaceCard(place)),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: _userPlaces.isNotEmpty
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

  // 포스트 생성 화면으로 이동 (my_places_screen.dart의 _navigateToPlaceDetail과 다름)
  void _continueToPostCreation(PlaceModel place) async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final fromPostDeploy = args?['fromPostDeploy'] ?? false;

    if (fromPostDeploy) {
      final result = await Navigator.pushNamed(
        context,
        '/post-place',
        arguments: {
          'place': place,
          'fromSelection': true,
          'fromPostDeploy': true,
        },
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/post-place',
        arguments: {
          'place': place,
          'fromSelection': true,
        },
      );
    }
  }
}
