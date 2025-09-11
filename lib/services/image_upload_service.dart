import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<List<String>> uploadStoreImages({
    List<XFile>? imageFiles,
    bool fromCamera = false,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('사용자 인증이 필요합니다.');
      }

      List<XFile> files = [];
      
      if (imageFiles != null && imageFiles.isNotEmpty) {
        files = imageFiles;
      } else {
        // 이미지 선택
        try {
          if (fromCamera) {
            final XFile? image = await _picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 1920,
              maxHeight: 1080,
              imageQuality: 85,
            );
            if (image != null) files.add(image);
          } else {
            final List<XFile> images = await _picker.pickMultiImage(
              maxWidth: 1920,
              maxHeight: 1080,
              imageQuality: 85,
            );
            files = images;
          }
        } catch (e) {
          if (kDebugMode) {
            print('이미지 선택 오류: $e');
          }
          throw Exception('이미지 선택에 실패했습니다: $e');
        }
      }

      if (files.isEmpty) {
        throw Exception('선택된 이미지가 없습니다.');
      }

      List<String> downloadUrls = [];
      List<String> failedUploads = [];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        
        try {
          // 이미지 압축
          final compressedImage = await _compressImage(file);
          
          // 업로드 경로 생성
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'store_${currentUser.uid}_${timestamp}_$i.jpg';
          final storageRef = _storage.ref().child('stores/${currentUser.uid}/$fileName');

          // 파일 업로드
          final uploadTask = await storageRef.putData(
            compressedImage,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'userId': currentUser.uid,
                'uploadedAt': timestamp.toString(),
                'originalName': file.name,
              },
            ),
          );

          // 다운로드 URL 획득
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          downloadUrls.add(downloadUrl);
          
          if (kDebugMode) {
            print('이미지 업로드 성공: $fileName');
          }
        } catch (e) {
          if (kDebugMode) {
            print('개별 이미지 업로드 실패 [$i]: $e');
          }
          failedUploads.add('이미지 ${i + 1}: $e');
          continue; // 다음 이미지 계속 처리
        }
      }

      // 결과 처리
      if (downloadUrls.isEmpty) {
        throw Exception('모든 이미지 업로드가 실패했습니다:\n${failedUploads.join('\n')}');
      } else if (failedUploads.isNotEmpty) {
        if (kDebugMode) {
          print('일부 이미지 업로드 실패: ${failedUploads.join(', ')}');
        }
        // 부분 성공의 경우에도 성공한 URL들은 반환
      }

      return downloadUrls;
    } catch (e) {
      if (kDebugMode) {
        print('uploadStoreImages 전체 오류: $e');
      }
      rethrow;
    }
  }

  Future<Uint8List> _compressImage(XFile file) async {
    try {
      if (kDebugMode) {
        print('이미지 압축 시작: ${file.name}');
      }
      
      final bytes = await file.readAsBytes();
      
      if (bytes.isEmpty) {
        throw Exception('이미지 파일이 비어있습니다');
      }
      
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('이미지 디코딩 실패: 지원되지 않는 이미지 형식입니다');
      }

      if (kDebugMode) {
        print('원본 이미지 크기: ${image.width}x${image.height}');
      }

      // 이미지 리사이징 (최대 1920x1080)
      img.Image resized = image;
      if (image.width > 1920 || image.height > 1080) {
        // 비율 유지하면서 리사이징
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1920 / 1080) {
          // 가로가 더 긴 경우
          newWidth = 1920;
          newHeight = (1920 / aspectRatio).round();
        } else {
          // 세로가 더 긴 경우
          newHeight = 1080;
          newWidth = (1080 * aspectRatio).round();
        }
        
        resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
        
        if (kDebugMode) {
          print('리사이징된 이미지 크기: ${resized.width}x${resized.height}');
        }
      }

      // JPEG로 압축 (품질 85%)
      final compressedBytes = img.encodeJpg(resized, quality: 85);
      
      if (kDebugMode) {
        print('압축 완료: ${bytes.length} -> ${compressedBytes.length} bytes');
      }
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      if (kDebugMode) {
        print('이미지 압축 오류: $e');
      }
      throw Exception('이미지 압축 실패: $e');
    }
  }

  Future<void> deleteStoreImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('이미지 삭제 실패: $e');
    }
  }

  Future<List<String>> getStoreImages(String userId) async {
    try {
      if (kDebugMode) {
        print('스토어 이미지 로드 시작: $userId');
      }
      
      final listResult = await _storage.ref('stores/$userId').listAll();
      List<String> urls = [];
      
      for (final item in listResult.items) {
        try {
          final url = await item.getDownloadURL();
          urls.add(url);
        } catch (e) {
          if (kDebugMode) {
            print('개별 이미지 URL 획득 실패: ${item.name}, 오류: $e');
          }
          // 개별 이미지 실패는 무시하고 계속 진행
          continue;
        }
      }
      
      if (kDebugMode) {
        print('스토어 이미지 로드 완료: ${urls.length}개');
      }
      
      // 최신 이미지가 먼저 오도록 정렬 (파일명에 타임스탬프 포함되어 있음)
      urls.sort((a, b) => b.compareTo(a));
      
      return urls;
    } catch (e) {
      if (kDebugMode) {
        print('스토어 이미지 로드 오류: $e');
      }
      return [];
    }
  }
}