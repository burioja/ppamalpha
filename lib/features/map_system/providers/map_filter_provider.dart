import 'package:flutter/foundation.dart';

/// 지도 필터 상태 관리 Provider
class MapFilterProvider with ChangeNotifier {
  // 필터 상태
  String _selectedCategory = 'all';
  double _maxDistance = 1.0;
  int _minReward = 0;
  bool _showUrgentOnly = false;
  bool _showVerifiedOnly = false;
  bool _showUnverifiedOnly = false;

  // Getters
  String get selectedCategory => _selectedCategory;
  double get maxDistance => _maxDistance;
  int get minReward => _minReward;
  bool get showUrgentOnly => _showUrgentOnly;
  bool get showVerifiedOnly => _showVerifiedOnly;
  bool get showUnverifiedOnly => _showUnverifiedOnly;

  // Setters
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setMaxDistance(double distance) {
    _maxDistance = distance;
    notifyListeners();
  }

  void setMinReward(int reward) {
    _minReward = reward;
    notifyListeners();
  }

  void setUrgentOnly(bool value) {
    _showUrgentOnly = value;
    notifyListeners();
  }

  void setVerifiedOnly(bool value) {
    _showVerifiedOnly = value;
    notifyListeners();
  }

  void setUnverifiedOnly(bool value) {
    _showUnverifiedOnly = value;
    notifyListeners();
  }

  /// 필터 초기화
  void resetFilters() {
    _selectedCategory = 'all';
    _maxDistance = 1.0;
    _minReward = 0;
    _showUrgentOnly = false;
    _showVerifiedOnly = false;
    _showUnverifiedOnly = false;
    notifyListeners();
  }

  /// 필터 적용 여부
  bool get hasActiveFilters {
    return _selectedCategory != 'all' ||
        _minReward > 0 ||
        _showUrgentOnly ||
        _showVerifiedOnly ||
        _showUnverifiedOnly;
  }

  /// 필터 데이터 맵 반환
  Map<String, dynamic> toMap() {
    return {
      'category': _selectedCategory,
      'maxDistance': _maxDistance,
      'minReward': _minReward,
      'showUrgentOnly': _showUrgentOnly,
      'showVerifiedOnly': _showVerifiedOnly,
      'showUnverifiedOnly': _showUnverifiedOnly,
    };
  }
}
