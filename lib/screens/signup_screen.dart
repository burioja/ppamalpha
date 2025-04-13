import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/address_search_widget.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _nickName = TextEditingController();
  String _selectedCountryCode = "+82";
  List<Map<String, String>> _countryCodes = [];
  String? _selectedYear;
  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedGender;
  List<bool> _isChecked = List.generate(5, (_) => false);
  File? _profileImage;

  bool get _buttonActive => _isChecked[1] && _isChecked[2] && _isChecked[3];

  @override
  void initState() {
    super.initState();
    _loadCountryCodes();
  }

  Future<void> _loadCountryCodes() async {
    String jsonString = await rootBundle.loadString('assets/country_codes.json');
    List<dynamic> jsonResponse = json.decode(jsonString);
    setState(() {
      _countryCodes = jsonResponse.map((item) => {
        "code": item["code"].toString(),
        "name": item["name"].toString()
      }).toList();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImage == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('user_profiles').child('$userId.jpg');
      await ref.putFile(_profileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('이미지 업로드 실패: $e');
      return null;
    }
  }

  Future<void> _signup() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: userProvider.email.trim(),
        password: _passwordController.text.trim(),
      );
      final User? user = userCredential.user;
      if (user != null) {
        final profileImageUrl = await _uploadProfileImage(user.uid);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': userProvider.email.trim(),
          'phoneNumber': userProvider.phoneNumber.trim(),
          'address': userProvider.address.trim(),
          'birthDate': '$_selectedYear-$_selectedMonth-$_selectedDay',
          'gender': _selectedGender,
          'workPlaces': userProvider.workPlaces,
          'nickName': userProvider.nickName.trim(),
          'profileImageUrl': profileImageUrl,
          'createdAt': Timestamp.now(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print('회원가입 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 실패. 다시 시도해주세요.')),
      );
    }
  }

  void _updateCheckState(int index) {
    setState(() {
      if (index == 0) {
        bool isAllChecked = !_isChecked.every((element) => element);
        _isChecked = List.generate(5, (index) => isAllChecked);
      } else {
        _isChecked[index] = !_isChecked[index];
        _isChecked[0] = _isChecked.getRange(1, 5).every((element) => element);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF4D4DFF),
            onPrimary: Colors.white,
            secondary: const Color(0xFF4D4DFF),
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep++;
              });
            } else {
              _signup();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            }
          },
          steps: [
            Step(
              title: const Text("기본 정보"),
              content: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.camera_alt, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(labelText: '이메일'),
                    onChanged: userProvider.setEmail,
                  ),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호'),
                  ),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호 확인'),
                  ),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "성별"),
                    value: _selectedGender,
                    items: const [
                      DropdownMenuItem(value: "남성", child: Text("남성")),
                      DropdownMenuItem(value: "여성", child: Text("여성")),
                    ],
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text("추가 정보"),
              content: TextField(
                decoration: const InputDecoration(labelText: '닉네임'),
                onChanged: userProvider.setNickName,
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text("약관 동의"),
              content: Column(
                children: List.generate(5, (index) => renderContainer(
                  _isChecked[index],
                  [
                    '모두 동의',
                    '만 14세 이상입니다.(필수)',
                    '개인정보처리방침(필수)',
                    '서비스 이용 약관(필수)',
                    '이벤트 및 할인 혜택 안내 동의(선택)',
                  ][index],
                      () => _updateCheckState(index),
                )),
              ),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget renderContainer(bool checked, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: checked ? Colors.blue : Colors.grey, width: 2.0),
                color: checked ? Colors.blue : Colors.white,
              ),
              child: Icon(Icons.check, color: checked ? Colors.white : Colors.grey, size: 18),
            ),
            const SizedBox(width: 15),
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}