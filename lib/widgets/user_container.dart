// lib/widgets/user_container.dart
import 'package:flutter/material.dart';
import 'user_status_widget.dart'; // fetchUserWorkplaces 함수 임포트

class UserContainer extends StatelessWidget {
  const UserContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90, // 원래 높이로 복원
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 위치 표시 부분 (좌측에 고정)
          const Padding(
            padding: EdgeInsets.only(left: 8.0), // 왼쪽 여백
            child: SizedBox(
              width: 80, // 고정된 너비 설정
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // 가운데 정렬
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  SizedBox(height: 4), // 아이콘과 텍스트 사이 간격
                  Text(
                    '삼성동', // 위치 텍스트
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // 상태 컨테이너 (가운데 고정, 좌우 스크롤 및 세로 스크롤)
          Center(
            child: SizedBox(
              width: 185, // 상태 컨테이너의 너비를 원래 크기로 복원
              height: 50, // 상태 컨테이너의 높이 고정
              child: FutureBuilder<List<List<WorkplaceData>>>(
                future: fetchUserWorkplaces(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator(color: Colors.white);
                  } else if (snapshot.hasError) {
                    return const Text('오류 발생', style: TextStyle(color: Colors.white));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('데이터가 없습니다.', style: TextStyle(color: Colors.white));
                  } else {
                    // 세로 PageView를 사용하여 그룹 간 이동
                    return PageView.builder(
                      scrollDirection: Axis.vertical, // 세로 스크롤
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, verticalIndex) {
                        final group = snapshot.data![verticalIndex];

                        // 가로 PageView의 컨트롤러를 생성하고 초기 페이지를 3으로 설정
                        final pageController = PageController(initialPage: 3);

                        return PageView.builder(
                          controller: pageController, // 초기 페이지 설정을 위해 PageController 사용
                          scrollDirection: Axis.horizontal, // 가로 스크롤
                          itemCount: group[0].data.length, // 각 그룹 내 항목 개수 (4개: groupdata1, groupdata2, groupdata3, workplaceinput+workplaceadd)
                          itemBuilder: (context, horizontalIndex) {
                            WorkplaceData workplaceData = group[0]; // 그룹 색상과 정보
                            return Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: workplaceData.color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  workplaceData.data[horizontalIndex], // 가로 스크롤 시 하나씩만 표시
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ),

          // 소지금 표시 부분 (우측에 고정)
          const Padding(
            padding: EdgeInsets.only(right: 8.0), // 오른쪽 여백
            child: SizedBox(
              width: 80, // 고정된 너비 설정
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '₩ 900,000', // 소지금 텍스트
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
