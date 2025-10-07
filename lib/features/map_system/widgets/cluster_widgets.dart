import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/data/user_service.dart';

class SimpleClusterDot extends StatelessWidget {
  const SimpleClusterDot({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.all(6),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class SingleMarkerWidget extends StatelessWidget {
  final String imagePath;
  final double size;
  final bool isSuper;
  final String? userId;
  final VoidCallback? onTap;

  const SingleMarkerWidget({
    super.key,
    required this.imagePath,
    this.size = 31.0,
    this.isSuper = false,
    this.userId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 현재 사용자 ID 가져오기
    final currentUserId = UserService().currentUserId;
    final isMyMarker = currentUserId != null && userId != null && userId == currentUserId;
    
    // 테두리 색상 결정: 내 마커(빨간색) > 슈퍼마커(amber) > 일반(white)
    Color borderColor;
    int borderWidth;
    if (isMyMarker) {
      borderColor = Colors.red;
      borderWidth = 3;
    } else if (isSuper) {
      borderColor = Colors.amber;
      borderWidth = 3;
    } else {
      borderColor = Colors.white;
      borderWidth = 2;
    }
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor, 
            width: borderWidth.toDouble()
          ),
          boxShadow: [
            BoxShadow(
              color: isMyMarker 
                  ? Colors.red.withOpacity(0.4)
                  : isSuper 
                      ? Colors.amber.withOpacity(0.4)
                      : Colors.black.withOpacity(0.3),
              blurRadius: isMyMarker ? 6 : isSuper ? 6 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            imagePath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
