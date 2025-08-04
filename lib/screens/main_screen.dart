import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_screen.dart';
import 'wallet_screen.dart';

import '../services/location_service.dart';
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
  int _selectedIndex = 0;
  String _currentLocation = '?ÑÏπò Î∂àÎü¨?§Îäî Ï§?..';


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
          _currentLocation = 'Ï£ºÏÜåÎ•?Í∞Ä?∏Ïò¨ ???ÜÏäµ?àÎã§.';
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
          // ?îÅ ModeSwitcher
          ModeSwitcher(
            isWorkMode: _isWorkMode,
            onToggle: () {
              setState(() {
                _isWorkMode = !_isWorkMode;
                // Î™®Îìú Î≥ÄÍ≤????åÎ†à?¥Ïä§ ?∏Îç±??Î¶¨ÏÖã
                _currentWorkplaceIndex = 0;
                _currentItemIndex = 0;
              });
            },
          ),
          const SizedBox(width: 10),

          // ?ìç ?ÑÏπò (?ÑÎ•¥Î©?Îß??îÎ©¥?ºÎ°ú ?¥Îèô)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 0); // ?êÎäî Îß??ÑÏö© ?§ÌÅ¨Î¶??¥Îèô
              },
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, // ???òÌèâ Í∞Ä?¥Îç∞ ?ïÎ†¨
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

          // ?í∞ M ?ÑÏù¥ÏΩ?(?àÏÇ∞ ?îÎ©¥ ?¥Îèô)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetScreen()));
            },
            child: Image.asset(
              'assets/images/icon_budget.png', // ???§Ï†ú Í≤ΩÎ°ú??ÎßûÍ≤å ?§Ï†ï ?ÑÏöî
              width: 22,
              height: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),

          // ?îç Í≤Ä???ÑÏù¥ÏΩ?(Í≤Ä?âÏ∞Ω ?ÑÌôò)
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())); // TODO: Í≤Ä???§ÌÅ¨Î¶?Íµ¨ÌòÑ
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
                              ? "???ÑÏπò"
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
