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

    // ??�� ?�라 검??결과 분기
    Widget buildSearchResults() {
      if (selectedIndex == 1) {
        return const Text('?���?지??검??결과 ?�시');
      } else if (selectedIndex == 0) {
        return const Text('?�� 커�??�티 검??결과 ?�시');
      } else if (selectedIndex == 4) {
        return const Text('?�� ?�렛 검??결과 ?�시');
      } else {
        return const Text('?�� ?�른 ??��?�는 검??결과 ?�음');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('검??),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '검?�어�??�력?�세??,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => searchProvider.setQuery(value),
            ),
            const SizedBox(height: 20),
            Text('검?�어: "$query"', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: buildSearchResults()),
          ],
        ),
      ),
    );
  }
}
