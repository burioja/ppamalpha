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
      // 로그인 성공 시 메인 화면으로 이동
      if (userCredential.user != null) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 이미지와 텍스트
            Column(
              children: [
                const SizedBox(height: 60), // 상단 여백
                Image.asset(
                  'assets/images/logo.png', // 올바른 경로
                  width: 150,
                  height: 150,
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 80), // 아이콘과 로그인 영역 사이의 여백

            // 이메일 입력 창
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF4D4DFF), width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF4D4DFF), width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF4D4DFF), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 비밀번호 입력 창
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),

            // 로그인 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _login,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4D4DFF)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4D4DFF),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 회원가입 버튼
            SizedBox(
              width: double.infinity,
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white, // 텍스트 색상 지정
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 이메일 찾기, 비밀번호 찾기, 회원가입하기 텍스트 버튼
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
          ],
        ),
      ),
    );
  }
}
