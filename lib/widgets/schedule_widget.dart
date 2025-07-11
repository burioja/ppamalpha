import 'package:flutter/material.dart';

class ScheduleWidget extends StatefulWidget {
  const ScheduleWidget({super.key});

  @override
  State<ScheduleWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<ScheduleWidget> {
  final List<Map<String, dynamic>> _schedules = [
    {'title': '회의', 'time': '09:00', 'date': '2024-01-15'},
    {'title': '점심약속', 'time': '12:30', 'date': '2024-01-15'},
    {'title': '운동', 'time': '18:00', 'date': '2024-01-15'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '오늘의 스케줄',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  // 스케줄 추가 기능
                },
              ),
            ],
          ),
        ),
        
        // 스케줄 리스트
        Expanded(
          child: ListView.builder(
            itemCount: _schedules.length,
            itemBuilder: (context, index) {
              final schedule = _schedules[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(schedule['title']),
                  subtitle: Text(schedule['time']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      // 삭제 기능
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
} 