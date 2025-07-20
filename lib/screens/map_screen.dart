import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_place_screen.dart';

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
      const ImageConfiguration(size: Size(48, 48)),
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

  /// ✅ Firestore에서 마커 불러오기
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    for (var doc in docs) {
      final data = doc.data();
      final LatLng pos = LatLng(data['lat'], data['lng']);
      final marker = Marker(
        markerId: MarkerId(doc.id),
        position: pos,
        icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: data['title'],
          snippet: 'Price: ${data['price']}, Amount: ${data['amount']}',
        ),
        onTap: () {
          if (data['userId'] == userId) {
            _removeMarker(doc.id);
          }
        },
      );
      setState(() {
        _markers.add(marker);
      });
    }
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

    final marker = Marker(
      markerId: MarkerId(doc.id),
      position: position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: 'PPAM Marker',
        snippet: 'Price: ${result['price']}, Amount: ${result['amount']}',
      ),
      onTap: () {
        if (userId == FirebaseAuth.instance.currentUser?.uid) {
          _removeMarker(doc.id);
        }
      },
    );

    setState(() {
      _markers.add(marker);
    });
  }

  /// ✅ 마커 삭제 (Firestore + UI)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == markerId);
    });
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
          ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}
