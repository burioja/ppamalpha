import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      } else {
        setState(() {
          _currentPosition = const LatLng(37.495872, 127.025046); // 기본 위치
        });
      }
    } catch (e) {
      print('초기 위치 설정 오류: $e');
      setState(() {
        _currentPosition = const LatLng(37.492894, 127.012469); // 오류 시 기본 위치
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // JSON 스타일 적용
    _applyMapStyle();

    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15.0),
        ),
      );
    }
  }

  // 맵 스타일 적용 함수
  Future<void> _applyMapStyle() async {
    try {
      // JSON 스타일 파일 로드
      String mapStyle = await DefaultAssetBundle.of(context)
          .loadString('assets/map_style.json');

      // Google Map 스타일 적용
      mapController.setMapStyle(mapStyle);
    } catch (e) {
      print('맵 스타일 적용 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("현재 위치를 불러오는 중입니다...")) // 로딩 메시지
          : GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: _currentPosition!,
          zoom: 15.0,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
