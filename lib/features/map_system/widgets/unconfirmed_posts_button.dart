import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/data/post_collection_service.dart';

/// 미확인 포스트 플로팅 버튼 위젯
class UnconfirmedPostsButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnconfirmedPostsButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (userId == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: PostCollectionService().getUnconfirmedPostCountStream(userId),
      builder: (context, snapshot) {
        final unconfirmedCount = snapshot.data ?? 0;
        
        // 미확인 포스트가 없으면 숨김
        if (unconfirmedCount == 0) {
          return const SizedBox.shrink();
        }

        return Positioned(
          bottom: 80, // 바텀 네비게이션으로부터 16px 위
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(25),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '미확인 포스트 $unconfirmedCount개',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

