import 'package:flutter/material.dart';

class MapFilterProvider with ChangeNotifier {
  bool _showCouponsOnly = false;
  double _distanceKm = 3.0; // 기본 3km

  bool get showCouponsOnly => _showCouponsOnly;
  double get distanceKm => _distanceKm;

  void toggleCouponsOnly() {
    _showCouponsOnly = !_showCouponsOnly;
    notifyListeners();
  }

  void setDistance(double km) {
    _distanceKm = km;
    notifyListeners();
  }
}


