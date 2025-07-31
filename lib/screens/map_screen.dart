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
import 'package:google_maps_cluster_manager/google_maps_cluster_manager.dart';
import 'post_place_screen.dart';

/// ✅ 마커 아이템 클래스 (클러스터링용)
class MarkerItem extends ClusterItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;

  MarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required LatLng position,
  }) : super(position);
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
  
  // 클러스터링 관련 변수들
  late ClusterManager<MarkerItem> _clusterManager;
  final List<MarkerItem> _markerItems = [];

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
    _loadCustomMarker();
    _initializeClusterManager();
    _loadMarkersFromFirestore();
  }

  /// ✅ 클러스터 매니저 초기화
  void _initializeClusterManager() {
    _clusterManager = ClusterManager<MarkerItem>(
      _markerItems, 
      _updateMarkers,
      markerBuilder: _getMarkerFromClusterItem,
      clusterItemBuilder: _getClusterBitmap,
      levels: [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
      extraPercent: 0.25,
      minZoom: 0,
      maxZoom: 19,
    );
  }

  /// ✅ 마커 업데이트 콜백
  void _updateMarkers(Set<Marker> markers) {
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  /// ✅ 클러스터 매니저용 마커 생성 함수
  Future<Marker> _getMarkerFromClusterItem(MarkerItem item) async {
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: item.title,
        snippet: 'Price: ${item.price}원, Amount: ${item.amount}개',
      ),
      onTap: () {
        // 마커 상호작용 메뉴 표시
        if (item.userId == userId) {
          _showMarkerActionMenu(item.id, item.data);
        } else {
          _showMarkerInfo(item.data);
        }
      },
    );
  }

  /// ✅ 클러스터 아이콘 생성 함수
  Future<BitmapDescriptor> _getClusterBitmap(List<MarkerItem> cluster) async {
    final size = 150;
    final color = Colors.blue;
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    textPainter.text = TextSpan(
      text: cluster.length.toString(),
      style: TextStyle(
        fontSize: size / 3,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size / 2 - textPainter.width / 2,
        size / 2 - textPainter.height / 2,
      ),
    );
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
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
    _clusterManager.setMapController(controller);
  }

  /// ✅ Firestore에서 마커 불러오기 (클러스터링 지원)
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    _markerItems.clear();
    
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
    
    // 클러스터 매니저에 마커 아이템들 추가
    _clusterManager.setItems(_markerItems);
  }

  /// ✅ Firestore에 마커 저장 (클러스터링 지원)
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
      userId: userId,
      data: markerData,
      position: position,
    );

    // 클러스터 매니저에 새 마커 추가
    _markerItems.add(markerItem);
    _clusterManager.setItems(_markerItems);
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

  /// ✅ 마커 삭제 (Firestore + UI + 클러스터링)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    
    // 클러스터 매니저에서 마커 제거
    _markerItems.removeWhere((item) => item.id == markerId);
    _clusterManager.setItems(_markerItems);
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
            onLongPress: (LatLng latLng) {
              setState(() {
                _longPressedLatLng = latLng;
              });
            },
            markers: {
              ..._markers,
              if (_longPressedLatLng != null)
                Marker(
                  markerId: const MarkerId('long_press_marker'),
                  position: _longPressedLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "선택한 위치"),
                ),
            },
            onCameraMove: _clusterManager.onCameraMove,
            onCameraIdle: _clusterManager.onCameraIdle,
          ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}
