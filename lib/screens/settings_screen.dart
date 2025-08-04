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
    _loadUserData(); // 초기 ?�이??로드
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData();
  }

  Future<void> _saveUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.updateUserData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?�보가 ?�공?�으�??�?�되?�습?�다.')),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login'); // 로그???�면?�로 ?�동
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("개인?�보 ?�정")),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height, // 최소 ?�이 ?�정
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ?�메??(?�정 불�?)
                  TextField(
                    controller: TextEditingController(text: userProvider.email),
                    decoration: const InputDecoration(
                      labelText: '?�메??,
                      border: OutlineInputBorder(),
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 10),

                  // ?�드??번호
                  TextField(
                    controller: TextEditingController(text: userProvider.phoneNumber),
                    decoration: const InputDecoration(
                      labelText: '?�드??번호',
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

                  // Workplace ?�력
                  Column(
                    children: List.generate(userProvider.workPlaces.length, (index) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceinput']),
                              decoration: const InputDecoration(labelText: '?�터 ?�력'),
                              onChanged: (value) {
                                userProvider.updateWorkPlace(index, 'workplaceinput', value);
                              },
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceadd']),
                              decoration: const InputDecoration(labelText: '?�터 추�?'),
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

                  // ?�??�?로그?�웃 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _saveUserData,
                        child: const Text("?�??),
                      ),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("로그?�웃"),
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
