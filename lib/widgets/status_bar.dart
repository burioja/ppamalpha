import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../screens/map_search_screen.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final selectedIndex = searchProvider.selectedTabIndex; // 🔧 현재 탭 인덱스 가져오기


    return GestureDetector(
      onTap: () {
        if (selectedIndex == 1) { // 🔧 Map 탭일 때만 전용 검색 화면 이동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapSearchScreen()),
          );
        }
        // 다른 탭일 경우는 아무 동작 안 하고 텍스트 입력 가능
      },
      child: AbsorbPointer( // 🔧 클릭만 감지하고 TextField는 읽기 모드
        absorbing: selectedIndex == 1, // 🔧 지도 탭일 땐 입력 방지
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: TextField(
            decoration: const InputDecoration(
              hintText: '검색어를 입력하세요...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              if (selectedIndex != 1) {
                searchProvider.setQuery(value); // 🔧 지도 탭이 아닐 때만 검색어 저장
              }
            },
          ),
        ),
      ),
    );
  }
}