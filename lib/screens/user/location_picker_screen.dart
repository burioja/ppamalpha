import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  MapController? _mapController;
  LatLng? _current;
  LatLng? _picked;
  // String? _pickedAddress; // 사용되지 않음
  final TextEditingController _addressController = TextEditingController();
  List<Location> _searchResults = [];
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initCurrentLocation();
  }

  Future<void> _initCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        setState(() {
          _current = LatLng(pos.latitude, pos.longitude);
        });
      }
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null) {
        final addr = await LocationService.getAddressFromCoordinates(pos.latitude, pos.longitude);
        if (mounted) {
          Navigator.pop(context, {
            'location': LatLng(pos.latitude, pos.longitude),
            'address': addr,
          });
        }
      }
    } finally {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final list = await locationFromAddress(query);
      setState(() => _searchResults = list);
    } catch (_) {
      setState(() => _searchResults = []);
    }
  }

  Future<void> _confirmPick() async {
    final p = _picked;
    if (p == null) return;
    final addr = await LocationService.getAddressFromCoordinates(p.latitude, p.longitude);
    if (mounted) {
      Navigator.pop(context, {
        'location': p,
        'address': addr,
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 선택'),
        actions: [
          TextButton(
            onPressed: _picked != null ? _confirmPick : null,
            child: const Text('확인'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadingLocation ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('현재 위치 사용'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: '주소로 검색',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchAddress(_addressController.text),
                ),
              ),
              onSubmitted: _searchAddress,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final loc = _searchResults[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text('${loc.latitude.toStringAsFixed(6)}, ${loc.longitude.toStringAsFixed(6)}'),
                    onTap: () {
                      setState(() {
                        _picked = LatLng(loc.latitude, loc.longitude);
                        _searchResults = [];
                        _addressController.clear();
                      });
                      _mapController?.move(_picked!, 15.0);
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: _current == null
                ? const Center(child: Text('지도를 초기화하는 중...'))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _current!,
                      initialZoom: 15.0,
                      onTap: (tapPosition, point) {
                        setState(() => _picked = point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ppamproto',
                      ),
                      if (_picked != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _picked!,
                              width: 40.0,
                              height: 40.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}








