import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WritePostScreen extends StatelessWidget {
  final String category; // Threads, Recommendations, Votes를 위해 추가
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  WritePostScreen({super.key, required this.category}); // 카테고리 추가

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () async {
                // 글쓰기 버튼 클릭 시 Firestore에 데이터 추가
                await FirebaseFirestore.instance.collection(category).add({
                  'title': titleController.text,
                  'content': contentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'author': 'UserID', // 현재 사용자 ID로 변경 필요
                });

                Navigator.pop(context); // 글쓰기 완료 후 돌아가기
              },
              child: const Text('Submit Post'),
            ),
          ],
        ),
      ),
    );
  }
}
