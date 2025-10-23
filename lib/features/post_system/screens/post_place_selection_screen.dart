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
          _error = '배포자를 불러오는데 실패했습니다: $e';
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
          padding: const EdgeInsets.all(50),
          maxZoom: 17.0,
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
<<<<<<< HEAD
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isSelected 
                ? Colors.blue.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: Colors.blue[600]!, width: 3)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _onPlaceTap(place),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [Colors.blue[50]!, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Place Image with enhanced styling
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[100]!, Colors.blue[200]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(Icons.work, size: 40, color: Colors.blue),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Place Info with enhanced styling
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Category Icon with background
                          if (place.category != null && place.category!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getCategoryIcon(place.category),
                                size: 16,
                                color: Colors.blue[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          // Place Name with enhanced styling
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    place.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.blue[800] : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // 인증 뱃지 with enhanced styling
                                if (place.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.verified, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          '인증',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // 삭제 버튼 with enhanced styling
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              onPressed: () => _deletePlace(place),
                              tooltip: '배포자 삭제',
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Address with enhanced styling
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                place.address ?? '주소 없음',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Status indicators with enhanced styling
                      Row(
                        children: [
                          // 활성 상태
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: place.isActive ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: place.isActive ? Colors.green[300]! : Colors.red[300]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  place.isActive ? Icons.check_circle : Icons.cancel,
                                  size: 14,
                                  color: place.isActive ? Colors.green[600] : Colors.red[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  place.isActive ? '활성' : '비활성',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: place.isActive ? Colors.green[700] : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 인증 상태 (중복이지만 더 눈에 띄게)
                          if (place.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[400]!, Colors.blue[600]!],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    '인증됨',
                                    style: TextStyle(
                                      fontSize: 12,
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
                // Arrow Icon with enhanced styling
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: isSelected ? Colors.blue[600] : Colors.grey[400],
                    size: 20,
                  ),
                ),
              ],
            ),
=======
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
>>>>>>> 8df3eab (배포자 선택 화면 디자인 개선 - 이미지 디자인에 맞게 수정)
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
            '위치 정보가 있는 배포자가 없습니다',
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
              initialZoom: 10.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // 회전만 비활성화
              ),
              onMapReady: () {
                // Auto-fit to bounds when map is ready - 모든 배포자가 한눈에 보이도록
                if (_mapController != null) {
                  _mapController!.fitCamera(
                    CameraFit.bounds(
                      bounds: bounds,
                      padding: const EdgeInsets.all(50), // 적절한 패딩
                      maxZoom: 17.0, // 최대 줌 레벨 확대
                    ),
                  );
                }
              },
            ),
            children: [
              // OSM 기반 CartoDB Voyager 타일 (라벨 없음)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.ppamalpha.app',
              ),
              MarkerLayer(
                markers: placesWithLocations.map((place) {
                  return Marker(
                    point: LatLng(
                      place.location!.latitude,
                      place.location!.longitude,
                    ),
                    width: 50,
                    height: 50,
                    child: Stack(
                      clipBehavior: Clip.none,
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
                          left: 58,
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
        title: const Text('배포자 선택'),
<<<<<<< HEAD
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
=======
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
>>>>>>> 8df3eab (배포자 선택 화면 디자인 개선 - 이미지 디자인에 맞게 수정)
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
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.work_outline, 
                              size: 64, 
                              color: Colors.blue[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '등록된 배포자가 없습니다',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '새로운 배포자를 만들어 포스트를 배포해보세요',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _navigateToCreatePlace,
                            icon: const Icon(Icons.add),
                            label: const Text('배포자 만들기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
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
              label: const Text('배포자 추가'),
<<<<<<< HEAD
              backgroundColor: Colors.blue[600],
=======
              backgroundColor: Colors.purple[600],
>>>>>>> 8df3eab (배포자 선택 화면 디자인 개선 - 이미지 디자인에 맞게 수정)
              foregroundColor: Colors.white,
              elevation: 6,
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

