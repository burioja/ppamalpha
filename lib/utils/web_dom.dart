// Web-only implementation
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';

void setMetaContent(String name, String content) {
  final el = html.document.querySelector('meta[name="$name"]') as html.MetaElement?;
  if (el != null) el.content = content;
}

Future<void> loadGoogleMapsScript(String apiKey) async {
  final id = 'gmaps-js';
  if (html.document.getElementById(id) != null) return; // already loaded
  final script = html.ScriptElement()
    ..id = id
    ..type = 'text/javascript'
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey&v=weekly';
  final completer = Completer<void>();
  script.onLoad.listen((_) => completer.complete());
  script.onError.listen((_) => completer.complete());
  html.document.head!.append(script);
  await completer.future;
}

Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    html.window.open(uri.toString(), '_blank');
  }
}


