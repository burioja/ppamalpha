import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 사용자 데이터
  String _email = '';
  String _phoneNumber = '';
  String _address = '';
  List<Map<String, String>> _workPlaces = [];

  // Getter
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;
  List<Map<String, String>> get workPlaces => _workPlaces;

  // Setter
  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void setPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  void setAddress(String address) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'address': address,
      });
      _address = address;
      notifyListeners();
    }
  }

  void setWorkPlaces(List<Map<String, String>> workPlaces) {
    _workPlaces = workPlaces;
    notifyListeners();
  }

  // WorkPlaces 관리 메서드
  void addWorkPlace() {
    _workPlaces.add({'workplaceinput': '', 'workplaceadd': ''});
    notifyListeners();
  }

  void removeWorkPlace(int index) {
    if (index >= 0 && index < _workPlaces.length) {
      _workPlaces.removeAt(index);
      notifyListeners();
    }
  }

  void updateWorkPlace(int index, String key, String value) {
    if (index >= 0 && index < _workPlaces.length) {
      _workPlaces[index][key] = value;
      notifyListeners();
    }
  }

  // Firebase에서 사용자 데이터 가져오기
  Future<void> fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _email = doc['email'] ?? '';
          _phoneNumber = doc['phoneNumber'] ?? '';
          _address = doc['address'] ?? '';
          _workPlaces = List<Map<String, String>>.from(doc['workPlaces'] ?? []);
          notifyListeners();
        }
      }
    } catch (e) {
      print('사용자 데이터 가져오기 실패: $e');
    }
  }

  // Firebase에 사용자 데이터 업데이트
  Future<void> updateUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'email': _email,
          'phoneNumber': _phoneNumber,
          'address': _address,
          'workPlaces': _workPlaces,
        });

        // FirebaseAuth 이메일 업데이트
        await user.updateEmail(_email);
        notifyListeners();
      }
    } catch (e) {
      print('사용자 데이터 업데이트 실패: $e');
    }
  }
}
