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
  int _currentStep = 0; // 현재 Step 상태 변수 추가
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

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
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: userProvider.email.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': userProvider.email.trim(),
          'phoneNumber': userProvider.phoneNumber.trim(),
          'address': userProvider.address.trim(),
          'workPlaces': userProvider.workPlaces,
          'createdAt': Timestamp.now(),
        });

        userProvider.setEmail(userProvider.email.trim());
        userProvider.setPhoneNumber(userProvider.phoneNumber.trim());
        userProvider.setAddress(userProvider.address.trim());

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

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF4D4DFF), // 활성화된 스텝 색상
            onPrimary: Colors.white, // 활성화된 스텝 아이콘 내부 색상
            secondary: const Color(0xFF4D4DFF), // 비활성화된 스텝 색상
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          elevation: 10,
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
              content: SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: '이메일'),
                        onChanged: userProvider.setEmail,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '비밀번호 확인'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: const InputDecoration(labelText: '핸드폰 번호'),
                        onChanged: userProvider.setPhoneNumber,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 60,
                        child: AddressSearchWidget(
                          onAddressSelected: (selectedAddress) {
                            userProvider.setAddress(selectedAddress);
                            _addressController.text = selectedAddress;
                          },
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: '주소',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text("추가 정보"),
              content: SizedBox(
                height: 250,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Column(
                        children: List.generate(
                          userProvider.workPlaces.length,
                              (index) => Row(
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
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: userProvider.addWorkPlace,
                      ),
                    ],
                  ),
                ),
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text("완료"),
              content: const Center(child: Text("회원가입 완료 단계")),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }
}
