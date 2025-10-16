import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

/// 포스트 편집 화면의 미디어 처리 핸들러
class PostEditMediaHandler {
  // 이미지 선택
  static Future<List<dynamic>> pickImages(
    BuildContext context,
    List<dynamic> currentImages,
    List<String> currentImageNames,
  ) async {
    try {
      if (kIsWeb) {
        return await _pickImagesWeb(context, currentImages, currentImageNames);
      } else {
        return await _pickImagesMobile(context, currentImages, currentImageNames);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
      return currentImages;
    }
  }

  static Future<List<dynamic>> _pickImagesWeb(
    BuildContext context,
    List<dynamic> currentImages,
    List<String> currentImageNames,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        allowCompression: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newImages = List<dynamic>.from(currentImages);
        final newNames = List<String>.from(currentImageNames);

        for (final file in result.files) {
          if (file.size > 10 * 1024 * 1024) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('이미지 크기는 10MB 이하여야 합니다.')),
              );
            }
            continue;
          }

          if (file.bytes != null) {
            newImages.add(file.bytes!);
            newNames.add(file.name);
          }
        }

        return newImages;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
    return currentImages;
  }

  static Future<List<dynamic>> _pickImagesMobile(
    BuildContext context,
    List<dynamic> currentImages,
    List<String> currentImageNames,
  ) async {
    if (kIsWeb) {
      return await _pickImagesWeb(context, currentImages, currentImageNames);
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (image != null) {
      final newImages = List<dynamic>.from(currentImages);
      newImages.add(File(image.path));
      return newImages;
    }

    return currentImages;
  }

  // 사운드 선택
  static Future<Map<String, dynamic>> pickSound(BuildContext context) async {
    try {
      if (kIsWeb) {
        return await _pickSoundWeb(context);
      } else {
        return await _pickSoundMobile(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사운드 선택 실패: $e')),
        );
      }
      return {};
    }
  }

  static Future<Map<String, dynamic>> _pickSoundWeb(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.size > 50 * 1024 * 1024) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사운드 파일 크기는 50MB 이하여야 합니다.')),
            );
          }
          return {};
        }

        if (file.bytes != null) {
          return {
            'sound': file.bytes!,
            'fileName': file.name,
          };
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사운드 선택 실패: $e')),
        );
      }
    }
    return {};
  }

  static Future<Map<String, dynamic>> _pickSoundMobile(BuildContext context) async {
    if (kIsWeb) {
      return await _pickSoundWeb(context);
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.isNotEmpty) {
      final PlatformFile file = result.files.first;
      if (file.path != null) {
        return {
          'sound': File(file.path!),
          'fileName': file.name,
        };
      }
    }
    return {};
  }

  // 크로스 플랫폼 이미지 위젯 빌드
  static Widget buildCrossPlatformImage(dynamic imageData) {
    if (imageData is String) {
      if (imageData.startsWith('data:image/')) {
        return Image.memory(
          base64Decode(imageData.split(',')[1]),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else if (imageData.startsWith('http')) {
        return Image.network(
          imageData,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      } else {
        return Image.file(
          File(imageData),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        );
      }
    } else if (imageData is Uint8List) {
      return Image.memory(
        imageData,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (imageData is File) {
      return Image.file(
        imageData,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }
}


