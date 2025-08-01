import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_place_screen.dart';

/// ✅ 마커 아이템 클래스
class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;

  MarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  final String _googleApiKey = "YOUR_API_KEY"; // 바꿔줘
  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  final Set<Marker> _markers = {};
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // 마커 관련 변수들
  final List<MarkerItem> _markerItems = [];
  double _currentZoom = 15.0;
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
    _loadCustomMarker();
    _loadMarkersFromFirestore();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      print('맵 스타일 로드 오류: $e');
    }
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(37.495872, 127.025046);
      });
    } catch (_) {
      _currentPosition = const LatLng(37.492894, 127.012469);
    }
  }

  Future<void> _loadCustomMarker() async {
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(96, 96)), // 2배 크기로 고정
      'assets/images/ppam_work.png',
    );
    setState(() {
      _customMarkerIcon = icon;
    });
  }

  void goToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15.0));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) controller.setMapStyle(_mapStyle);
  }

  /// ✅ 간단한 클러스터링 함수
  void _updateClustering() {
    print('현재 줌 레벨: $_currentZoom, 마커 개수: ${_markerItems.length}');
    
    if (_currentZoom < 12.0 && _markerItems.length > 1) {
      // 줌이 멀고 마커가 2개 이상이면 클러스터링 적용
      _createClusters();
    } else {
      // 줌이 가까우거나 마커가 1개 이하면 개별 마커 표시
      _showIndividualMarkers();
    }
  }

  /// ✅ 클러스터 생성
  void _createClusters() {
    print('클러스터 생성 시작 - 마커 개수: ${_markerItems.length}');
    
    _clusteredMarkers.clear();
    final clusters = <String, List<MarkerItem>>{};
    
    // 마커들을 그룹화 (더 세밀한 그리드 기반)
    for (final item in _markerItems) {
      // 더 작은 그리드로 분할하여 클러스터링 효과 향상
      final gridKey = '${(item.position.latitude * 1000).round()}_${(item.position.longitude * 1000).round()}';
      clusters.putIfAbsent(gridKey, () => []).add(item);
    }
    
    print('생성된 클러스터 개수: ${clusters.length}');
    
    // 클러스터 마커 생성
    for (final cluster in clusters.values) {
      if (cluster.length == 1) {
        // 단일 마커는 그대로 표시
        final item = cluster.first;
        _clusteredMarkers.add(_createMarker(item));
      } else {
        // 여러 마커는 클러스터로 표시
        final center = _calculateClusterCenter(cluster);
        _clusteredMarkers.add(_createClusterMarker(center, cluster.length));
        print('클러스터 생성: ${cluster.length}개 마커');
      }
    }
    
    setState(() {
      _isClustered = true;
    });
    
    print('클러스터링 완료 - 표시될 마커 개수: ${_clusteredMarkers.length}');
  }

  /// ✅ 개별 마커 표시
  void _showIndividualMarkers() {
    print('개별 마커 표시 - 마커 개수: ${_markerItems.length}');
    
    _clusteredMarkers.clear();
    for (final item in _markerItems) {
      _clusteredMarkers.add(_createMarker(item));
    }
    
    setState(() {
      _isClustered = false;
    });
    
    print('개별 마커 표시 완료 - 표시될 마커 개수: ${_clusteredMarkers.length}');
  }

  /// ✅ 클러스터 중심점 계산
  LatLng _calculateClusterCenter(List<MarkerItem> cluster) {
    double totalLat = 0;
    double totalLng = 0;
    
    for (final item in cluster) {
      totalLat += item.position.latitude;
      totalLng += item.position.longitude;
    }
    
    return LatLng(totalLat / cluster.length, totalLng / cluster.length);
  }

  /// ✅ 마커 생성
  Marker _createMarker(MarkerItem item) {
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: item.title,
        snippet: 'Price: ${item.price}원, Amount: ${item.amount}개',
      ),
      onTap: () {
        if (item.userId == userId) {
          _showMarkerActionMenu(item.id, item.data);
        } else {
          _showMarkerInfo(item.data);
        }
      },
    );
  }

  /// ✅ 클러스터 마커 생성
  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
      ),
      onTap: () {
        // 클러스터 탭시 줌 인
        mapController.animateCamera(CameraUpdate.zoomIn());
      },
    );
  }

  /// ✅ Firestore에서 마커 불러오기
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    print('Firestore에서 ${docs.length}개의 마커 데이터 로드');

    _markerItems.clear();
    _markers.clear();
    _clusteredMarkers.clear();
    
    for (var doc in docs) {
      final data = doc.data();
      final LatLng pos = LatLng(data['lat'], data['lng']);
      
      final markerItem = MarkerItem(
        id: doc.id,
        title: data['title'] ?? 'PPAM Marker',
        price: data['price']?.toString() ?? '0',
        amount: data['amount']?.toString() ?? '0',
        userId: data['userId'] ?? '',
        data: data,
        position: pos,
      );
      
      _markerItems.add(markerItem);
    }
    
    print('마커 아이템 생성 완료: ${_markerItems.length}개');
    
    // 클러스터링 적용
    _updateClustering();
  }

  /// ✅ Firestore에 마커 저장
  Future<void> _addMarkerToFirestore(LatLng position, Map<String, dynamic> result) async {
    if (userId == null) return;
    final doc = await FirebaseFirestore.instance.collection('markers').add({
      'lat': position.latitude,
      'lng': position.longitude,
      'title': 'PPAM Marker',
      'price': result['price'],
      'amount': result['amount'],
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final markerData = {
      'title': 'PPAM Marker',
      'price': result['price'],
      'amount': result['amount'],
      'userId': userId,
    };

    // 새로운 마커 아이템 생성
    final markerItem = MarkerItem(
      id: doc.id,
      title: 'PPAM Marker',
      price: result['price']?.toString() ?? '0',
      amount: result['amount']?.toString() ?? '0',
      userId: userId ?? '',
      data: markerData,
      position: position,
    );

    // 마커 추가
    _markerItems.add(markerItem);
    
    // 클러스터링 업데이트
    _updateClustering();
  }

  /// ✅ 마커 액션 메뉴 표시 (소유자용)
  void _showMarkerActionMenu(String markerId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '전단지 메뉴'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('가격: ${data['price']}원'),
              const SizedBox(height: 8),
              Text('수량: ${data['amount']}개'),
              const SizedBox(height: 16),
              const Text(
                '원하는 작업을 선택하세요:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showMarkerInfo(data);
              },
              child: const Text('정보 보기'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showRecoveryDialog(markerId, data);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('회수하기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 마커 정보 표시
  void _showMarkerInfo(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '전단지 정보'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('가격: ${data['price']}원'),
              const SizedBox(height: 8),
              Text('수량: ${data['amount']}개'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 마커 회수 확인 다이얼로그
  void _showRecoveryDialog(String markerId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('전단지 회수'),
          content: Text('${data['title'] ?? '전단지'}를 회수하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeMarker(markerId);
                _showRecoverySuccessDialog();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('예'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 회수 완료 다이얼로그
  void _showRecoverySuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회수 완료'),
          content: const Text('전단지가 성공적으로 회수되었습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 마커 삭제 (Firestore + UI)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    
    // 마커 제거
    _markerItems.removeWhere((item) => item.id == markerId);
    
    // 클러스터링 업데이트
    _updateClustering();
  }

  /// ✅ 마커 추가
  Future<void> _handleAddMarker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostPlaceScreen()),
    );

    if (result != null && _longPressedLatLng != null) {
      await _addMarkerToFirestore(_longPressedLatLng!, result);
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  Widget _buildPopupWidget() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("이 위치에 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("이 주소에 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("주변 사업자에게 뿌리기"),
            ),
            const Divider(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text("취소", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
          : Stack(
        children: [
          GoogleMap(
            key: mapWidgetKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onLongPress: (LatLng latLng) {
              setState(() {
                _longPressedLatLng = latLng;
              });
            },
            markers: {
              ..._clusteredMarkers,
              if (_longPressedLatLng != null)
                Marker(
                  markerId: const MarkerId('long_press_marker'),
                  position: _longPressedLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "선택한 위치"),
                ),
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              _updateClustering();
            },

          ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}
