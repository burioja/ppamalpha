import 'package:flutter/material.dart';

class MapFilterProvider with ChangeNotifier {
  bool _showCouponsOnly = false;
  bool _showMyPostsOnly = false;

  bool get showCouponsOnly => _showCouponsOnly;
  bool get showMyPostsOnly => _showMyPostsOnly;

  void toggleCouponsOnly() {
    _showCouponsOnly = !_showCouponsOnly;
    notifyListeners();
  }

  void toggleMyPostsOnly() {
    _showMyPostsOnly = !_showMyPostsOnly;
    notifyListeners();
  }

  void resetFilters() {
    _showCouponsOnly = false;
    _showMyPostsOnly = false;
    notifyListeners();
  }
}


