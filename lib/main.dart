import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service/firebase_service.dart';
import 'dart:ui';
import 'package:provider/provider.dart'; // Provider 패키지 추가
import 'provider/workplace_provider.dart'; // WorkplaceProvider 추가

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
    ChangeNotifierProvider(
      create: (context) => WorkplaceProvider(), // WorkplaceProvider 초기화
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
    return MultiProvider( // MultiProvider로 변경
      providers: [
        ChangeNotifierProvider(create: (_) => WorkplaceProvider()), // WorkplaceProvider 추가
      ],
      child: MaterialApp(
        title: 'Firebase 로그인',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        // 로그인 상태에 따라 첫 화면 결정
        home: AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainScreen(),
          '/signup': (context) => const SignupScreen(),
        },
      ),
    );
  }
}

// 사용자 로그인 상태에 따라 화면 전환
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 로딩 화면 표시
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          // 사용자가 로그인되어 있으면 메인 화면으로
          return const MainScreen();
        } else {
          // 로그인이 안 되어 있으면 로그인 화면으로
          return const LoginScreen();
        }
      },
    );
  }
}
