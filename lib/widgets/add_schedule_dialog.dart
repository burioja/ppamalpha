import 'package:flutter/material.dart';
import '../services/schedule_service.dart';

class AddScheduleDialog extends StatefulWidget {
  final String selectedDate;

  const AddScheduleDialog({
    super.key,
    required this.selectedDate,
  });

  @override
  State<AddScheduleDialog> createState() => _AddScheduleDialogState();
}

class _AddScheduleDialogState extends State<AddScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedTime = '09:00';
  String _selectedCategory = 'personal';
  String _selectedPriority = 'medium';
  String _selectedShareScope = 'personal'; // 공유범위 선택
  int _duration = 60;

  final ScheduleService _scheduleService = ScheduleService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _addSchedule() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _scheduleService.addSchedule(
          title: _titleController.text,
          date: widget.selectedDate,
          time: _selectedTime,
          description: _descriptionController.text,
          duration: _duration,
          location: _locationController.text,
          category: _selectedCategory,
          priority: _selectedPriority,
          shareScope: _selectedShareScope,
        );
        
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스케줄이 추가되었습니다.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류가 발생했습니다: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 스케줄 추가'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedTime,
                      decoration: const InputDecoration(
                        labelText: '시간',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(24, (hour) {
                        final time = '${hour.toString().padLeft(2, '0')}:00';
                        return DropdownMenuItem(value: time, child: Text(time));
                      }),
                      onChanged: (value) {
                        setState(() {
                          _selectedTime = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _duration,
                      decoration: const InputDecoration(
                        labelText: '시간(분)',
                        border: OutlineInputBorder(),
                      ),
                      items: [30, 60, 90, 120, 180].map((duration) {
                        return DropdownMenuItem(value: duration, child: Text('$duration분'));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _duration = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '카테고리',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'work', child: Text('업무')),
                        DropdownMenuItem(value: 'personal', child: Text('개인')),
                        DropdownMenuItem(value: 'health', child: Text('건강')),
                        DropdownMenuItem(value: 'study', child: Text('학습')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: '우선순위',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(value: 'low', child: Text('낮음')),
                        DropdownMenuItem(value: 'medium', child: Text('보통')),
                        DropdownMenuItem(value: 'high', child: Text('높음')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '장소',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedShareScope,
                decoration: const InputDecoration(
                  labelText: '공유 범위',
                  border: OutlineInputBorder(),
                ),
                items: [
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _addSchedule,
          child: const Text('추가'),
        ),
      ],
    );
  }
} 