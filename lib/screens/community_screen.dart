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
// 댓글 토글 상태 관리
  Map<String, bool> _commentBoxVisibility = {};

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
            final postId = post.id;
            final data = post.data() as Map<String, dynamic>;
            final String? imageUrl = data['profileImageUrl'];
            final String title = data['title'] ?? '';
            final String content = data['content'] ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 게시물 본문
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
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

                  const SizedBox(height: 6),

                  // 댓글 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _commentBoxVisibility[postId] =
                          !(_commentBoxVisibility[postId] ?? false);
                        });
                      },
                      icon: const Icon(Icons.comment, size: 16),
                      label: const Text("댓글 달기"),
                    ),
                  ),

                  // 댓글 입력창 & 목록
                  if (_commentBoxVisibility[postId] == true)
                    _buildCommentsSection(postId, collectionName),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentsSection(String postId, String collectionName) {
    final TextEditingController _commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 댓글 목록
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(collectionName)
              .doc(postId)
              .collection('comments')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final comments = snapshot.data!.docs;
            return Column(
              children: comments.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  title: Text(data['text'] ?? ''),
                  subtitle: Text(data['author'] ?? '익명'),
                );
              }).toList(),
            );
          },
        ),

        // 댓글 입력창
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: '댓글을 입력하세요',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                final text = _commentController.text.trim();
                if (text.isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(postId)
                      .collection('comments')
                      .add({
                    'text': text,
                    'author': '익명', // 필요 시 사용자 이름으로 교체
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  _commentController.clear();
                }
              },
            ),
          ],
        ),
      ],
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

