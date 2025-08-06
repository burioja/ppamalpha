import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import '../../services/post_service.dart';
import '../../models/post_model.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with SingleTickerProviderStateMixin {
  final ImagePicker picker = ImagePicker();
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  final PostService _postService = PostService();
  List<Map<String, dynamic>> walletItems = [];
  List<PostModel> collectedPosts = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWalletItems();
    _loadCollectedPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletItems() async {
    if (userId == null) return;

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .orderBy('receivedAt', descending: true)
          .get();

      setState(() {
        walletItems = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('지갑 아이템 로드 오류: $e');
    }
  }

  Future<void> _loadCollectedPosts() async {
    if (userId == null) return;

    try {
      final posts = await _postService.getCollectedPosts(userId);
      setState(() {
        collectedPosts = posts;
      });
    } catch (e) {
      debugPrint('회수한 포스트 로드 오류: $e');
    }
  }

  Future<Uint8List> _compressAndResizeImage(File imageFile) async {
    try {
      Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) throw Exception('이미지를 디코딩할 수 없습니다.');
      
      // 기본 크기 로그
      debugPrint('이미지 크기: ${image.width}x${image.height}');
      
      const int maxWidth = 1024;
      const int maxHeight = 1024;
      const int quality = 85;
      
      // 리사징이 필요한지 확인
      bool needsResize = image.width > maxWidth || image.height > maxHeight;
      
      if (needsResize) {
        // 비율을 유지하면서 리사이징
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // 가로가 긴 경우
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          // 세로가 긴 경우
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
        
        // 이미지 리사이징
        image = img.copyResize(image, width: newWidth, height: newHeight);
        debugPrint('리사이징 완료: ${image.width}x${image.height}');
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
        
        // 압축된 바이트를 Firebase Storage에 업로드
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
          'sourceName': isUpload ? '업로드' : '지도마커',
          'receivedAt': Timestamp.now(),
          'compressed': true, // 압축 여부 표시
        });
      }

      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 지갑 아이템 새로고침
      await _loadWalletItems();

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length}개의 이미지가 업로드되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('이미지 업로드 오류: $e');
      
      // 로딩 다이얼로그 닫기
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 오류 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteWalletItem(String itemId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .doc(itemId)
          .delete();

      await _loadWalletItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('아이템이 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('아이템 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildWalletItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item['fileUrl'],
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 60,
                height: 60,
                color: Colors.grey[300],
                child: const Icon(Icons.image, color: Colors.grey),
              );
            },
          ),
        ),
        title: Text(
          item['fileName'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소스: ${item['sourceName'] ?? 'Unknown'}'),
            Text('받은 시간: ${_formatTimestamp(item['receivedAt'])}'),
            if (item['compressed'] == true)
              const Text('압축됨', style: TextStyle(color: Colors.blue)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              _deleteWalletItem(item['id']);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('삭제'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectedPost(PostModel post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.post_add,
            color: Colors.green,
            size: 30,
          ),
        ),
        title: Text(
          post.content.length > 50 ? '${post.content.substring(0, 50)}...' : post.content,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주소: ${post.address}'),
            Text('회수 시간: ${_formatDate(post.createdAt)}'),
          ],
        ),
        onTap: () => _showPostDetail(post),
      ),
    );
  }

  void _showPostDetail(PostModel post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회수한 포스트'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내용: ${post.content}'),
              const SizedBox(height: 8),
              Text('주소: ${post.address}'),
              const SizedBox(height: 8),
              Text('작성일: ${_formatDate(post.createdAt)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final dateTime = timestamp.toDate();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지갑'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '이미지'),
            Tab(text: '회수한 포스트'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'upload') {
                _pickAndUploadImage(true);
              } else if (value == 'received') {
                _pickAndUploadImage(false);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text('이미지 업로드'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'received',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('받은 이미지'),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.add),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 이미지 탭
          walletItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wallet,
                        size: 100,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 20),
                      Text(
                        '지갑이 비어있습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '오른쪽 상단의 + 버튼을 눌러\n이미지를 추가해보세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: walletItems.length,
                  itemBuilder: (context, index) {
                    return _buildWalletItem(walletItems[index]);
                  },
                ),
          // 회수한 포스트 탭
          collectedPosts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.post_add,
                        size: 100,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 20),
                      Text(
                        '회수한 포스트가 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '지도에서 포스트를 회수하면\n여기에 표시됩니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: collectedPosts.length,
                  itemBuilder: (context, index) {
                    return _buildCollectedPost(collectedPosts[index]);
                  },
                ),
        ],
      ),
    );
  }
} 