import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../screens/user/map_search_screen.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final selectedIndex = searchProvider.selectedTabIndex; // ?�� ?�재 ???�덱??가?�오�?


    return GestureDetector(
      onTap: () {
        if (selectedIndex == 1) { // ?�� Map ??�� ?�만 ?�용 검???�면 ?�동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapSearchScreen()),
          );
        }
        // ?�른 ??�� 경우???�무 ?�작 ???�고 ?�스???�력 가??
      },
      child: AbsorbPointer( // ?�� ?�릭�?감�??�고 TextField???�기 모드
        absorbing: selectedIndex == 1, // ?�� 지????�� ???�력 방�?
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: TextField(
            decoration: const InputDecoration(
              hintText: '검?�어�??�력?�세??..',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              if (selectedIndex != 1) {
                searchProvider.setQuery(value); // ?�� 지????�� ?�닐 ?�만 검?�어 ?�??
              }
            },
          ),
        ),
      ),
    );
  }
}
