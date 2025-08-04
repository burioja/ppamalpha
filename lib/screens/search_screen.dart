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

    // ??— ?°ë¼ ê²€??ê²°ê³¼ ë¶„ê¸°
    Widget buildSearchResults() {
      if (selectedIndex == 1) {
        return const Text('?—ºï¸?ì§€??ê²€??ê²°ê³¼ ?œì‹œ');
      } else if (selectedIndex == 0) {
        return const Text('?“ ì»¤ë??ˆí‹° ê²€??ê²°ê³¼ ?œì‹œ');
      } else if (selectedIndex == 4) {
        return const Text('?’° ?”ë › ê²€??ê²°ê³¼ ?œì‹œ');
      } else {
        return const Text('?“„ ?¤ë¥¸ ??—?œëŠ” ê²€??ê²°ê³¼ ?†ìŒ');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ê²€??),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'ê²€?‰ì–´ë¥??…ë ¥?˜ì„¸??,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => searchProvider.setQuery(value),
            ),
            const SizedBox(height: 20),
            Text('ê²€?‰ì–´: "$query"', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: buildSearchResults()),
          ],
        ),
      ),
    );
  }
}
