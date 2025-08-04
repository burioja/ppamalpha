import 'package:flutter/material.dart';

class StatusProvider with ChangeNotifier {
  String _currentText = '';

  String get currentText => _currentText;

  void setCurrentText(String text) {
    _currentText = text;
    notifyListeners();
  }
}
