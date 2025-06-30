import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart'; // 꼭 임포트해줘
import 'post_place_screen.dart'; // ← 파일 위치에 맞게 경로 수정 필요

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  Marker? _searchMarker;
  final String _googleApiKey = "YOUR_API_KEY"; // ← 너의 키로 바꿔줘

  final GlobalKey mapWidgetKey = GlobalKey();

  LatLng? _longPressedLatLng;
  ScreenCoordinate? _popupScreenCoord;

  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
  }

  void goToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
      );
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final String style =
      await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
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
    } catch (e) {
      print('초기 위치 설정 오류: $e');
      setState(() {
        _currentPosition = const LatLng(37.492894, 127.012469);
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  Future<void> _handleLongPress(LatLng position) async {
    final screenCoord = await mapController.getScreenCoordinate(position);
    setState(() {
      _longPressedLatLng = position;
      _popupScreenCoord = screenCoord;
    });
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
              onPressed: () {
                print("📍 이 위치에 뿌리기: $_longPressedLatLng");
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text("이 위치에 뿌리기"),
            ),
            TextButton(
              onPressed: () async {
                if (_longPressedLatLng != null) {
                  try {
                    List<Placemark> placemarks = await placemarkFromCoordinates(
                      _longPressedLatLng!.latitude,
                      _longPressedLatLng!.longitude,
                    );
                    if (placemarks.isNotEmpty) {
                      final placemark = placemarks.first;
                      final address = "${placemark.locality ?? ''} ${placemark.street ?? ''}".trim();

                      // 👉 PostPlaceScreen으로 주소 넘기기
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostPlaceScreen(
                            latLng: _longPressedLatLng!,
                            address: address,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    print("역지오코딩 오류: $e");
                  }
                }

                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text("이 주소에 뿌리기"),
            ),
            TextButton(
              onPressed: () {
                print("📍 주변 사업자에게 뿌리기");
                // TODO: 주변 사업자 조회 기능 추가
                setState(() {
                  _longPressedLatLng = null;
                });
              },
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
            initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 15.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            onLongPress: (LatLng latLng) {
              setState(() {
                _longPressedLatLng = latLng;
              });
            },
            markers: {
              if (_searchMarker != null) _searchMarker!,
              if (_longPressedLatLng != null)
                Marker(
                  markerId: const MarkerId('long_press_marker'),
                  position: _longPressedLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "선택한 위치"),
                ),
            },
          ),

          // 📍 팝업 위젯
          if (_longPressedLatLng != null)
            Center(
              child: _buildPopupWidget(), // 화면 정중앙에 고정
            ),
        ],
      ),
    );
  }
}
