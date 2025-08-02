// community_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/search_provider.dart';
import '../providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_detail_screen.dart';

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
    _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onPageChanged(int index) {
    setState(() => _selectedMenuIndex = index);
  }

  Widget _buildPostList(String collectionName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(collectionName).orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final searchQuery = Provider.of<SearchProvider>(context).query;

        final posts = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String title = data['title'] ?? '';
          final String content = data['content'] ?? '';
          return searchQuery.isEmpty || title.toLowerCase().contains(searchQuery.toLowerCase()) || content.toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postId = post.id;
            final data = post.data() as Map<String, dynamic>;
            final String? imageUrl = data['profileImageUrl'];
            final String title = data['title'] ?? '';
            final String content = data['content'] ?? '';
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            final String formattedDate = timestamp != null ? '${timestamp.year}.${timestamp.month.toString().padLeft(2, '0')}.${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}' : 'yyyy.mm.dd 00:00';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(postId: postId, collectionName: collectionName),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 프로필, 제목, 닉네임
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                                ? NetworkImage(imageUrl)
                                : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(data['author'] ?? '닉네임', style: const TextStyle(color: Colors.blue)),
                                    const SizedBox(width: 8),
                                    Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    const Text('조회 0', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 본문 클릭 시 디테일 페이지 이동
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(postId: postId, collectionName: collectionName),
                            ),
                          );
                        },
                        child: Text(
                          content,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 8),

                      // 하단 아이콘 (댓글 아이콘만 클릭 시 이동)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(postId: postId, collectionName: collectionName),
                                ),
                              );
                            },
                            child: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                          ),
                          const Icon(Icons.thumb_up_alt_outlined, size: 20, color: Colors.grey),
                          const Icon(Icons.thumb_down_alt_outlined, size: 20, color: Colors.grey),
                          const Icon(Icons.bookmark_border, size: 20, color: Colors.grey),
                          const Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                          const Icon(Icons.edit, size: 20, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
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
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                _menuItems.length,
                    (index) => GestureDetector(
                  onTap: () => _onMenuTap(index),
                  child: Text(
                    _menuItems[index],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _selectedMenuIndex == index ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
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
