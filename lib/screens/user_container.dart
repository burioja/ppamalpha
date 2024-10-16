import 'package:flutter/material.dart';
import 'status_screen.dart'; // 상태 컨테이너 참조

class UserContainer extends StatelessWidget {
  const UserContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      color: Colors.blue,
      child: Row(
        children: [
          // 위치 표시 부분 (비율 2)
          Flexible(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0), // 양쪽 패딩 추가
              child: SizedBox(
                width: 80, // 고정된 너비 설정 (위치 표시)
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // 가운데 정렬
                  children: const [
                    Icon(Icons.location_on, color: Colors.white),
                    SizedBox(height: 4), // 위아래 간격 추가
                    Text(
                      '삼성동',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 상태 컨테이너 부분 (비율 6)
          Flexible(
            flex: 6,
            child: Center(
              child: SizedBox(
                width: 250, // 상태 컨테이너 가로 크기 고정
                height: 80, // 상태 컨테이너 높이 고정
                child: const StatusScreen(), // 상태 컨테이너
              ),
            ),
          ),

          // 소지금 표시 부분 (비율 2)
          Flexible(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0), // 양쪽 패딩 추가
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 100, // 고정된 너비 설정 (소지금 표시)
                  child: const Text(
                    '1000000',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
