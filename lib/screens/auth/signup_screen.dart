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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _selectedGender;
  int _currentStep = 0;
  final List<bool> _isChecked = List.generate(5, (index) => false);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
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
            if (_currentStep < 2) {
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
                    controller: _emailController,
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _validatePasswords(),
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
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
                    '만14세 이상입니다(필수)',
                    '개인정보처리방침(필수)',
                    '마케팅 정보 이용 동의(선택)',
                    '이벤트 및 프로모션 알림 동의(선택)',
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