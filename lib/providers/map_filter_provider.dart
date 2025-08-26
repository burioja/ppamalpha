import 'package:flutter/material.dart';

class MapFilterProvider with ChangeNotifier {
  bool _showCouponsOnly = false;

  bool get showCouponsOnly => _showCouponsOnly;

  void toggleCouponsOnly() {
    _showCouponsOnly = !_showCouponsOnly;
    notifyListeners();
  }
}


