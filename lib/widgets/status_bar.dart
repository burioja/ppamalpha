import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../screens/map_search_screen.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final selectedIndex = searchProvider.selectedTabIndex; // ?”§ ?„ì¬ ???¸ë±??ê°€?¸ì˜¤ê¸?


    return GestureDetector(
      onTap: () {
        if (selectedIndex == 1) { // ?”§ Map ??¼ ?Œë§Œ ?„ìš© ê²€???”ë©´ ?´ë™
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapSearchScreen()),
          );
        }
        // ?¤ë¥¸ ??¼ ê²½ìš°???„ë¬´ ?™ì‘ ???˜ê³  ?ìŠ¤???…ë ¥ ê°€??
      },
      child: AbsorbPointer( // ?”§ ?´ë¦­ë§?ê°ì??˜ê³  TextField???½ê¸° ëª¨ë“œ
        absorbing: selectedIndex == 1, // ?”§ ì§€????¼ ???…ë ¥ ë°©ì?
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'ê²€?‰ì–´ë¥??…ë ¥?˜ì„¸??..',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              if (selectedIndex != 1) {
                searchProvider.setQuery(value); // ?”§ ì§€????´ ?„ë‹ ?Œë§Œ ê²€?‰ì–´ ?€??
              }
            },
          ),
        ),
      ),
    );
  }
}
