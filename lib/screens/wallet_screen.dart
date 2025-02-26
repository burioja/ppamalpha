import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:io';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final List<File> _uploadedImages = []; // 내가 업로드한 이미지 리스트
  final List<File> _receivedImages = []; // 내가 받은 이미지 리스트

  /// 📌 갤러리에서 이미지 선택
  Future<void> _pickImage(bool isUpload) async {
    final pickedFiles = await ImagePicker().pickMultiImage(); // 여러 개 선택 가능
    if (pickedFiles.isNotEmpty) {
      setState(() {
        if (isUpload) {
          _uploadedImages.addAll(pickedFiles.map((file) => File(file.path)));
        } else {
          _receivedImages.addAll(pickedFiles.map((file) => File(file.path)));
        }
      });
    }
  }

  /// 📌 캐러셀 위젯 (이미지 리스트를 가로 슬라이드 방식으로 표시)
  Widget _buildImageCarousel(List<File> images) {
    if (images.isEmpty) {
      return const Center(child: Text("이미지가 없습니다."));
    }
    return CarouselSlider(
      options: CarouselOptions(
        height: 150, // 캐러셀 높이
        enlargeCenterPage: true,
        enableInfiniteScroll: true,
        viewportFraction: 0.5, // 이미지 간 간격 조절
      ),
      items: images.map((file) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover, width: 100),
        );
      }).toList(),
    );
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
            // 📌 내가 올린 그림
            const Text("내가 업로드한 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_uploadedImages),

            // 📌 업로드 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickImage(true),
                icon: const Icon(Icons.upload, color: Colors.blue),
                label: const Text("이미지 업로드", style: TextStyle(color: Colors.blue)),
              ),
            ),

            const SizedBox(height: 20),

            // 📌 내가 받은 그림
            const Text("내가 받은 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_receivedImages),

            // 📌 받기 버튼
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickImage(false),
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
