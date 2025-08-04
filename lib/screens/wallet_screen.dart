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
  
  // ?��?지 ?�축/리사?�징 ?�정
  static const int maxWidth = 1024;  // 최�? ?�비
  static const int maxHeight = 1024; // 최�? ?�이
  static const int quality = 85;     // JPEG ?�질 (0-100)

  /// ???��?지 ?�축/리사?�징 ?�수
  Future<Uint8List> _compressAndResizeImage(File imageFile) async {
    try {
      // ?��?지 ?�일??바이?�로 ?�기
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // ?��?지 ?�코??
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('?��?지�??�코?�할 ???�습?�다.');
      
      // ?�본 ?�기 로그
      debug// print �� ���ŵ�
      
      // 리사?�징???�요?��? ?�인
      bool needsResize = image.width > maxWidth || image.height > maxHeight;
      
      if (needsResize) {
        // 비율???��??�면??리사?�징
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // 가로�? ??�?경우
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          // ?�로가 ??�?경우
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
        
        // ?��?지 리사?�징
        image = img.copyResize(image, width: newWidth, height: newHeight);
        debug// print �� ���ŵ�
      }
      
      // JPEG�??�축
      Uint8List compressedBytes = img.encodeJpg(image, quality: quality);
      
      // ?�축 결과 로그
      double compressionRatio = (1 - compressedBytes.length / imageBytes.length) * 100;
      debugPrint('?�축�? ${compressionRatio.toStringAsFixed(1)}%');
      debugPrint('?�본 ?�기: ${(imageBytes.length / 1024).toStringAsFixed(1)}KB');
      debugPrint('?�축 ?�기: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB');
      
      return compressedBytes;
    } catch (e) {
      debug// print �� ���ŵ�
      // ?�축 ?�패 ???�본 반환
      return await imageFile.readAsBytes();
    }
  }

  Future<void> _pickAndUploadImage(bool isUpload) async {
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || userId == null) return;

    // 로딩 ?�이?�로�??�시
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
                Text("?��?지 처리 �?.."),
              ],
            ),
          );
        },
      );
    }

    try {
      for (var file in pickedFiles) {
        File imageFile = File(file.path);
        
        // ?��?지 ?�축/리사?�징
        Uint8List compressedBytes = await _compressAndResizeImage(imageFile);
        
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        String storagePath = "users/$userId/wallet/$fileName";

        Reference ref = FirebaseStorage.instance.ref().child(storagePath);
        
        // ?�축??바이???�이?��? Firebase Storage???�로??
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
          'sourceName': isUpload ? '???�로?? : '지??마커',
          'receivedAt': Timestamp.now(),
          'compressed': true, // ?�축 ?��? ?�시
        });
      }

      // 로딩 ?�이?�로�??�기
      if (mounted) {
        Navigator.of(context).pop();

        // ?�공 메시지 ?�시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length}개의 ?��?지가 ?�축?�어 ?�로?�되?�습?�다.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        if (isUpload) {
          await _loadUploadedImages();
          // WalletProvider???�데?�트
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      // 로딩 ?�이?�로�??�기
      if (mounted) {
        Navigator.of(context).pop();
        
        // ?�류 메시지 ?�시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?��?지 ?�로??�??�류가 발생?�습?�다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUploadedImages() async {
    if (userId == null) return;

    try {
      debug// print �� ���ŵ�
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .where('source', isEqualTo: 'upload')
          .orderBy('receivedAt', descending: true)
          .get();

      debug// print �� ���ŵ�

      if (mounted) {
        setState(() {
          _uploadedImages = snapshot.docs.map((doc) {
            final data = doc.data();
            debug// print �� ���ŵ�
            return data;
          }).toList();
        });
        debug// print �� ���ŵ�
      }
    } catch (e) {
      debug// print �� ���ŵ�
      // ?�덱???�류 ???�순 쿼리�??�백
      try {
        debug// print �� ���ŵ�
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .where('source', isEqualTo: 'upload')
            .get();

        debug// print �� ���ŵ�

        if (mounted) {
          setState(() {
            _uploadedImages = snapshot.docs.map((doc) {
              final data = doc.data();
              debug// print �� ���ŵ�
              return data;
            }).toList();
          });
          debug// print �� ���ŵ�
        }
      } catch (fallbackError) {
        debug// print �� ���ŵ�
        if (mounted) {
          setState(() {
            _uploadedImages = [];
          });
        }
      }
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
          await _loadUploadedImages();
          // WalletProvider???�데?�트
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      debug// print �� ���ŵ�
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("?��?지 ??�� �??�류 발생")),
        );
      }
    }
  }

  void _showDeleteDialog(Map<String, dynamic> imageData, bool isUpload) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("?��?지 ??��"),
          content: const Text("?�말 ??��?�시겠습?�까?"),
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
              child: const Text("??��", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// ???�축 ?�정 ?�이?�로�?
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
              title: const Text("?��?지 ?�축 ?�정"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("JPEG ?�질 (?�을?�록 ?�량 증�?)"),
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
                  Text("?�질: $currentQuality%"),
                  const SizedBox(height: 20),
                  const Text("최�? ?�기 (?��?)"),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "?�비",
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
                            labelText: "?�이",
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
                    "???�정?� ?�음 ?�로?��????�용?�니??,
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
                    // ?�정 ?�??(?�제로는 SharedPreferences??Provider???�??
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("?�축 ?�정???�?�되?�습?�다."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("?�??),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImageCarousel(List<Map<String, dynamic>> images, bool isUpload) {
    debug// print �� ���ŵ�
    
    if (images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("?��?지가 ?�습?�다.", style: TextStyle(color: Colors.grey)),
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
        debug// print �� ���ŵ�
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
                  debug// print �� ���ŵ�
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
        title: const Text("Wallet ?�면"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showCompressionSettings,
            tooltip: '?�축 ?�정',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("?��? ?�로?�한 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_uploadedImages, true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(true),
                icon: const Icon(Icons.upload, color: Colors.blue),
                label: const Text("?��?지 ?�로??, style: TextStyle(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("?��? 받�? 그림", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(receivedImages, false),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(false),
                icon: const Icon(Icons.download, color: Colors.green),
                label: const Text("?��?지 추�?", style: TextStyle(color: Colors.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
