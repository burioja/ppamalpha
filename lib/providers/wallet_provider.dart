import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletProvider with ChangeNotifier {
  List<Map<String, dynamic>> _receivedImages = [];
  List<Map<String, dynamic>> _uploadedImages = [];

  List<Map<String, dynamic>> get receivedImages => _receivedImages;
  List<Map<String, dynamic>> get uploadedImages => _uploadedImages;

  Future<void> loadUploadedImages() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .where('source', isEqualTo: 'upload')
          .orderBy('receivedAt', descending: true)
          .get();

      _uploadedImages = snapshot.docs.map((doc) => doc.data()).toList();
      print('업로드된 이미지 로드 완료: ${_uploadedImages.length}개');
      notifyListeners();
    } catch (e) {
      print('업로드된 이미지 로드 오류: $e');
      // 인덱스 오류 시 단순 쿼리로 폴백
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .where('source', isEqualTo: 'upload')
            .get();

        _uploadedImages = snapshot.docs.map((doc) => doc.data()).toList();
        print('폴백 쿼리로 업로드된 이미지 로드 완료: ${_uploadedImages.length}개');
        notifyListeners();
      } catch (fallbackError) {
        print('폴백 쿼리도 실패: $fallbackError');
        _uploadedImages = [];
        notifyListeners();
      }
    }
  }

  Future<void> loadReceivedImages() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .where('source', isEqualTo: 'received')
          .orderBy('receivedAt', descending: true)
          .get();

      _receivedImages = snapshot.docs.map((doc) => doc.data()).toList();
      print('수신된 이미지 로드 완료: ${_receivedImages.length}개');
      notifyListeners();
    } catch (e) {
      print('수신된 이미지 로드 오류: $e');
      // 인덱스 오류 시 단순 쿼리로 폴백
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .where('source', isEqualTo: 'received')
            .get();

        _receivedImages = snapshot.docs.map((doc) => doc.data()).toList();
        print('폴백 쿼리로 수신된 이미지 로드 완료: ${_receivedImages.length}개');
        notifyListeners();
      } catch (fallbackError) {
        print('폴백 쿼리도 실패: $fallbackError');
        _receivedImages = [];
        notifyListeners();
      }
    }
  }
}