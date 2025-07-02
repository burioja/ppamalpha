import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  final String collectionName;

  const PostDetailScreen({super.key, required this.postId, required this.collectionName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('게시글 상세보기')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection(collectionName).doc(postId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String title = data['title'] ?? '';
          final String content = data['content'] ?? '';
          final String? imageUrl = data['profileImageUrl'];
          final String author = data['author'] ?? '닉네임';
          final Timestamp? timestamp = data['timestamp'];
          final String formattedDate = timestamp != null
              ? DateFormat('yyyy.MM.dd HH:mm').format(timestamp.toDate())
              : 'yyyy.MM.dd HH:mm';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
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
                              Text(author, style: const TextStyle(color: Colors.blue)),
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
                const SizedBox(height: 16),
                Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey),
                    Icon(Icons.thumb_up_alt_outlined, size: 20, color: Colors.grey),
                    Icon(Icons.thumb_down_alt_outlined, size: 20, color: Colors.grey),
                    Icon(Icons.bookmark_border, size: 20, color: Colors.grey),
                    Icon(Icons.share_outlined, size: 20, color: Colors.grey),
                    Icon(Icons.edit, size: 20, color: Colors.grey),
                  ],
                ),

                const SizedBox(height: 24),
                const Text('댓글 00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                const SizedBox(height: 12),
                _buildCommentsSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    final TextEditingController commentController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                final timestamp = data['timestamp'] as Timestamp?;
                final String formattedDate = timestamp != null
                    ? DateFormat('yyyy.MM.dd HH:mm').format(timestamp.toDate())
                    : 'yyyy.MM.dd HH:mm';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty)
                        ? NetworkImage(data['profileImageUrl'])
                        : const AssetImage('assets/images/default_profile.png') as ImageProvider,
                  ),
                  title: Row(
                    children: [
                      Text(data['author'] ?? '익명', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  subtitle: Text(data['text'] ?? ''),
                );
              }).toList(),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: commentController,
                decoration: const InputDecoration(hintText: '댓글을 남겨보세요'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () async {
                final text = commentController.text.trim();
                if (text.isNotEmpty) {
                  final userProvider = Provider.of<UserProvider>(context, listen: false);
                  await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(postId)
                      .collection('comments')
                      .add({
                    'text': text,
                    'author': userProvider.nickName,
                    'profileImageUrl': userProvider.profileImageUrl,
                    'userId': FirebaseAuth.instance.currentUser?.uid,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  commentController.clear();
                }
              },
            )
          ],
        ),
      ],
    );
  }
}