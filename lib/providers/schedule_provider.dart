import 'package:flutter/foundation.dart';

class ScheduleProvider extends ChangeNotifier {
  List<ScheduleItem> _schedules = [];
  
  List<ScheduleItem> get schedules => _schedules;
  
  void addSchedule(ScheduleItem schedule) {
    _schedules.add(schedule);
    notifyListeners();
  }
  
  void removeSchedule(String id) {
    _schedules.removeWhere((schedule) => schedule.id == id);
    notifyListeners();
  }
}

class ScheduleItem {
  final String id;
  final String title;
  final DateTime date;
  
  ScheduleItem({
    required this.id,
    required this.title,
    required this.date,
  });
} 