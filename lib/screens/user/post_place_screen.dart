import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _ageMinController = TextEditingController();
  final TextEditingController _ageMaxController = TextEditingController();
  
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _currentAddress;
  bool _isLoading = false;
  bool _showAddressConfirmation = false;
  String? _mapStyle;
  
  // 설정 옵션들
  String _selectedPeriodUnit = 'Hour';
  String _selectedFunction = 'Using';
  String _selectedGender = '상관없음';
  String _selectedAgeRange = '상관없음';
  String? _selectedWalletFile;
  
  // 기본 위치 (서울 시청)
  static const LatLng _defaultLocation = LatLng(37.5665, 126.9780);

  @override
  void initState() {
    super.initState();
    // 기본 위치로 초기화
    _selectedLocation = _defaultLocation;
    _currentAddress = '서울특별시 중구 세종대로 110';
    _addressController.text = _currentAddress!;
    
    // 기본값 설정
    _priceController.text = '1000';
    _amountController.text = '10';
    _periodController.text = '24';
    _ageMinController.text = '20';
    _ageMaxController.text = '30';
    
    // 지도 스타일 로드
    _loadMapStyle();
    
    // 현재 위치 가져오기 시도
    _getCurrentLocation();
  }

  // 지도 스타일 로드
  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // 스타일 로드 실패 시 무시
    }
  }

  // 지도 생성 시 스타일 적용
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  // 총액 계산
  int get _totalAmount {
    int price = int.tryParse(_priceController.text) ?? 0;
    int amount = int.tryParse(_amountController.text) ?? 0;
    return price * amount;
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
        // 위치를 가져올 수 없으면 기본 위치 유지
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 가져올 수 없어 기본 위치를 사용합니다.')),
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

  // 월렛 파일 선택 다이얼로그
  void _showWalletFileSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('월렛에서 파일 선택'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                // 임시로 더미 데이터 사용 (실제로는 월렛에서 가져와야 함)
                Expanded(
                  child: ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final fileName = '파일 ${index + 1}.jpg';
                      final isSelected = _selectedWalletFile == fileName;
                      
                      return ListTile(
                        leading: const Icon(Icons.image),
                        title: Text(fileName),
                        subtitle: Text('${DateTime.now().subtract(Duration(days: index)).toString().substring(0, 10)}'),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                        onTap: () {
                          setState(() {
                            _selectedWalletFile = fileName;
                          });
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createPost() async {
    if (_selectedLocation == null || _selectedWalletFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치와 파일을 선택해주세요')),
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
        content: _selectedWalletFile!,
        location: GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        address: _currentAddress ?? '',
        price: int.tryParse(_priceController.text) ?? 0,
        amount: int.tryParse(_amountController.text) ?? 0,
        period: int.tryParse(_periodController.text) ?? 24,
        periodUnit: _selectedPeriodUnit,
        function: _selectedFunction,
        target: '$_selectedGender/$_selectedAgeRange',
        ageMin: int.tryParse(_ageMinController.text) ?? 20,
        ageMax: int.tryParse(_ageMaxController.text) ?? 30,
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
        title: const Text('포스트 뿌리기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 지도 영역
                  Expanded(
                    flex: 2,
                    child: _selectedLocation == null
                        ? const Center(child: Text('위치를 선택해주세요'))
                        : GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: _selectedLocation!,
                              zoom: 15.0,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            onTap: _onMapTap,
                            markers: _selectedLocation != null
                                ? {
                                    Marker(
                                      markerId: const MarkerId('selected_location'),
                                      position: _selectedLocation!,
                                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
                          const Icon(
                            Icons.location_on,
                            color: Colors.blue,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '이 주소가 맞습니까?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Text(
                              _currentAddress ?? '',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _confirmAddress,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.check),
                                  label: const Text('예, 맞습니다'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _editAddress,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('아니오, 수정'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  
                  // 포스트 설정 영역
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 위치 정보 표시
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentAddress ?? '위치를 선택해주세요',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // 월렛 파일 선택
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('선택된 파일', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.image, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedWalletFile ?? '월렛에서 파일을 선택해주세요',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _showWalletFileSelector,
                                        child: const Text('파일 선택'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // 가격 및 수량 설정
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Price', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (value) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _amountController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        onChanged: (value) => setState(() {}),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black, width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Total: $_totalAmount',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // 기능 설정
                            const Text('Function', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            
                            // 기간 설정
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Period', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _periodController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: DropdownButton<String>(
                                    value: _selectedPeriodUnit,
                                    underline: Container(),
                                    items: ['Hour', 'Day', 'Week', 'Month'].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        _selectedPeriodUnit = newValue!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // 기능 버튼들
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedFunction = 'Using'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedFunction == 'Using' ? Colors.blue : Colors.grey.shade300,
                                      foregroundColor: _selectedFunction == 'Using' ? Colors.white : Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Using'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => setState(() => _selectedFunction = 'Reply'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedFunction == 'Reply' ? Colors.blue : Colors.grey.shade300,
                                      foregroundColor: _selectedFunction == 'Reply' ? Colors.white : Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Reply'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // 타겟 설정
                            const Text('Target', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            
                            // 성별 드롭다운
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: DropdownButton<String>(
                                          value: _selectedGender,
                                          isExpanded: true,
                                          underline: Container(),
                                          items: ['상관없음', '남성', '여성'].map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              _selectedGender = newValue!;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Age Range', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: DropdownButton<String>(
                                          value: _selectedAgeRange,
                                          isExpanded: true,
                                          underline: Container(),
                                          items: ['상관없음', '10대', '20대', '30대', '40대', '50대+'].map((String value) {
                                            return DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            );
                                          }).toList(),
                                          onChanged: (String? newValue) {
                                            setState(() {
                                              _selectedAgeRange = newValue!;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // 나이 범위 설정
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Age (min)', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _ageMinController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Age (max)', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      TextField(
                                        controller: _ageMaxController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            
                            // PPAM! 버튼
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade300, Colors.yellow.shade300],
                                ),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: ElevatedButton(
                                onPressed: _createPost,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'PPAM!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _priceController.dispose();
    _amountController.dispose();
    _periodController.dispose();
    _ageMinController.dispose();
    _ageMaxController.dispose();
    super.dispose();
  }
} 