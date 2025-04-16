import 'package:flutter/material.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('예산 화면')),
      body: const Center(child: Text('이곳은 소지금 관련 화면입니다')),
    );
  }
}