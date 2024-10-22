import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../provider/workplace_provider.dart'; // Provider 경로

class StatusScreen extends StatefulWidget {
  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<String> statusList = []; // 상태 목록
  int currentIndex = 0; // 현재 표시되는 인덱스
  int groupIndex = 0; // 현재 group의 인덱스 (상하 스크롤)
  String? userEmail; // 로그인한 사용자의 이메일
  Color? backgroundColor; // 배경 색상
  bool isMultipleWorkplaces = false; // 여러 개의 workplace 여부

  @override
  void initState() {
    super.initState();
    fetchUserEmail(); // 사용자 이메일 가져오기
  }

  Future<void> fetchUserEmail() async {
    User? user = FirebaseAuth.instance.currentUser; // 현재 로그인한 사용자 가져오기
    if (user != null) {
      setState(() {
        userEmail = user.email; // 이메일 저장
      });
      fetchWorkplaceData(); // 데이터 불러오기
    } else {
      setState(() {
        statusList = ['로그인 정보가 없습니다.']; // 에러 메시지
      });
    }
  }

  Future<void> fetchWorkplaceData() async {
    if (userEmail == null) return; // 이메일이 없으면 종료

    // users 컬렉션에서 이메일을 기준으로 문서 가져오기
    QuerySnapshot userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail) // 이메일로 쿼리
        .get();

    if (userQuery.docs.isEmpty) {
      setState(() {
        statusList = ['사용자 문서가 존재하지 않습니다.']; // 에러 메시지
      });
      return;
    }

    DocumentSnapshot userDoc = userQuery.docs.first;

    // workplaceinput과 workplaces 배열 불러오기
    List<Map<String, dynamic>>? workplaceArray = userDoc.data()?.containsKey('workplaces') == true
        ? userDoc['workplaces'] as List<Map<String, dynamic>>
        : null;

    String? workplaceInput = userDoc.data()?.containsKey('workplaceinput') == true
        ? userDoc['workplaceinput'] as String?
        : null;

    String? workplaceAdd = userDoc.data()?.containsKey('workplaceadd') == true
        ? userDoc['workplaceadd'] as String?
        : null;

    // workplaceinput이 없을 경우
    if (workplaceArray == null || workplaceArray.isEmpty) {
      setState(() {
        statusList = ['customer']; // 표시할 텍스트
      });
      return;
    }

    // workplaceinput이 있을 경우
    if (workplaceArray.isNotEmpty) {
      setState(() {
        isMultipleWorkplaces = workplaceArray.length > 1; // 여러 개의 workplace 여부 체크
        statusList = []; // 상태 리스트 초기화
        backgroundColor = generateRandomColor(); // 랜덤 배경색 설정

        for (var workplace in workplaceArray) {
          String workplaceId = workplace['workplaceinput'] ?? '';
          String workplaceInfo = '${workplaceId} ${workplace['workplaceadd'] ?? ''}';
          // workplaces에서 ID에 해당하는 데이터 조회
          fetchWorkplaceDetails(workplaceId, workplaceInfo);
        }
      });
    }
  }

  Future<void> fetchWorkplaceDetails(String workplaceId, String workplaceInfo) async {
    // workplaces 컬렉션에서 문서 ID가 workplaceId와 일치하는 항목 가져오기
    DocumentSnapshot workplaceDoc = await FirebaseFirestore.instance
        .collection('workplaces')
        .doc(workplaceId) // 문서 ID로 접근
        .get();

    if (workplaceDoc.exists) {
      String groupData1 = workplaceDoc['groupdata1'] ?? '';
      String groupData2 = workplaceDoc['groupdata2'] ?? '';
      String groupData3 = workplaceDoc['groupdata3'] ?? '';

      setState(() {
        statusList.add('$groupData1 - $groupData2 - $groupData3 - $workplaceInfo');
        // 각 workplace에 대한 정보를 추가
      });
    }
  }

  // 랜덤 색상 생성
  Color generateRandomColor() {
    Random random = Random();
    return Color.fromARGB(
      255, // 불투명
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 workplaceInput 값 가져오기
    String? workplaceInput = Provider.of<WorkplaceProvider>(context).workplaceInput;

    return Container(
      color: backgroundColor ?? Colors.white, // 배경 색상
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 좌우 스크롤
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  if (currentIndex > 0) {
                    currentIndex--; // 이전 인덱스로 이동
                  }
                });
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Text(
                isMultipleWorkplaces && statusList.isNotEmpty
                    ? statusList[currentIndex]
                    : statusList.isNotEmpty ? statusList[0] : 'customer',
                style: TextStyle(fontSize: 16),
              ),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () {
                setState(() {
                  if (currentIndex < statusList.length - 1) {
                    currentIndex++; // 다음 인덱스로 이동
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
