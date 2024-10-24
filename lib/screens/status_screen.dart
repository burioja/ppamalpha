import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../provider/statusProvider.dart'; // 프로바이더 import

class StatusScreen extends StatefulWidget {
  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<List<String>> workplaceDataList = []; // 직장 정보 목록 (그룹화)
  List<Color> colors = []; // 고정 색상 목록
  String? userEmail; // 로그인한 사용자의 이메일
  late PageController _verticalPageController;

  @override
  void initState() {
    super.initState();
    fetchUserEmail(); // 사용자 이메일 가져오기
    _verticalPageController = PageController(); // 세로 페이지 컨트롤러 초기화
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
        workplaceDataList = [['로그인 정보가 없습니다.']]; // 에러 메시지
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
        workplaceDataList = [['사용자 문서가 존재하지 않습니다.']]; // 에러 메시지
      });
      return;
    }

    DocumentSnapshot userDoc = userQuery.docs.first;
    Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

    if (userData == null) {
      setState(() {
        workplaceDataList = [['사용자 문서에 데이터가 없습니다.']];
      });
      return;
    }

    // workplaceinput과 workplaceadd 배열 불러오기
    List<Map<String, dynamic>>? workplaceArray = List<Map<String, dynamic>>.from(userData['workPlaces'] ?? []);

    // workplaceinput이 없을 경우
    if (workplaceArray.isEmpty) {
      setState(() {
        workplaceDataList = [['사용자의 직장 정보가 없습니다.']]; // 에러 메시지
      });
      return;
    }

    // 직장 정보를 리스트에 추가
    for (var workplace in workplaceArray) {
      String workplaceId = workplace['workplaceinput'] ?? '';
      String workplaceAdd = workplace['workplaceadd'] ?? '';

      if (workplaceId.isNotEmpty) {
        // workplaceinput을 표시할 정보로 저장
        String workplaceInfo = '$workplaceId${workplaceAdd.isNotEmpty ? ' ($workplaceAdd)' : ''}';

        // 각 직장에 대한 데이터(가로 스크롤 아이템)를 가져오기
        List<String> groupData = await fetchGroupData(workplaceId);

        // workplaceinput을 추가
        groupData.add(workplaceInfo);

        workplaceDataList.add(groupData.isNotEmpty ? groupData : [workplaceInfo]); // 그룹 데이터 추가
        colors.add(getRandomColor()); // 고정 색상 추가
      }
    }

    // 결과 목록을 업데이트
    setState(() {
      Provider.of<StatusProvider>(context, listen: false).setWorkplaceDataList(workplaceDataList);
    });
  }

  Future<List<String>> fetchGroupData(String workplaceId) async {
    List<String> groupData = [];

    // workplaces 컬렉션에서 id 필드가 workplaceId와 일치하는 문서 가져오기
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('workplaces')
        .where('id', isEqualTo: workplaceId) // 'id' 필드와 비교
        .get();

    // 문서가 존재할 경우 데이터를 groupData에 추가
    for (var doc in querySnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      // groupdata1, groupdata2, groupdata3을 추가
      if (data['groupdata1'] != null) groupData.add(data['groupdata1']);
      if (data['groupdata2'] != null) groupData.add(data['groupdata2']);
      if (data['groupdata3'] != null) groupData.add(data['groupdata3']);
    }

    return groupData;
  }

  // 랜덤 색상 생성
  Color getRandomColor() {
    Random random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 배경 색상
      body: workplaceDataList.isNotEmpty
          ? PageView.builder(
        controller: _verticalPageController,
        scrollDirection: Axis.vertical, // 세로 스크롤 설정
        itemCount: workplaceDataList.length,
        physics: BouncingScrollPhysics(), // 세로 스크롤의 물리적 효과
        itemBuilder: (context, verticalIndex) {
          // 세로 스크롤할 때마다 해당 인덱스에 맞는 색상 적용
          Color backgroundColor = colors[verticalIndex % colors.length];

          return Container(
            decoration: BoxDecoration(
              color: backgroundColor, // 배경색 적용
              borderRadius: BorderRadius.circular(15), // 둥근 모서리 반경 설정
            ),
            child: Center(
              child: Container(
                height: 100,
                width: MediaQuery.of(context).size.width * 1.0, // 화면 너비의 100%로 설정
                decoration: BoxDecoration(
                  color: Colors.transparent, // 배경색을 투명하게 설정
                  borderRadius: BorderRadius.circular(15), // 둥근 모서리 반경 설정
                ),
                child: PageView.builder(
                  scrollDirection: Axis.horizontal, // 가로 스크롤 설정
                  itemCount: workplaceDataList[verticalIndex].length, // 현재 그룹의 아이템 수
                  physics: BouncingScrollPhysics(), // 가로 스크롤의 물리적 효과
                  controller: PageController(
                    initialPage: (workplaceDataList[verticalIndex].length > 0)
                        ? workplaceDataList[verticalIndex].length - 1 // 마지막 페이지로 설정
                        : 0, // 데이터가 없을 경우 0으로 설정
                    viewportFraction: 1.0, // 뷰포트 비율 설정
                  ),
                  itemBuilder: (context, horizontalIndex) {
                    // 현재 그룹의 데이터가 존재하는지 확인
                    if (horizontalIndex >= workplaceDataList[verticalIndex].length) {
                      return Container(); // 아이템이 없으면 빈 컨테이너 반환
                    }

                    // 현재 그룹의 데이터 표시
                    String currentItem = workplaceDataList[verticalIndex][horizontalIndex];

                    // 현재 아이템을 프로바이더에 설정
                    Provider.of<StatusProvider>(context, listen: false).setCurrentItem(currentItem);

                    return Container(
                      alignment: Alignment.center, // 항상 중앙에 오도록 설정
                      decoration: BoxDecoration(
                        color: Colors.transparent, // 배경색을 투명하게 설정
                        borderRadius: BorderRadius.circular(15), // 둥근 모서리 반경 설정
                      ),
                      child: Text(
                        currentItem, // 현재 그룹의 데이터 표시
                        style: TextStyle(color: Colors.white, fontSize: 18), // 텍스트 스타일
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      )
          : Center(
        child: Text(
          '정보가 없습니다.', // 정보가 없을 때 메시지
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }



}
