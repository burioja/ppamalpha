import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 기존 변??
  String _email = '';
  String _phoneNumber = '';
  String _address = '';
  List<Map<String, String>> _workPlaces = [];

  // 추�???변??
  String _nickName = '';
  String _profileImageUrl = '';
  String _birthDate = '';
  String _gender = '';
  List<String> _followers = [];
  List<String> _following = [];
  List<String> _connections = [];
  double _balance = 0.0;
  String _bankAccount = '';

  // Getter
  String get email => _email;
  String get phoneNumber => _phoneNumber;
  String get address => _address;
  List<Map<String, String>> get workPlaces => _workPlaces;
  String get nickName => _nickName;
  String get profileImageUrl => _profileImageUrl;
  String get birthDate => _birthDate;
  String get gender => _gender;
  List<String> get followers => _followers;
  List<String> get following => _following;
  List<String> get connections => _connections;
  double get balance => _balance;
  String get bankAccount => _bankAccount;

  // Setter
  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void setPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  void setNickName(String nickName) {
    _nickName = nickName;
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



  void setProfileImageUrl(String url) {
    _profileImageUrl = url;
    notifyListeners();
  }

  void setBirthDate(String birthDate) {
    _birthDate = birthDate;
    notifyListeners();
  }

  void setGender(String gender) {
    _gender = gender;
    notifyListeners();
  }

  void setFollowers(List<String> followers) {
    _followers = followers;
    notifyListeners();
  }

  void setFollowing(List<String> following) {
    _following = following;
    notifyListeners();
  }

  void setConnections(List<String> connections) {
    _connections = connections;
    notifyListeners();
  }

  void setBalance(double balance) {
    _balance = balance;
    notifyListeners();
  }

  void setBankAccount(String bankAccount) {
    _bankAccount = bankAccount;
    notifyListeners();
  }

  // WorkPlaces 관�?메서??
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

  // Firebase?�서 ?�용???�이??가?�오�?
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

          // 추�????�이??가?�오�?
          _nickName = doc['nickName'] ?? '';
          _profileImageUrl = doc['profileImageUrl'] ?? '';
          _birthDate = doc['birthDate'] ?? '';
          _gender = doc['gender'] ?? '';
          _followers = List<String>.from(doc['followers'] ?? []);
          _following = List<String>.from(doc['following'] ?? []);
          _connections = List<String>.from(doc['connections'] ?? []);
          _balance = doc['balance']?.toDouble() ?? 0.0;
          _bankAccount = doc['bankAccount'] ?? '';

          notifyListeners();
        }
      }
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // Firebase???�용???�이???�데?�트
  Future<void> updateUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'email': _email,
          'phoneNumber': _phoneNumber,
          'address': _address,
          'workPlaces': _workPlaces,
          'nickName': _nickName,

          // 추�????�이???�데?�트

          'profileImageUrl': _profileImageUrl,
          'birthDate': _birthDate,
          'gender': _gender,
          'followers': _followers,
          'following': _following,
          'connections': _connections,
          'balance': _balance,
          'bankAccount': _bankAccount,
        });

        // FirebaseAuth ?�메???�데?�트
        await user.updateEmail(_email);
        notifyListeners();
      }
    } catch (e) {
      // print �� ���ŵ�
    }
  }
}
