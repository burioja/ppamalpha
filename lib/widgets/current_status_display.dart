// lib/widgets/current_status_display.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/status_provider.dart';

class CurrentStatusDisplay extends StatelessWidget {
  const CurrentStatusDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StatusProvider>(
      builder: (context, statusProvider, child) {
        return Text(
          statusProvider.currentText,
          style: const TextStyle(fontSize: 18, color: Colors.black),
        );
      },
    );
  }
}
