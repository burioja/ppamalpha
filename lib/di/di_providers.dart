import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Providers
import '../providers/auth_provider.dart';
import '../providers/screen_provider.dart';
import '../providers/search_provider.dart';
import '../providers/user_provider.dart';
import '../providers/wallet_provider.dart';

// Map Providers
import '../features/map_system/providers/map_view_provider.dart';
import '../features/map_system/providers/marker_provider.dart';
import '../features/map_system/providers/tile_provider.dart';
import '../features/map_system/providers/map_filter_provider.dart';

// Post Providers
import '../features/post_system/providers/post_provider.dart';

/// DI - Provider 등록
/// 
/// **역할**: 모든 Provider 생성 및 등록
/// **사용**: app.dart의 MultiProvider에서 사용
class DIProviders {
  /// 전체 Provider 목록 생성
  static List<SingleChildWidget> getProviders() {
    return [
      // 인증
      ...authProviders,
      
      // 맵
      ...mapProviders,
      
      // 포스트
      ...postProviders,
      
      // 사용자
      ...userProviders,
    ];
  }

  /// 인증 관련 Provider
  static List<SingleChildWidget> get authProviders => [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
      ];

  /// 맵 관련 Provider
  static List<SingleChildWidget> get mapProviders => [
        ChangeNotifierProvider(
          create: (_) => MapViewProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MarkerProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => TileProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MapFilterProvider(),
        ),
      ];

  /// 포스트 관련 Provider
  static List<SingleChildWidget> get postProviders => [
        ChangeNotifierProvider(
          create: (_) => PostProvider(),
        ),
      ];

  /// 사용자 관련 Provider
  static List<SingleChildWidget> get userProviders => [
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ScreenProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(),
        ),
      ];
}

