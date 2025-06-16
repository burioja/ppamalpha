import 'package:flutter/material.dart';

class SearchProvider with ChangeNotifier {
  String _query = '';
  int _selectedTabIndex = 0; // 🔧 추가됨

  String get query => _query;
  int get selectedTabIndex => _selectedTabIndex; // 🔧 추가됨

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }

  void setSelectedTabIndex(int index) { // 🔧 추가됨
    _selectedTabIndex = index;
    notifyListeners();
  }
}