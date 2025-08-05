import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/user/main_screen.dart';
import '../screens/user/map_screen.dart';
import '../screens/user/wallet_screen.dart';
import '../screens/user/budget_screen.dart';
import '../screens/user/search_screen.dart';
import '../screens/user/map_search_screen.dart';
import '../screens/user/track_connection_screen.dart';
import '../screens/user/settings_screen.dart';
import '../screens/user/post_place_screen.dart';
import '../screens/shared/migration_screen.dart';
import '../screens/shared/debug_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String main = '/main';
  static const String map = '/map';
  static const String wallet = '/wallet';
  static const String budget = '/budget';
  static const String search = '/search';
  static const String mapSearch = '/map-search';
  static const String trackConnection = '/track-connection';
  static const String settings = '/settings';
  static const String postPlace = '/post-place';
  static const String migration = '/migration';
  static const String debug = '/debug';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    main: (context) => const MainScreen(),
    map: (context) => const MapScreen(),
    wallet: (context) => const WalletScreen(),
    budget: (context) => const BudgetScreen(),
    search: (context) => const SearchScreen(),
    mapSearch: (context) => const MapSearchScreen(),
    trackConnection: (context) => const TrackConnectionScreen(type: 'track'),
    settings: (context) => const SettingsScreen(),
    postPlace: (context) => const PostPlaceScreen(),
    migration: (context) => const MigrationScreen(),
    debug: (context) => const DebugScreen(),
  };
} 