import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController(); // 주소 입력용 컨트롤러

  // 회원가입 로직
  Future<void> _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);

    try {
      // 1. Firebase Auth에 사용자 생성
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: userProvider.email.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        // 2. Firestore에 사용자 정보 저장
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': userProvider.email.trim(),
          'phoneNumber': userProvider.phoneNumber.trim(),
          'address': userProvider.address.trim(),
          'workPlaces': userProvider.workPlaces,
          'createdAt': Timestamp.now(), // 생성 시간 저장
        });

        // Firestore 저장 성공 후 상태 업데이트
        userProvider.setEmail(userProvider.email.trim());
        userProvider.setPhoneNumber(userProvider.phoneNumber.trim());
        userProvider.setAddress(userProvider.address.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );

        // 회원가입 완료 후 메인 화면으로 이동
        Navigator.pushReplacementNamed(context, '/main');
      }
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
        child: ConstrainedBox( // 추가된 코드
          constraints: const BoxConstraints(
            minHeight: 600, // 최소 높이를 설정하여 레이아웃 충돌 방지
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이메일 입력
                TextField(
                  decoration: const InputDecoration(labelText: '이메일'),
                  onChanged: userProvider.setEmail,
                ),
                const SizedBox(height: 10),

                // 비밀번호 입력
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                ),
                const SizedBox(height: 10),

                // 비밀번호 확인
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호 확인'),
                ),
                const SizedBox(height: 10),

                // 핸드폰 번호 입력
                TextField(
                  decoration: const InputDecoration(labelText: '핸드폰 번호'),
                  onChanged: userProvider.setPhoneNumber,
                ),
                const SizedBox(height: 10),

                // 주소 입력
                SizedBox(
                  height: 60, // 높이를 명시적으로 설정
                  child: AddressSearchWidget(
                    onAddressSelected: (selectedAddress) {
                      userProvider.setAddress(selectedAddress);
                      _addressController.text = selectedAddress; // TextField에 반영
                    },
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '주소sdf',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // Workplace 입력
                Column(
                  children: List.generate(userProvider.workPlaces.length, (index) {
                    return Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: '일터 입력'),
                            onChanged: (value) {
                              userProvider.updateWorkPlace(index, 'workplaceinput', value);
                            },
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(labelText: '일터 추가'),
                            onChanged: (value) {
                              userProvider.updateWorkPlace(index, 'workplaceadd', value);
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
                  onPressed: userProvider.addWorkPlace,
                ),
                const SizedBox(height: 20),

                // 회원가입 버튼
                ElevatedButton(
                  onPressed: _signup,
                  child: const Text("회원가입"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  }