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
  List<String> _suggestions = []; // 자동완성 리스트
  String? _mapStyle; // 맵 스타일 저장

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle(); // 맵 스타일 로드
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue),
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

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
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
            style: _mapStyle, // GoogleMap의 style 속성 사용
          ),
          // 검색창과 돋보기 버튼
          Positioned(
            top: 20,
            right: 10,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  alignment: Alignment.centerRight,
                  transform: Matrix4.translationValues(
                      _isSearchVisible ? 0 : MediaQuery.of(context).size.width,
                      0,
                      0),
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (value) async {
                          final suggestions =
                          await _getPlaceSuggestions(value);
                          setState(() {
                            _suggestions = suggestions;
                          });
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
                    });
                  },
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          // 자동완성 리스트 표시
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 70, // 검색창 바로 아래에 위치
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
