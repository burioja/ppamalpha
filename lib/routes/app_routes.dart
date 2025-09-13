import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/address_search_screen.dart';
import '../screens/user/main_screen.dart';
import '../features/map_system/screens/map_screen.dart';
import '../core/models/post/post_model.dart';

import '../screens/user/budget_screen.dart';
import '../screens/user/search_screen.dart';
import '../screens/user/settings_screen.dart';
import '../screens/user/post_place_screen.dart';
import '../screens/user/post_place_selection_screen.dart';

import '../screens/user/location_picker_screen.dart';
import '../screens/user/post_detail_screen.dart';
import '../screens/user/post_edit_screen.dart';
import '../screens/user/post_deploy_screen.dart';
import '../core/models/place/place_model.dart';
import '../screens/place/create_place_screen.dart';
import '../screens/place/place_detail_screen.dart';
import '../screens/place/place_image_viewer_screen.dart';
import '../screens/place/place_search_screen.dart';
import '../screens/user/store_screen.dart';


class AppRoutes {
  static const String login = '/login';
  static const String signup = '/signup';
  static const String addressSearch = '/address-search';
  static const String main = '/main';
  static const String map = '/map';

  static const String budget = '/budget';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String postPlace = '/post-place';
  static const String postPlaceSelection = '/post-place-selection';
  static const String postDetail = '/post-detail';
  static const String postEdit = '/post-edit';

  static const String locationPicker = '/location-picker';
  static const String postDeploy = '/post-deploy';
  static const String createPlace = '/create-place';
  static const String placeDetail = '/place-detail';
  static const String placeSearch = '/place-search';
  static const String placeImageViewer = '/place-image-viewer';
  static const String store = '/store';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    signup: (context) => const SignupScreen(),
    addressSearch: (context) => const AddressSearchScreen(),
    main: (context) => const MainScreen(),
    map: (context) => const MapScreen(),

    budget: (context) => const BudgetScreen(),
    search: (context) => const SearchScreen(),
    settings: (context) => const SettingsScreen(),
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
    createPlace: (context) => const CreatePlaceScreen(),
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
    store: (context) => const StoreScreen(),
  };
} 