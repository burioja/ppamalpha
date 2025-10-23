import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';

class PostFileService {
  // 이미지 선택 (웹/모바일 통합)
  static Future<List<dynamic>> pickImages(BuildContext context) async {
    try {
      if (kIsWeb) {
        return await _pickImageWeb();
      } else {
        return await _pickImageMobile();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
      return [];
    }
  }

  // 이미지 선택 (웹)
  static Future<List<dynamic>> _pickImageWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<dynamic> images = [];
        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            throw Exception('파일 크기가 너무 큽니다. 10MB 이하의 파일을 선택해주세요.');
          }
          if (file.bytes != null) {
            images.add(file.bytes!);
          }
        }
        return images;
      }
      return [];
    } catch (e) {
      throw Exception('웹 이미지 선택 실패: $e');
    }
  }

  // 이미지 선택 (모바일)
  static Future<List<dynamic>> _pickImageMobile() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      List<dynamic> imageBytes = [];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        imageBytes.add(bytes);
      }
      return imageBytes;
    }
    return [];
  }

  // 단일 이미지 선택 (기존 호환성)
  static Future<List<dynamic>> pickImage(BuildContext context) async {
    try {
      if (kIsWeb) {
        return await _pickImageWeb();
      } else {
        return await _pickImageMobile();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
      return [];
    }
  }

  // 사운드 파일 선택 (웹/모바일 통합)
  static Future<Map<String, dynamic>?> pickSound(BuildContext context) async {
    try {
      if (kIsWeb) {
        return await _pickSoundWeb();
      } else {
        return await _pickSoundMobile();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사운드 선택 실패: $e')),
        );
      }
      return null;
    }
  }

  // 사운드 파일 선택 (웹)
  static Future<Map<String, dynamic>?> _pickSoundWeb() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          throw Exception('파일 크기가 너무 큽니다. 50MB 이하의 파일을 선택해주세요.');
        }
        if (file.bytes != null) {
          return {
            'bytes': file.bytes!,
            'name': file.name,
            'size': file.size,
          };
        }
      }
      return null;
    } catch (e) {
      throw Exception('웹 사운드 선택 실패: $e');
    }
  }

  // 사운드 파일 선택 (모바일)
  static Future<Map<String, dynamic>?> _pickSoundMobile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        final fileBytes = await File(file.path!).readAsBytes();
        return {
          'bytes': fileBytes,
          'name': file.name,
          'size': file.size,
          'path': file.path,
        };
      }
    }
    return null;
  }

  // 이미지 제거
  static List<dynamic> removeImage(List<dynamic> images, int index) {
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
    }
    return images;
  }

  // 사운드 제거
  static Map<String, dynamic>? removeSound() {
    return null;
  }

  // 파일 크기 포맷팅
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 파일 확장자 확인
  static bool isValidImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  static bool isValidAudioFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(extension);
  }

  // 파일 타입별 아이콘 반환
  static IconData getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
        return Icons.audiotrack;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }

  // 파일 타입별 색상 반환
  static Color getFileColor(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Colors.blue;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
      case 'ogg':
        return Colors.orange;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
