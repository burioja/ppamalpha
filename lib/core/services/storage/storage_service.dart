import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Firebase Storage 서비스
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 이미지와 썸네일 업로드
  Future<String> uploadImageBytesWithThumbnail(
    Uint8List imageData,
    String path,
    String fileName,
  ) async {
    try {
      final ref = _storage.ref().child('$path/$fileName');
      final uploadTask = ref.putData(
        imageData,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('이미지 업로드 실패: $e');
      }
      rethrow;
    }
  }

  /// 이미지 삭제
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('이미지 삭제 실패: $e');
      }
      rethrow;
    }
  }
}

