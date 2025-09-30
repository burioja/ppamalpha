import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
  final VoidCallback? onTap;

  const SingleMarkerWidget({
    super.key,
    required this.imagePath,
    this.size = 31.0,
    this.isSuper = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSuper ? Colors.amber : Colors.white, 
            width: isSuper ? 3 : 2
          ),
          boxShadow: [
            BoxShadow(
              color: isSuper 
                  ? Colors.amber.withOpacity(0.4)
                  : Colors.black.withOpacity(0.3),
              blurRadius: isSuper ? 6 : 4,
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
