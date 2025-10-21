import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/data/user_service.dart';

class SimpleClusterDot extends StatelessWidget {
  const SimpleClusterDot({
    super.key, 
    required this.count,
  });
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getClusterColors(count),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _getClusterColors(count).first.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }

  List<Color> _getClusterColors(int count) {
    if (count >= 20) {
      return [const Color(0xFFFF4444), const Color(0xFFFF6666)]; // 빨강
    } else if (count >= 10) {
      return [const Color(0xFFFF8800), const Color(0xFFFFAA44)]; // 주황
    } else if (count >= 5) {
      return [const Color(0xFF4D4DFF), const Color(0xFF8080FF)]; // 보라
    } else {
      return [const Color(0xFF00AA44), const Color(0xFF44CC66)]; // 초록
    }
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
        child: Stack(
          children: [
            ClipOval(
              child: Image.asset(
                imagePath,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            ),
            
            // 슈퍼 마커 표시
            if (isSuper)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}