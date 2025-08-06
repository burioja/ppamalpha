import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/post_service.dart';
import '../../services/location_service.dart';
import '../../models/post_model.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final PostService _postService = PostService();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _currentAddress;
  bool _isLoading = false;
  bool _showAddressConfirmation = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final address = await LocationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _currentAddress = address;
          _addressController.text = address;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치를 가져올 수 없습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치를 가져오는데 실패했습니다: $e')),
      );
    }
  }

  void _onMapTap(LatLng location) async {
    setState(() => _isLoading = true);
    try {
      final address = await LocationService.getAddressFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      setState(() {
        _selectedLocation = location;
        _currentAddress = address;
        _addressController.text = address;
        _isLoading = false;
        _showAddressConfirmation = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('주소를 가져오는데 실패했습니다: $e')),
      );
    }
  }

  void _confirmAddress() {
    setState(() => _showAddressConfirmation = false);
  }

  void _editAddress() {
    setState(() => _showAddressConfirmation = false);
    // 주소 입력 모드로 전환
  }

  Future<void> _createPost() async {
    if (_selectedLocation == null || _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치와 내용을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }
      
      await _postService.createPost(
        userId: currentUser.uid,
        content: _contentController.text.trim(),
        location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        address: _currentAddress ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('포스트가 성공적으로 생성되었습니다!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 생성에 실패했습니다: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이 위치에 뿌리기'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 지도 영역
                Expanded(
                  flex: 2,
                  child: _selectedLocation == null
                      ? const Center(child: Text('위치를 선택해주세요'))
                      : GoogleMap(
                          onMapCreated: (controller) => _mapController = controller,
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation!,
                            zoom: 15,
                          ),
                          onTap: _onMapTap,
                          markers: _selectedLocation != null
                              ? {
                                  Marker(
                                    markerId: const MarkerId('selected_location'),
                                    position: _selectedLocation!,
                                    infoWindow: InfoWindow(
                                      title: '선택된 위치',
                                      snippet: _currentAddress,
                                    ),
                                  ),
                                }
                              : {},
                        ),
                ),
                
                // 주소 확인 다이얼로그
                if (_showAddressConfirmation)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.blue.shade50,
                    child: Column(
                      children: [
                        Text(
                          '이 주소가 맞습니까?',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentAddress ?? '',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: _confirmAddress,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('예'),
                            ),
                            ElevatedButton(
                              onPressed: _editAddress,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('아니오'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                // 포스트 내용 입력 영역
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: '주소',
                            border: OutlineInputBorder(),
                          ),
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _contentController,
                          decoration: const InputDecoration(
                            labelText: '포스트 내용',
                            border: OutlineInputBorder(),
                            hintText: '이 위치에 대한 메시지를 입력하세요...',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _createPost,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            '포스트 뿌리기',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _addressController.dispose();
    super.dispose();
  }
} 