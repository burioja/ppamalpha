import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({Key? key}) : super(key: key);

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<String> _groupData = []; // 3번째 그룹의 데이터
  bool _isLoading = true; // 로딩 상태

  @override
  void initState() {
    super.initState();
    _fetchUserWorkplaceData();
  }

  Future<void> _fetchUserWorkplaceData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print("사용자가 로그인되어 있지 않습니다.");
        return;
      }

      final userId = user.email;
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userId)
          .get();

      if (userSnapshot.docs.isEmpty) {
        print("사용자를 찾을 수 없습니다.");
        return;
      }

      // 사용자 워크플레이스 ID 가져오기
      final workplaceId = userSnapshot.docs.first.data()['workplaceinput'] ?? '';
      final workplaceSnapshot = await FirebaseFirestore.instance
          .collection('workplaces')
          .doc(workplaceId)
          .get();

      if (!workplaceSnapshot.exists) {
        print("해당 워크플레이스가 존재하지 않습니다.");
        return;
      }

      // 워크플레이스 데이터에서 그룹 정보를 가져오기
      final workplaceData = workplaceSnapshot.data();
      if (workplaceData == null || !workplaceData.containsKey('groupdata3')) {
        print("워크플레이스 데이터가 없습니다.");
        return;
      }

      // 3번째 그룹 데이터 가져오기
      _groupData = List<String>.from(workplaceData['groupdata3'] ?? []);
    } catch (e) {
      print("데이터를 가져오는 중 오류 발생: $e");
    } finally {
      setState(() {
        _isLoading = false; // 로딩 완료
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Status Screen")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupData.isEmpty
          ? const Center(child: Text("데이터가 없습니다."))
          : SingleChildScrollView(
        scrollDirection: Axis.horizontal, // 수평 스크롤 설정
        child: Row(
          children: _groupData.map((item) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8), // 항목 간격
              padding: const EdgeInsets.all(16), // 패딩 추가
              decoration: BoxDecoration(
                color: Colors.blue, // 배경 색상
                borderRadius: BorderRadius.circular(8), // 테두리 둥글게
              ),
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 24),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}