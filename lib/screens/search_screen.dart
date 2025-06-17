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

    // 탭에 따라 검색 결과 분기
    Widget buildSearchResults() {
      if (selectedIndex == 1) {
        return const Text('🗺️ 지도 검색 결과 표시');
      } else if (selectedIndex == 0) {
        return const Text('📝 커뮤니티 검색 결과 표시');
      } else if (selectedIndex == 4) {
        return const Text('💰 월렛 검색 결과 표시');
      } else {
        return const Text('📄 다른 탭에서는 검색 결과 없음');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        backgroundColor: Colors.blueAccent,
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
