import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final List<TextEditingController> _workplaceinputControllers = [TextEditingController()];
  final List<TextEditingController> _workplaceaddControllers = [TextEditingController()];

  // 이메일 인증 및 핸드폰 인증 여부
  final bool _emailVerified = false;
  final bool _phoneVerified = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  void _verifyEmail() {
    // 이메일 인증 처리 로직
    // 이메일 인증 후 _emailVerified = true로 변경
  }

  void _verifyPhone() {
    // 핸드폰 인증 처리 로직
    // 핸드폰 인증 후 _phoneVerified = true로 변경
  }

  void _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      // 비밀번호 불일치 처리
      return;
    }

    try {
      // Firebase Auth로 계정 생성
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Firestore에 사용자 정보 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'workPlaces': List.generate(
          _workplaceinputControllers.length,
              (index) => {
            'workplaceinput': _workplaceinputControllers[index].text,
            'workplaceadd': _workplaceaddControllers[index].text,
          },
        ),
      });

      // 회원가입 성공 처리
    } catch (e) {
      // 에러 처리
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 이메일 입력 창 + 인증 버튼
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: '이메일',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _verifyEmail,  // 이메일 인증 처리
                  ),
                ),
              ),
              if (_emailVerified)
                const Text("이메일 인증 완료", style: TextStyle(color: Colors.green)),

              // 2. 비밀번호 입력 창
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),

              // 3. 비밀번호 확인 창
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
              ),
              if (_passwordController.text != _confirmPasswordController.text)
                const Text("비밀번호가 일치하지 않습니다.", style: TextStyle(color: Colors.red)),
              if (_passwordController.text == _confirmPasswordController.text && _passwordController.text.isNotEmpty)
                const Text("비밀번호 일치", style: TextStyle(color: Colors.green)),

              // 4. 핸드폰 번호 입력 창 + 인증 버튼
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: '핸드폰 번호',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _verifyPhone,  // 핸드폰 인증 처리
                  ),
                ),
              ),
              if (_phoneVerified)
                const Text("핸드폰 인증 완료", style: TextStyle(color: Colors.green)),

              // 5. 주소 입력 창
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: '주소'),
              ),

              // 6. 일터 입력 창 (추가/삭제 버튼) - workplaceinput과 workplaceadd 함께 입력
              Column(
                children: List.generate(_workplaceinputControllers.length, (index) {
                  return Row(
                    children: [
                      // workplaceinput 입력 필드
                      Expanded(
                        child: TextField(
                          controller: _workplaceinputControllers[index],
                          decoration: const InputDecoration(labelText: '일터 입력'),
                        ),
                      ),
                      // workplaceadd 입력 필드
                      Expanded(
                        child: TextField(
                          controller: _workplaceaddControllers[index],
                          decoration: const InputDecoration(labelText: '일터 추가'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _workplaceinputControllers.removeAt(index);
                            _workplaceaddControllers.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                }),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _workplaceinputControllers.add(TextEditingController());
                    _workplaceaddControllers.add(TextEditingController());
                  });
                },
              ),

              // 회원가입 버튼
              ElevatedButton(
                onPressed: _signup,
                child: const Text("회원가입"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
