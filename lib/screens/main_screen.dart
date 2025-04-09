import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'community_screen.dart';
import 'shop_screen.dart';
import 'store_screen.dart';
import 'wallet_screen.dart';
import '../widgets/user_container.dart'; // 사용자 컨테이너 임포트

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2; // 기본적으로 Map 화면을 선택
  final PageController _navController = PageController(viewportFraction: 0.25);

  final List<Widget> _widgetOptions = [
    const CommunityScreen(),
    const ShopScreen(),
    const MapScreen(),
    const StoreScreen(),
    const WalletScreen(),
  ];

  final List<IconData> _icons = [
    Icons.people,
    Icons.shopping_cart,
    Icons.map,
    Icons.store,
    Icons.account_balance_wallet,
  ];

  final List<String> _labels = [
    'Community',
    'Shop',
    'Map',
    'Store',
    'Wallet',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const UserContainer(), // 상단 상태창
            Expanded( // 아래 공간을 꽉 채움
              child: _widgetOptions[_selectedIndex],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SizedBox(
        height: 70,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.25),
          scrollDirection: Axis.horizontal,
          itemCount: _widgetOptions.length,
          itemBuilder: (context, index) {
            final isSelected = index == _selectedIndex;
            final icons = [
              Icons.people,
              Icons.shopping_cart,
              Icons.map,
              Icons.store,
              Icons.account_balance_wallet,
            ];
            final labels = [
              'Community',
              'Shop',
              'Map',
              'Store',
              'Wallet',
            ];
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icons[index],
                        color: isSelected ? Colors.blue : Colors.grey),
                    const SizedBox(height: 4),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}