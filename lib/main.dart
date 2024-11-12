// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_service.dart';
import 'providers/status_provider.dart'; // StatusProvider 임포트
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 및 에러 처리
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase 초기화 에러: $e');
    // 초기화 실패 시 오류 화면 표시, 여기서는 단순히 에러 로그만 표시
  }

  // Firebase 언어 설정
  setFirebaseLocale();

  FirebaseService firebaseService = FirebaseService();
  await firebaseService.uploadWorkplaces(); // 앱 시작 시 데이터 업로드

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StatusProvider()), // StatusProvider 등록
      ],
      child: const MyApp(),
    ),
  );
}

void setFirebaseLocale() {
  final String locale = window.locale.languageCode;
  FirebaseAuth.instance.setLanguageCode(locale);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
      title: 'Firebase 로그인',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(), // 로그인 상태에 따라 첫 화면 결정
      routes: {
        '/login': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}

// 사용자 로그인 상태에 따라 화면 전환
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
