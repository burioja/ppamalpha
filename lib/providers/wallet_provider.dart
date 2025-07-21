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

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .where('source', isEqualTo: 'upload')
        .orderBy('receivedAt', descending: true)
        .get();

    _uploadedImages = snapshot.docs.map((doc) => doc.data()).toList();
    notifyListeners();
  }

  Future<void> loadReceivedImages() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .where('source', isEqualTo: 'received')
        .orderBy('receivedAt', descending: true)
        .get();

    _receivedImages = snapshot.docs.map((doc) => doc.data()).toList();
    notifyListeners();
  }
}