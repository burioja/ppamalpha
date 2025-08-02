import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WritePostScreen extends StatelessWidget {
  final String category;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  WritePostScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write Post')),
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
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection(category).add({
                  'title': titleController.text,
                  'content': contentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'author': '익명',
                  'profileImageUrl': '', // <- 기본값으로 비워둠
                });
                Navigator.pop(context);
              },
              child: const Text('Submit Post'),
            ),
          ],
        ),
      ),
    );
  }
}
