import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle; // 경로 수정
import 'package:image/image.dart' as img;

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 정보
  User? get currentUser => _auth.currentUser;

  // 이미지 업로드 (원본 + 썸네일)
  Future<Map<String, String>> uploadImageWithThumbnail(File image, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      print('=== uploadImageWithThumbnail 시작 ===');
      print('파일명: $fileName');
      print('폴더: $folder');
      
      // 원본 이미지 업로드
      final originalPath = '$folder/original/$fileName';
      final originalRef = _storage.ref().child(originalPath);
      print('원본 경로: $originalPath');
      final originalMetadata = SettableMetadata(contentType: _guessContentType(fileName));
      final originalUploadTask = originalRef.putFile(image, originalMetadata);
      final originalSnapshot = await originalUploadTask;
      final originalUrl = await originalSnapshot.ref.getDownloadURL();
      print('원본 URL: $originalUrl');
      
      // 썸네일 생성 및 업로드
      final thumbnailData = await _createThumbnail(await image.readAsBytes());
      final thumbnailPath = '$folder/thumbnails/$fileName';
      final thumbnailRef = _storage.ref().child(thumbnailPath);
      print('썸네일 경로: $thumbnailPath');
      final thumbnailMetadata = SettableMetadata(contentType: 'image/jpeg');
      final thumbnailUploadTask = thumbnailRef.putData(thumbnailData, thumbnailMetadata);
      final thumbnailSnapshot = await thumbnailUploadTask;
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      print('썸네일 URL: $thumbnailUrl');
      
      final result = {
        'original': originalUrl,
        'thumbnail': thumbnailUrl,
      };
      print('최종 결과: $result');
      return result;
    } catch (e) {
      print('에러: 이미지 업로드 실패 - $e');
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  // 기존 메서드 유지 (하위 호환성)
  Future<String> uploadImage(File image, String folder) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      final ref = _storage.ref().child('$folder/$fileName');
      final metadata = SettableMetadata(contentType: _guessContentType(fileName));
      final uploadTask = ref.putFile(image, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('이미지 업로드 실패: $e');
    }
  }

  // 웹 Data URL 기반 이미지 업로드 (원본 + 썸네일)
  Future<Map<String, String>> uploadImageDataUrlWithThumbnail(String dataUrl, String folder, String fileName) async {
    try {
      // 원본 이미지 업로드
      final originalRef = _storage.ref().child('$folder/original/$fileName');
      final originalSnapshot = await originalRef.putString(
        dataUrl,
        format: PutStringFormat.dataUrl,
      );
      final originalUrl = await originalSnapshot.ref.getDownloadURL();
      
      // Data URL을 바이트로 변환하여 썸네일 생성
      final base64Data = dataUrl.split(',')[1];
      final imageBytes = base64Decode(base64Data);
      final thumbnailData = await _createThumbnail(imageBytes);
      
      // 썸네일 업로드
      final thumbnailRef = _storage.ref().child('$folder/thumbnails/$fileName');
      final thumbnailMetadata = SettableMetadata(contentType: 'image/jpeg');
      final thumbnailSnapshot = await thumbnailRef.putData(thumbnailData, thumbnailMetadata);
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      
      return {
        'original': originalUrl,
        'thumbnail': thumbnailUrl,
      };
    } catch (e) {
      throw Exception('Data URL 이미지 업로드 실패: $e');
    }
  }

  // 웹 바이트 기반 이미지 업로드 (원본 + 썸네일)
  Future<Map<String, String>> uploadImageBytesWithThumbnail(Uint8List imageBytes, String folder, String fileName) async {
    try {
      print('=== uploadImageBytesWithThumbnail 시작 (웹용) ===');
      print('파일명: $fileName');
      print('폴더: $folder');
      print('이미지 크기: ${imageBytes.length} bytes');
      
      // 원본 이미지 업로드
      final originalPath = '$folder/original/$fileName';
      final originalRef = _storage.ref().child(originalPath);
      print('원본 경로: $originalPath');
      final originalMetadata = SettableMetadata(contentType: _guessContentType(fileName));
      final originalSnapshot = await originalRef.putData(imageBytes, originalMetadata);
      final originalUrl = await originalSnapshot.ref.getDownloadURL();
      print('원본 URL: $originalUrl');
      
      // 썸네일 생성 및 업로드
      final thumbnailData = await _createThumbnail(imageBytes);
      final thumbnailPath = '$folder/thumbnails/$fileName';
      final thumbnailRef = _storage.ref().child(thumbnailPath);
      print('썸네일 경로: $thumbnailPath');
      final thumbnailMetadata = SettableMetadata(contentType: 'image/jpeg');
      final thumbnailSnapshot = await thumbnailRef.putData(thumbnailData, thumbnailMetadata);
      final thumbnailUrl = await thumbnailSnapshot.ref.getDownloadURL();
      print('썸네일 URL: $thumbnailUrl');
      
      final result = {
        'original': originalUrl,
        'thumbnail': thumbnailUrl,
      };
      print('최종 결과: $result');
      return result;
    } catch (e) {
      print('에러: 바이트 이미지 업로드 실패 - $e');
      throw Exception('바이트 이미지 업로드 실패: $e');
    }
  }

  // 기존 메서드 유지 (하위 호환성)
  Future<String> uploadImageDataUrl(String dataUrl, String folder, String fileName) async {
    try {
      final ref = _storage.ref().child('$folder/$fileName');
      final TaskSnapshot snapshot = await ref.putString(
        dataUrl,
        format: PutStringFormat.dataUrl,
      );
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Data URL 이미지 업로드 실패: $e');
    }
  }

  // 웹용 Blob 이미지 업로드
  Future<String> uploadImageFromBlob(dynamic blob, String folder, String fileName) async {
    try {
      if (blob == null) {
        throw Exception('Blob이 null입니다.');
      }
      
      final ref = _storage.ref().child('$folder/$fileName');
      final metadata = SettableMetadata(contentType: _guessContentType(fileName));
      final uploadTask = ref.putBlob(blob, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('업로드된 이미지의 다운로드 URL을 가져올 수 없습니다.');
      }
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Blob 이미지 업로드 실패: $e');
    }
  }

  // 웹용 바이트 오디오 업로드
  Future<String> uploadAudioBytes(Uint8List audioBytes, String folder, String fileName) async {
    try {
      final ref = _storage.ref().child('$folder/$fileName');
      final metadata = SettableMetadata(contentType: _guessContentType(fileName));
      final uploadTask = ref.putData(audioBytes, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      if (downloadUrl.isEmpty) {
        throw Exception('업로드된 오디오의 다운로드 URL을 가져올 수 없습니다.');
      }
      
      return downloadUrl;
    } catch (e) {
      throw Exception('바이트 오디오 업로드 실패: $e');
    }
  }

  // 이미지 URL 해석: http/https/data:image/ 는 그대로, gs:// 또는 경로는 download URL 생성
  Future<String?> resolveImageUrl(String value) async {
    try {
      if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:image/')) {
        return value;
      }
      if (value.startsWith('gs://')) {
        final ref = _storage.refFromURL(value);
        return await ref.getDownloadURL();
      }
      // storage 경로로 간주
      final ref = _storage.ref().child(value);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // 썸네일 생성 메서드
  Future<Uint8List> _createThumbnail(Uint8List imageBytes) async {
    try {
      print('썸네일 생성 시작 - 원본 이미지 크기: ${imageBytes.length} bytes');
      
      // 이미지 디코딩
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('에러: 이미지 디코딩 실패 - 지원되지 않는 형식이거나 손상된 데이터');
        throw Exception('이미지 디코딩 실패 - 지원되지 않는 형식');
      }
      
      print('원본 이미지 크기: ${image.width}x${image.height}');
      
      // 썸네일 크기 계산 (최대 300x300, 비율 유지)
      const maxSize = 300;
      int width, height;
      
      if (image.width > image.height) {
        width = maxSize;
        height = (image.height * maxSize / image.width).round();
      } else {
        height = maxSize;
        width = (image.width * maxSize / image.height).round();
      }
      
      print('썸네일 크기: ${width}x$height');
      
      // 이미지 리사이즈
      final thumbnail = img.copyResize(image, width: width, height: height);
      print('리사이즈 완료');
      
      // JPEG로 인코딩 (품질 85%)
      final jpegBytes = img.encodeJpg(thumbnail, quality: 85);
      print('썸네일 JPEG 인코딩 완료 - 생성된 크기: ${jpegBytes.length} bytes');
      
      if (jpegBytes.isEmpty) {
        throw Exception('JPEG 인코딩 결과가 비어있음');
      }
      
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('에러: 썸네일 생성 실패 - $e');
      throw Exception('썸네일 생성 실패: $e');
    }
  }

  String? _guessContentType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.bmp')) return 'image/bmp';
    if (name.endsWith('.svg')) return 'image/svg+xml';
    if (name.endsWith('.m4a')) return 'audio/mp4';
    if (name.endsWith('.mp3')) return 'audio/mpeg';
    if (name.endsWith('.wav')) return 'audio/wav';
    return null; // Firebase가 추정하도록 둠
  }

  // JSON 파일을 읽어 Firebase에 업로드하는 함수
  Future<void> uploadWorkplaces() async {
    try {
      // JSON 파일 로드
      final String response = await rootBundle.loadString('assets/workplaces.json');
      final data = json.decode(response)['workplaces'];

      // Firestore에 데이터 삽입
      for (var workplace in data) {
        final String id = workplace['id'].toString();
        final docRef = _firestore.collection('workplaces').doc(id);

        // ID가 존재하는지 확인
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set(workplace);
          // 크레스 '$id'가 Firebase에 추가되었습니다.
        } else {
          // 크레스 '$id'는 이미 존재합니다. 건너뛰기
        }
      }

      // JSON 데이터가 Firebase에 업로드되었습니다.
    } catch (e) {
      // 오류 발생: $e
    }
  }
}

