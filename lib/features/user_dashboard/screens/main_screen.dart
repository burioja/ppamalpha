import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../map_system/screens/map_screen.dart';
import 'inbox_screen.dart';
import 'wallet_screen.dart';

import '../../../core/services/location/location_service.dart';
import '../../../core/services/data/points_service.dart';
import '../../../core/models/user/user_points_model.dart';
import 'budget_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../../../providers/search_provider.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String _currentLocation = '위치 불러오는 중...';
  UserPointsModel? _userPoints;
  final PointsService _pointsService = PointsService();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _widgetOptions = [
      MapScreen(onAddressChanged: _onAddressChanged),
      const InboxScreen(),
    ];
    _loadCurrentAddress();
    _loadUserPoints();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 포인트 새로고침
      _loadUserPoints();
    }
  }

  final List<IconData> _icons = [
    Icons.map,
    Icons.inbox,
  ];

  final List<String> _labels = [
    'Map',
    'Inbox',
  ];



  Future<void> _loadCurrentAddress() async {
    try {
      String address = await LocationService.getCurrentAddress();
      if (mounted) {
        setState(() {
          _currentLocation = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLocation = '주소를 가져올 수 없습니다.';
        });
      }
    }
  }

  void _onAddressChanged(String address) {
    if (mounted) {
      setState(() {
        _currentLocation = address;
      });
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('🔄 메인 스크린 포인트 로드 중... 사용자: ${user.uid}');
        final points = await _pointsService.getUserPoints(user.uid);
        if (mounted) {
          setState(() {
            _userPoints = points;
          });
          debugPrint('✅ 메인 스크린 포인트 로드 완료: ${points?.totalPoints ?? 0}P');
        }
      } else {
        debugPrint('⚠️ 현재 로그인된 사용자가 없음');
      }
    } catch (e) {
      debugPrint('❌ 포인트 로드 오류: $e');
    }
  }

  void _onItemTapped(int index) {
    Provider.of<SearchProvider>(context, listen: false).setSelectedTabIndex(index);
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: const Color(0xFF4D4DFF),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 중앙 위치 (터치하면 지도 화면으로 이동)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 0); // 지도 탭으로 이동
              },
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // 중앙 정렬
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _currentLocation,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 포인트 표시 (지갑으로 이동)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _userPoints != null ? '${_userPoints!.formattedPoints}P' : '0P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 오른쪽 M 아이콘(예산 화면 이동)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
            },
            child: Image.asset(
              'assets/images/icon_budget.png',
              width: 22,
              height: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          // 오른쪽 검색 아이콘(검색창 열기)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
            child: const Icon(Icons.search, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),

          // 오른쪽 설정 아이콘(설정 화면 열기)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            child: const Icon(Icons.settings, size: 22, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomNavBar() {
    const Color accentColor = Color(0xFF4D4DFF);

    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 15, left: 8, right: 8),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_icons.length, (index) {
          final isSelected = index == _selectedIndex;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: GestureDetector(
                onTap: () => _onItemTapped(index),
                child: SizedBox(
                  height: 60,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[index],
                          color: isSelected ? accentColor : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labels[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? accentColor : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _widgetOptions[_selectedIndex]),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomNavBar(),
    );
  }
} 