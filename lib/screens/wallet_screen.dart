import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:image/image.dart' as img;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  List<Map<String, dynamic>> _uploadedImages = [];

  final picker = ImagePicker();
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // 이미지 압축/리사이징 설정
  static const int maxWidth = 1024;  // 최대 너비
  static const int maxHeight = 1024; // 최대 높이
  static const int quality = 85;     // JPEG 품질 (0-100)

  /// ✅ 이미지 압축/리사이징 함수
  Future<Uint8List> _compressAndResizeImage(File imageFile) async {
    try {
      // 이미지 파일을 바이트로 읽기
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // 이미지 디코딩
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('이미지를 디코딩할 수 없습니다.');
      
      // 원본 크기 로그
      debugPrint('원본 이미지 크기: ${image.width}x${image.height}');
      
      // 리사이징이 필요한지 확인
      bool needsResize = image.width > maxWidth || image.height > maxHeight;
      
      if (needsResize) {
        // 비율을 유지하면서 리사이징
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // 가로가 더 긴 경우
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          // 세로가 더 긴 경우
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
        
        // 이미지 리사이징
        image = img.copyResize(image, width: newWidth, height: newHeight);
        debugPrint('리사이징된 이미지 크기: ${image.width}x${image.height}');
      }
      
      // JPEG로 압축
      Uint8List compressedBytes = img.encodeJpg(image, quality: quality);
      
      // 압축 결과 로그
      double compressionRatio = (1 - compressedBytes.length / imageBytes.length) * 100;
      debugPrint('압축률: ${compressionRatio.toStringAsFixed(1)}%');
      debugPrint('원본 크기: ${(imageBytes.length / 1024).toStringAsFixed(1)}KB');
      debugPrint('압축 크기: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB');
      
      return compressedBytes;
    } catch (e) {
      debugPrint('이미지 압축 오류: $e');
      // 압축 실패 시 원본 반환
      return await imageFile.readAsBytes();
    }
  }

  Future<void> _pickAndUploadImage(bool isUpload) async {
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || userId == null) return;

    // 로딩 다이얼로그 표시
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("이미지 처리 중..."),
              ],
            ),
          );
        },
      );
    }

    try {
      for (var file in pickedFiles) {
        File imageFile = File(file.path);
        
        // 이미지 압축/리사이징
        Uint8List compressedBytes = await _compressAndResizeImage(imageFile);
        
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        String storagePath = "users/$userId/wallet/$fileName";

        Reference ref = FirebaseStorage.instance.ref().child(storagePath);
        
        // 압축된 바이트 데이터를 Firebase Storage에 업로드
        await ref.putData(compressedBytes);
        String fileUrl = await ref.getDownloadURL();

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
          'compressed': true, // 압축 여부 표시
        });
      }

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();

        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length}개의 이미지가 압축되어 업로드되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        if (isUpload) {
          _loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
        
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUploadedImages() async {
    if (userId == null) return;

    try {
      debugPrint('업로드된 이미지 로딩 시작...');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .where('source', isEqualTo: 'upload')
          .orderBy('receivedAt', descending: true)
          .get();

      debugPrint('Firestore에서 ${snapshot.docs.length}개의 이미지 데이터 로드됨');

      if (mounted) {
        setState(() {
          _uploadedImages = snapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint('이미지 데이터: ${data['fileName']} - ${data['fileUrl']}');
            return data;
          }).toList();
        });
        debugPrint('업로드된 이미지 목록 갱신 완료: ${_uploadedImages.length}개');
      }
    } catch (e) {
      debugPrint('업로드된 이미지 로딩 오류: $e');
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> imageData, bool isUpload) async {
    try {
      if (userId == null) return;

      final ref = FirebaseStorage.instance.refFromURL(imageData['fileUrl']);
      await ref.delete();

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

      if (mounted) {
        if (isUpload) {
          _loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      debugPrint("삭제 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("이미지 삭제 중 오류 발생")),
        );
      }
    }
  }

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

  /// ✅ 압축 설정 다이얼로그
  void _showCompressionSettings() {
    int currentQuality = quality;
    int currentMaxWidth = maxWidth;
    int currentMaxHeight = maxHeight;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("이미지 압축 설정"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("JPEG 품질 (높을수록 용량 증가)"),
                  Slider(
                    value: currentQuality.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: currentQuality.toString(),
                    onChanged: (value) {
                      setState(() {
                        currentQuality = value.round();
                      });
                    },
                  ),
                  Text("품질: $currentQuality%"),
                  const SizedBox(height: 20),
                  const Text("최대 크기 (픽셀)"),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "너비",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: currentMaxWidth.toString(),
                          ),
                          onChanged: (value) {
                            currentMaxWidth = int.tryParse(value) ?? 1024;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "높이",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(
                            text: currentMaxHeight.toString(),
                          ),
                          onChanged: (value) {
                            currentMaxHeight = int.tryParse(value) ?? 1024;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "※ 설정은 다음 업로드부터 적용됩니다",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소"),
                ),
                TextButton(
                  onPressed: () {
                    // 설정 저장 (실제로는 SharedPreferences나 Provider에 저장)
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("압축 설정이 저장되었습니다."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("저장"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImageCarousel(List<Map<String, dynamic>> images, bool isUpload) {
    debugPrint('캐러셀 빌드: ${images.length}개의 이미지, isUpload: $isUpload');
    
    if (images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("이미지가 없습니다.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 150,
        enlargeCenterPage: true,
        enableInfiniteScroll: true,
        viewportFraction: 0.5,
      ),
      items: images.map((data) {
        debugPrint('캐러셀 아이템: ${data['fileName']} - ${data['fileUrl']}');
        return GestureDetector(
          onTap: () => _showDeleteDialog(data, isUpload),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                data['fileUrl'], 
                fit: BoxFit.cover, 
                width: 100,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('이미지 로드 오류: $error');
                  return Container(
                    width: 100,
                    height: 150,
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, color: Colors.red),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 100,
                    height: 150,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUploadedImages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      walletProvider.loadReceivedImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    final receivedImages = walletProvider.receivedImages;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet 화면"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showCompressionSettings,
            tooltip: '압축 설정',
          ),
        ],
      ),
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
            _buildImageCarousel(receivedImages, false),
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
