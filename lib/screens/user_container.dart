import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/workplace_provider.dart'; // Provider 경로 추가

class UserContainer extends StatelessWidget {
  const UserContainer({super.key});

  @override
  Widget build(BuildContext context) {
    // WorkplaceProvider에서 workplaceInput 값을 가져옴
    final workplaceInput = Provider.of<WorkplaceProvider>(context).workplaceInput;

    return Container(
      height: 90,
      color: Colors.blue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 좌우 끝에 붙이기
        children: [
          // 위치 표시 부분 (좌측에 고정)
          Padding(
            padding: const EdgeInsets.only(left: 8.0), // 왼쪽 여백
            child: SizedBox(
              width: 80, // 고정된 너비 설정
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // 가운데 정렬
                children: const [
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
              width: 235, // 상태 컨테이너의 너비를 줄임
              height: 70, // 상태 컨테이너의 높이 고정
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white,
                ),
                child: Center(
                  child: Text(
                    workplaceInput ?? '상태가 없습니다.', // workplaceInput 값을 표시
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),

          // 소지금 표시 부분 (우측에 고정)
          Padding(
            padding: const EdgeInsets.only(right: 8.0), // 오른쪽 여백
            child: SizedBox(
              width: 80, // 고정된 너비 설정
              child: Align(
                alignment: Alignment.centerRight,
                child: const Text(
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