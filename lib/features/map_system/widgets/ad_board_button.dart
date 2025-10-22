import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../post_system/services/ad_board_service.dart';

class AdBoardButton extends StatelessWidget {
  final VoidCallback onTap;

  const AdBoardButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: AdBoardService().getReceivableCountStream(
        countryCode: 'KR', // 기본값: 한국
        regionCode: null, // 전체 지역
      ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();

        return Positioned(
          bottom: 16 + 56 + 16, // BottomNav height + FAB padding + some margin
          left: 16, // 왼쪽에 배치
          child: FloatingActionButton.extended(
            onPressed: onTap,
            icon: const Icon(Icons.campaign, color: Colors.white),
            label: Text(
              '광고보드 ($count)',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      },
    );
  }
}
