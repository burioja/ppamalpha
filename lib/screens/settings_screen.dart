import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadUserData(); // 초기 데이터 로드
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData();
  }

  Future<void> _saveUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.updateUserData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('정보가 성공적으로 저장되었습니다.')),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로 이동
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("개인정보 수정")),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height, // 최소 높이 설정
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이메일 (수정 불가)
                  TextField(
                    controller: TextEditingController(text: userProvider.email),
                    decoration: const InputDecoration(
                      labelText: '이메일',
                      border: OutlineInputBorder(),
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 10),

                  // 핸드폰 번호
                  TextField(
                    controller: TextEditingController(text: userProvider.phoneNumber),
                    decoration: const InputDecoration(
                      labelText: '핸드폰 번호',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: userProvider.setPhoneNumber,
                  ),
                  const SizedBox(height: 10),

                  // 주소
                  TextField(
                    controller: TextEditingController(text: userProvider.address),
                    decoration: const InputDecoration(
                      labelText: '주소',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: userProvider.setAddress,
                  ),
                  const SizedBox(height: 10),

                  // Workplace 입력
                  Column(
                    children: List.generate(userProvider.workPlaces.length, (index) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceinput']),
                              decoration: const InputDecoration(labelText: '일터 입력'),
                              onChanged: (value) {
                                userProvider.updateWorkPlace(index, 'workplaceinput', value);
                              },
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceadd']),
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

                  // 저장 및 로그아웃 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _saveUserData,
                        child: const Text("저장"),
                      ),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("로그아웃"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
