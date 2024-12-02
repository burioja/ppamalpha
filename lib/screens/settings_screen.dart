import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData();

    setState(() {
      _emailController.text = userProvider.email;
      _phoneController.text = userProvider.phoneNumber;
      _addressController.text = userProvider.address;
    });
  }

  Future<void> _updateUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    userProvider.setEmail(_emailController.text.trim());
    userProvider.setPhoneNumber(_phoneController.text.trim());
    userProvider.setAddress(_addressController.text.trim());

    await userProvider.updateUserData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정보가 성공적으로 업데이트되었습니다.')),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로 이동
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("개인정보 수정")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이메일
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 10),

              // 핸드폰 번호
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: '핸드폰 번호'),
              ),
              const SizedBox(height: 10),

              // 주소
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: '주소'),
              ),
              const SizedBox(height: 10),

              // 버튼 Row (정보 저장 + 로그아웃)
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _updateUserData,
                    child: const Text("정보 저장"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, // 로그아웃 버튼 색상
                    ),
                    child: const Text("로그아웃"),
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
