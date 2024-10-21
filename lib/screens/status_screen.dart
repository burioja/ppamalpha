import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../provider/workplace_provider.dart'; // Provider 경로 수정

class StatusScreen extends StatefulWidget {
  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  List<String> statusList = []; // 상태 목록
  int currentIndex = 0; // 현재 표시되는 인덱스
  int groupIndex = 0; // 현재 group의 인덱스 (상하 스크롤)
  String? userEmail; // 로그인한 사용자의 이메일
  List<String> workplaceInputList = []; // workplaceinput 리스트
  bool isVerticalScroll = false; // 상하 스크롤 상태 확인용

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
      if (mounted) {
        setState(() {
          statusList = ['로그인 정보가 없습니다.']; // 에러 메시지
        });
      }
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
      if (mounted) {
        setState(() {
          statusList = ['사용자 문서가 존재하지 않습니다.']; // 에러 메시지
        });
      }
      return;
    }

    DocumentSnapshot userDoc = userQuery.docs.first;

    // 사용자 데이터에서 workplaceinput을 가져옴
    String? workplaceInput = userDoc['workplaceinput'] as String?;
    List<dynamic>? workplaceArray = userDoc['workplaces'] as List<dynamic>?;

    // workplaceinput이 있으면 workplaces 컬렉션에서 데이터 조회
    if (workplaceInput != null) {
      // workplaces 컬렉션에서 문서 ID가 workplaceinput과 일치하는 항목 가져오기
      QuerySnapshot workplaceQuery = await FirebaseFirestore.instance
          .collection('workplaces')
          .where('name', isEqualTo: workplaceInput)
          .get();

      if (workplaceQuery.docs.isNotEmpty) {
        DocumentSnapshot workplaceDoc = workplaceQuery.docs.first;

        // groupdata1, groupdata2, groupdata3 불러오기
        String groupData1 = workplaceDoc['groupdata1'] ?? '';
        String groupData2 = workplaceDoc['groupdata2'] ?? '';
        String groupData3 = workplaceDoc['groupdata3'] ?? '';

        // workplaceadd 가져오기
        String workplaceAdd = userDoc['workplaceadd'] ?? '';

        // 상태 리스트에 추가
        setState(() {
          statusList = [
            groupData1,
            groupData2,
            groupData3,
            '$workplaceInput $workplaceAdd'
          ];
        });

        // Provider에 현재 workplaceInput 저장
        Provider.of<WorkplaceProvider>(context, listen: false).setWorkplaceInput(workplaceInput);
      }
    }

    // workplaceinput 배열이 있을 때
    if (workplaceArray != null) {
      setState(() {
        workplaceInputList = workplaceArray.map((e) => e.toString()).toList();
      });
    }
  }

  // 좌우 스크롤 업데이트
  void updateHorizontalStatus(int delta) {
    if (statusList.isNotEmpty) {
      setState(() {
        currentIndex += delta;
        if (currentIndex < 0) {
          currentIndex = 0; // 처음이면 더 움직이지 않음
        } else if (currentIndex >= statusList.length) {
          currentIndex = statusList.length - 1; // 끝이면 더 움직이지 않음
        }
      });
    }
  }

  // 상하 스크롤 업데이트 (루프)
  void updateVerticalStatus(int delta) {
    if (workplaceInputList.isNotEmpty) {
      setState(() {
        groupIndex = (groupIndex + delta) % workplaceInputList.length;
        if (groupIndex < 0) {
          groupIndex += workplaceInputList.length; // 음수 인덱스 처리
        }
        String selectedWorkplaceInput = workplaceInputList[groupIndex];
        // workplaceinput을 기반으로 workplaces와 연관된 데이터를 불러옴
        fetchRelatedData(selectedWorkplaceInput);
      });
    }
  }

  // workplaceinput을 기반으로 workplaces와 연관된 데이터를 불러오는 함수
  Future<void> fetchRelatedData(String workplaceInput) async {
    QuerySnapshot workplaceQuery = await FirebaseFirestore.instance
        .collection('workplaces')
        .where('name', isEqualTo: workplaceInput)
        .get();

    if (workplaceQuery.docs.isNotEmpty) {
      DocumentSnapshot workplaceDoc = workplaceQuery.docs.first;
      String groupData1 = workplaceDoc['groupdata1'] ?? '';
      String groupData2 = workplaceDoc['groupdata2'] ?? '';
      String groupData3 = workplaceDoc['groupdata3'] ?? '';

      // 상태 리스트 업데이트
      setState(() {
        statusList = [
          groupData1,
          groupData2,
          groupData3,
          '$workplaceInput ${workplaceInputList.isNotEmpty ? workplaceInputList[groupIndex] : ''}'
        ];
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
    Color backgroundColor = isVerticalScroll
        ? generateRandomColor()
        : Colors.blue; // 상하 스크롤 시 배경색 변경

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dx > 0) {
          updateHorizontalStatus(-1); // 이전 상태
        } else if (details.velocity.pixelsPerSecond.dx < 0) {
          updateHorizontalStatus(1); // 다음 상태
        }
      },
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy > 0) {
          updateVerticalStatus(-1); // 이전 workplaceinput
        } else if (details.velocity.pixelsPerSecond.dy < 0) {
          updateVerticalStatus(1); // 다음 workplaceinput
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상태 화면'),
        ),
        body: Container(
          color: backgroundColor,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Text(
                    statusList.isNotEmpty ? statusList[currentIndex] : '상태 없음',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '현재 Workplace: ${workplaceInputList.isNotEmpty ? workplaceInputList[groupIndex] : '없음'}',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
