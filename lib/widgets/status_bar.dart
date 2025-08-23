import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../screens/user/map_search_screen.dart';

class StatusBar extends StatefulWidget {
  const StatusBar({super.key});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = Provider.of<SearchProvider>(context, listen: false);
    final selectedIndex = searchProvider.selectedTabIndex;

    return GestureDetector(
      onTap: () {
        if (selectedIndex == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapSearchScreen()),
          );
        }
      },
      child: AbsorbPointer(
        absorbing: selectedIndex == 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: '무엇을 찾을까요? (#쿠폰, @가게, 텍스트)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Consumer<SearchProvider>(
                builder: (_, sp, __) {
                  final hasText = sp.query.isNotEmpty || _controller.text.isNotEmpty;
                  return hasText
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            sp.clearQuery();
                          },
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => searchProvider.triggerSearch(),
            onChanged: (value) {
              if (selectedIndex != 1) {
                searchProvider.setQueryDebounced(value);
              }
            },
          ),
        ),
      ),
    );
  }
}
