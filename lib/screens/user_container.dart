import 'package:flutter/material.dart';

class UserContainer extends StatelessWidget {
  const UserContainer({super.key});

  @override
  Widget build(BuildContext context) {

    return Container(
      height: 90,
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 좌우 끝에 붙이기
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
                    '삼성동',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

          // 상태 컨테이너 (가운데 고정)
          Center(
            child: SizedBox(
              width: 185, // 상태 컨테이너의 너비를 줄임
              height: 50, // 상태 컨테이너의 높이 고정
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue, // 배경색 (원하는 색으로 변경 가능)
                  borderRadius: BorderRadius.circular(15), // 둥근 테두리 반경 설정
                  border: Border.all(
                    color: Colors.black, // 테두리 색상
                    width: 3, // 테두리 두께
                  ),
                ),
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
