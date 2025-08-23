import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart' show rootBundle; // 경로 수정

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 정보
  User? get currentUser => _auth.currentUser;

  // 이미지 업로드
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

  // 웹 Data URL 기반 이미지 업로드
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

