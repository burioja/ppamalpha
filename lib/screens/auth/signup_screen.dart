import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/data/place_service.dart';
import '../../core/models/place/place_model.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  
  // 1단계: 개인정보 입력
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emailVerificationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phoneVerificationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _addressDetailController = TextEditingController(); // 상세주소 별도 관리
  GeoPoint? _homeLocation; // 집 주소 좌표 저장

  String? _selectedCountryCode = '+82';
  String? _selectedGender = 'male';
  int _selectedYear = 2000;
  int _selectedMonth = 1;
  int _selectedDay = 1;
  
  bool _isEmailVerified = false;
  bool _isPhoneVerified = false;
  bool _isEmailVerifying = false;
  bool _isPhoneVerifying = false;
  String _emailVerificationCode = '';
  String _phoneVerificationCode = '';
  
  // 2단계: 추가정보 입력
  final TextEditingController _nicknameController = TextEditingController();
  // 단일 일터 정보
  final TextEditingController _workplaceNameController = TextEditingController();
  final TextEditingController _workplaceAddressController = TextEditingController();
  final TextEditingController _workplaceAddressDetailController = TextEditingController(); // 일터 상세주소
  GeoPoint? _workplaceLocation; // 일터 위치 정보
  
  bool _allowSexualContent = false;
  bool _allowViolentContent = false;
  bool _allowHateContent = false;
  
  // 3단계: 약관 동의
  bool _serviceTermsAgreed = false;
  bool _privacyPolicyAgreed = false;
  bool _locationAgreed = false;
  bool _thirdPartyAgreed = false;
  
  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _emailController.dispose();
    _emailVerificationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _phoneVerificationController.dispose();
    _addressController.dispose();
    _addressDetailController.dispose();
    _nicknameController.dispose();
    _workplaceNameController.dispose();
    _workplaceAddressController.dispose();
    _workplaceAddressDetailController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_emailController.text.trim().isEmpty) {
      _showToast('이메일을 입력해주세요');
      return;
    }

    // 이메일 형식 검증
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showToast('올바른 이메일 형식이 아닙니다');
      return;
    }
    
    setState(() {
      _isEmailVerifying = true;
    });
    
    // 이메일 중복 확인
    // Note: fetchSignInMethodsForEmail is deprecated
    // Email uniqueness will be checked during actual account creation
    
    // 인증번호 생성 및 발송 (실제로는 이메일 서비스 사용)
    _emailVerificationCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    
    // 시뮬레이션: 실제로는 이메일 발송
    await Future.delayed(const Duration(seconds: 1));
    
    _showToast('인증번호가 발송되었습니다: $_emailVerificationCode');
    setState(() {
      _isEmailVerifying = false;
    });
  }

  void _verifyEmailCode() {
    if (_emailVerificationController.text.trim() == _emailVerificationCode) {
      setState(() {
        _isEmailVerified = true;
      });
      _showToast('이메일 인증이 완료되었습니다');
    } else {
      _showToast('인증번호가 일치하지 않습니다');
    }
  }

  Future<void> _sendPhoneVerification() async {
    if (_phoneController.text.trim().isEmpty) {
      _showToast('전화번호를 입력해주세요');
      return;
    }
    
    setState(() {
      _isPhoneVerifying = true;
    });
    
    // 인증번호 생성 및 발송 (실제로는 SMS 서비스 사용)
    _phoneVerificationCode = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    
    // 시뮬레이션: 실제로는 SMS 발송
    await Future.delayed(const Duration(seconds: 1));
    
    _showToast('인증번호가 발송되었습니다: $_phoneVerificationCode');
    setState(() {
      _isPhoneVerifying = false;
    });
  }

  void _verifyPhoneCode() {
    if (_phoneVerificationController.text.trim() == _phoneVerificationCode) {
      setState(() {
        _isPhoneVerified = true;
      });
      _showToast('전화번호 인증이 완료되었습니다');
    } else {
      _showToast('인증번호가 일치하지 않습니다');
    }
  }

  Future<void> _pickAddress() async {
    // 주소 검색 화면으로 이동
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // 주소와 상세주소를 분리하여 저장
        _addressController.text = result['address']?.toString() ?? '';
        _addressDetailController.text = result['detailAddress']?.toString() ?? '';

        // 좌표 정보 저장 (geocoding 불필요하도록)
        if (result['lat'] != null && result['lon'] != null) {
          _homeLocation = GeoPoint(
            double.parse(result['lat'].toString()),
            double.parse(result['lon'].toString()),
          );
          debugPrint('📍 집 주소 좌표 저장: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
        }
      });
    }
  }

  Future<void> _pickWorkplaceAddress() async {
    // 근무지 주소 검색 화면으로 이동
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        // 주소와 상세주소를 분리하여 저장
        _workplaceAddressController.text = result['address']?.toString() ?? '';
        _workplaceAddressDetailController.text = result['detailAddress']?.toString() ?? '';

        // 위도/경도 정보 저장
        if (result['lat'] != null && result['lon'] != null) {
          _workplaceLocation = GeoPoint(
            double.parse(result['lat'].toString()),
            double.parse(result['lon'].toString()),
          );
          debugPrint('📍 일터 주소 좌표 저장: ${_workplaceLocation!.latitude}, ${_workplaceLocation!.longitude}');
        }
      });
    }
  }

  // 일터 추가/제거 기능 제거 (단일 일터만 지원)

  Future<void> _checkNicknameDuplicate() async {
    if (_nicknameController.text.trim().isEmpty) {
      _showToast('닉네임을 입력해주세요');
      return;
    }
    
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: _nicknameController.text.trim())
          .get();
      
      if (query.docs.isNotEmpty) {
        _showToast('이미 사용 중인 닉네임입니다');
      } else {
        _showToast('사용 가능한 닉네임입니다');
      }
    } catch (e) {
      _showToast('닉네임 중복 확인 중 오류가 발생했습니다');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _validateStep1() {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      _showToast('모든 필드를 입력해주세요');
      return false;
    }
    
    if (!_isEmailVerified) {
      _showToast('이메일 인증을 완료해주세요');
      return false;
    }
    
    if (!_isPhoneVerified) {
      _showToast('전화번호 인증을 완료해주세요');
      return false;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showToast('비밀번호가 일치하지 않습니다');
      return false;
    }
    
    return true;
  }

  bool _validateStep2() {
    if (_nicknameController.text.trim().isEmpty) {
      _showToast('닉네임을 입력해주세요');
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (!_serviceTermsAgreed || !_privacyPolicyAgreed || !_locationAgreed) {
      _showToast('필수 약관에 동의해주세요');
      return false;
    }
    return true;
  }

  Future<void> _registerUser() async {
    try {
      // Firebase Auth로 계정 생성
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userId = credential.user!.uid;
      String? workplaceId;

      // 일터 정보가 있으면 플레이스로 자동 생성
      if (_workplaceNameController.text.trim().isNotEmpty &&
          _workplaceAddressController.text.trim().isNotEmpty) {

        final placeService = PlaceService();

        // 플레이스 모델 생성 (회원가입 일터는 인증됨)
        final newPlace = PlaceModel(
          id: '', // Firestore가 자동 생성
          name: _workplaceNameController.text.trim(),
          description: '${_nicknameController.text.trim()}님의 일터',
          address: _workplaceAddressController.text.trim(), // 기본 주소만
          detailAddress: _workplaceAddressDetailController.text.trim(), // 상세주소 분리
          location: _workplaceLocation,
          createdBy: userId,
          createdAt: DateTime.now(),
          isActive: true,
          isVerified: true, // 👈 회원가입 일터는 인증됨
        );

        // 플레이스 생성
        workplaceId = await placeService.createPlace(newPlace);
      }

      // Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': _emailController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'phone': '$_selectedCountryCode${_phoneController.text.trim()}',
        'address': _addressController.text.trim(), // 기본 주소만 저장
        'secondAddress': _addressDetailController.text.trim(), // 상세주소 별도 저장
        'homeLocation': _homeLocation, // 집 좌표 저장 (geocoding 불필요)
        'gender': _selectedGender,
        'birthDate': '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}',
        'workplaceId': workplaceId, // 단일 일터 ID
        'allowSexualContent': _allowSexualContent,
        'allowViolentContent': _allowViolentContent,
        'allowHateContent': _allowHateContent,
        'serviceTermsAgreed': _serviceTermsAgreed,
        'privacyPolicyAgreed': _privacyPolicyAgreed,
        'locationAgreed': _locationAgreed,
        'thirdPartyAgreed': _thirdPartyAgreed,
        'createdAt': FieldValue.serverTimestamp(),
        'profileImageUrl': _profileImage?.path,
      });

      _showToast('회원가입이 완료되었습니다');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      _showToast('회원가입 중 오류가 발생했습니다: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('회원가입 ${_currentStep + 1}/3'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // 스크롤로 페이지 넘어가는 것 방지
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Text('이전'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep == 0 && _validateStep1()) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (_currentStep == 1 && _validateStep2()) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (_currentStep == 2 && _validateStep3()) {
                    _registerUser();
                  }
                },
                child: Text(_currentStep == 2 ? '가입 완료' : '다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '개인정보 입력',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 이메일 입력
          const Text('이메일 (아이디)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: '이메일을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이메일을 입력하세요';
                    }
                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isEmailVerifying ? null : _sendEmailVerification,
                child: Text(_isEmailVerifying ? '발송중...' : '인증'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 이메일 인증번호 입력
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailVerificationController,
                  decoration: const InputDecoration(
                    hintText: '인증번호 입력',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _verifyEmailCode,
                child: const Text('확인'),
              ),
            ],
          ),
          if (_isEmailVerified)
            const Text('✅ 이메일 인증 완료', style: TextStyle(color: Colors.green)),
          const SizedBox(height: 16),
          
          // 비밀번호 입력
          const Text('비밀번호', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              hintText: '비밀번호를 입력하세요',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          
          // 비밀번호 확인
          TextFormField(
            controller: _confirmPasswordController,
            decoration: const InputDecoration(
              hintText: '비밀번호를 다시 입력하세요',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          if (_passwordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty)
            Text(
              _passwordController.text == _confirmPasswordController.text 
                ? '✅ 비밀번호가 일치합니다' 
                : '❌ 비밀번호가 일치하지 않습니다',
              style: TextStyle(
                color: _passwordController.text == _confirmPasswordController.text 
                  ? Colors.green 
                  : Colors.red,
              ),
            ),
          const SizedBox(height: 16),
          
          // 전화번호 입력
          const Text('전화번호', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              DropdownButton<String>(
                value: _selectedCountryCode,
                items: const [
                  DropdownMenuItem(value: '+82', child: Text('+82')),
                  DropdownMenuItem(value: '+1', child: Text('+1')),
                  DropdownMenuItem(value: '+81', child: Text('+81')),
                ],
                onChanged: (value) => setState(() => _selectedCountryCode = value),
                hint: const Text('국가코드'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    hintText: '전화번호를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isPhoneVerifying ? null : _sendPhoneVerification,
                child: Text(_isPhoneVerifying ? '발송중...' : '인증'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 전화번호 인증번호 입력
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneVerificationController,
                  decoration: const InputDecoration(
                    hintText: '인증번호 입력',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _verifyPhoneCode,
                child: const Text('확인'),
              ),
            ],
          ),
          if (_isPhoneVerified)
            const Text('✅ 전화번호 인증 완료', style: TextStyle(color: Colors.green)),
          const SizedBox(height: 16),
          
          // 생년월일 입력
          const Text('생년월일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedYear,
                  items: List.generate(100, (index) => 2024 - index)
                      .map((year) => DropdownMenuItem(value: year, child: Text('$year년')))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedYear = value!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedMonth,
                  items: List.generate(12, (index) => index + 1)
                      .map((month) => DropdownMenuItem(value: month, child: Text('$month월')))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedMonth = value!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedDay,
                  items: List.generate(31, (index) => index + 1)
                      .map((day) => DropdownMenuItem(value: day, child: Text('$day일')))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedDay = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 성별 선택
          const Text('성별', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = 'male'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'male' ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '남성',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedGender = 'female'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedGender == 'female' ? Colors.pink : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '여성',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 주소 입력
          const Text('주소', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: '주소를 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _pickAddress,
                child: const Text('주소 검색'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추가정보 입력',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 프로필 이미지
          const Text('프로필 이미지', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null
                    ? const Icon(Icons.camera_alt, size: 50, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // 닉네임 입력
          const Text('닉네임', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    hintText: '닉네임을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _checkNicknameDuplicate,
                child: const Text('중복확인'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 일터 정보 (단일 입력)
          const Text('일터 정보 (선택사항)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _workplaceNameController,
            decoration: const InputDecoration(
              labelText: '일터 이름',
              hintText: '예: 카페 ABC',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _workplaceAddressController,
                  decoration: const InputDecoration(
                    labelText: '일터 주소',
                    hintText: '주소를 검색하세요',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _pickWorkplaceAddress,
                child: const Text('주소 검색'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '※ 일터를 등록하면 자동으로 플레이스가 생성되어 인증됩니다.',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          ),
          
          const SizedBox(height: 24),
          
          // 콘텐츠 필터 설정
          const Text('콘텐츠 필터 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          
          // 선정적인 자료
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('선정적인 자료'),
              Switch(
                value: _allowSexualContent,
                onChanged: (value) => setState(() => _allowSexualContent = value),
              ),
            ],
          ),
          
          // 폭력적인 자료
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('폭력적인 자료'),
              Switch(
                value: _allowViolentContent,
                onChanged: (value) => setState(() => _allowViolentContent = value),
              ),
            ],
          ),
          
          // 혐오 자료
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('혐오 자료'),
              Switch(
                value: _allowHateContent,
                onChanged: (value) => setState(() => _allowHateContent = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '약관 동의',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 서비스 약관 동의
          _buildAgreementItem(
            '서비스 약관 동의',
            _serviceTermsAgreed,
            (value) => setState(() => _serviceTermsAgreed = value),
            true,
          ),
          
          // 개인정보 수집 및 이용동의
          _buildAgreementItem(
            '개인정보 수집 및 이용동의',
            _privacyPolicyAgreed,
            (value) => setState(() => _privacyPolicyAgreed = value),
            true,
          ),
          
          // 위치정보 수집 및 서비스 이용동의
          _buildAgreementItem(
            '위치정보 수집 및 서비스 이용동의',
            _locationAgreed,
            (value) => setState(() => _locationAgreed = value),
            true,
          ),
          
          // 제3자 정보제공 이용동의
          _buildAgreementItem(
            '제3자 정보제공 이용동의',
            _thirdPartyAgreed,
            (value) => setState(() => _thirdPartyAgreed = value),
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementItem(String title, bool value, Function(bool) onChanged, bool required) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title + (required ? ' (필수)' : ' (선택)'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // 약관 원문 보기
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(title),
                        content: const Text('약관 내용이 여기에 표시됩니다.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('원문보기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}