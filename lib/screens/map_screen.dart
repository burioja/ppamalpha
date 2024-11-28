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

  final String _googleApiKey = "AIzaSyCb94vRxZmszRM3FhO4b6vaX5eRwR4F1Kg";
  bool _isSearchVisible = false; // 검색창 표시 여부

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
          _currentPosition = const LatLng(37.495872, 127.025046);
        });
      }
    } catch (e) {
      print('초기 위치 설정 오류: $e');
      setState(() {
        _currentPosition = const LatLng(37.492894, 127.012469);
      });
    }
  }

  Future<List<String>> _getPlaceSuggestions(String query) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&types=geocode&key=$_googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List;
        return predictions
            .map((prediction) => prediction['description'] as String)
            .toList();
      } else {
        print('Google Places API 오류: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Google Places API 호출 실패: $e');
      return [];
    }
  }

  Future<void> _searchLocation(String query) async {
    try {
      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final location = data['results'][0]['geometry']['location'];
        final newPosition = LatLng(location['lat'], location['lng']);

        setState(() {
          _currentPosition = newPosition;
          _searchMarker = Marker(
            markerId: const MarkerId("search_marker"),
            position: newPosition,
            infoWindow: InfoWindow(title: query),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
        });

        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPosition, zoom: 15.0),
          ),
        );
      } else {
        print('주소 검색 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('주소 검색 실패: $e');
    }
  }

  Future<void> _applyMapStyle() async {
    try {
      String mapStyle = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      mapController.setMapStyle(mapStyle);
    } catch (e) {
      print('맵 스타일 적용 오류: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;

    // 맵 스타일 적용
    _applyMapStyle();

    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15.0),
        ),
      );
    }
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
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: {
              if (_searchMarker != null) _searchMarker!,
            },
          ),
          Positioned(
            top: 20,
            left: 10,
            right: 10,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSearchVisible ? MediaQuery.of(context).size.width - 80 : 0,
                  child: Visibility(
                    visible: _isSearchVisible,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '검색할 위치를 입력하세요',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            _searchLocation(_searchController.text);
                            setState(() {
                              _isSearchVisible = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearchVisible = !_isSearchVisible;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            mapController.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: _currentPosition!, zoom: 15.0),
              ),
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
