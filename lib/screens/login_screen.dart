import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (userCredential.user != null) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end, // 아래부터 채우기
          children: [
            Expanded(
              flex: 3, // 로고가 있는 영역
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png', // 올바른 경로
                  width: 150,
                  height: 150,
                ),
              ),
            ),
            Expanded(
              flex: 2, // 입력 필드 & 버튼
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    // 이메일 입력 창
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력 창
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 로그인 버튼
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4D4DFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '로그인',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12), // 버튼 사이 간격
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4D4DFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '가입하기',
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 이메일 찾기, 비밀번호 찾기 텍스트 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TextButton(
                          onPressed: () {
                            // 이메일 찾기 구현
                          },
                          child: const Text(
                            '이메일 찾기',
                            style: TextStyle(color: Color(0xFF4D4DFF)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // 비밀번호 찾기 구현
                          },
                          child: const Text(
                            '비밀번호 찾기',
                            style: TextStyle(color: Color(0xFF4D4DFF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30), // 바닥에서 살짝 띄움
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
