import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/user_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;
  
  // 기본 정보
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  
  // 개인 정보
  String? _selectedGender;
  final TextEditingController _birthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _secondAddressController = TextEditingController();
  
  // 계정 정보
  final TextEditingController _accountController = TextEditingController();
  
  // 워크플레이스 정보
  final List<Map<String, String>> _workplaces = [];
  final TextEditingController _workplaceNameController = TextEditingController();
  final TextEditingController _workplaceAddressController = TextEditingController();
  
  int _currentStep = 0;
  final List<bool> _isChecked = List.generate(5, (index) => false);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nicknameController.dispose();
    _phoneNumberController.dispose();
    _birthController.dispose();
    _addressController.dispose();
    _secondAddressController.dispose();
    _accountController.dispose();
    _workplaceNameController.dispose();
    _workplaceAddressController.dispose();
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

  void _updateCheckState(int index) {
    setState(() {
      _isChecked[index] = !_isChecked[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.blue),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 4) {
              setState(() {
                _currentStep++;
              });
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
                  // 프로필 이미지
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
                  
                  // 이메일 (필수)
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: '이메일 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '이메일을 입력해주세요';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return '올바른 이메일 형식을 입력해주세요';
                      }
                      return null;
                    },
                    onChanged: userProvider.setEmail,
                  ),
                  const SizedBox(height: 16),
                  
                  // 비밀번호 (필수)
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '비밀번호를 입력해주세요';
                      }
                      if (value.length < 6) {
                        return '비밀번호는 6자 이상이어야 합니다';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 비밀번호 확인 (필수)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '비밀번호 확인 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '비밀번호 확인을 입력해주세요';
                      }
                      if (value != _passwordController.text) {
                        return '비밀번호가 일치하지 않습니다';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text("개인 정보"),
              content: Column(
                children: [
                  // 닉네임 (필수)
                  TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: '닉네임 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '닉네임을 입력해주세요';
                      }
                      if (value.length < 2) {
                        return '닉네임은 2자 이상이어야 합니다';
                      }
                      return null;
                    },
                    onChanged: userProvider.setNickName,
                  ),
                  const SizedBox(height: 16),
                  
                  // 전화번호 (필수)
                  TextFormField(
                    controller: _phoneNumberController,
                    decoration: const InputDecoration(
                      labelText: '전화번호 *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '전화번호를 입력해주세요';
                      }
                      if (!RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$').hasMatch(value.replaceAll('-', ''))) {
                        return '올바른 전화번호 형식을 입력해주세요 (예: 010-1234-5678)';
                      }
                      return null;
                    },
                    onChanged: userProvider.setPhoneNumber,
                  ),
                  const SizedBox(height: 16),
                  
                  // 성별 (필수)
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "성별 *",
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedGender,
                    items: const [
                      DropdownMenuItem(value: "male", child: Text("남성")),
                      DropdownMenuItem(value: "female", child: Text("여성")),
                    ],
                    onChanged: (value) => setState(() => _selectedGender = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '성별을 선택해주세요';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 생년월일 (필수)
                  TextFormField(
                    controller: _birthController,
                    decoration: const InputDecoration(
                      labelText: '생년월일 * (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '생년월일을 입력해주세요';
                      }
                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                        return '올바른 형식으로 입력해주세요 (예: 1990-01-01)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text("주소 정보"),
              content: Column(
                children: [
                  // 주소 (필수)
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '주소 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '주소를 입력해주세요';
                      }
                      return null;
                    },
                    onChanged: userProvider.setAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // 상세주소 (선택)
                  TextFormField(
                    controller: _secondAddressController,
                    decoration: const InputDecoration(
                      labelText: '상세주소',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text("계정 정보"),
              content: Column(
                children: [
                  // 계좌번호 (필수)
                  TextFormField(
                    controller: _accountController,
                    decoration: const InputDecoration(
                      labelText: '계좌번호 * (리워드 지급용)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '계좌번호를 입력해주세요';
                      }
                      if (!RegExp(r'^\d{10,20}$').hasMatch(value.replaceAll('-', ''))) {
                        return '올바른 계좌번호를 입력해주세요';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text("약관 동의"),
              content: Column(
                children: List.generate(5, (index) => renderContainer(
                  _isChecked[index],
                  [
                    '모두 동의',
                    '만14세 이상입니다(필수)',
                    '개인정보처리방침(필수)',
                    '마케팅 정보 이용 동의(선택)',
                    '이벤트 및 프로모션 알림 동의(선택)',
                  ][index],
                      () => _updateCheckState(index),
                )),
              ),
              isActive: _currentStep >= 4,
            ),
          ],
        ),
      ),
    );
  }

  String _validatePasswords() {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
      return '이메일 형식이 올바르지 않습니다.';
    }
    if (pass.isNotEmpty && pass.length < 8) {
      return '비밀번호는 8자 이상이어야 합니다.';
    }
    if (confirm.isNotEmpty && confirm != pass) {
      return '비밀번호와 확인이 일치하지 않습니다.';
    }
    return '';
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