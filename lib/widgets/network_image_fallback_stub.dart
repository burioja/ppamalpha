import 'package:flutter/material.dart';

Widget buildNetworkImage(String url) {
  return Image.network(
    url,
    fit: BoxFit.cover,
    loadingBuilder: (c, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    errorBuilder: (c, e, st) => const Icon(Icons.broken_image),
  );
}





