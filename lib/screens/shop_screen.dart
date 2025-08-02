// lib/screens/shop_screen.dart
import 'package:flutter/material.dart';
import '../widgets/current_status_display.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Shop 화면입니다.',
            style: TextStyle(fontSize: 20),
          ),
          SizedBox(height: 16),
          CurrentStatusDisplay(), // 현재 텍스트 표시
        ],
      ),
    );
  }
}
