import 'package:flutter/material.dart';

class SearchProvider with ChangeNotifier {
  String _query = '';
  int _selectedTabIndex = 0; // ?�� 추�???

  String get query => _query;
  int get selectedTabIndex => _selectedTabIndex; // ?�� 추�???

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }

  void setSelectedTabIndex(int index) { // ?�� 추�???
    _selectedTabIndex = index;
    notifyListeners();
  }
}
