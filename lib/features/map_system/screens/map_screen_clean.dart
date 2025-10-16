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
import '../../../core/models/user/user_model.dart';  // UserModel과 UserType 추가
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';  // MarkerService 추가
import '../../../core/services/data/user_service.dart';  // UserService 추가
import '../../../core/constants/app_constants.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/marker_layer_widget.dart';
import '../utils/client_cluster.dart';
import '../widgets/cluster_widgets.dart';
import '../../post_system/controllers/post_deployment_controller.dart';
import '../../../core/services/osm_geocoding_service.dart';
import '../../post_system/widgets/address_search_dialog.dart';
// OSM 기반 Fog of War 시스템
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

/// 마커 아이템 클래스
class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl;
  final int remainingAmount;
  final DateTime? expiryDate;

  MarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
    this.imageUrl,
    required this.remainingAmount,
    this.expiryDate,
  });
}

class MapScreen extends StatefulWidget {
  final Function(String)? onAddressChanged;
  final VoidCallback? onNavigateToInbox;
  
  const MapScreen({super.key, this.onAddressChanged, this.onNavigateToInbox});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OSM 기반 Fog of War 상태
  List<Polygon> _grayPolygons = []; // 회색 영역들 (과거 방문 위치)
  List<CircleMarker> _ringCircles = [];
  List<Marker> _currentMarkers = [];
  
  // 클러스터링 관련 변수들
  List<Marker> _clusteredMarkers = [];
  Size _lastMapSize = const Size(0, 0);
  LatLng _mapCenter = const LatLng(37.5665, 126.9780); // 서울 기본값
  double _mapZoom = 10.0;
  
  // 새로운 클러스터링 시스템용 변수들
  Timer? _clusterDebounceTimer;
  List<ClusterMarkerModel> _visibleMarkerModels = [];
  
  // 사용자 위치 정보
  LatLng? _homeLocation;
  List<LatLng> _workLocations = [];
  
  // 기본 상태
  MapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 14.0;
  String _currentAddress = '위치 불러오는 중...';
