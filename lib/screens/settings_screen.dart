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
    _loadUserData(); // Ï¥àÍ∏∞ ?∞Ïù¥??Î°úÎìú
  }

  Future<void> _loadUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData();
  }

  Future<void> _saveUserData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.updateUserData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?ïÎ≥¥Í∞Ä ?±Í≥µ?ÅÏúºÎ°??Ä?•Îêò?àÏäµ?àÎã§.')),
    );
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login'); // Î°úÍ∑∏???îÎ©¥?ºÎ°ú ?¥Îèô
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Í∞úÏù∏?ïÎ≥¥ ?òÏ†ï")),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height, // ÏµúÏÜå ?íÏù¥ ?§Ï†ï
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ?¥Î©î??(?òÏ†ï Î∂àÍ?)
                  TextField(
                    controller: TextEditingController(text: userProvider.email),
                    decoration: const InputDecoration(
                      labelText: '?¥Î©î??,
                      border: OutlineInputBorder(),
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 10),

                  // ?∏Îìú??Î≤àÌò∏
                  TextField(
                    controller: TextEditingController(text: userProvider.phoneNumber),
                    decoration: const InputDecoration(
                      labelText: '?∏Îìú??Î≤àÌò∏',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: userProvider.setPhoneNumber,
                  ),
                  const SizedBox(height: 10),

                  // Ï£ºÏÜå
                  TextField(
                    controller: TextEditingController(text: userProvider.address),
                    decoration: const InputDecoration(
                      labelText: 'Ï£ºÏÜå',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: userProvider.setAddress,
                  ),
                  const SizedBox(height: 10),

                  // Workplace ?ÖÎ†•
                  Column(
                    children: List.generate(userProvider.workPlaces.length, (index) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceinput']),
                              decoration: const InputDecoration(labelText: '?ºÌÑ∞ ?ÖÎ†•'),
                              onChanged: (value) {
                                userProvider.updateWorkPlace(index, 'workplaceinput', value);
                              },
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(
                                  text: userProvider.workPlaces[index]['workplaceadd']),
                              decoration: const InputDecoration(labelText: '?ºÌÑ∞ Ï∂îÍ?'),
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

                  // ?Ä??Î∞?Î°úÍ∑∏?ÑÏõÉ Î≤ÑÌäº
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: _saveUserData,
                        child: const Text("?Ä??),
                      ),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Î°úÍ∑∏?ÑÏõÉ"),
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
