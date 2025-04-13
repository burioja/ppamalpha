import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  _CommunityScreenState createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedMenuIndex = 0;
  final PageController _pageController = PageController();

  final List<String> _menuItems = ['Threads', 'Suggestions', 'Votes'];

  void _onMenuTap(int index) {
    setState(() => _selectedMenuIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedMenuIndex = index);
  }

  Widget _buildPostList(String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!.docs;

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;
            final String? imageUrl = data.containsKey('profileImageUrl') ? data['profileImageUrl'] : null;
            final String title = data['title'] ?? '';
            final String content = data['content'] ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade200,
                        image: imageUrl != null && imageUrl.isNotEmpty
                            ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 텍스트
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Container(height: 1, color: Colors.grey.shade300),
                          const SizedBox(height: 6),
                          Text(content, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 상단 메뉴
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_menuItems.length, (index) {
                final isSelected = _selectedMenuIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onMenuTap(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox( // 👉 자동 줄이기
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _menuItems[index],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.blue : Colors.black,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4.0),
                            height: 2,
                            width: 50,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // 좌우 드래그 가능한 페이지
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                return _buildPostList(_menuItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
