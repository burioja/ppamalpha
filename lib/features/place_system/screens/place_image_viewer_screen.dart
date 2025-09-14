import 'package:flutter/material.dart';

class PlaceImageViewerScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const PlaceImageViewerScreen({super.key, required this.images, required this.initialIndex});

  @override
  State<PlaceImageViewerScreen> createState() => _PlaceImageViewerScreenState();
}

class _PlaceImageViewerScreenState extends State<PlaceImageViewerScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('이미지 보기', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.image_not_supported, size: 80, color: Colors.white70);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}


