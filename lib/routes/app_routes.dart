import 'package:flutter/material.dart';

// Authentication screens
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/address_search_screen.dart';

// Core models
import '../core/models/post/post_model.dart';
import '../core/models/place/place_model.dart';

// Map System (already moved to features)
import '../features/map_system/screens/map_screen.dart';

// User Dashboard System
import '../features/user_dashboard/screens/main_screen.dart';
import '../features/user_dashboard/screens/budget_screen.dart';
import '../features/user_dashboard/screens/search_screen.dart';
import '../features/user_dashboard/screens/settings_screen.dart';
import '../features/user_dashboard/screens/location_picker_screen.dart';
import '../features/user_dashboard/screens/store_screen.dart';
import '../features/user_dashboard/screens/points_screen.dart';

// Post System
import '../features/post_system/screens/post_place_screen.dart';
import '../features/post_system/screens/post_place_selection_screen.dart';
import '../features/post_system/screens/post_detail_screen.dart';
import '../features/post_system/screens/post_edit_screen.dart';
import '../features/post_system/screens/post_deploy_screen.dart';
import '../features/post_system/screens/post_statistics_screen.dart';
import '../features/post_system/screens/deployment_statistics_dashboard_screen.dart';
import '../features/post_system/screens/my_posts_statistics_dashboard_screen.dart';
import '../features/post_system/screens/post_deploy_design_demo.dart';
import '../features/post_system/screens/post_place_screen_design_demo.dart';

// Place System
import '../features/place_system/screens/create_place_screen.dart';
import '../features/place_system/screens/edit_place_screen.dart';
import '../features/place_system/screens/place_detail_screen.dart';
import '../features/place_system/screens/place_image_viewer_screen.dart';
import '../features/place_system/screens/place_search_screen.dart';
import '../features/place_system/screens/my_places_screen.dart';
import '../features/place_system/screens/place_statistics_screen.dart';

// Admin System
import '../features/admin/admin_cleanup_screen.dart';


class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String addressSearch = '/address-search';
  static const String main = '/main';
  static const String map = '/map';

  static const String budget = '/budget';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String points = '/points';
  static const String postPlace = '/post-place';
  static const String postPlaceSelection = '/post-place-selection';
  static const String postDetail = '/post-detail';
  static const String postEdit = '/post-edit';
  static const String postStatistics = '/post-statistics';
  static const String deploymentStatistics = '/deployment-statistics';
  static const String myPostsStatistics = '/my-posts-statistics';

  static const String locationPicker = '/location-picker';
  static const String postDeploy = '/post-deploy';
  static const String createPlace = '/create-place';
  static const String editPlace = '/edit-place';
  static const String placeDetail = '/place-detail';
  static const String placeSearch = '/place-search';
  static const String placeImageViewer = '/place-image-viewer';
  static const String myPlaces = '/my-places';
  static const String placeStatistics = '/place-statistics';

  // Admin routes
  static const String adminCleanup = '/admin-cleanup';
  static const String store = '/store';
  
  // Design demo routes
  static const String postDeployDesignDemo = '/post-deploy-design-demo';
  static const String postPlaceDesignDemo = '/post-place-design-demo';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    addressSearch: (context) => const AddressSearchScreen(),
    main: (context) => const MainScreen(),
    map: (context) => const MapScreen(),

    budget: (context) => const BudgetScreen(),
    search: (context) => const SearchScreen(),
    settings: (context) => const SettingsScreen(),
    points: (context) => const PointsScreen(),
    postPlace: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final place = args?['place'] as PlaceModel?;
      
      if (place == null) {
        return const Scaffold(
          body: Center(child: Text('플레이스 정보를 찾을 수 없습니다.')),
        );
      }
      
      return PostPlaceScreen(place: place);
    },
    postPlaceSelection: (context) => const PostPlaceSelectionScreen(),

    postDeploy: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) {
        return const Scaffold(body: Center(child: Text('배포 정보를 찾을 수 없습니다.')));
      }
      return PostDeployScreen(arguments: args);
    },
    locationPicker: (context) => const LocationPickerScreen(),
    postDetail: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final post = args?['post'] as PostModel?;
      final isEditable = args?['isEditable'] as bool? ?? false;
      
      if (post == null) {
        return const Scaffold(
          body: Center(child: Text('포스트 정보를 찾을 수 없습니다.')),
        );
      }
      
      return PostDetailScreen(post: post, isEditable: isEditable);
    },
    postEdit: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final post = args?['post'] as PostModel?;
      if (post == null) {
        return const Scaffold(
          body: Center(child: Text('포스트 정보를 찾을 수 없습니다.')),
        );
      }
      return PostEditScreen(post: post);
    },
    postStatistics: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final post = args?['post'] as PostModel?;
      if (post == null) {
        return const Scaffold(
          body: Center(child: Text('포스트 정보를 찾을 수 없습니다.')),
        );
      }
      return PostStatisticsScreen(post: post);
    },
    deploymentStatistics: (context) => const DeploymentStatisticsDashboardScreen(),
    myPostsStatistics: (context) => const MyPostsStatisticsDashboardScreen(),
    createPlace: (context) => const CreatePlaceScreen(),
    editPlace: (context) {
      final place = ModalRoute.of(context)?.settings.arguments as PlaceModel?;
      if (place == null) {
        return const Scaffold(
          body: Center(child: Text('플레이스 정보를 찾을 수 없습니다.')),
        );
      }
      return EditPlaceScreen(place: place);
    },
    placeDetail: (context) {
      final placeId = ModalRoute.of(context)?.settings.arguments as String?;
      if (placeId == null) {
        return const Scaffold(
          body: Center(child: Text('플레이스 ID를 찾을 수 없습니다.')),
        );
      }
      return PlaceDetailScreen(placeId: placeId);
    },
    placeSearch: (context) => const PlaceSearchScreen(),
    placeImageViewer: (context) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final images = (args?['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
      final index = args?['index'] as int? ?? 0;
      return PlaceImageViewerScreen(images: images, initialIndex: index);
    },
    myPlaces: (context) => const MyPlacesScreen(),
    placeStatistics: (context) {
      final place = ModalRoute.of(context)?.settings.arguments as PlaceModel?;
      if (place == null) {
        return const Scaffold(
          body: Center(child: Text('플레이스 정보를 찾을 수 없습니다.')),
        );
      }
      return PlaceStatisticsScreen(place: place);
    },
    store: (context) => const StoreScreen(),
    adminCleanup: (context) => const AdminCleanupScreen(),
    
    // Design demo
    postDeployDesignDemo: (context) => const PostDeployDesignDemo(),
    postPlaceDesignDemo: (context) => const PostPlaceScreenDesignDemo(),
  };
} 