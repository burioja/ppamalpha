import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/marker_service.dart';
// OSM 기반 Fog of War 시스템
import '../../services/osm_fog_service.dart';
import '../../services/nominatim_service.dart';
import '../../services/location_service.dart';

/// 마커 아이템 클래스
class MarkerItem {
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

  MarkerItem({
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
  });
}

class MapScreen extends StatefulWidget {
  final Function(String)? onAddressChanged;
  
  const MapScreen({super.key, this.onAddressChanged});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OSM 기반 Fog of War 상태
  List<Polygon> _fogPolygons = [];
  List<CircleMarker> _ringCircles = [];
  List<Marker> _currentMarkers = [];
  List<Marker> _userMarkers = [];
  
  // 기본 상태
  MapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 15.0;
  String _currentAddress = '위치 불러오는 중...';
  LatLng? _longPressedLatLng;
  Widget? _customMarkerIcon;
  
  // 포스트 관련
  List<PostModel> _posts = [];
  List<MarkerData> _markers = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // 필터 관련
  bool _showFilter = false;
  String _selectedCategory = 'all';
  double _maxDistance = 1000.0;
  int _minReward = 0;
  
  // 클러스터링 관련
  List<Marker> _clusteredMarkers = [];
  bool _isClustered = false;
  static const double _clusterRadius = 50.0; // 픽셀 단위

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocation();
    _loadCustomMarker();
    _loadPosts();
    _loadMarkers();
  }

  void _loadCustomMarker() {
    _customMarkerIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/ppam_work.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Future<void> _initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = '위치 권한이 거부되었습니다.';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
        });
        return;
      }
      
      await _getCurrentLocation();
    } catch (e) {
        setState(() {
        _errorMessage = '위치를 가져오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
        setState(() {
        _currentPosition = newPosition;
        _errorMessage = null;
      });

      // OSM Fog of War 재구성
      _rebuildFog(newPosition);
      
      // 주소 업데이트
      _updateCurrentAddress();
      
      // 포스트 및 마커 로드
      _loadPosts();
      _loadMarkers();
      
      // 현재 위치 마커 생성
      _createCurrentLocationMarker(newPosition);
      
      // 지도 중심 이동
      _mapController?.move(newPosition, _currentZoom);
      
    } catch (e) {
    setState(() {
        _errorMessage = '현재 위치를 가져올 수 없습니다: $e';
      });
    }
  }

  void _createCurrentLocationMarker(LatLng position) {
    final marker = Marker(
      point: position,
      width: 30,
      height: 30,
      child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
          Icons.my_location,
            color: Colors.white,
          size: 16,
        ),
      ),
    );
        
    setState(() {
      _currentMarkers = [marker];
    });
  }

  void _rebuildFog(LatLng currentPosition) {
    final fogPolygon = OSMFogService.createFogPolygon(currentPosition);
    final ringCircle = OSMFogService.createRingCircle(currentPosition);
        
    setState(() {
      _fogPolygons = [fogPolygon];
      _ringCircles = [ringCircle];
    });
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentPosition == null) return;
    
    try {
      final address = await NominatimService.reverseGeocode(_currentPosition!);
        setState(() {
        _currentAddress = address;
      });

      // 상위 위젯에 주소 전달
      widget.onAddressChanged?.call(address);
    } catch (e) {
    setState(() {
        _currentAddress = '주소 변환 실패';
      });
    }
  }

  Future<void> _loadPosts() async {
    if (_currentPosition == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await PostService().getFlyersNearLocation(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
        );
    
    setState(() {
        _posts = posts;
        _isLoading = false;
      });
      
      _updateMarkers();
    } catch (e) {
    setState(() {
        _errorMessage = '포스트를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMarkers() async {
    if (_currentPosition == null) return;

    try {
      final markers = await MarkerService.getMarkersInRadius(
        center: _currentPosition!,
        radiusInKm: _maxDistance / 1000.0,
      );
    
    setState(() {
        _markers = markers;
      });
      
      _updateMarkers();
    } catch (e) {
      print('마커 로드 중 오류: $e');
    }
  }

  void _updateMarkers() {
    final markers = <Marker>[];
    
    // 포스트 마커들 (파란색) - 모든 사용자에게 보임
    for (final post in _posts) {
      if (post.isActive && !post.isCollected && !post.isExpired()) {
        final position = LatLng(post.location.latitude, post.location.longitude);
        
        // 거리 확인
        if (_currentPosition != null) {
          final distance = _calculateDistance(_currentPosition!, position);
          if (distance > _maxDistance) continue;
        }
        
        // 필터 조건 확인
        if (!_matchesFilter(post)) continue;
        
        final marker = Marker(
      point: position,
          width: 40,
          height: 40,
      child: GestureDetector(
            onTap: () => _showPostDetail(post),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ppam_work.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
        
        markers.add(marker);
      }
    }

    // 사용자 마커들 (ppam_work 이미지) - 모든 사용자에게 보임
    for (final marker in _markers) {
      final position = marker.position;
      
      // 거리 확인
      if (_currentPosition != null) {
        final distance = _calculateDistance(_currentPosition!, position);
        if (distance > _maxDistance) continue;
      }
      
      final markerWidget = Marker(
      point: position,
        width: 35,
        height: 35,
      child: GestureDetector(
          onTap: () => _showMarkerDetail(marker),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ppam_work.png',
                width: 31,
                height: 31,
                fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
      
      markers.add(markerWidget);
    }

    setState(() {
      _userMarkers = markers;
    });
  }

  void _showMarkerDetail(MarkerData marker) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = marker.userId == currentUserId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marker.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('설명: ${marker.description}'),
            Text('생성일: ${marker.createdAt.toString().split(' ')[0]}'),
            if (marker.expiryDate != null)
              Text('만료일: ${marker.expiryDate!.toString().split(' ')[0]}'),
            if (isOwner) 
              Text('배포자: 본인', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          if (isOwner)
                TextButton(
                  onPressed: () {
                Navigator.pop(context);
                _deleteMarker(marker);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMarker(MarkerData marker) async {
    try {
      await MarkerService.deleteMarker(marker.id);
      _loadMarkers(); // 마커 목록 새로고침
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커가 삭제되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  bool _matchesFilter(PostModel post) {
    // 카테고리 필터 (현재는 모든 포스트 허용)
    if (_selectedCategory != 'all') {
      // 카테고리 필터링 로직 구현
    }
    
    // 리워드 필터
    if (post.reward < _minReward) return false;
    
    return true;
  }

  Future<void> _collectPost(PostModel post) async {
    try {
      await PostService().collectPost(
        postId: post.flyerId, 
        userId: FirebaseAuth.instance.currentUser!.uid
      );
      _loadPosts(); // 포스트 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 수집했습니다!')),
          );
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 수집 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _removePost(PostModel post) async {
    try {
      await PostService().deletePost(post.flyerId);
      _loadPosts(); // 포스트 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 회수했습니다!')),
          );
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
      );
    }
  }

    void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '필터 설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 필터 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 일반/쿠폰 토글
                    Row(
                      children: [
                        const Text('포스트 타입:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
          child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'all'),
            child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                                      color: _selectedCategory == 'all' ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '전체',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'coupon'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedCategory == 'coupon' ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '쿠폰만',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                color: Colors.white,
                                        fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 거리 슬라이더
                    Row(
                      children: [
                        const Text('거리:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text('${_maxDistance.toInt()}m', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Slider(
                                value: _maxDistance,
                                min: 100,
                                max: 5000,
                                divisions: 49,
                                onChanged: (value) {
        setState(() {
                                    _maxDistance = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 리워드 슬라이더
                    Row(
                      children: [
                        const Text('최소 리워드:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text('${_minReward}원', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Slider(
                                value: _minReward.toDouble(),
                                min: 0,
                                max: 10000,
                                divisions: 100,
                                onChanged: (value) {
    setState(() {
                                    _minReward = value.toInt();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 정렬 옵션
                    Row(
            children: [
                        const Text('정렬:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '가까운순',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '최신순',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
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
            ),
            // 하단 버튼들
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
              onPressed: () {
                        Navigator.pop(context);
                        _resetFilters();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
              onPressed: () {
                        Navigator.pop(context);
                        _updateMarkers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('적용'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

      void _showMarkerInstallDialog() {
    if (_longPressedLatLng == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '이 위치에 뿌리기',
              style: TextStyle(
                  fontSize: 20,
                fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 설명
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '수수료: 무료\n반경: 1km\n타겟팅: 설정 가능',
              style: TextStyle(
                fontSize: 14,
                  color: Colors.grey[600],
              ),
              ),
            ),
            const SizedBox(height: 20),
            // 버튼들
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 이 위치에 뿌리기 버튼
            SizedBox(
              width: double.infinity,
                    height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                        Navigator.pop(context);
                        _navigateToPostPlace();
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('이 위치에 뿌리기'),
                style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
                  // 이 주소에 뿌리기 버튼
            SizedBox(
              width: double.infinity,
                    height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                        Navigator.pop(context);
                        _navigateToPostAddress();
                      },
                      icon: const Icon(Icons.home),
                      label: const Text('이 주소에 뿌리기'),
                style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
                  // 특정 업종에 뿌리기 버튼
            SizedBox(
              width: double.infinity,
                    height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                        Navigator.pop(context);
                        _navigateToPostBusiness();
                      },
                      icon: const Icon(Icons.business),
                      label: const Text('특정 업종에 뿌리기'),
                style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
                  // 마커 생성 버튼
            SizedBox(
              width: double.infinity,
                    height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                        Navigator.pop(context);
                        _showCreateMarkerDialog();
                      },
                      icon: const Icon(Icons.add_location),
                      label: const Text('마커 생성'),
                style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
                  const SizedBox(height: 12),
                  // 취소 버튼
            SizedBox(
              width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                onPressed: () {
                        Navigator.pop(context);
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _resetFilters() {
    setState(() {
      _selectedCategory = 'all';
      _maxDistance = 1000.0;
      _minReward = 0;
    });
    _updateMarkers();
  }

  void _navigateToPostPlace() {
    // 위치 기반 포스트 배포 화면으로 이동
    Navigator.pushNamed(context, '/post-deploy', arguments: {
      'location': _longPressedLatLng,
      'type': 'location',
    });
  }

  void _navigateToPostAddress() {
    // 주소 기반 포스트 배포 화면으로 이동
    Navigator.pushNamed(context, '/post-deploy', arguments: {
        'location': _longPressedLatLng,
        'type': 'address',
    });
  }

  void _navigateToPostBusiness() {
    // 업종 기반 포스트 배포 화면으로 이동
    Navigator.pushNamed(context, '/post-deploy', arguments: {
        'location': _longPressedLatLng,
        'type': 'category',
    });
  }

  void _showCreateMarkerDialog() {
    if (_longPressedLatLng == null) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마커 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
          TextButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('제목을 입력해주세요.')),
                );
                return;
              }

              try {
                await MarkerService.createMarker(
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  position: _longPressedLatLng!,
                  additionalData: {
                    'type': 'user_marker',
                    'createdAt': DateTime.now().toIso8601String(),
                  },
                  expiryDate: DateTime.now().add(const Duration(days: 30)),
                );

                Navigator.pop(context);
                _loadMarkers(); // 마커 목록 새로고침
      ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('마커가 생성되었습니다!')),
      );
              } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('마커 생성 중 오류가 발생했습니다: $e')),
                );
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  void _onMapReady() {
    // 현재 위치로 지도 이동
    if (_currentPosition != null) {
      _mapController?.move(_currentPosition!, _currentZoom);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(_degreesToRadians(point1.latitude)) * sin(_degreesToRadians(point2.latitude)) * 
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onSecondaryTapDown: (TapDownDetails details) {
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              final mapWidth = renderBox.size.width;
              final mapHeight = renderBox.size.height;
              final latRatio = localPosition.dy / mapHeight;
              final lngRatio = localPosition.dx / mapWidth;
              final lat = _currentPosition!.latitude + (0.01 * (0.5 - latRatio));
              final lng = _currentPosition!.longitude + (0.01 * (lngRatio - 0.5));
              setState(() {
                _longPressedLatLng = LatLng(lat, lng);
              });
            },
            child: FlutterMap(
              mapController: _mapController,
        options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(37.5665, 126.9780), // 서울 기본값
                initialZoom: _currentZoom,
          onMapReady: _onMapReady,
                onTap: (tapPosition, point) {
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                onLongPress: (tapPosition, point) {
                  setState(() {
                    _longPressedLatLng = point;
                  });
                  // 롱프레스 시 즉시 마커 설치 다이얼로그 표시
                  _showMarkerInstallDialog();
          },
        ),
        children: [
                // OSM 기본 타일
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.ppamalpha.app',
                ),
                // Fog of War 마스크 (전세계 검정 + 1km 원형 홀)
                PolygonLayer(polygons: _fogPolygons),
                // 1km 경계선
                CircleLayer(circles: _ringCircles),
                // 현재 위치 마커
                MarkerLayer(markers: _currentMarkers),
                // 사용자 마커
                MarkerLayer(markers: _userMarkers),
                // 롱프레스 마커
              if (_longPressedLatLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _longPressedLatLng!,
                  width: 40,
                  height: 40,
                        child: _customMarkerIcon ??
                            const Icon(
                              Icons.add_location,
                      color: Colors.blue,
                              size: 40,
                  ),
                        ),
                      ],
                    ),
                      ],
                    ),
          ),
          // 에러 메시지
          if (_errorMessage != null)
           Positioned(
              top: 50,
              left: 16,
              right: 16,
             child: Container(
                padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          // 로딩 인디케이터
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // 필터 버튼 (우상단)
          Positioned(
            top: 60,
            right: 16,
             child: Container(
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
                onPressed: _showFilterDialog,
                icon: const Icon(Icons.tune, color: Colors.blue),
                iconSize: 24,
                    ),
                  ),
                ),
          // 현위치 버튼 (우하단)
           Positioned(
            bottom: 80,
            right: 16,
             child: Container(
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
              onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.move(_currentPosition!, _currentZoom);
                  }
                },
                icon: const Icon(Icons.my_location, color: Colors.blue),
                iconSize: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 