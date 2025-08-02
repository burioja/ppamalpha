import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_screen.dart';
import 'community_screen.dart';
import 'shop_screen.dart';
import 'store_screen.dart';
import 'wallet_screen.dart';
import '../providers/status_provider.dart';
import '../widgets/user_status_widget.dart';
import '../services/location_service.dart';
import 'write_post_screen.dart';
import 'budget_screen.dart';
import 'search_screen.dart';
import '../providers/search_provider.dart';
import '../widgets/mode_switcher.dart';




class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isWorkMode = true;
  int _selectedIndex = 2;
  String _currentLocation = '위치 불러오는 중...';
  int _currentWorkplaceIndex = 0;
  int _currentItemIndex = 0;

  final List<Widget> _widgetOptions = [
    const CommunityScreen(),
    MapScreen(key: MapScreen.mapKey), // ✅ 수정된 부분
    const StoreScreen(),              // ✅ 쉼표 추가
    const ShopScreen(),
    const WalletScreen(),
  ];

  final List<IconData> _icons = [
    Icons.people,
    Icons.map,
    Icons.store,
    Icons.shopping_cart,
    Icons.account_balance_wallet,
  ];

  final List<String> _labels = [
    'Community',
    'Map',
    'Store',
    'Shop',
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
    Provider.of<SearchProvider>(context, listen: false).setSelectedTabIndex(index); // 🔧 탭 변경 시 검색 상태에 반영
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildStoreCarousel() {
    return FutureBuilder<List<List<WorkplaceData>>>(
      future: fetchUserWorkplacesByMode(_isWorkMode ? 'work' : 'life'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 185,
            height: 50,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        } else if (snapshot.hasError) {
          return const Text('오류 발생', style: TextStyle(color: Colors.white));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('데이터 없음', style: TextStyle(color: Colors.white));
        } else {
          final workplaces = snapshot.data!;
          
          // 모든 플레이스를 하나의 리스트로 만들기
          List<WorkplaceData> allWorkplaces = [];
          for (var group in workplaces) {
            allWorkplaces.addAll(group);
          }
          
          print('로드된 플레이스 개수: ${allWorkplaces.length} (모드: ${_isWorkMode ? 'work' : 'life'})');
          for (var workplace in allWorkplaces) {
            print('플레이스: ${workplace.data.last} (ID: ${workplace.placeId})');
          }
          
          if (allWorkplaces.isEmpty) {
            allWorkplaces.add(WorkplaceData(['Customer'], Colors.grey.shade300));
          }
          
          return SizedBox(
            width: 185,
            height: 50,
            child: PageView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allWorkplaces.length,
              controller: PageController(initialPage: _currentItemIndex),
              physics: const BouncingScrollPhysics(), // 드래그 감도 개선
              onPageChanged: (index) {
                setState(() {
                  _currentWorkplaceIndex = 0;
                  _currentItemIndex = index;
                });
                
                final selectedWorkplace = allWorkplaces[index];
                final workplaceName = selectedWorkplace.data.isNotEmpty 
                    ? selectedWorkplace.data.last 
                    : (_isWorkMode ? 'Customer' : '개인');
                
                print('선택된 플레이스: $workplaceName (모드: ${_isWorkMode ? 'work' : 'life'})');
                
                // StatusProvider 업데이트
                Provider.of<StatusProvider>(context, listen: false)
                    .setCurrentText(workplaceName);
              },
              itemBuilder: (context, index) {
                final workplace = allWorkplaces[index];
                return Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: workplace.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      workplace.data.isNotEmpty 
                          ? workplace.data.last 
                          : 'Customer',
                      style: TextStyle(
                        color: workplace.color == Colors.grey.shade300 
                            ? Colors.black 
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 50,
      color: _isWorkMode ? const Color(0xFFFF6666) : const Color(0xFF4D4DFF),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 🔁 ModeSwitcher
          ModeSwitcher(
            isWorkMode: _isWorkMode,
            onToggle: () {
              setState(() {
                _isWorkMode = !_isWorkMode;
                // 모드 변경 시 플레이스 인덱스 리셋
                _currentWorkplaceIndex = 0;
                _currentItemIndex = 0;
              });
            },
          ),
          const SizedBox(width: 10),

          // 📍 위치 (누르면 맵 화면으로 이동)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 1); // 또는 맵 전용 스크린 이동
              },
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // ← 수평 가운데 정렬
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

          // 💰 M 아이콘 (예산 화면 이동)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
            },
            child: Image.asset(
              'assets/images/icon_budget.png', // ← 실제 경로에 맞게 설정 필요
              width: 22,
              height: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          // 🔍 검색 아이콘 (검색창 전환)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())); // TODO: 검색 스크린 구현
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
          final isStore = _labels[index] == 'Store';
          final isCommunityWriteButton = _selectedIndex == 0 && index == 0;
          final isMapLocationButton = _selectedIndex == 1 && index == 1;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: GestureDetector(
                onTap: () {
                  if (isCommunityWriteButton) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WritePostScreen(category: 'Threads'),
                      ),
                    );
                  } else if (isMapLocationButton) {
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
                    child: isStore
                        ? _buildStoreCarousel()
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCommunityWriteButton
                              ? Icons.edit
                              : isMapLocationButton
                              ? Icons.my_location
                              : _icons[index],
                          color: isSelected ? accentColor : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCommunityWriteButton
                              ? "글쓰기"
                              : isMapLocationButton
                              ? "내 위치"
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
