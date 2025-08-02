import 'package:flutter/material.dart';
import '../services/schedule_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleWidget extends StatefulWidget {
  final String? selectedShareScope; // 필터 파라미터 추가

  const ScheduleWidget({
    super.key,
    this.selectedShareScope,
  });

  @override
  State<ScheduleWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<ScheduleWidget> {
  String _selectedShareScope = 'all'; // 필터 상태 추가
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    // 외부에서 전달된 필터 값이 있으면 사용
    if (widget.selectedShareScope != null) {
      _selectedShareScope = widget.selectedShareScope!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // 필터에 따른 스케줄 스트림 선택
    Stream<QuerySnapshot<Map<String, dynamic>>> getScheduleStream() {
      switch (_selectedShareScope) {
        case 'personal':
          return _scheduleService.getPersonalSchedules(dateString);
        case 'team':
          return _scheduleService.getTeamSchedules(dateString);
        case 'public':
          return _scheduleService.getPublicSchedules(dateString);
        default:
          return _scheduleService.getSchedulesByDate(dateString);
      }
    }

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
              Row(
                children: [
                  // 필터 드롭다운
                  DropdownButton<String>(
                    value: _selectedShareScope,
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('전체')),
                      DropdownMenuItem(value: 'personal', child: Text('개인용')),
                      DropdownMenuItem(value: 'team', child: Text('팀 공유')),
                      DropdownMenuItem(value: 'public', child: Text('공개')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedShareScope = value!;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      // 스케줄 추가 기능
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // 스케줄 리스트
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: getScheduleStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text('오류가 발생했습니다: ${snapshot.error}'),
                );
              }
              
              final schedules = snapshot.data?.docs ?? [];
              
              if (schedules.isEmpty) {
                return const Center(
                  child: Text(
                    '스케줄이 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: schedules.length,
                itemBuilder: (context, index) {
                  final doc = schedules[index];
                  final data = doc.data();
                  final isCompleted = data['isCompleted'] ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        isCompleted ? Icons.check_circle : Icons.schedule,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                      title: Text(
                        data['title'] ?? '제목 없음',
                        style: TextStyle(
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? Colors.grey : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['time'] ?? '00:00'),
                          if (data['shareScope'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getShareScopeColor(data['shareScope']),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getShareScopeText(data['shareScope']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          // 편집 기능
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getShareScopeColor(String? shareScope) {
    switch (shareScope) {
      case 'personal':
        return Colors.blue;
      case 'team':
        return Colors.orange;
      case 'public':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getShareScopeText(String? shareScope) {
    switch (shareScope) {
      case 'personal':
        return '개인용';
      case 'team':
        return '팀 공유';
      case 'public':
        return '공개';
      default:
        return '알 수 없음';
    }
  }
} 