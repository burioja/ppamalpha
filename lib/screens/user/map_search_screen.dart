import 'package:flutter/material.dart';

class MapSearchScreen extends StatelessWidget {
  const MapSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: '검색어를 입력하세요',
            border: InputBorder.none,
          ),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('지금 주로 찾는 장소', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...List.generate(3, (i) => const ListTile(title: Text('주로 찾는 장소입니다'), subtitle: Text('지역명'))),

          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('지금 최근 검색', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('더보기', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          ...List.generate(10, (i) => const ListTile(title: Text('최근 검색한 장소입니다'), subtitle: Text('지역명'))),
        ],
      ),
    );
  }
}
