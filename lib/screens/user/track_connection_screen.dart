import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrackConnectionScreen extends StatefulWidget {
  final String type; // 'track' 또는 'connection'
  
  const TrackConnectionScreen({
    super.key,
    required this.type,
  });

  @override
  State<TrackConnectionScreen> createState() => _TrackConnectionScreenState();
}

class _TrackConnectionScreenState extends State<TrackConnectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'track' ? '팔로우하는 크리에이터' : '팔로워';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (widget.type == 'track')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  // 데이터 새로고침
                });
              },
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getUserList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류가 발생했습니다: ${snapshot.error}'),
                ],
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.type == 'track' ? Icons.track_changes : Icons.people,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.type == 'track' 
                        ? 'Track하는 크리에이터가 없습니다.' 
                        : 'Connection이 없습니다.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index];
              return _buildUserCard(userData);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUserList() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return [];
    }

    try {
      if (widget.type == 'track') {
        // 사용자가 Track하는 크리에이터 목록 가져오기
        final trackQuery = await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('tracks')
            .get();

        final trackUserIds = trackQuery.docs.map((doc) => doc.id).toList();
        
        if (trackUserIds.isEmpty) return [];

        final usersQuery = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: trackUserIds)
            .get();

        return usersQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nickname': data['nickname'] ?? 'Unknown',
            'profileImageUrl': data['profileImageUrl'],
            'authority': data['authority'] ?? 'User',
          };
        }).toList();
      } else {
        // 사용자를 Track하는 팔로워 목록 가져오기
        final connectionQuery = await _firestore
            .collection('users')
            .where('tracks.$currentUserId', isEqualTo: true)
            .get();

        return connectionQuery.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'nickname': data['nickname'] ?? 'Unknown',
            'profileImageUrl': data['profileImageUrl'],
            'authority': data['authority'] ?? 'User',
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching user list: $e');
      return [];
    }
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) return 3;
    if (width > 400) return 2;
    return 1;
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: userData['profileImageUrl'] != null
                  ? NetworkImage(userData['profileImageUrl'])
                  : null,
              child: userData['profileImageUrl'] == null
                  ? Text(
                      userData['nickname']?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              userData['nickname'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              userData['authority'] ?? 'User',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
} 
