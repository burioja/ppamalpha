import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  final String _googleApiKey = "AIzaSyCb94vRxZmszRM3FhO4b6vaX5eRwR4F1Kg"; 

  List<String> _suggestions = [];
  String? _mapStyle;

  LatLng? _longPressedPosition;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
  }

  void goToCurrentLocation() {
    if (_currentPosition != null && mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
      );
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final String style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
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

  Future<List<String>> _getPlaceSuggestions(String query) async {
    final url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&types=geocode&key=$_googleApiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['predictions'] as List)
            .map((prediction) => prediction['description'] as String)
            .toList();
      }
    } catch (e) {
      print('Place API 호출 실패: $e');
    }
    return [];
  }

  Future<void> _searchLocation(String query) async {
    final url =
        'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$_googleApiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final location = json.decode(response.body)['results'][0]['geometry']['location'];
        final latLng = LatLng(location['lat'], location['lng']);
        setState(() {
          _currentPosition = latLng;
          _searchMarker = Marker(
            markerId: const MarkerId("search_marker"),
            position: latLng,
            infoWindow: InfoWindow(title: query),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });
        mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15.0));
      }
    } catch (e) {
      print('Geocode API 실패: $e');
    }
  }

  void _showLongPressMenu(LatLng position) async {
    final screenCoord = await mapController.getScreenCoordinate(position);
    final size = MediaQuery.of(context).size;
    final overlay = Overlay.of(context);

    _overlayEntry?.remove(); // 기존에 떠있는 팝업 있으면 제거

    double left = screenCoord.x.toDouble();
    double top = screenCoord.y.toDouble();

    // 🧹 화면 넘어가는 것 방지
    const double popupWidth = 150;
    const double popupHeight = 100;

    if (left + popupWidth > size.width) {
      left = size.width - popupWidth - 10;
    }
    if (top + popupHeight > size.height) {
      top = size.height - popupHeight - 10;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: popupWidth,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    print("여기에 뿌리기: $position");
                    _overlayEntry?.remove();
                  },
                  child: const Text("여기에 뿌리기"),
                ),
                const Divider(),
                TextButton(
                  onPressed: () => _overlayEntry?.remove(),
                  child: const Text("취소"),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
              : GoogleMap(
            onMapCreated: _onMapCreated,
            onLongPress: (LatLng latLng) {
              _longPressedPosition = latLng;
              _showLongPressMenu(latLng);
            },
            initialCameraPosition: CameraPosition(target: _currentPosition!, zoom: 15.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: {
              if (_searchMarker != null) _searchMarker!,
            },
          ),

          // 현재 위치 버튼

        ],
      ),
    );
  }
}
