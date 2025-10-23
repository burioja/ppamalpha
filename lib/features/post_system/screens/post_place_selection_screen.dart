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
        });
        return;
      }

      final places = await _placeService.getPlacesByUser(currentUser.uid);
      setState(() {
        _userPlaces = places;
        _isLoading = false;
      });

      // 지도 bounds 설정
      if (places.isNotEmpty) {
        _initialBounds = _calculateBounds(places);
        // 지도가 렌더링된 후에 bounds를 적용하므로 여기서는 설정만 함
      }
    } catch (e) {
      setState(() {
        _error = '배포자 목록을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  LatLngBounds _calculateBounds(List<PlaceModel> places) {
    if (places.isEmpty) {
      return LatLngBounds(
        LatLng(37.5665, 126.9780), // 서울 기본 위치
        LatLng(37.5665, 126.9780),
      );
    }

    // 위치 정보가 있는 플레이스만 필터링
    final placesWithLocation = places.where((place) => place.location != null).toList();
    
    if (placesWithLocation.isEmpty) {
      return LatLngBounds(
        LatLng(37.5665, 126.9780), // 서울 기본 위치
        LatLng(37.5665, 126.9780),
      );
    }

    double minLat = placesWithLocation.first.location!.latitude;
    double maxLat = placesWithLocation.first.location!.latitude;
    double minLng = placesWithLocation.first.location!.longitude;
    double maxLng = placesWithLocation.first.location!.longitude;

    for (final place in placesWithLocation) {
      minLat = math.min(minLat, place.location!.latitude);
      maxLat = math.max(maxLat, place.location!.latitude);
      minLng = math.min(minLng, place.location!.longitude);
      maxLng = math.max(maxLng, place.location!.longitude);
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  void _fitMapToBounds() {
    if (_mapController != null && _initialBounds != null) {
      // FlutterMap이 렌더링된 후에 실행되도록 지연
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null && _initialBounds != null) {
          _mapController!.fitCamera(
            CameraFit.bounds(
              bounds: _initialBounds!,
              padding: const EdgeInsets.all(50),
              maxZoom: 17.0,
            ),
          );
        }
      });
    }
  }

  void _navigateToCreatePlace() {
    Navigator.pushNamed(context, '/create-place').then((_) => _loadUserPlaces());
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
        title: const Text('배포자 삭제'),
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
        // 선택된 배포자가 삭제되었다면 선택 해제
        if (_selectedPlaceId == place.id) {
          setState(() {
            _selectedPlaceId = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${place.name}이(가) 삭제되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserPlaces(); // 목록 새로고침
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isSelected
            ? Border.all(color: Colors.purple[600]!, width: 2)
            : Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () => _onPlaceTap(place),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Place Image
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.work, size: 40, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              // Place Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (place.isVerified) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '인증',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.red[400]),
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
                        Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          '활성',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (place.isVerified) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.verified, size: 16, color: Colors.blue[600]),
                          const SizedBox(width: 4),
                          Text(
                            '인증',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  IconButton(
                    onPressed: () => _deletePlace(place),
                    icon: Icon(Icons.delete, color: Colors.red[400], size: 20),
                  ),
                  IconButton(
                    onPressed: () => _onPlaceTap(place),
                    icon: Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPlaceTap(PlaceModel place) {
    setState(() {
      _selectedPlaceId = place.id;
    });
    
    // 포스트 생성 화면으로 이동
    _continueToPostCreation(place);
  }

  Widget _buildMapSection() {
    if (_userPlaces.isEmpty) {
      return Container(
        height: 200,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '등록된 배포자가 없습니다',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialBounds?.center ?? const LatLng(37.5665, 126.9780),
            initialZoom: 13.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              // 지도가 준비되면 bounds 적용
              if (_initialBounds != null) {
                _fitMapToBounds();
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.ppamalpha',
            ),
            MarkerLayer(
              markers: _userPlaces.where((place) => place.location != null).map((place) {
                final isSelected = _selectedPlaceId == place.id;
                return Marker(
                  point: LatLng(place.location!.latitude, place.location!.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _onPlaceTap(place),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple[600] : Colors.blue[600],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.work,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('배포자 선택'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _loadUserPlaces,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ),
        ],
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
                            '등록된 배포자가 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreatePlace,
                            icon: const Icon(Icons.add),
                            label: const Text('새 배포자 만들기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[600],
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
                        // 지도 섹션
                        _buildMapSection(),
                        
                        // 배포자 목록 헤더
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '총 ${_userPlaces.length}개의 배포자',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _navigateToCreatePlace,
                                icon: const Icon(Icons.add),
                                label: const Text('새 배포자'),
                              ),
                            ],
                          ),
                        ),
                        
                        // 배포자 목록
                        Expanded(
                          child: ListView(
                            children: [
                              ..._userPlaces.map((place) => _buildPlaceCard(place)),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ],
                    ),
      floatingActionButton: _userPlaces.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreatePlace,
              icon: const Icon(Icons.add),
              label: const Text('배포자 추가'),
              backgroundColor: Colors.purple[600],
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
      final result = await Navigator.pushNamed(
        context,
        '/post-place',
        arguments: {
          'place': place,
          'fromSelection': true,
        },
      );

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }
}