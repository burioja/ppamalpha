import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/signup_screen.dart';
import 'providers/status_provider.dart';
import 'providers/user_provider.dart';
import 'providers/search_provider.dart';
import 'providers/screen_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/firebase_service.dart';
import 'widgets/user_status_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase 초기화 오류 처리
  }

  setFirebaseLocale();

  FirebaseService firebaseService = FirebaseService();
  await firebaseService.uploadWorkplaces();

  // 기본 개인 프로필 생성 (필요시 구현)
  // await createDefaultPersonalPlace();

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
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider()
        ),
        ChangeNotifierProvider<ScreenProvider>(
            create: (_) => ScreenProvider()
        ),
        ChangeNotifierProvider(
            create: (_) => WalletProvider()
        ),
      ],
      child: MaterialApp(
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            // 다양한 입력 장치를 사용하여 데스크톱에서도 마우스로 스크롤이 가능합니다.
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