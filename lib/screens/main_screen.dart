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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 위치 표시
          SizedBox(
            width: 75,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 20),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _currentLocation,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 검색창 (가운데)
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
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

          const SizedBox(width: 8),

          // 소지금 표시
          const SizedBox(
            width: 85,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '₩ 900,000',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
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
                    // ✨ 글쓰기 버튼 눌렸을 때
                    // 기본 카테고리를 Threads로 고정하거나 상태 관리 필요
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WritePostScreen(category: 'Threads'),
                      ),
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
