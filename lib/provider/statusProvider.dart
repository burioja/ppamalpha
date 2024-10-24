import 'package:flutter/foundation.dart';

class StatusProvider extends ChangeNotifier {
  String? _currentItem; // 현재 표시되는 아이템
  List<List<String>> _workplaceDataList = []; // 직장 정보 목록 (그룹화)

  String? get currentItem => _currentItem; // 현재 아이템 getter
  List<List<String>> get workplaceDataList => _workplaceDataList; // 데이터 목록 getter

  void setWorkplaceDataList(List<List<String>> workplaceDataList) {
    _workplaceDataList = workplaceDataList; // 데이터 목록 설정
    notifyListeners(); // 값이 변경되면 구독자에게 알림
  }

  void setCurrentItem(String currentItem) {
    _currentItem = currentItem; // 현재 아이템 설정
    notifyListeners(); // 값이 변경되면 구독자에게 알림
  }
}
