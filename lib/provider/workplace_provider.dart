import 'package:flutter/foundation.dart';

class WorkplaceProvider extends ChangeNotifier {
  String? _workplaceInput;

  String? get workplaceInput => _workplaceInput;

  void setWorkplaceInput(String workplaceInput) {
    _workplaceInput = workplaceInput;
    notifyListeners(); // 값이 변경되면 구독자에게 알림
  }
}
