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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 중앙에 아이콘
              const Icon(Icons.lock, size: 100, color: Colors.blue),
              const SizedBox(height: 40),

              // 이메일 입력 창
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 20),

              // 비밀번호 입력 창
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
              ),
              const SizedBox(height: 20),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _login,
                child: const Text('로그인'),
              ),

              const SizedBox(height: 10),

              // 이메일 찾기, 비밀번호 찾기, 회원가입하기 텍스트 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      // 이메일 찾기 구현
                    },
                    child: const Text('이메일 찾기'),
                  ),
                  TextButton(
                    onPressed: () {
                      // 비밀번호 찾기 구현
                    },
                    child: const Text('비밀번호 찾기'),
                  ),
                  TextButton(
                    onPressed: () {
                      // 회원가입하기 화면으로 이동
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text('회원가입하기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
