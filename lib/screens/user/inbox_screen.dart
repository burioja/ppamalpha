import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  bool _sortByExpiry = false; // false: 받은날짜순, true: 소멸시기순

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _myPostsStream() {
    if (_uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('user_posts');
    return (_sortByExpiry
        ? base.orderBy('expireAt', descending: false)
        : base.orderBy('createdAt', descending: true))
      .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _receivedPostsStream() {
    if (_uid == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    final base = FirebaseFirestore.instance
        .collection('users')
        .doc(_uid)
        .collection('received_posts');
    return (_sortByExpiry
        ? base.orderBy('expireAt', descending: false)
        : base.orderBy('receivedAt', descending: true))
      .snapshots();
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPostTile(Map<String, dynamic> data) {
    final title = (data['title'] ?? '제목 없음').toString();
    final type = (data['type'] ?? '일반').toString();
    final reward = (data['reward'] ?? data['price'] ?? 0).toString();
    final author = (data['creatorName'] ?? data['owner'] ?? '알 수 없음').toString();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.post_add, color: Colors.blue),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$type · 리워드 $reward · $author'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('인박스'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내 포스트'),
            Tab(text: '받은 포스트'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() {
                _sortByExpiry = (v == 'expire');
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'received', child: Text('받은날짜순')),
              PopupMenuItem(value: 'expire', child: Text('소멸시기순')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 내 포스트
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmpty('내 포스트가 없습니다', Icons.mail_outline);
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildPostTile(docs[index].data()),
              );
            },
          ),
          // 받은 포스트
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _receivedPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return _buildEmpty('받은 포스트가 없습니다', Icons.move_to_inbox);
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) => _buildPostTile(docs[index].data()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/post-place'),
        child: const Icon(Icons.add),
      ),
    );
  }
}



