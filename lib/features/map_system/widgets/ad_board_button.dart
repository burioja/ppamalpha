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
          bottom: 80, // 바텀 네비게이션 위로 이동
          right: 16, // 오른쪽에 배치
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(25),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[600]!, Colors.red[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.campaign,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
