import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String? _userId;
  String? _userName;
  String? _email;
  String? _phoneNumber;
  String? _address;
  List<Map<String, String>> _workPlaces = [];
  bool _isLoggedIn = false;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get email => _email;
  String? get phoneNumber => _phoneNumber;
  String? get address => _address;
  List<Map<String, String>> get workPlaces => _workPlaces;
  bool get isLoggedIn => _isLoggedIn;

  void setUser(String userId, String userName) {
    _userId = userId;
    _userName = userName;
    _isLoggedIn = true;
    notifyListeners();
  }

  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void setNickName(String nickName) {
    _userName = nickName;
    notifyListeners();
  }

  void setPhoneNumber(String phoneNumber) {
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  void setAddress(String address) {
    _address = address;
    notifyListeners();
  }

  void addWorkPlace() {
    _workPlaces.add({'workplaceinput': '', 'workplaceadd': ''});
    notifyListeners();
  }

  void updateWorkPlace(int index, String key, String value) {
    if (index < _workPlaces.length) {
      _workPlaces[index][key] = value;
      notifyListeners();
    }
  }

  void removeWorkPlace(int index) {
    if (index < _workPlaces.length) {
      _workPlaces.removeAt(index);
      notifyListeners();
    }
  }

  Future<void> fetchUserData() async {
    // TODO: 실제 데이터 로드 구현
  }

  Future<void> updateUserData() async {
    // TODO: 실제 데이터 업데이트 구현
  }

  void logout() {
    _userId = null;
    _userName = null;
    _email = null;
    _phoneNumber = null;
    _address = null;
    _workPlaces.clear();
    _isLoggedIn = false;
    notifyListeners();
  }
}