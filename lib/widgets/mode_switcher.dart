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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isWorkMode ? const Color(0xFFFF6C6C) : const Color(0xFF5A68FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Image.asset(
              isWorkMode
                  ? 'assets/images/logo_work.png'
                  : 'assets/images/logo_life.png',
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Life',
                  style: TextStyle(
                    color: isWorkMode ? Colors.grey[300] : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Work',
                  style: TextStyle(
                    color: isWorkMode ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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