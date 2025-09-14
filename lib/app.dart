import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes/app_routes.dart';
import 'providers/user_provider.dart';
import 'providers/search_provider.dart';
import 'providers/screen_provider.dart';
import 'providers/wallet_provider.dart';
import 'features/map_system/providers/map_filter_provider.dart';
import 'screens/auth/login_screen.dart';
import 'features/user_dashboard/screens/main_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
        ChangeNotifierProvider<MapFilterProvider>(
          create: (_) => MapFilterProvider(),
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
        routes: AppRoutes.routes,
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