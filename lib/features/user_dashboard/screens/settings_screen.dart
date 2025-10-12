import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/models/place/place_model.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/data/user_service.dart';
import '../../../utils/admin_point_grant.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/info_section_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  
  // 개인정보 컨트롤러들
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _secondAddressController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  
  // 상태 변수들
  String? _selectedGender;
  String? _profileImageUrl;
  String _userEmail = '';
  bool _allowSexualContent = false;
  bool _allowViolentContent = false;
  bool _allowHateContent = false;
  
  // 프로필 이미지 강제 업데이트를 위한 카운터
  int _profileUpdateCounter = 0;

  // 섹션 확장/축소 상태
  bool _personalInfoExpanded = true;
  bool _addressInfoExpanded = true;
  bool _accountInfoExpanded = true;
  bool _workplaceInfoExpanded = true;
  bool _contentFilterExpanded = true;
  
  // 집 주소 관련 (좌표 포함)
  GeoPoint? _homeLocation;
  String? _homeAddress;
  String? _homeSecondAddress;
  
  // 일터 관련 (단일 workplaceId 기반)
  final PlaceService _placeService = PlaceService();
  String? _workplaceId;
  PlaceModel? _workplace;
  final TextEditingController _workplaceNameController = TextEditingController();
  final TextEditingController _workplaceAddressController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }


  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _secondAddressController.dispose();
    _accountController.dispose();
    _birthController.dispose();
    _workplaceNameController.dispose();
    _workplaceAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 기본 정보 로드
      setState(() {
        _userEmail = user.email ?? '';
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        debugPrint('📄 사용자 데이터 로드: ${userData.keys.toList()}');
        debugPrint('🖼️ profileImageUrl in Firestore: ${userData['profileImageUrl']}');

        setState(() {
          _nicknameController.text = userData['nickname'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _secondAddressController.text = userData['secondAddress'] ?? '';
          _accountController.text = userData['account'] ?? '';
          _birthController.text = userData['birthDate'] ?? '';
          final genderValue = userData['gender'] as String?;
          _selectedGender = (genderValue == 'male' || genderValue == 'female') ? genderValue : null;
          _profileImageUrl = userData['profileImageUrl'];
          debugPrint('💾 _profileImageUrl 설정됨: $_profileImageUrl');
          _allowSexualContent = userData['allowSexualContent'] ?? false;
          _allowViolentContent = userData['allowViolentContent'] ?? false;
          _allowHateContent = userData['allowHateContent'] ?? false;

          // 집 주소 정보 로드 (좌표 포함)
          _homeAddress = userData['address'] as String?;
          _homeSecondAddress = userData['secondAddress'] as String?;
          _homeLocation = userData['homeLocation'] as GeoPoint?;
          if (_homeLocation != null) {
            debugPrint('🏠 집 주소 좌표 로드: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
          }

          // 일터 정보 로드 (workplaceId 기반)
          _workplaceId = userData['workplaceId'] as String?;
        });

        // workplaceId가 있으면 플레이스 정보 조회
        if (_workplaceId != null && _workplaceId!.isNotEmpty) {
          _loadWorkplaceInfo();
        }
      }
    } catch (e) {
      _showToast('사용자 정보를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _loadWorkplaceInfo() async {
    try {
      if (_workplaceId == null) return;
      
      final place = await _placeService.getPlaceById(_workplaceId!);
      if (place != null && mounted) {
        setState(() {
          _workplace = place;
          _workplaceNameController.text = place.name;
          _workplaceAddressController.text = place.formattedAddress ?? place.address ?? '';
        });
        debugPrint('✅ 일터 정보 로드 완료: ${place.name}');
      }
    } catch (e) {
      debugPrint('❌ 일터 정보 로드 실패: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.updateUserProfile(
        nickname: _nicknameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        secondAddress: _secondAddressController.text.trim(),
        account: _accountController.text.trim(),
        birth: _birthController.text.trim(),
        gender: _selectedGender,
        profileImageUrl: _profileImageUrl,
      );

      // 콘텐츠 필터 및 집 주소 좌표는 별도 저장
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final updates = <String, dynamic>{
          'allowSexualContent': _allowSexualContent,
          'allowViolentContent': _allowViolentContent,
          'allowHateContent': _allowHateContent,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        
        // 집 주소 좌표 저장 (회원가입과 동일)
        if (_homeLocation != null) {
          updates['homeLocation'] = _homeLocation;
          debugPrint('🏠 집 주소 좌표 업데이트: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
        }
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updates);
      }

      _showToast('개인정보가 성공적으로 저장되었습니다');
    } catch (e) {
      print('사용자 데이터 저장 실패: $e');
      _showToast('저장 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewWorkplace(String name, String address, GeoPoint? location) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showToast('로그인이 필요합니다');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // 새 플레이스 생성 (회원가입과 동일한 로직)
      final newPlace = PlaceModel(
        id: '', // Firestore가 자동 생성
        name: name,
        description: '${_nicknameController.text.trim()}님의 일터',
        address: address,
        location: location,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        isActive: true,
        isVerified: true, // 회원가입 일터와 동일하게 인증됨
      );

      final newWorkplaceId = await _placeService.createPlace(newPlace);

      // users 문서에 workplaceId 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'workplaceId': newWorkplaceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _workplaceId = newWorkplaceId;
      });

      await _loadWorkplaceInfo(); // 일터 정보 로드
      _showToast('일터가 추가되었습니다');
      debugPrint('✅ 일터 추가 완료: $name');
    } catch (e) {
      debugPrint('❌ 일터 추가 실패: $e');
      _showToast('일터 추가 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOrUpdateWorkplace() async {
    if (_workplaceNameController.text.trim().isEmpty || 
        _workplaceAddressController.text.trim().isEmpty) {
      _showToast('일터 이름과 주소를 모두 입력해주세요');
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 일터 정보가 이미 있으면 업데이트
      if (_workplaceId != null && _workplace != null) {
        // 기존 플레이스 업데이트
        final updatedPlace = _workplace!.copyWith(
          name: _workplaceNameController.text.trim(),
          address: _workplaceAddressController.text.trim(),
          updatedAt: DateTime.now(),
        );
        
        await _placeService.updatePlace(updatedPlace.id, updatedPlace);
        _showToast('일터 정보가 수정되었습니다');
        debugPrint('✅ 일터 업데이트 완료: ${updatedPlace.name}');
      }

      await _loadWorkplaceInfo(); // 정보 새로고침
    } catch (e) {
      debugPrint('❌ 일터 저장 실패: $e');
      _showToast('일터 저장 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _deleteWorkplace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일터 삭제'),
        content: const Text('일터를 삭제하시겠습니까?\n내플레이스 및 맵에서도 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _workplaceId == null) return;

      // 플레이스 비활성화
      if (_workplace != null) {
        await _placeService.updatePlace(_workplace!.id, _workplace!.copyWith(isActive: false));
      }

      // users 문서에서 workplaceId 제거
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'workplaceId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _workplaceId = null;
        _workplace = null;
        _workplaceNameController.clear();
        _workplaceAddressController.clear();
      });

      _showToast('일터가 삭제되었습니다');
      debugPrint('✅ 일터 삭제 완료');
    } catch (e) {
      debugPrint('❌ 일터 삭제 실패: $e');
      _showToast('일터 삭제 중 오류가 발생했습니다: $e');
    }
  }

  // 집 주소 추가 다이얼로그
  Future<void> _showAddHomeAddressDialog() async {
    final TextEditingController addressController = TextEditingController();
    final TextEditingController detailController = TextEditingController();
    GeoPoint? selectedLocation;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('집 주소 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 주소 검색
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: '주소',
                        hintText: '주소 검색을 눌러주세요',
                      ),
                      readOnly: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/address-search');
                      if (result != null && result is Map<String, dynamic>) {
                        addressController.text = result['address'] ?? '';
                        if (result['lat'] != null && result['lon'] != null) {
                          selectedLocation = GeoPoint(
                            double.parse(result['lat'].toString()),
                            double.parse(result['lon'].toString()),
                          );
                          debugPrint('🏠 집 주소 좌표: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}');
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 상세주소
              TextField(
                controller: detailController,
                decoration: const InputDecoration(
                  labelText: '상세주소',
                  hintText: '동, 호수 등 상세주소를 입력해주세요',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addressController.text.isEmpty) {
                _showToast('주소를 입력해주세요');
                return;
              }
              if (selectedLocation == null) {
                _showToast('주소 검색을 통해 좌표를 선택해주세요');
                return;
              }

              // 집 주소 정보 저장
              setState(() {
                _homeAddress = addressController.text.trim();
                _homeSecondAddress = detailController.text.trim();
                _homeLocation = selectedLocation;
                _addressController.text = _homeAddress!;
                _secondAddressController.text = _homeSecondAddress!;
              });

              // Firestore에 저장
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'address': _homeAddress,
                    'secondAddress': _homeSecondAddress,
                    'homeLocation': _homeLocation,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  _showToast('집 주소가 추가되었습니다');
                  Navigator.pop(context);
                }
              } catch (e) {
                debugPrint('❌ 집 주소 추가 실패: $e');
                _showToast('집 주소 추가 중 오류가 발생했습니다: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 집 주소 수정 다이얼로그
  Future<void> _showEditHomeAddressDialog() async {
    final TextEditingController addressController = TextEditingController(text: _homeAddress);
    final TextEditingController detailController = TextEditingController(text: _homeSecondAddress);
    GeoPoint? selectedLocation = _homeLocation;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('집 주소 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 주소 검색
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: '주소',
                        hintText: '주소 검색을 눌러주세요',
                      ),
                      readOnly: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/address-search');
                      if (result != null && result is Map<String, dynamic>) {
                        addressController.text = result['address'] ?? '';
                        if (result['lat'] != null && result['lon'] != null) {
                          selectedLocation = GeoPoint(
                            double.parse(result['lat'].toString()),
                            double.parse(result['lon'].toString()),
                          );
                          debugPrint('🏠 집 주소 좌표: ${selectedLocation!.latitude}, ${selectedLocation!.longitude}');
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 상세주소
              TextField(
                controller: detailController,
                decoration: const InputDecoration(
                  labelText: '상세주소',
                  hintText: '동, 호수 등 상세주소를 입력해주세요',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (addressController.text.isEmpty) {
                _showToast('주소를 입력해주세요');
                return;
              }
              if (selectedLocation == null) {
                _showToast('주소 검색을 통해 좌표를 선택해주세요');
                return;
              }

              // 집 주소 정보 업데이트
              setState(() {
                _homeAddress = addressController.text.trim();
                _homeSecondAddress = detailController.text.trim();
                _homeLocation = selectedLocation;
                _addressController.text = _homeAddress!;
                _secondAddressController.text = _homeSecondAddress!;
              });

              // Firestore에 저장
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'address': _homeAddress,
                    'secondAddress': _homeSecondAddress,
                    'homeLocation': _homeLocation,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  _showToast('집 주소가 수정되었습니다');
                  Navigator.pop(context);
                }
              } catch (e) {
                debugPrint('❌ 집 주소 수정 실패: $e');
                _showToast('집 주소 수정 중 오류가 발생했습니다: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 집 주소 삭제
  Future<void> _deleteHomeAddress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('집 주소 삭제'),
        content: const Text('정말로 집 주소를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'address': FieldValue.delete(),
          'secondAddress': FieldValue.delete(),
          'homeLocation': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _homeAddress = null;
          _homeSecondAddress = null;
          _homeLocation = null;
          _addressController.clear();
          _secondAddressController.clear();
        });

        _showToast('집 주소가 삭제되었습니다');
      }
    } catch (e) {
      debugPrint('❌ 집 주소 삭제 실패: $e');
      _showToast('집 주소 삭제 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null) {
      setState(() {
        // result가 Map인 경우 address 필드와 좌표 정보 추출
        if (result is Map<String, dynamic>) {
          _homeAddress = result['address'] ?? '';
          _homeSecondAddress = result['detailAddress'] ?? '';
          _addressController.text = _homeAddress ?? '';
          _secondAddressController.text = _homeSecondAddress ?? '';
          
          // 좌표 정보 저장 (회원가입과 동일)
          if (result['lat'] != null && result['lon'] != null) {
            _homeLocation = GeoPoint(
              double.parse(result['lat'].toString()),
              double.parse(result['lon'].toString()),
            );
            debugPrint('🏠 집 주소 좌표 저장: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
          }
        } else {
          _homeAddress = result.toString();
          _addressController.text = _homeAddress ?? '';
        }
      });
    }
  }

  Future<void> _pickWorkplaceAddress() async {
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null) {
      setState(() {
        // result가 Map인 경우 address 필드만 추출
        if (result is Map<String, dynamic>) {
          _workplaceAddressController.text = result['address'] ?? '';
        } else {
          _workplaceAddressController.text = result.toString();
        }
      });
    }
  }

  Future<void> _showAddWorkplaceDialog() async {
    // 새 일터 추가용 임시 컨트롤러
    final tempNameController = TextEditingController();
    final tempAddressController = TextEditingController();
    GeoPoint? tempLocation;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일터 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempNameController,
              decoration: const InputDecoration(
                labelText: '일터 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tempAddressController,
              decoration: const InputDecoration(
                labelText: '주소',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final searchResult = await Navigator.pushNamed(dialogContext, '/address-search');
                if (searchResult != null) {
                  if (searchResult is Map<String, dynamic>) {
                    tempAddressController.text = searchResult['address'] ?? '';
                    // 좌표 정보 저장
                    if (searchResult['lat'] != null && searchResult['lon'] != null) {
                      tempLocation = GeoPoint(
                        double.parse(searchResult['lat'].toString()),
                        double.parse(searchResult['lon'].toString()),
                      );
                    }
                  } else {
                    tempAddressController.text = searchResult.toString();
                  }
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('주소 검색'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              tempNameController.dispose();
              tempAddressController.dispose();
              Navigator.pop(dialogContext, false);
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tempNameController.text.trim().isEmpty || 
                  tempAddressController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('일터 이름과 주소를 모두 입력해주세요')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('추가'),
          ),
        ],
      ),
    );

    if (result == true) {
      // 새 일터 생성
      await _createNewWorkplace(
        tempNameController.text.trim(),
        tempAddressController.text.trim(),
        tempLocation,
      );
    }

    tempNameController.dispose();
    tempAddressController.dispose();
  }

  Future<void> _showEditWorkplaceDialog() async {
    // 현재 일터 정보를 임시 컨트롤러에 복사
    final tempNameController = TextEditingController(text: _workplace?.name ?? '');
    final tempAddressController = TextEditingController(text: _workplace?.formattedAddress ?? _workplace?.address ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일터 정보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tempNameController,
              decoration: const InputDecoration(
                labelText: '일터 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tempAddressController,
              decoration: const InputDecoration(
                labelText: '주소',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final searchResult = await Navigator.pushNamed(dialogContext, '/address-search');
                if (searchResult != null) {
                  if (searchResult is Map<String, dynamic>) {
                    tempAddressController.text = searchResult['address'] ?? '';
                  } else {
                    tempAddressController.text = searchResult.toString();
                  }
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('주소 검색'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              tempNameController.dispose();
              tempAddressController.dispose();
              Navigator.pop(dialogContext, false);
            },
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      // 수정된 정보로 업데이트
      final updatedPlace = _workplace!.copyWith(
        name: tempNameController.text.trim(),
        address: tempAddressController.text.trim(),
        updatedAt: DateTime.now(),
      );
      
      try {
        await _placeService.updatePlace(updatedPlace.id, updatedPlace);
        _showToast('일터 정보가 수정되었습니다');
        await _loadWorkplaceInfo(); // 정보 새로고침
      } catch (e) {
        _showToast('일터 수정 중 오류가 발생했습니다: $e');
      }
    }

    tempNameController.dispose();
    tempAddressController.dispose();
  }


  String _getDisplayAddress(String address) {
    // 이미 저장된 근무지 주소가 JSON 형식일 수 있으므로 처리
    // 주소가 단순 문자열이면 그대로 반환
    if (!address.startsWith('{') && !address.startsWith('[')) {
      return address;
    }

    // JSON 형식이면 파싱 시도 (이전에 잘못 저장된 경우)
    try {
      // Map 형식으로 파싱 시도는 하지 않고,
      // 단순히 JSON 문자열이 보이는 경우 안내 메시지 표시
      return '주소 정보 오류 (다시 설정해주세요)';
    } catch (e) {
      return address;
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onProfileUpdated() async {
    debugPrint('📥 _onProfileUpdated 호출됨');
    
    // 이전 URL 저장
    final previousUrl = _profileImageUrl;
    debugPrint('📥 이전 profileImageUrl: $previousUrl');
    
    await _loadUserData();  // 데이터 다시 로드 (await 추가)
    debugPrint('📊 _loadUserData 완료 - 새 profileImageUrl: $_profileImageUrl');
    
    // URL 변경 확인
    if (previousUrl != _profileImageUrl) {
      debugPrint('✅ profileImageUrl이 변경됨: $previousUrl → $_profileImageUrl');
    } else {
      debugPrint('⚠️ profileImageUrl이 변경되지 않음');
    }
    
    if (mounted) {
      setState(() {
        _profileUpdateCounter++;  // 카운터 증가로 ProfileHeaderCard 강제 재빌드
      });
      debugPrint('🔄 setState 호출 완료 - _profileUpdateCounter: $_profileUpdateCounter');
    } else {
      debugPrint('⚠️ mounted가 false - setState 건너뜀');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("개인정보 설정"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 프로필 헤더
                    ProfileHeaderCard(
                      key: ValueKey('profile_header_$_profileUpdateCounter'),
                      profileImageUrl: _profileImageUrl,
                      nickname: _nicknameController.text,
                      email: _userEmail,
                      onProfileUpdated: _onProfileUpdated,
                    ),

                    // 기본 정보 섹션
                    InfoSectionCard(
                      title: '기본 정보',
                      icon: Icons.person,
                      isCollapsible: true,
                      isExpanded: _personalInfoExpanded,
                      onToggle: () => setState(() => _personalInfoExpanded = !_personalInfoExpanded),
                      children: [
                        InfoField(
                          label: '닉네임',
                          isRequired: true,
                          child: TextFormField(
                            controller: _nicknameController,
                            decoration: InputDecoration(
                              hintText: '닉네임을 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '닉네임을 입력해주세요';
                              }
                              return null;
                            },
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        InfoField(
                          label: '전화번호',
                          isRequired: true,
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: '010-0000-0000',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        InfoField(
                          label: '생년월일',
                          isRequired: true,
                          child: TextFormField(
                            controller: _birthController,
                            decoration: InputDecoration(
                              hintText: 'YYYY-MM-DD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.datetime,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '생년월일을 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        InfoField(
                          label: '성별',
                          isRequired: true,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            value: (_selectedGender == 'male' || _selectedGender == 'female')
                                ? _selectedGender
                                : null,
                            items: const [
                              DropdownMenuItem(value: "male", child: Text("남성")),
                              DropdownMenuItem(value: "female", child: Text("여성")),
                            ],
                            onChanged: (value) => setState(() => _selectedGender = value),
                            hint: const Text('성별을 선택하세요'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '성별을 선택해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // 주소 정보 섹션 (일터와 동일한 카드 형태)
                    InfoSectionCard(
                      title: '주소 정보',
                      icon: Icons.location_on,
                      accentColor: Colors.orange,
                      isCollapsible: true,
                      isExpanded: _addressInfoExpanded,
                      onToggle: () => setState(() => _addressInfoExpanded = !_addressInfoExpanded),
                      children: [
                        // 집 주소 정보 표시/수정 폼
                        if (_homeAddress != null && _homeAddress!.isNotEmpty) ...[
                          // 등록된 집 주소 정보 표시
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.home, color: Colors.orange, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _homeAddress!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (_homeSecondAddress != null && _homeSecondAddress!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _homeSecondAddress!,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                          if (_homeLocation != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.my_location, size: 12, color: Colors.green),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '좌표 저장됨',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.green[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _showEditHomeAddressDialog,
                                        icon: const Icon(Icons.edit),
                                        label: const Text('수정'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _deleteHomeAddress,
                                        icon: const Icon(Icons.delete),
                                        label: const Text('삭제'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // 집 주소가 없을 때 안내 메시지 및 추가 버튼
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.home_outlined, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      '등록된 집 주소가 없습니다',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '집 주소를 추가하세요',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _showAddHomeAddressDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('집 주소 추가'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // 계정 정보 섹션
                    InfoSectionCard(
                      title: '계정 정보',
                      icon: Icons.account_balance,
                      accentColor: Colors.green,
                      isCollapsible: true,
                      isExpanded: _accountInfoExpanded,
                      onToggle: () => setState(() => _accountInfoExpanded = !_accountInfoExpanded),
                      children: [
                        InfoField(
                          label: '계좌번호 (리워드 지급용)',
                          isRequired: true,
                          child: TextFormField(
                            controller: _accountController,
                            decoration: InputDecoration(
                              hintText: '은행명과 계좌번호를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '계좌번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // 근무지 섹션
                    InfoSectionCard(
                      title: '근무지',
                      icon: Icons.work,
                      accentColor: Colors.purple,
                      isCollapsible: true,
                      isExpanded: _workplaceInfoExpanded,
                      onToggle: () => setState(() => _workplaceInfoExpanded = !_workplaceInfoExpanded),
                      children: [
                        // 일터 정보 표시/수정 폼
                        if (_workplace != null) ...[
                          // 등록된 일터 정보 표시
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.purple.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.business, color: Colors.purple, size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _workplace!.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _workplace!.formattedAddress ?? _workplace!.address ?? '주소 없음',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          // 수정 다이얼로그 표시
                                          _showEditWorkplaceDialog();
                                        },
                                        icon: const Icon(Icons.edit),
                                        label: const Text('수정'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.purple,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _deleteWorkplace,
                                        icon: const Icon(Icons.delete),
                                        label: const Text('삭제'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // 일터가 없을 때 안내 메시지 및 추가 버튼
                          Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.business_outlined, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(
                                      '등록된 일터가 없습니다',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '새로운 일터를 추가하세요',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _showAddWorkplaceDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('일터 추가'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),

                    // 콘텐츠 필터 섹션
                    InfoSectionCard(
                      title: '콘텐츠 필터 설정',
                      icon: Icons.filter_alt,
                      accentColor: Colors.red,
                      isCollapsible: true,
                      isExpanded: _contentFilterExpanded,
                      onToggle: () => setState(() => _contentFilterExpanded = !_contentFilterExpanded),
                      children: [
                        InfoToggle(
                          label: '선정적인 자료',
                          value: _allowSexualContent,
                          onChanged: (value) => setState(() => _allowSexualContent = value),
                          description: '성인 콘텐츠 표시 여부를 설정합니다',
                        ),
                        InfoToggle(
                          label: '폭력적인 자료',
                          value: _allowViolentContent,
                          onChanged: (value) => setState(() => _allowViolentContent = value),
                          description: '폭력적인 콘텐츠 표시 여부를 설정합니다',
                        ),
                        InfoToggle(
                          label: '혐오 자료',
                          value: _allowHateContent,
                          onChanged: (value) => setState(() => _allowHateContent = value),
                          description: '혐오 표현이 포함된 콘텐츠 표시 여부를 설정합니다',
                        ),
                      ],
                    ),

                    // 내 플레이스 섹션
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/my-places');
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '내 플레이스',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '등록한 플레이스를 관리합니다',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 저장/로그아웃 버튼
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '변경사항 저장',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '로그아웃',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 관리자 도구 버튼 (개발/디버그용)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/admin-cleanup');
                              },
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('관리자 도구'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }
}
