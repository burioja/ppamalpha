import 'package:flutter/material.dart';

class SearchProvider with ChangeNotifier {
  String _query = '';
  int _selectedTabIndex = 0; // ?”§ ì¶”ê???

  String get query => _query;
  int get selectedTabIndex => _selectedTabIndex; // ?”§ ì¶”ê???

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }

  void setSelectedTabIndex(int index) { // ?”§ ì¶”ê???
    _selectedTabIndex = index;
    notifyListeners();
  }
}
