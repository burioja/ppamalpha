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
  
  // ?¥Î?ÏßÄ ?ïÏ∂ï/Î¶¨ÏÇ¨?¥Ïßï ?§Ï†ï
  static const int maxWidth = 1024;  // ÏµúÎ? ?àÎπÑ
  static const int maxHeight = 1024; // ÏµúÎ? ?íÏù¥
  static const int quality = 85;     // JPEG ?àÏßà (0-100)

  /// ???¥Î?ÏßÄ ?ïÏ∂ï/Î¶¨ÏÇ¨?¥Ïßï ?®Ïàò
  Future<Uint8List> _compressAndResizeImage(File imageFile) async {
    try {
      // ?¥Î?ÏßÄ ?åÏùº??Î∞îÏù¥?∏Î°ú ?ΩÍ∏∞
      Uint8List imageBytes = await imageFile.readAsBytes();
      
      // ?¥Î?ÏßÄ ?îÏΩî??
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('?¥Î?ÏßÄÎ•??îÏΩî?©Ìï† ???ÜÏäµ?àÎã§.');
      
      // ?êÎ≥∏ ?¨Í∏∞ Î°úÍ∑∏
      debug// print πÆ ¡¶∞≈µ 
      
      // Î¶¨ÏÇ¨?¥Ïßï???ÑÏöî?úÏ? ?ïÏù∏
      bool needsResize = image.width > maxWidth || image.height > maxHeight;
      
      if (needsResize) {
        // ÎπÑÏú®???†Ï??òÎ©¥??Î¶¨ÏÇ¨?¥Ïßï
        double aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // Í∞ÄÎ°úÍ? ??Í∏?Í≤ΩÏö∞
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          // ?∏Î°úÍ∞Ä ??Í∏?Í≤ΩÏö∞
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
        
        // ?¥Î?ÏßÄ Î¶¨ÏÇ¨?¥Ïßï
        image = img.copyResize(image, width: newWidth, height: newHeight);
        debug// print πÆ ¡¶∞≈µ 
      }
      
      // JPEGÎ°??ïÏ∂ï
      Uint8List compressedBytes = img.encodeJpg(image, quality: quality);
      
      // ?ïÏ∂ï Í≤∞Í≥º Î°úÍ∑∏
      double compressionRatio = (1 - compressedBytes.length / imageBytes.length) * 100;
      debugPrint('?ïÏ∂ïÎ•? ${compressionRatio.toStringAsFixed(1)}%');
      debugPrint('?êÎ≥∏ ?¨Í∏∞: ${(imageBytes.length / 1024).toStringAsFixed(1)}KB');
      debugPrint('?ïÏ∂ï ?¨Í∏∞: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB');
      
      return compressedBytes;
    } catch (e) {
      debug// print πÆ ¡¶∞≈µ 
      // ?ïÏ∂ï ?§Ìå® ???êÎ≥∏ Î∞òÌôò
      return await imageFile.readAsBytes();
    }
  }

  Future<void> _pickAndUploadImage(bool isUpload) async {
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty || userId == null) return;

    // Î°úÎî© ?§Ïù¥?ºÎ°úÍ∑??úÏãú
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
                Text("?¥Î?ÏßÄ Ï≤òÎ¶¨ Ï§?.."),
              ],
            ),
          );
        },
      );
    }

    try {
      for (var file in pickedFiles) {
        File imageFile = File(file.path);
        
        // ?¥Î?ÏßÄ ?ïÏ∂ï/Î¶¨ÏÇ¨?¥Ïßï
        Uint8List compressedBytes = await _compressAndResizeImage(imageFile);
        
        String fileName = "${DateTime.now().millisecondsSinceEpoch}_${file.name}";
        String storagePath = "users/$userId/wallet/$fileName";

        Reference ref = FirebaseStorage.instance.ref().child(storagePath);
        
        // ?ïÏ∂ï??Î∞îÏù¥???∞Ïù¥?∞Î? Firebase Storage???ÖÎ°ú??
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
          'sourceName': isUpload ? '???ÖÎ°ú?? : 'ÏßÄ??ÎßàÏª§',
          'receivedAt': Timestamp.now(),
          'compressed': true, // ?ïÏ∂ï ?¨Î? ?úÏãú
        });
      }

      // Î°úÎî© ?§Ïù¥?ºÎ°úÍ∑??´Í∏∞
      if (mounted) {
        Navigator.of(context).pop();

        // ?±Í≥µ Î©îÏãúÏßÄ ?úÏãú
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pickedFiles.length}Í∞úÏùò ?¥Î?ÏßÄÍ∞Ä ?ïÏ∂ï?òÏñ¥ ?ÖÎ°ú?úÎêò?àÏäµ?àÎã§.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      if (mounted) {
        if (isUpload) {
          await _loadUploadedImages();
          // WalletProvider???ÖÎç∞?¥Ìä∏
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      // Î°úÎî© ?§Ïù¥?ºÎ°úÍ∑??´Í∏∞
      if (mounted) {
        Navigator.of(context).pop();
        
        // ?§Î•ò Î©îÏãúÏßÄ ?úÏãú
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?¥Î?ÏßÄ ?ÖÎ°ú??Ï§??§Î•òÍ∞Ä Î∞úÏÉù?àÏäµ?àÎã§: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUploadedImages() async {
    if (userId == null) return;

    try {
      debug// print πÆ ¡¶∞≈µ 
      
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .where('source', isEqualTo: 'upload')
          .orderBy('receivedAt', descending: true)
          .get();

      debug// print πÆ ¡¶∞≈µ 

      if (mounted) {
        setState(() {
          _uploadedImages = snapshot.docs.map((doc) {
            final data = doc.data();
            debug// print πÆ ¡¶∞≈µ 
            return data;
          }).toList();
        });
        debug// print πÆ ¡¶∞≈µ 
      }
    } catch (e) {
      debug// print πÆ ¡¶∞≈µ 
      // ?∏Îç±???§Î•ò ???®Ïàú ÏøºÎ¶¨Î°??¥Î∞±
      try {
        debug// print πÆ ¡¶∞≈µ 
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .where('source', isEqualTo: 'upload')
            .get();

        debug// print πÆ ¡¶∞≈µ 

        if (mounted) {
          setState(() {
            _uploadedImages = snapshot.docs.map((doc) {
              final data = doc.data();
              debug// print πÆ ¡¶∞≈µ 
              return data;
            }).toList();
          });
          debug// print πÆ ¡¶∞≈µ 
        }
      } catch (fallbackError) {
        debug// print πÆ ¡¶∞≈µ 
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
          // WalletProvider???ÖÎç∞?¥Ìä∏
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadUploadedImages();
        } else {
          final walletProvider = Provider.of<WalletProvider>(context, listen: false);
          await walletProvider.loadReceivedImages();
        }
      }
    } catch (e) {
      debug// print πÆ ¡¶∞≈µ 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("?¥Î?ÏßÄ ??†ú Ï§??§Î•ò Î∞úÏÉù")),
        );
      }
    }
  }

  void _showDeleteDialog(Map<String, dynamic> imageData, bool isUpload) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("?¥Î?ÏßÄ ??†ú"),
          content: const Text("?ïÎßê ??†ú?òÏãúÍ≤†Ïäµ?àÍπå?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Ï∑®ÏÜå"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteImage(imageData, isUpload);
              },
              child: const Text("??†ú", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// ???ïÏ∂ï ?§Ï†ï ?§Ïù¥?ºÎ°úÍ∑?
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
              title: const Text("?¥Î?ÏßÄ ?ïÏ∂ï ?§Ï†ï"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("JPEG ?àÏßà (?íÏùÑ?òÎ°ù ?©Îüâ Ï¶ùÍ?)"),
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
                  Text("?àÏßà: $currentQuality%"),
                  const SizedBox(height: 20),
                  const Text("ÏµúÎ? ?¨Í∏∞ (?ΩÏ?)"),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: "?àÎπÑ",
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
                            labelText: "?íÏù¥",
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
                    "???§Ï†ï?Ä ?§Ïùå ?ÖÎ°ú?úÎ????ÅÏö©?©Îãà??,
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
                  child: const Text("Ï∑®ÏÜå"),
                ),
                TextButton(
                  onPressed: () {
                    // ?§Ï†ï ?Ä??(?§Ï†úÎ°úÎäî SharedPreferences??Provider???Ä??
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("?ïÏ∂ï ?§Ï†ï???Ä?•Îêò?àÏäµ?àÎã§."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text("?Ä??),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildImageCarousel(List<Map<String, dynamic>> images, bool isUpload) {
    debug// print πÆ ¡¶∞≈µ 
    
    if (images.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("?¥Î?ÏßÄÍ∞Ä ?ÜÏäµ?àÎã§.", style: TextStyle(color: Colors.grey)),
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
        debug// print πÆ ¡¶∞≈µ 
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
                  debug// print πÆ ¡¶∞≈µ 
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
        title: const Text("Wallet ?îÎ©¥"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showCompressionSettings,
            tooltip: '?ïÏ∂ï ?§Ï†ï',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("?¥Í? ?ÖÎ°ú?úÌïú Í∑∏Î¶º", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(_uploadedImages, true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(true),
                icon: const Icon(Icons.upload, color: Colors.blue),
                label: const Text("?¥Î?ÏßÄ ?ÖÎ°ú??, style: TextStyle(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("?¥Í? Î∞õÏ? Í∑∏Î¶º", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildImageCarousel(receivedImages, false),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _pickAndUploadImage(false),
                icon: const Icon(Icons.download, color: Colors.green),
                label: const Text("?¥Î?ÏßÄ Ï∂îÍ?", style: TextStyle(color: Colors.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
