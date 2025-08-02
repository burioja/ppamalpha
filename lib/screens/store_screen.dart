import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // 🔑 로그인 화면 import
import 'track_connection_screen.dart'; // 👥 Track/Connection 화면 import
import 'migration_screen.dart'; // 🔄 마이그레이션 화면 import
import 'store_search_screen.dart'; // 🔍 스토어 검색 화면 import
import '../widgets/schedule_widget.dart'; // 📅 스케줄 위젯 import
import '../widgets/add_schedule_dialog.dart'; // 📅 스케줄 추가 다이얼로그 import
import '../widgets/edit_schedule_dialog.dart'; // 📅 스케줄 편집 다이얼로그 import
import '../services/schedule_service.dart'; // 📅 스케줄 서비스 import
import '../services/user_service.dart'; // 👤 사용자 서비스 import
import 'dart:math';
import '../widgets/user_status_widget.dart';
import '../services/track_service.dart'; // 📊 트랙 서비스 import

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  // 현재 표시할 화면을 관리하는 상태
  bool _showSchedule = false;
  String _selectedShareScope = 'all'; // 필터 상태 추가
  final ScheduleService _scheduleService = ScheduleService();
  final UserService _userService = UserService();

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

  // 권한에 따른 색상 반환
  Color _getAuthorityColor(String authority) {
    switch (authority.toLowerCase()) {
      case 'owner':
      case '소유자':
      case '사장':
      case '대표':
      case '캡틴':
        return Colors.red.shade700;
      case 'manager':
      case '관리자':
      case '매니저':
      case '보조캡틴':
        return Colors.orange.shade700;
      case 'employee':
      case '직원':
      case '스태프':
        return Colors.blue.shade700;
      case 'customer':
      case '고객':
      case '손님':
      case '회원':
        return Colors.green.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  // 권한에 따른 텍스트 반환
  String _getAuthorityText(String authority) {
    switch (authority.toLowerCase()) {
      case 'owner':
      case '소유자':
      case '사장':
      case '대표':
      case '캡틴':
        return '소유자';
      case 'manager':
      case '관리자':
      case '매니저':
      case '보조캡틴':
        return '관리자';
      case 'employee':
      case '직원':
      case '스태프':
        return '직원';
      case 'customer':
      case '고객':
      case '손님':
      case '회원':
        return '고객';
      default:
        return authority;
    }
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
      floatingActionButton: _showSchedule ? FloatingActionButton(
        onPressed: () async {
          final today = DateTime.now();
          final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AddScheduleDialog(selectedDate: dateString),
          );
          
          if (result == true) {
            setState(() {
              // 화면 새로고침
            });
          }
        },
        child: const Icon(Icons.add),
        tooltip: '스케줄 추가',
      ) : null,
      body: _showSchedule
          ? Column(
              children: [
                // 필터링 UI 추가
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '공유 범위: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
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
                    ],
                  ),
                ),
                Expanded(child: ScheduleWidget(selectedShareScope: _selectedShareScope)),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
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
                      padding: const EdgeInsets.all(12.0),
                      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _userService.getUserProfile(),
                        builder: (context, snapshot) {
                          final userData = snapshot.data?.data() ?? {};
                          final nickname = userData['nickname'] ?? '닉네임';
                          final profileImageUrl = userData['profileImageUrl'];
                          
                          return FutureBuilder<Map<String, dynamic>>(
                            future: Future.wait([
                              _userService.getUserStats(),
                              _userService.getUserAuthority(),
                            ]).then((results) => {
                              'stats': results[0] as Map<String, dynamic>,
                              'authority': results[1] as String?,
                            }),
                            builder: (context, snapshot) {
                              final stats = (snapshot.data?['stats'] as Map<String, dynamic>?) ?? {};
                              final authority = snapshot.data?['authority'] as String? ?? 'User';
                              final followingCount = stats['followingCount'] ?? 0;
                              final connectionsCount = stats['connectionsCount'] ?? 0;
                              
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 프로필 이미지
                                  CircleAvatar(
                                    radius: 32,
                                    backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                                        ? NetworkImage(profileImageUrl)
                                        : const AssetImage('assets/images/default_profile.png') as ImageProvider,
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
                                              nickname,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getAuthorityColor(authority).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _getAuthorityColor(authority).withOpacity(0.3)),
                                              ),
                                              child: Text(
                                                _getAuthorityText(authority),
                                                style: TextStyle(
                                                  color: _getAuthorityColor(authority),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // 트랙
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => const TrackConnectionScreen(type: 'track'),
                                                    ),
                                                  );
                                                },
                                              child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                        const Icon(Icons.track_changes, size: 16, color: Colors.green),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: FutureBuilder<int>(
                                                        future: TrackService.getTrackCount('work'), // 모든 Track 개수
                                                        builder: (context, snapshot) {
                                                          final trackCount = snapshot.data ?? 0;
                                                          return Text(
                                                            'Track $trackCount',
                                                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                                                            overflow: TextOverflow.ellipsis,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                    ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // 커넥션
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => const TrackConnectionScreen(type: 'connection'),
                                                    ),
                                                  );
                                                },
                                              child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                      const Icon(Icons.people, size: 16, color: Colors.orange),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'Connection $connectionsCount',
                                                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 스토어 검색 버튼
                                  IconButton(
                                    icon: Icon(Icons.search, color: Colors.grey.shade700),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const StoreSearchScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  // 설정 버튼
                                  IconButton(
                                    icon: Icon(Icons.settings, color: Colors.grey.shade700),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const MigrationScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Upcoming Event 영역 - Firebase 데이터 연결
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
                        const SizedBox(height: 8),
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: _scheduleService.getTodaySchedules(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  print('=== StreamBuilder 에러 디버깅 (Upcoming Event) ===');
                                  print('에러: ${snapshot.error}');
                                  print('에러 타입: ${snapshot.error.runtimeType}');
                                  print('스택 트레이스: ${snapshot.error.toString()}');
                                  return Column(
                                    children: [
                                      Text('오류가 발생했습니다: ${snapshot.error}'),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final today = DateTime.now();
                                          final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                                          
                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AddScheduleDialog(selectedDate: dateString),
                                          );
                                          
                                          if (result == true) {
                                            setState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('스케줄 추가'),
                                      ),
                                    ],
                                  );
                                }

                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final schedules = snapshot.data?.docs ?? [];
                                
                                if (schedules.isEmpty) {
                                  return Column(
                                    children: [
                                      const Text(
                                        '오늘 예정된 일정이 없습니다.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final today = DateTime.now();
                                          final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                                          
                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AddScheduleDialog(selectedDate: dateString),
                                          );
                                          
                                          if (result == true) {
                                            setState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('스케줄 추가'),
                                      ),
                                    ],
                                  );
                                }

                                // 최대 3개까지만 표시
                                final upcomingSchedules = schedules.take(3).toList();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: upcomingSchedules.map((doc) {
                                    final data = doc.data();
                                    print('=== _UpcomingEventRow 데이터 디버깅 ===');
                                    print('문서 ID: ${doc.id}');
                                    print('전체 데이터: $data');
                                    print('isCompleted 원본: ${data['isCompleted']} (${data['isCompleted'].runtimeType})');
                                    print('time: ${data['time']} (${data['time'].runtimeType})');
                                    print('title: ${data['title']} (${data['title'].runtimeType})');
                                    return _UpcomingEventRow(
                                      time: data['time'] ?? '00:00',
                                      title: data['title'] ?? '제목 없음',
                                      scheduleId: doc.id,
                                      isCompleted: data['isCompleted'] ?? false,
                                      scheduleService: _scheduleService,
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date Carousel + 하단 3열 스케줄
                  SizedBox(
                    height: 350, // 고정 높이 설정
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
  final String? scheduleId;
  final bool? isCompleted;
  final ScheduleService? scheduleService;

  const _UpcomingEventRow({
    required this.time,
    required this.title,
    this.scheduleId,
    this.isCompleted,
    this.scheduleService,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final done = isCompleted ?? false;
    final textStyle = done
        ? const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 15)
        : const TextStyle(color: Colors.black, fontSize: 15);
    
    return GestureDetector(
      onTap: scheduleId != null && scheduleService != null ? () async {
        try {
          await scheduleService!.toggleScheduleCompletion(scheduleId!, !done);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(done ? '스케줄을 미완료로 변경했습니다.' : '스케줄을 완료했습니다.'),
              duration: const Duration(seconds: 1),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } : null,
      child: Row(
        children: [
          if (scheduleId != null && scheduleService != null)
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: done ? Colors.green : Colors.grey,
            ),
          if (scheduleId != null && scheduleService != null)
            const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: textStyle,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
  final ScheduleService _scheduleService = ScheduleService();

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

  // 날짜를 문자열로 변환
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleDates = _dates.sublist(_startIndex, _startIndex + _visibleCount);
    return Column(
      mainAxisSize: MainAxisSize.min, // 추가
      children: [
        // Date Carousel
        Container(
          height: 80,
          child: Row(
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
                    mainAxisAlignment: MainAxisAlignment.center,
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
        ),
        const SizedBox(height: 16),
        // 하단 3열 스케줄 - Firebase 데이터 연결
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_visibleCount, (i) {
              final date = visibleDates[i];
              final dateString = _formatDate(date);
              
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _scheduleService.getSchedulesByDate(dateString),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('=== StreamBuilder 에러 디버깅 (3열 스케줄) ===');
                        print('에러: ${snapshot.error}');
                        print('에러 타입: ${snapshot.error.runtimeType}');
                        print('스택 트레이스: ${snapshot.error.toString()}');
                        print('날짜: $dateString');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('오류: ${snapshot.error}'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AddScheduleDialog(selectedDate: dateString),
                                  );
                                  
                                  if (result == true) {
                                    setState(() {});
                                  }
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('추가', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final schedules = snapshot.data?.docs ?? [];
                      
                      if (schedules.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '일정 없음',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AddScheduleDialog(selectedDate: dateString),
                                  );
                                  
                                  if (result == true) {
                                    setState(() {});
                                  }
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('추가', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final itemHeight = 50.0; // 각 스케줄 아이템의 높이
                          final totalHeight = schedules.length * itemHeight;
                          final isOverflow = totalHeight > constraints.maxHeight;
                          
                          return Stack(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...schedules.map((doc) {
                                      final data = doc.data();
                                      print('=== _ScheduleCell 데이터 디버깅 ===');
                                      print('문서 ID: ${doc.id}');
                                      print('전체 데이터: $data');
                                      print('isCompleted 원본: ${data['isCompleted']} (${data['isCompleted'].runtimeType})');
                                      print('time: ${data['time']} (${data['time'].runtimeType})');
                                      print('title: ${data['title']} (${data['title'].runtimeType})');
                                      print('done 변환 전: ${data['isCompleted'] ?? false}');
                                      return Container(
                                        height: itemHeight,
                                        margin: const EdgeInsets.only(bottom: 4),
                                        child: _ScheduleCell(
                                          time: data['time'] ?? '00:00',
                                          title: data['title'] ?? '제목 없음',
                                          done: data['isCompleted'] ?? false,
                                          scheduleId: doc.id,
                                          scheduleService: _scheduleService,
                                          scheduleData: data,
                                        ),
                                      );
                                    }).toList(),
                                    // 스케줄이 있어도 추가 버튼 표시
                                    Container(
                                      height: 40,
                                      margin: const EdgeInsets.only(top: 8),
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final result = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AddScheduleDialog(selectedDate: dateString),
                                          );
                                          
                                          if (result == true) {
                                            setState(() {});
                                          }
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('추가', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade50,
                                          foregroundColor: Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
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
                      );
                    },
                  ),
                ),
              );
            }),
          ),
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
  final String scheduleId;
  final ScheduleService scheduleService;
  final Map<String, dynamic> scheduleData;
  
  const _ScheduleCell({
    required this.time, 
    required this.title, 
    required this.done, 
    required this.scheduleId,
    required this.scheduleService,
    required this.scheduleData,
    Key? key
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final textStyle = done
        ? const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 14)
        : const TextStyle(color: Colors.black, fontSize: 14);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: done ? Colors.grey.shade200 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // 체크박스 (완료 토글)
          GestureDetector(
            onTap: () async {
              try {
                await scheduleService.toggleScheduleCompletion(scheduleId, !done);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(done ? '스케줄을 미완료로 변경했습니다.' : '스케줄을 완료했습니다.'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('오류가 발생했습니다: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: done ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          // 스케줄 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: textStyle.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: textStyle.copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // 편집 아이콘 (연필)
          GestureDetector(
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => EditScheduleDialog(
                  scheduleId: scheduleId,
                  scheduleData: scheduleData,
                ),
              );
              
              if (result == 'deleted') {
                // 삭제된 경우 화면 새로고침
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('스케줄이 삭제되었습니다.')),
                  );
                }
              } else if (result == 'updated') {
                // 수정된 경우 화면 새로고침
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('스케줄이 수정되었습니다.')),
                  );
                }
              }
            },
            child: Icon(
              Icons.edit,
              size: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}