// Web-only implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

void setMetaContent(String name, String content) {
  final el = html.document.querySelector('meta[name="$name"]') as html.MetaElement?;
  if (el != null) el.content = content;
}

// 구글맵 스크립트 로드 함수 제거됨 (OSM 사용)

Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    html.window.open(uri.toString(), '_blank');
  }
}


