import 'package:flutter/material.dart';

class ModeSwitcher extends StatelessWidget {
  final bool isWorkMode;
  final VoidCallback onToggle;

  const ModeSwitcher({
    super.key,
    required this.isWorkMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(
          color: isWorkMode ? const Color(0xFFFF6666) : const Color(0xF4D4DFF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Image.asset(
              isWorkMode
                  ? 'assets/images/logo_life.png'
                  : 'assets/images/logo_work.png',
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,       // 🔧 세로축(상-하 방향) 중앙 정렬
              children: [
                Text(
                  'Work',
                  style: TextStyle(
                    color: isWorkMode ?  Color(0xFFFF6666) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Life',
                  style: TextStyle(
                    color: isWorkMode ? Colors.white : Color(0xFF4D4DFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}