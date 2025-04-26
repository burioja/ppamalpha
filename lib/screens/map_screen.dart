import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  Marker? _searchMarker;
  final TextEditingController _searchController = TextEditingController();
  final String _googleApiKey = "YOUR_API_KEY_HERE"; // 🔑 실제 API 키로 교체 필요
  bool _isSearchVisible = false;
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

          // 검색창 + 검색 아이콘
          Positioned(
            top: 20,
            right: 10,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.centerRight,
                  transform: Matrix4.translationValues(
                      _isSearchVisible ? 0 : MediaQuery.of(context).size.width, 0, 0),
                  height: 40,
                  child: Visibility(
                    visible: _isSearchVisible,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 80,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: '검색할 위치를 입력하세요',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (value) async {
                          final suggestions = await _getPlaceSuggestions(value);
                          setState(() => _suggestions = suggestions);
                        },
                        onSubmitted: (value) {
                          _searchLocation(value);
                          setState(() {
                            _isSearchVisible = false;
                            _suggestions.clear();
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                      if (!_isSearchVisible) {
                        _searchController.clear();
                        _suggestions.clear();
                      }
                    });
                  },
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),

          // 자동완성 리스트
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 70,
              left: 10,
              right: 10,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(10),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index]),
                      onTap: () {
                        _searchLocation(_suggestions[index]);
                        setState(() {
                          _isSearchVisible = false;
                          _suggestions.clear();
                        });
                      },
                    );
                  },
                ),
              ),
            ),

          // 현재 위치 버튼
          Positioned(
            top: 80,
            right: 10,
            child: FloatingActionButton(
              onPressed: () {
                if (_currentPosition != null) {
                  mapController.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: _currentPosition!, zoom: 15.0),
                    ),
                  );
                }
              },
              mini: true,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}