import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_screen.dart';
import 'wallet_screen.dart';

import '../../services/location_service.dart';
import 'budget_screen.dart';
import 'search_screen.dart';
import '../../providers/search_provider.dart';
import '../../widgets/mode_switcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isWorkMode = true;
  int _selectedIndex = 0;
  String _currentLocation = '위치 불러오는 중...';

  final List<Widget> _widgetOptions = [
    MapScreen(key: MapScreen.mapKey),
    const WalletScreen(),
  ];

  final List<IconData> _icons = [
    Icons.map,
    Icons.account_balance_wallet,
  ];

  final List<String> _labels = [
    'Map',
    'Wallet',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentAddress();
  }

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

  void _onItemTapped(int index) {
    Provider.of<SearchProvider>(context, listen: false).setSelectedTabIndex(index);
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: _isWorkMode ? const Color(0xFFFF6666) : const Color(0xFF4D4DFF),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 왼쪽 ModeSwitcher
          ModeSwitcher(
            isWorkMode: _isWorkMode,
            onToggle: () {
              setState(() {
                _isWorkMode = !_isWorkMode;
                // 모드 변경 시 인덱스 리셋
                // _currentWorkplaceIndex = 0;
                // _currentItemIndex = 0;
              });
            },
          ),
          const SizedBox(width: 10),

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
          const SizedBox(width: 10),

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
        ],
      ),
    );
  }

  Widget _buildCustomNavBar() {
    final Color accentColor = _isWorkMode ? const Color(0xFFFF6666) : const Color(0xFF4D4DFF);

    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 15, left: 8, right: 8),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_icons.length, (index) {
          final isSelected = index == _selectedIndex;
          final isMapLocationButton = _selectedIndex == 0 && index == 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: GestureDetector(
                onTap: () {
                  if (isMapLocationButton) {
                    final state = MapScreen.mapKey.currentState;
                    if (state != null) {
                      state.goToCurrentLocation();
                    }
                  } else {
                    _onItemTapped(index);
                  }
                },
                child: Container(
                  height: 60,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMapLocationButton
                              ? Icons.my_location
                              : _icons[index],
                          color: isSelected ? accentColor : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMapLocationButton
                              ? "현재위치"
                              : _labels[index],
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