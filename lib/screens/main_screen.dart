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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;
  String _currentLocation = '위치 불러오는 중...';
  final TextEditingController _searchController = TextEditingController();

  final List<Widget> _widgetOptions = [
    const CommunityScreen(),
    const MapScreen(),
    const StoreScreen(),
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
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildStoreCarousel() {
    return FutureBuilder<List<List<WorkplaceData>>>(
      future: fetchUserWorkplaces(),
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
          final group = snapshot.data!;
          return SizedBox(
            width: 185,
            height: 50,
            child: PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: group.length,
              onPageChanged: (vIdx) {
                Provider.of<StatusProvider>(context, listen: false)
                    .setCurrentText(group[vIdx][0].data[3]);
              },
              itemBuilder: (context, vIdx) {
                final innerPage = PageController(initialPage: 3);
                return PageView.builder(
                  controller: innerPage,
                  scrollDirection: Axis.horizontal,
                  itemCount: group[vIdx][0].data.length,
                  onPageChanged: (hIdx) {
                    String currentText = group[vIdx][0].data[hIdx];
                    Provider.of<StatusProvider>(context, listen: false)
                        .setCurrentText(currentText);
                  },
                  itemBuilder: (context, hIdx) {
                    final item = group[vIdx][0];
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          item.data[hIdx],
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
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
      height: 70,
      color: Colors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '검색',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                  onSubmitted: (query) {
                    print('$_selectedIndex 검색: $query');
                  },
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedIndex = 1),
                  child: Container(
                    height: 24,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const BudgetScreen()));
                  },
                  child: Container(
                    width: double.infinity,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₩ 900,000',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_icons.length, (index) {
          final isSelected = index == _selectedIndex;
          final isStore = _labels[index] == 'Store';
          final isCommunityWriteButton = _selectedIndex == 0 && index == 0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  if (isCommunityWriteButton) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WritePostScreen(category: 'Threads'),                      ),
                    );
                  } else {
                    _onItemTapped(index);
                  }
                },
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: isStore
                        ? _buildStoreCarousel()
                        : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCommunityWriteButton ? Icons.edit : _icons[index],
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCommunityWriteButton ? "글쓰기" : _labels[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.blue : Colors.grey,
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
