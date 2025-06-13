import 'package:flutter/material.dart';

class SearchProvider with ChangeNotifier {
  String _query = '';

  String get query => _query;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }
}