import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // 🔑 로그인 화면 import
import '../widgets/schedule_widget.dart'; // 📅 스케줄 위젯 import
import 'dart:math';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  // 현재 표시할 화면을 관리하는 상태
  bool _showSchedule = false;

  void _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("로그아웃"),
        content: const Text("로그아웃 하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("확인"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut(); // 🔒 Firebase 로그아웃

      // 로그인 화면으로 이동 + 모든 뒤로가기 스택 제거
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // 스케줄 화면 토글 함수
  void _toggleSchedule() {
    setState(() {
      _showSchedule = !_showSchedule;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showSchedule ? 'Schedule' : 'Store'),
        actions: [
          // 📅 스케줄 메뉴 버튼
          IconButton(
            icon: Icon(_showSchedule ? Icons.store : Icons.schedule),
            onPressed: _toggleSchedule,
            tooltip: _showSchedule ? '스토어로 돌아가기' : '스케줄',
          ),
          // 🔑 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '로그아웃',
          ),
        ],
      ),
      body: _showSchedule
          ? const ScheduleWidget()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 Store 정보 영역
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 프로필 이미지
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: AssetImage('assets/images/default_profile.png'),
                          ),
                          const SizedBox(width: 16),
                          // 닉네임, 권한
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '닉네임',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Authority',
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // 트랙
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.track_changes, size: 16, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text('Track', style: TextStyle(color: Colors.green)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 커넥션
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.people, size: 16, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text('Connection', style: TextStyle(color: Colors.orange)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 설정 버튼
                          IconButton(
                            icon: Icon(Icons.settings, color: Colors.grey.shade700),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Upcoming Event 영역
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upcoming Event',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _UpcomingEventRow(time: '09:00', title: '팀 미팅'),
                                const SizedBox(height: 8),
                                _UpcomingEventRow(time: '13:30', title: '프로젝트 마감'),
                                const SizedBox(height: 8),
                                _UpcomingEventRow(time: '18:00', title: '헬스장'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Date Carousel + 하단 3열 스케줄
                  Expanded(
                    child: _DateCarouselAndSchedule(),
                  ),
                ],
              ),
            ),
    );
  }
}

// Upcoming Event 줄(Row) 위젯
class _UpcomingEventRow extends StatelessWidget {
  final String time;
  final String title;

  const _UpcomingEventRow({
    required this.time,
    required this.title,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// Date Carousel + 하단 3열 스케줄 위젯
class _DateCarouselAndSchedule extends StatefulWidget {
  @override
  State<_DateCarouselAndSchedule> createState() => _DateCarouselAndScheduleState();
}

class _DateCarouselAndScheduleState extends State<_DateCarouselAndSchedule> {
  // 오늘 날짜 기준으로 날짜 리스트 생성
  List<DateTime> _dates = [];
  int _startIndex = 0;
  int _visibleCount = 3;

  @override
  void initState() {
    super.initState();
    _loadInitialDates();
  }

  void _loadInitialDates() {
    final today = DateTime.now();
    _dates = List.generate(6, (i) => today.add(Duration(days: i)));
  }

  void _loadMoreDates() {
    final lastDate = _dates.last;
    setState(() {
      _dates.addAll(List.generate(3, (i) => lastDate.add(Duration(days: i + 1))));
    });
  }

  void _onScrollEnd() {
    // 마지막 날짜가 보이면 추가 로딩
    if (_startIndex + _visibleCount >= _dates.length) {
      _loadMoreDates();
    }
  }

  void _onRight() {
    setState(() {
      if (_startIndex + _visibleCount < _dates.length) {
        _startIndex++;
        _onScrollEnd();
      }
    });
  }

  void _onLeft() {
    setState(() {
      if (_startIndex > 0) {
        _startIndex--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleDates = _dates.sublist(_startIndex, _startIndex + _visibleCount);
    return Column(
      children: [
        // Date Carousel
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _onLeft,
            ),
            ...visibleDates.map((date) {
              final idx = _dates.indexOf(date);
              String label = '';
              if (idx == 0) label = 'D-Day';
              else if (idx == 1) label = 'D+1';
              else if (idx == 2) label = 'D+2';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    if (label.isNotEmpty)
                      Text(label, style: const TextStyle(fontSize: 12, color: Colors.blue)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${date.month}/${date.day}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _onRight,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 하단 3열 스케줄
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_visibleCount, (i) {
            final date = visibleDates[i];
            // 1~7개 랜덤 더미 스케줄 생성
            final rand = Random(date.day + date.month + date.year + i);
            final count = rand.nextInt(7) + 1;
            final schedules = List.generate(count, (idx) => {
              'time': '${9 + idx}:00',
              'title': '스케줄 ${idx + 1}',
              'done': idx == 0 && i == 0, // 첫번째 열의 첫번째만 완료
            });
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                height: 220, // 화면 높이의 일부만 차지하도록 제한
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 한 줄당 대략 38px(글씨+여백)로 가정
                    final totalHeight = schedules.length * 38.0;
                    final isOverflow = totalHeight > constraints.maxHeight;
                    return Stack(
                      children: [
                        Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var sched in schedules) ...[
                                  _ScheduleCell(
                                    time: sched['time'] as String,
                                    title: sched['title'] as String,
                                    done: sched['done'] as bool,
                                  ),
                                  const SizedBox(height: 10),
                                ]
                              ],
                            ),
                          ),
                        ),
                        if (isOverflow)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.grey.shade100.withOpacity(0.0),
                                    Colors.grey.shade100.withOpacity(0.8),
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// 스케줄 셀 위젯
class _ScheduleCell extends StatelessWidget {
  final String time;
  final String title;
  final bool done;
  const _ScheduleCell({required this.time, required this.title, required this.done, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final textStyle = done
        ? const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 14)
        : const TextStyle(color: Colors.black, fontSize: 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: textStyle),
        Text(title, style: textStyle),
      ],
    );
  }
}