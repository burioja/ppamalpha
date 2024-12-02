import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // Firebase Auth로 계정 생성
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: userProvider.email.trim(),
        password: _passwordController.text.trim(),
      );

      // Firebase와 상태 업데이트
      await userProvider.updateUserData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 성공!')),
      );

      // 회원가입 성공 후 초기화
      Navigator.pop(context);
    } catch (e) {
      print('회원가입 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 실패. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 이메일 입력 창
              TextField(
                decoration: const InputDecoration(labelText: '이메일'),
                onChanged: (value) => userProvider.setEmail(value),
              ),

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

              // 4. 핸드폰 번호 입력 창
              TextField(
                decoration: const InputDecoration(labelText: '핸드폰 번호'),
                onChanged: (value) => userProvider.setPhoneNumber(value),
              ),

              // 5. 주소 입력 창
              TextField(
                decoration: const InputDecoration(labelText: '주소'),
                onChanged: (value) => userProvider.setAddress(value),
              ),

              // 6. 일터 입력
              Column(
                children: List.generate(userProvider.workPlaces.length, (index) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: '일터 입력'),
                          onChanged: (value) {
                            userProvider.workPlaces[index]['workplaceinput'] = value;
                            userProvider.notifyListeners();
                          },
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(labelText: '일터 추가'),
                          onChanged: (value) {
                            userProvider.workPlaces[index]['workplaceadd'] = value;
                            userProvider.notifyListeners();
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          userProvider.removeWorkPlace(index);
                        },
                      ),
                    ],
                  );
                }),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  userProvider.addWorkPlace();
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
