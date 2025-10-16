import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/user/user_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../../core/services/data/user_service.dart';
import '../../../core/constants/app_constants.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import '../widgets/marker_layer_widget.dart';
import '../utils/client_cluster.dart';
import '../widgets/cluster_widgets.dart';
import '../../post_system/controllers/post_deployment_controller.dart';
import '../../../core/services/osm_geocoding_service.dart';
import '../../post_system/widgets/address_search_dialog.dart';
import '../services/external/osm_fog_service.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../widgets/unified_fog_overlay_widget.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/location/location_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/models/map/fog_level.dart';
import '../models/receipt_item.dart';
import '../widgets/receive_carousel.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart' as audio;

// Part files로 분할
part 'parts/map_screen_state.dart';
part 'parts/map_screen_fog.dart';
part 'parts/map_screen_post.dart';
part 'parts/map_screen_ui.dart';

/// 메인 지도 화면 (핵심만)
class MapScreen extends StatefulWidget {
  final Function(String)? onAddressChanged;
  final VoidCallback? onNavigateToInbox;

  const MapScreen({
    super.key,
    this.onAddressChanged,
    this.onNavigateToInbox,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // 상태 변수들은 part 파일에 정의
}

