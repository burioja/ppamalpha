import 'package:flutter/material.dart';

class ModeSwitcher extends StatelessWidget {
  final Function(int) onModeChanged;
  final int currentMode;

  const ModeSwitcher({
    super.key,
    required this.onModeChanged,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton('Work', 0, Icons.work),
          _buildModeButton('Life', 1, Icons.home),
        ],
      ),
    );
  }

  Widget _buildModeButton(String text, int mode, IconData icon) {
    final isSelected = currentMode == mode;
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => onModeChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}