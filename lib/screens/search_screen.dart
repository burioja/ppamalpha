import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context);
    final query = searchProvider.query;
    final selectedIndex = searchProvider.selectedTabIndex;

    // 선택된 탭에 따른 검색결과 분기
    Widget buildSearchResults() {
      if (selectedIndex == 1) {
        return const Text('지도에서 검색결과 표시');
      } else if (selectedIndex == 0) {
        return const Text('내 커뮤니티 검색결과 표시');
      } else if (selectedIndex == 4) {
        return const Text('내 지갑 검색결과 표시');
      } else {
        return const Text('기타 다른 검색결과 표시');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '검색어를 입력하세요',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => searchProvider.setQuery(value),
            ),
            const SizedBox(height: 20),
            Text('검색어: "$query"', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: buildSearchResults()),
          ],
        ),
      ),
    );
  }
}
