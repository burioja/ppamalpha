import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/web_dom_stub.dart'
    if (dart.library.html) 'utils/web_dom.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase 초기화 오류 처리
  }

  // .env 로드
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // 웹에서 google_maps_flutter_web이 읽을 수 있도록 메타 태그에 주입
  try {
    final apiKey = dotenv.env['GOOGLE_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      setMetaContent('google_maps_api_key', apiKey);
      await loadGoogleMapsScript(apiKey);
    }
  } catch (_) {}

  setFirebaseLocale();

  runApp(const MyApp());
}

void setFirebaseLocale() {
  final String locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  FirebaseAuth.instance.setLanguageCode(locale);
} 