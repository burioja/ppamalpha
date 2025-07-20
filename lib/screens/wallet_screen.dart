import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<Map<String, dynamic>> _uploadedImages = [];
  List<Map<String, dynamic>> _receivedImages = [];

  final picker = ImagePicker();
  final userId = FirebaseAuth.instance.currentUser?.uid;

  /// ✅ 이미지 선택 및 업로드
  Future<void> _pickAndUploadImage(bool isUpload) async {
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || userId == null) return;

    for (var file in pickedFiles) {
      File imageFile = File(file.path);
      String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
      String storagePath = "users/$userId/wallet/$fileName";

      // Storage 업로드
      Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(imageFile);
      String fileUrl = await ref.getDownloadURL();

      // Firestore 저장
      final walletDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet');

      await walletDoc.add({
        'fileName': file.name,
        'fileUrl': fileUrl,
        'fileType': 'image',
        'source': isUpload ? 'upload' : 'received',
        'sourceName': isUpload ? '내 업로드' : '지도 마커',
        'receivedAt': Timestamp.now(),
      });
    }

    _loadWalletImages(); // 다시 불러오기
  }

  /// ✅ 이미지 삭제
  Future<void> _deleteImage(Map<String, dynamic> imageData, bool isUpload) async {
    try {
      if (userId == null) return;

      // Storage 삭제
      final ref = FirebaseStorage.instance.refFromURL(imageData['fileUrl']);
      await ref.delete();

      // Firestore 삭제
      final walletRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet');

      final snapshot = await walletRef
          .where('fileUrl', isEqualTo: imageData['fileUrl'])
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // UI 갱신
      _loadWalletImages();
    } catch (e) {
      print("삭제 오류: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이미지 삭제 중 오류 발생")),
      );
    }
  }

  /// ✅ 삭제 확인 다이얼로그
  void _showDeleteDialog(Map<String, dynamic> imageData, bool isUpload) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("이미지 삭제"),
          content: const Text("정말 삭제하시겠습니까?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteImage(imageData, isUpload);
              },
              child: const Text("삭제", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 이미지 불러오기
  Future<void> _loadWalletImages() async {
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .orderBy('receivedAt', descending: true)
        .get();

    final all = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _uploadedImages = all.where((e) => e['source'] == 'upload').toList();
      _receivedImages = all.where((e) => e['source'] == 'received').toList();
    });
  }

  /// ✅ 캐러셀 표시
  Widget _buildImageCarousel(List<Map<String, dynamic>> images, bool isUpload) {
    if (images.isEmpty) {
      return const Center(child: Text("이미지가 없습니다."));
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 150,
        enlargeCenterPage: true,
        enableInfiniteScroll: true,
        viewportFraction: 0.5,
      ),
      items: images.map((data) {
        return GestureDetector(
          onTap: () => _showDeleteDialog(data, isUpload),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(data['fileUrl'], fit: BoxFit.cover, width: 100),
          ),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWalletImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Wallet 화면")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("내가 업로드한 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_uploadedImages, true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(true),
                icon: const Icon(Icons.upload, color: Colors.blue),
                label: const Text("이미지 업로드", style: TextStyle(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("내가 받은 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_receivedImages, false),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(false),
                icon: const Icon(Icons.download, color: Colors.green),
                label: const Text("이미지 추가", style: TextStyle(color: Colors.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
