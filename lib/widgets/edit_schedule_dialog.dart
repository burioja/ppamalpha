import 'package:flutter/material.dart';
import '../services/schedule_service.dart';

class EditScheduleDialog extends StatefulWidget {
  final String scheduleId;
  final Map<String, dynamic> scheduleData;

  const EditScheduleDialog({
    super.key,
    required this.scheduleId,
    required this.scheduleData,
  });

  @override
  State<EditScheduleDialog> createState() => _EditScheduleDialogState();
}

class _EditScheduleDialogState extends State<EditScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late String _selectedTime;
  late String _selectedCategory;
  late String _selectedPriority;
  late String _selectedShareScope; // 공유범위 추가
  late int _duration;
  bool _isUpdating = false;

  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    // 기존 데이터로 초기화 (타입 안전성 확보)
    _titleController = TextEditingController(text: widget.scheduleData['title']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.scheduleData['description']?.toString() ?? '');
    _locationController = TextEditingController(text: widget.scheduleData['location']?.toString() ?? '');
    _selectedTime = widget.scheduleData['time']?.toString() ?? '09:00';
    _selectedCategory = widget.scheduleData['category']?.toString() ?? 'personal';
    _selectedPriority = widget.scheduleData['priority']?.toString() ?? 'medium';
    _selectedShareScope = widget.scheduleData['shareScope']?.toString() ?? 'personal';
    
    // duration을 안전하게 int로 변환
    final durationData = widget.scheduleData['duration'];
    if (durationData is int) {
      _duration = durationData;
    } else if (durationData is String) {
      _duration = int.tryParse(durationData) ?? 60;
    } else {
      _duration = 60; // 기본값
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _updateSchedule() async {
    if (_formKey.currentState!.validate() && !_isUpdating) {
      setState(() {
        _isUpdating = true;
      });
      
      try {
        // 디버깅을 위한 데이터 출력
        print('업데이트할 데이터:');
        print('title: ${_titleController.text} (${_titleController.text.runtimeType})');
        print('time: $_selectedTime (${_selectedTime.runtimeType})');
        print('description: ${_descriptionController.text} (${_descriptionController.text.runtimeType})');
        print('duration: $_duration (${_duration.runtimeType})');
        print('location: ${_locationController.text} (${_locationController.text.runtimeType})');
        print('category: $_selectedCategory (${_selectedCategory.runtimeType})');
        print('priority: $_selectedPriority (${_selectedPriority.runtimeType})');
        
        // 기존 isCompleted 상태 유지
        final currentIsCompleted = widget.scheduleData['isCompleted'] as bool? ?? false;
        print('currentIsCompleted: $currentIsCompleted (${currentIsCompleted.runtimeType})');
        print('widget.scheduleData: ${widget.scheduleData}');
        print('widget.scheduleData[\'isCompleted\']: ${widget.scheduleData['isCompleted']} (${widget.scheduleData['isCompleted'].runtimeType})');
        
        await _scheduleService.updateSchedule(
          scheduleId: widget.scheduleId,
          title: _titleController.text.trim(),
          time: _selectedTime,
          description: _descriptionController.text.trim(),
          duration: _duration,
          location: _locationController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          isCompleted: currentIsCompleted, // 기존 완료 상태 유지
          shareScope: _selectedShareScope,
        );
        
        if (mounted) {
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('스케줄이 수정되었습니다.')),
          );
          
          print('=== 업데이트 성공 후 디버깅 ===');
          print('다이얼로그 닫기 시도...');
          print('Navigator.canPop(): ${Navigator.of(context).canPop()}');
          
          // 다이얼로그 닫기 - 안전한 방법
          if (Navigator.of(context).canPop()) {
            print('Navigator.pop() 호출...');
            Navigator.of(context).pop('updated'); // true 대신 문자열 반환
            print('Navigator.pop() 완료');
          } else {
            print('Navigator.canPop()이 false입니다');
          }
        }
      } catch (e) {
        print('스케줄 업데이트 오류: $e');
        print('오류 타입: ${e.runtimeType}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('오류가 발생했습니다: $e')),
          );
          setState(() {
            _isUpdating = false;
          });
        }
      }
    }
  }

  Future<void> _deleteSchedule() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      await _scheduleService.deleteSchedule(widget.scheduleId);
      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스케줄이 삭제되었습니다.')),
        );
        
        // 다이얼로그 닫기 - 안전한 방법
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop('deleted');
        }
      }
    } catch (e) {
      print('스케줄 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _closeDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: AlertDialog(
        title: const Text('스케줄 편집'),
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
            onPressed: _isUpdating ? null : () async {
              // 삭제 확인을 위한 간단한 확인
              try {
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    title: const Text('스케줄 삭제'),
                    content: const Text('이 스케줄을 삭제하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                
                if (shouldDelete == true) {
                  await _deleteSchedule();
                }
              } catch (e) {
                print('삭제 확인 다이얼로그 오류: $e');
                // 오류 발생 시 바로 삭제 진행
                await _deleteSchedule();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
          TextButton(
            onPressed: _isUpdating ? null : _closeDialog,
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: _isUpdating ? null : _updateSchedule,
            child: _isUpdating 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('수정'),
          ),
        ],
      ),
    );
  }
} 