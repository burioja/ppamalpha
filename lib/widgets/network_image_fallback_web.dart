import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html; // 임시 비활성화

Widget buildNetworkImage(String url) {
  // Chrome/Safari에서 이미지 캐시/헤더 문제 회피를 위해 nocache 쿼리 추가
  final nocacheUrl = _appendNoCache(url);
  return Image.network(
    nocacheUrl,
    fit: BoxFit.cover,
    loadingBuilder: (c, child, progress) => progress == null
        ? child
        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    errorBuilder: (c, e, st) => const Icon(Icons.broken_image),
  );
}

String _appendNoCache(String url) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return url.contains('?') ? '$url&nc=$now' : '$url?nc=$now';
}


