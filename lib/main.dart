import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'providers/status_provider.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase 초기화 에러: $e');
  }

  setFirebaseLocale();

  FirebaseService firebaseService = FirebaseService();
  await firebaseService.uploadWorkplaces();

  runApp(const MyApp());
}

void setFirebaseLocale() {
  final String locale = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  FirebaseAuth.instance.setLanguageCode(locale);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StatusProvider>(
          create: (_) => StatusProvider(),
        ),
      ],
      child: MaterialApp(
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            // 다양한 입력 장치를 허용하여 웹에서도 마우스 스크롤이 가능합니다.
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainScreen(),
          '/signup': (context) => const SignupScreen(),
        },
      ),
    );
  }
}

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
