import 'package:flutter/material.dart';
import 'dart:async';

class SearchProvider with ChangeNotifier {
  String _query = '';
  int _selectedTabIndex = 0; // ?�� 추�???
  Timer? _debounceTimer;

  String get query => _query;
  int get selectedTabIndex => _selectedTabIndex; // ?�� 추�???

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setQueryDebounced(String value, {Duration duration = const Duration(milliseconds: 250)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, () {
      _query = value;
      notifyListeners();
      // 실제 검색 트리거는 11.2(MeiliSearch 연동) 단계에서 구현
    });
  }

  void clearQuery() {
    _query = '';
    notifyListeners();
  }

  void triggerSearch() {
    // 엔터키/제출 시점의 검색 트리거 훅
    // 11.2 단계에서 실제 검색 연동 구현 예정
    notifyListeners();
  }

  void setSelectedTabIndex(int index) { // ?�� 추�???
    _selectedTabIndex = index;
    notifyListeners();
  }
}
