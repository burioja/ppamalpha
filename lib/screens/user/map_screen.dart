import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import 'package:provider/provider.dart';
import '../../providers/map_filter_provider.dart';

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
  const MapScreen({Key? key}) : super(key: key);
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;

  final userId = FirebaseAuth.instance.currentUser?.uid;
  final PostService _postService = PostService();
  
  final List<MarkerItem> _markerItems = [];
  final List<PostModel> _posts = [];
  double _currentZoom = 15.0;
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;
  StreamSubscription<QuerySnapshot>? _markersListener;
  final Set<Polygon> _fogOfWarPolygons = {};
  final Set<Circle> _fogOfWarCircles = {}; // 기존 호환성을 위해 유지
  
  // 사용자 이동 추적을 위한 변수들
  LatLng? _lastTrackedPosition;
  Timer? _movementTracker;
  static const double _movementThreshold = 50.0; // 50m 이상 이동 시 추적

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
    _loadCustomMarker();
    _loadMarkersFromFirestore();
    _loadPostsFromFirestore();
    _setupRealtimeListeners();
    _loadVisitsAndBuildFog();
  }

  @override
  void dispose() {
    // 실시간 리스너 정리
    _markersListener?.cancel();
    _movementTracker?.cancel();
    super.dispose();
  }

  Future<void> _loadVisitsAndBuildFog() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // 현재 위치가 없으면 기본 Fog of War만 생성
      if (_currentPosition == null) {
        _createPolygonBasedFog();
        return;
      }

      // Polygon 기반 Fog of War 생성
      final Set<Polygon> polygons = {};
      final Set<Circle> circles = {}; // 기존 호환성을 위해 유지
      
      // 전체 지도를 덮는 어두운 폴리곤
      final double latOffset = 0.1; // 약 11km
      final double lngOffset = 0.1; // 약 11km
      
      final List<LatLng> worldBounds = [
        LatLng(_currentPosition!.latitude - latOffset, _currentPosition!.longitude - lngOffset),
        LatLng(_currentPosition!.latitude + latOffset, _currentPosition!.longitude - lngOffset),
        LatLng(_currentPosition!.latitude + latOffset, _currentPosition!.longitude + lngOffset),
        LatLng(_currentPosition!.latitude - latOffset, _currentPosition!.longitude + lngOffset),
      ];
      
      // 전체 지도를 덮는 어두운 폴리곤
      polygons.add(
        Polygon(
          polygonId: const PolygonId('world_dark_overlay'),
          points: worldBounds,
          fillColor: Colors.black.withOpacity(0.7),
          strokeColor: Colors.transparent,
          strokeWidth: 0,
        ),
      );
      
      // 방문 기록이 있는 지역들 (과거 방문지) - 밝게 표시
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await FirebaseFirestore.instance
          .collection('visits')
          .doc(uid)
          .collection('points')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      // 방문 기록이 있는 지역들을 밝게 만들기 위한 폴리곤들
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final gp = data['geo'] as GeoPoint? ?? data['position'] as GeoPoint?;
        if (gp == null) continue;
        
        final visitLatLng = LatLng(gp.latitude, gp.longitude);
        final weight = (data['weight'] as num?)?.toDouble() ?? 1.0;
        final double radius = weight > 2.0 ? 0.5 : 0.3; // 자주 방문한 지역은 더 넓게
        
        // 방문 지역을 밝게 만들기 위한 투명한 폴리곤
        final List<LatLng> brightArea = _createCirclePoints(visitLatLng, radius);
        polygons.add(
          Polygon(
            polygonId: PolygonId('bright_visit_${doc.id}'),
            points: brightArea,
            fillColor: Colors.transparent,
            strokeColor: Colors.transparent,
            strokeWidth: 0,
          ),
        );
        
        // 기존 Circle 기반 시스템과의 호환성을 위해 유지
        circles.add(
          Circle(
            circleId: CircleId('bright_visit_${doc.id}'),
            center: visitLatLng,
            radius: (radius * 1000).toInt(), // km를 m로 변환
            strokeWidth: 0,
            fillColor: Colors.transparent,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _fogOfWarPolygons
            ..clear()
            ..addAll(polygons);
          _fogOfWarCircles
            ..clear()
            ..addAll(circles);
        });
        debugPrint('Polygon 기반 Fog of War 생성 완료: ${polygons.length}개 폴리곤');
        debugPrint('밝은 영역: 사용자 위치 1km 반경 + 방문 기록 ${snapshot.docs.length}개');
      }
    } catch (e) {
      debugPrint('Fog of War 로드 오류: $e');
      // 오류 발생 시 기본 Fog of War 생성
      _createPolygonBasedFog();
    }
  }

  // 기본 Fog of War 생성 (사용자 위치 반경 1km만 밝게)
  void _createDefaultFogOfWar() {
    if (_currentPosition == null) return;
    
    final Set<Circle> circles = {};
    
    // 메인 밝은 영역 (사용자 위치 반경 1km)
    circles.add(
      Circle(
        circleId: const CircleId('main_bright_area'),
        center: _currentPosition!,
        radius: 1000, // 1km 반경
        strokeWidth: 0,
        fillColor: Colors.transparent, // 투명하게 (지도가 밝게 보임)
      ),
    );
    
    // 전체 지도를 어둡게 덮는 큰 원 (Fog of War 효과)
    circles.add(
      Circle(
        circleId: const CircleId('dark_overlay'),
        center: _currentPosition!,
        radius: 10000, // 10km 반경 (충분히 큰 영역)
        strokeWidth: 0,
        fillColor: Colors.black.withOpacity(0.6), // 어두운 오버레이
      ),
    );
    
    setState(() {
      _fogOfWarCircles
        ..clear()
        ..addAll(circles);
    });
  }

  // 밝은 지역에 있는 마커만 필터링
  bool _isInBrightArea(LatLng position) {
    if (_currentPosition == null) return false;
    
    // 사용자 위치에서 1km 이내인지 확인
    final distance = _haversineKm(_currentPosition!, position);
    if (distance <= 1.0) return true; // 1km 이내
    
    // 방문 기록이 있는 지역인지 확인 (최근 30일)
    return _isInVisitedArea(position);
  }

  // 방문 기록이 있는 지역인지 확인
  bool _isInVisitedArea(LatLng position) {
    // 방문 기록이 로드되지 않았으면 false
    if (_fogOfWarCircles.isEmpty) return false;
    
    // 방문 기록이 있는 원형 영역 내에 있는지 확인
    for (final circle in _fogOfWarCircles) {
      if (circle.circleId.value.startsWith('bright_visit_') || 
          circle.circleId.value.startsWith('bright_frequent_')) {
        final distance = _haversineKm(circle.center, position);
        if (distance <= circle.radius / 1000.0) return true; // radius를 km 단위로 변환
      }
    }
    
    return false;
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // 스타일 로드 실패 시 기본 어두운 스타일 사용
      _createDefaultDarkStyle();
    }
  }

  // Polygon 기반 Fog of War 생성 (더 정확한 영역 제어)
  void _createPolygonBasedFog() {
    if (_currentPosition == null) return;
    
    final Set<Polygon> polygons = {};
    
    // 현재 뷰포트를 기준으로 전체 지도를 덮는 큰 사각형 생성
    // 실제로는 지도의 현재 보이는 영역을 기준으로 해야 함
    final double latOffset = 0.1; // 약 11km
    final double lngOffset = 0.1; // 약 11km
    
    final List<LatLng> worldBounds = [
      LatLng(_currentPosition!.latitude - latOffset, _currentPosition!.longitude - lngOffset),
      LatLng(_currentPosition!.latitude + latOffset, _currentPosition!.longitude - lngOffset),
      LatLng(_currentPosition!.latitude + latOffset, _currentPosition!.longitude + lngOffset),
      LatLng(_currentPosition!.latitude - latOffset, _currentPosition!.longitude + lngOffset),
    ];
    
    // 전체 지도를 덮는 어두운 폴리곤
    polygons.add(
      Polygon(
        polygonId: const PolygonId('world_dark_overlay'),
        points: worldBounds,
        fillColor: Colors.black.withOpacity(0.7),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
      ),
    );
    
    // 사용자 위치 주변 1km를 밝게 만들기 위해 구멍 뚫기
    final List<LatLng> brightArea = _createCirclePoints(_currentPosition!, 1.0);
    polygons.add(
      Polygon(
        polygonId: const PolygonId('bright_area_hole'),
        points: brightArea,
        fillColor: Colors.transparent,
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        holes: [], // 구멍을 만들기 위한 빈 배열
      ),
    );
    
    setState(() {
      _fogOfWarPolygons
        ..clear()
        ..addAll(polygons);
    });
    
    debugPrint('Polygon 기반 Fog of War 생성 완료: ${polygons.length}개 폴리곤');
  }

  // 사용자 이동 추적 시작
  void _startMovementTracking() {
    _movementTracker = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_currentPosition != null && mounted) {
        _trackUserMovement();
      }
    });
  }

  // 사용자 이동 추적 및 방문 기록 저장
  Future<void> _trackUserMovement() async {
    try {
      if (_currentPosition == null || _lastTrackedPosition == null) {
        _lastTrackedPosition = _currentPosition;
        return;
      }

      final distance = _haversineKm(_lastTrackedPosition!, _currentPosition!);
      
      // 50m 이상 이동했을 때만 추적
      if (distance * 1000 >= _movementThreshold) {
        await _saveVisitedLocation(_currentPosition!);
        _lastTrackedPosition = _currentPosition;
        
        // Fog of War 업데이트
        _loadVisitsAndBuildFog();
      }
    } catch (e) {
      debugPrint('사용자 이동 추적 오류: $e');
    }
  }

  // 방문한 위치를 Firestore에 저장
  Future<void> _saveVisitedLocation(LatLng position) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final now = DateTime.now();
      final locationKey = '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';
      
      // 방문 기록 저장
      await FirebaseFirestore.instance
          .collection('user_movements')
          .doc(uid)
          .collection('visited_cells')
          .doc(locationKey)
          .set({
        'location': GeoPoint(position.latitude, position.longitude),
        'visited_at': Timestamp.fromDate(now),
        'weight': FieldValue.increment(1), // 방문 횟수 증가
        'last_visit': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      debugPrint('방문 위치 저장됨: $locationKey');
    } catch (e) {
      debugPrint('방문 위치 저장 오류: $e');
    }
  }

  // 원형 영역을 폴리곤 포인트로 변환
  List<LatLng> _createCirclePoints(LatLng center, double radiusKm) {
    final List<LatLng> points = [];
    const int segments = 32; // 원을 32개 선분으로 근사
    
    for (int i = 0; i <= segments; i++) {
      final double angle = (2 * pi * i) / segments;
      final double lat = center.latitude + (radiusKm / 111.32) * cos(angle);
      final double lng = center.longitude + (radiusKm / (111.32 * cos(center.latitude * pi / 180))) * sin(angle);
      points.add(LatLng(lat, lng));
    }
    
    return points;
  }

  // 기본 어두운 스타일 생성 (Fog of War 효과)
  void _createDefaultDarkStyle() {
    final darkStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#242f3e"
          }
        ]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#263c3f"
          }
        ]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#6b9a76"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#38414e"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#212a37"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#9ca5b3"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#746855"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#1f2835"
          }
        ]
      },
      {
        "featureType": "road.highway",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#f3d19c"
          }
        ]
      },
      {
        "featureType": "transit",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#2f3948"
          }
        ]
      },
      {
        "featureType": "transit.station",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#d59563"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#515c6d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#17263c"
          }
        ]
      }
    ]
    ''';
    
    setState(() {
      _mapStyle = darkStyle;
    });
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(37.495872, 127.025046);
      });
      
      // 초기 위치 설정 후 이동 추적 시작
      _lastTrackedPosition = _currentPosition;
      _startMovementTracking();
    } catch (_) {
      _currentPosition = const LatLng(37.492894, 127.012469);
      _lastTrackedPosition = _currentPosition;
      _startMovementTracking();
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      const double targetSize = 48.0;
      
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        drawWidth = targetSize;
        drawHeight = targetSize / imageRatio;
        offsetY = (targetSize - drawHeight) / 2;
      }
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
      
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final ByteData? resizedBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedBytes != null) {
        final Uint8List resizedUint8List = resizedBytes.buffer.asUint8List();
        setState(() {
          _customMarkerIcon = BitmapDescriptor.fromBytes(resizedUint8List);
        });
      }
    } catch (e) {
      // 커스텀 마커 로드 실패 시 기본 마커 사용
    }
  }

  // 클러스터 마커용 이미지 생성 (말풍선 포함)
  Future<BitmapDescriptor?> _createClusterMarkerIcon(int count) async {
    try {
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      const double targetSize = 32.0; // 클러스터는 조금 더 크게
      
      // 배경 원 그리기
      final paint = Paint()
        ..color = Colors.orange.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(targetSize / 2, targetSize / 2),
        targetSize / 2,
        paint,
      );
      
      // 테두리 그리기
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(
        Offset(targetSize / 2, targetSize / 2),
        targetSize / 2,
        borderPaint,
      );
      
      // ppam_work 이미지 그리기 (중앙에)
      final double imageSize = targetSize * 0.6;
      final double imageOffset = (targetSize - imageSize) / 2;
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(imageOffset, imageOffset, imageSize, imageSize),
        Paint(),
      );
      
      // 숫자 말풍선 그리기 (우상단)
      final textPainter = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // 말풍선 배경
      final bubblePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      final bubbleRadius = 10.0;
      final bubbleX = targetSize - bubbleRadius - 5;
      final bubbleY = bubbleRadius + 5;
      
      canvas.drawCircle(
        Offset(bubbleX, bubbleY),
        bubbleRadius,
        bubblePaint,
      );
      
      // 숫자 그리기
      textPainter.paint(
        canvas,
        Offset(
          bubbleX - textPainter.width / 2,
          bubbleY - textPainter.height / 2,
        ),
      );
      
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final ByteData? resizedBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedBytes != null) {
        return BitmapDescriptor.fromBytes(resizedBytes.buffer.asUint8List());
      }
    } catch (e) {
      debugPrint('클러스터 마커 생성 오류: $e');
    }
    return null;
  }



  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  void _updateClustering() {
    // 줌 레벨에 따라 클러스터링 결정
    if (_currentZoom < 13.0) {
      _clusterMarkers();
    } else {
      _showIndividualMarkers();
    }
    
    // 디버그 정보 출력 (성능 향상을 위해 줄임)
    if (_currentZoom < 13.0) {
      debugPrint('클러스터링 업데이트: 줌=${_currentZoom}, 마커 수=${_clusteredMarkers.length}');
    }
  }

  void _showPostInfo(PostModel flyer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(flyer.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('발행자: ${flyer.creatorName}'),
              const SizedBox(height: 8),
              Text('리워드: ${flyer.reward}원'),
              const SizedBox(height: 8),
              Text('타겟: ${flyer.targetGender == 'all' ? '전체' : flyer.targetGender == 'male' ? '남성' : '여성'} ${flyer.targetAge[0]}~${flyer.targetAge[1]}세'),
              const SizedBox(height: 8),
              if (flyer.targetInterest.isNotEmpty)
                Text('관심사: ${flyer.targetInterest.join(', ')}'),
              const SizedBox(height: 8),
              Text('만료일: ${_formatDate(flyer.expiresAt)}'),
              const SizedBox(height: 8),
              if (flyer.canRespond) const Text('✓ 응답 가능'),
              if (flyer.canForward) const Text('✓ 전달 가능'),
              if (flyer.canRequestReward) const Text('✓ 리워드 수령 가능'),
              if (flyer.canUse) const Text('✓ 사용 가능'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            // 발행자만 회수 가능
            if (userId != null && userId == flyer.creatorId)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectPost(flyer);
                },
                child: const Text('회수'),
              ),
            // 조건에 맞는 사용자는 수령 가능
            if (userId != null && userId != flyer.creatorId && flyer.canRequestReward)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectFlyer(flyer);
                },
                child: const Text('수령'),
              ),
          ],
        );
      },
    );
  }

  // 발행자가 전단지 회수
  Future<void> _collectPost(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectFlyer(
          flyerId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('전단지를 회수했습니다!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전단지 회수에 실패했습니다: $e')),
        );
      }
    }
  }

  // 사용자가 전단지 수령
  Future<void> _collectFlyer(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        // TODO: 전단지 수령 로직 구현 (월렛에 추가, 리워드 지급 등)
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('전단지를 수령했습니다! ${flyer.reward}원 리워드가 지급되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전단지 수령에 실패했습니다: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _clusterMarkers() {
    if (_isClustered) return;
    
    debugPrint('클러스터링 시작: 마커 아이템 ${_markerItems.length}개, 포스트 ${_posts.length}개');
    
    final clusters = <String, List<dynamic>>{};
    final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = filter?.showMyPostsOnly ?? false;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    const double clusterRadius = 0.005; // 약 500m (더 세밀한 클러스터링)
    
    // 기존 마커 아이템들 클러스터링
    for (final item in _markerItems) {
      // 쿠폰만 필터
      if (couponsOnly && item.data['type'] != 'post_place') continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && item.userId != currentUserId) continue;
      
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final distance = _calculateDistance(clusterCenter, item.position);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(item);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${item.position.latitude},${item.position.longitude}';
        clusters[key] = [item];
      }
    }
    
    // 포스트들 클러스터링
    for (final post in _posts) {
      // 쿠폰만 필터
      if (couponsOnly && !(post.canUse || post.canRequestReward)) continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && post.creatorId != currentUserId) continue;
      
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final postLatLng = LatLng(post.location.latitude, post.location.longitude);
        final distance = _calculateDistance(clusterCenter, postLatLng);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(post);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${post.location.latitude},${post.location.longitude}';
        clusters[key] = [post];
      }
    }
    
    final Set<Marker> newMarkers = {};
    
    clusters.forEach((key, items) {
      if (items.length == 1) {
        final item = items.first;
        if (item is MarkerItem) {
          newMarkers.add(_createMarker(item));
        } else if (item is PostModel) {
          newMarkers.add(_createPostMarker(item));
        }
      } else {
        final center = _parseLatLng(key);
        // 클러스터 마커는 기본 아이콘으로 먼저 생성하고, 나중에 업데이트
        newMarkers.add(_createClusterMarker(center, items.length));
      }
    });
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = true;
    });
  }

  void _showIndividualMarkers() {
    debugPrint('개별 마커 표시 시작: 마커 아이템 ${_markerItems.length}개, 포스트 ${_posts.length}개');
    
    final Set<Marker> newMarkers = {};
    final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = filter?.showMyPostsOnly ?? false;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // 기존 마커들 추가
    for (final item in _markerItems) {
      // 쿠폰만 필터
      if (couponsOnly && item.data['type'] != 'post_place') continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && item.userId != currentUserId) continue;
      
      newMarkers.add(_createMarker(item));
      debugPrint('마커 추가됨: ${item.title} at ${item.position}');
    }
    
    // 포스트 마커들 추가
    for (final post in _posts) {
      // 쿠폰만 필터
      if (couponsOnly && !(post.canUse || post.canRequestReward)) continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && post.creatorId != currentUserId) continue;
      
      newMarkers.add(_createPostMarker(post));
      debugPrint('포스트 마커 추가됨: ${post.title} at ${post.location}');
    }
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = false;
    });
    
    debugPrint('마커 설정 완료: 총 ${newMarkers.length}개 마커');
  }

  LatLng _parseLatLng(String key) {
    final parts = key.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return sqrt(pow(point1.latitude - point2.latitude, 2) + 
                pow(point1.longitude - point2.longitude, 2));
  }

  double _haversineKm(LatLng a, LatLng b) {
    const double R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa = 
        sin(dLat/2) * sin(dLat/2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) *
        sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(aa), sqrt(1-aa));
    return R * c;
  }

  double _deg2rad(double d) => d * (pi / 180.0);

  Marker _createMarker(MarkerItem item) {
    // 전단지 타입인지 확인
    final isPostPlace = item.data['type'] == 'post_place';
    
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: item.title,
        snippet: isPostPlace 
            ? '${item.price}원 - ${item.data['creatorName'] ?? '알 수 없음'}'
            : '${item.price}원 - ${item.amount}개',
      ),
      onTap: () => _showMarkerInfo(item),
    );
  }

  Marker _createPostMarker(PostModel flyer) {
    return Marker(
      markerId: MarkerId(flyer.markerId),
      position: LatLng(flyer.location.latitude, flyer.location.longitude),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: flyer.title,
        snippet: '${flyer.reward}원 - ${flyer.creatorName}',
      ),
      onTap: () => _showPostInfo(flyer),
    );
  }

  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange), // 기본값
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커가 이 지역에 있습니다',
      ),
      onTap: () => _showClusterInfo(position, count),
    );
  }

  void _showMarkerInfo(MarkerItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 전단지 타입인지 확인
        final isPostPlace = item.data['type'] == 'post_place';
        final isOwner = item.userId == FirebaseAuth.instance.currentUser?.uid;
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isPostPlace ? Icons.description : Icons.location_on,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(item.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPostPlace) ...[
                Text('발행자: ${item.data['creatorName'] ?? '알 수 없음'}'),
                const SizedBox(height: 8),
                Text('리워드: ${item.price}원'),
                const SizedBox(height: 8),
                if (item.data['description'] != null && item.data['description'].isNotEmpty)
                  Text('설명: ${item.data['description']}'),
                const SizedBox(height: 8),
                if (item.data['targetGender'] != null)
                  Text('타겟 성별: ${item.data['targetGender'] == 'all' ? '전체' : item.data['targetGender'] == 'male' ? '남성' : '여성'}'),
                const SizedBox(height: 8),
                if (item.data['targetAge'] != null)
                  Text('타겟 나이: ${item.data['targetAge'][0]}~${item.data['targetAge'][1]}세'),
                const SizedBox(height: 8),
                if (item.data['address'] != null)
                  Text('주소: ${item.data['address']}'),
                const SizedBox(height: 8),
                if (item.expiryDate != null)
                  Text('만료일: ${_formatDate(item.expiryDate!)}'),
              ] else ...[
                Text('가격: ${item.price}원'),
                const SizedBox(height: 8),
                Text('수량: ${item.amount}개'),
                const SizedBox(height: 8),
                Text('남은 수량: ${item.remainingAmount}개'),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOwner ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOwner ? Colors.blue : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOwner ? Icons.person : Icons.people,
                      color: isOwner ? Colors.blue : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOwner ? '내가 등록한 마커' : '다른 사용자 마커',
                      style: TextStyle(
                        color: isOwner ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (isPostPlace) ...[
              // 전단지 수령 버튼 (소유자가 아닌 경우만)
              if (item.data['canRequestReward'] == true && !isOwner)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleFlyerRecovery(item);
                  },
                  child: const Text('수령'),
                ),
            ] else ...[
              // 일반 마커 수령/회수 버튼
              if (isOwner)
                // 마커 소유자만 회수 가능
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleMarkerCollection(item.id, item.data);
                  },
                  child: const Text('회수'),
                )
              else
                // 다른 사용자는 수령 가능
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleRecovery(item.id, item.data);
                  },
                  child: const Text('수령'),
                ),
            ],
          ],
        );
      },
    );
  }

  void _showClusterInfo(LatLng position, int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              const SizedBox(width: 8),
              Text('클러스터 정보'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('이 지역에 $count개의 마커가 있습니다.'),
              const SizedBox(height: 8),
              Text(
                '더 자세히 보려면 이 지역으로 확대해보세요.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 해당 지역으로 줌인
                mapController.animateCamera(
                  CameraUpdate.newLatLngZoom(position, 16.0),
                );
              },
              child: const Text('확대하기'),
            ),
          ],
        );
      },
    );
  }

  void _handleRecovery(String markerId, Map<String, dynamic> data) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'isCollected': true,
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('마커를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마커 수령에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 마커 소유자가 회수하는 함수
  void _handleMarkerCollection(String markerId, Map<String, dynamic> data) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'isActive': false, // 비활성화
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('마커를 회수했습니다!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마커 회수에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 전단지 수령 처리
  void _handleFlyerRecovery(MarkerItem item) async {
    try {
      final flyerId = item.data['flyerId'] as String;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // PostService를 통해 전단지 수령
        await _postService.collectFlyer(
          flyerId: flyerId,
          userId: currentUserId,
        );
        
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(item.id).update({
          'isCollected': true,
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
        });
        
        // 마커 목록에서 제거
        setState(() {
          _markerItems.removeWhere((marker) => marker.id == item.id);
        });
        
        // 클러스터링 업데이트
        _updateClustering();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전단지를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전단지 수령에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();
      
      _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('마커 로드 오류: $e');
    }
  }

  void _setupRealtimeListeners() {
    // 실시간 마커 리스너 설정
    _markersListener = FirebaseFirestore.instance
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _processMarkersSnapshot(snapshot);
        });
  }

  void _processMarkersSnapshot(QuerySnapshot snapshot) {
    setState(() {
      _markerItems.clear();
    });
    
    debugPrint('마커 스냅샷 처리 중: ${snapshot.docs.length}개 마커');
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = data['position'] as GeoPoint;
      
      // 만료된 마커는 제외
      if (data['expiryDate'] != null) {
        final expiryDate = data['expiryDate'].toDate() as DateTime;
        if (DateTime.now().isAfter(expiryDate)) {
          debugPrint('만료된 마커 제외: ${doc.id}');
          continue; // 만료된 마커는 건너뛰기
        }
      }
      
      final markerItem = MarkerItem(
        id: doc.id,
        title: data['title'] ?? '',
        price: data['price']?.toString() ?? '0',
        amount: data['amount']?.toString() ?? '0',
        userId: data['userId'] ?? '',
        data: data,
        position: LatLng(geoPoint.latitude, geoPoint.longitude),
        imageUrl: data['imageUrl'],
        remainingAmount: data['remainingAmount'] ?? 0,
        expiryDate: data['expiryDate']?.toDate(),
      );
      
      // Fog of War: 밝은 지역에 있는 마커만 표시
      if (_isInBrightArea(markerItem.position)) {
        _markerItems.add(markerItem);
        debugPrint('마커 로드됨 (밝은 지역): ${markerItem.title} at ${markerItem.position}, 타입: ${data['type']}');
      } else {
        debugPrint('마커 제외됨 (어두운 지역): ${markerItem.title} at ${markerItem.position}');
      }
    }
    
    debugPrint('마커 처리 완료: 총 ${_markerItems.length}개 마커 로드됨 (밝은 지역만)');
    
    // 클러스터링 업데이트로 마커들을 지도에 표시
    _updateClustering();
  }

  Future<void> _loadPostsFromFirestore() async {
    try {
      if (_currentPosition != null) {
        // 사용자 정보 가져오기 (실제로는 사용자 프로필에서 가져와야 함)
        final userGender = 'male'; // 임시 값
        final userAge = 25; // 임시 값
        final userInterests = ['패션', '뷰티']; // 임시 값
        final userPurchaseHistory = ['화장품']; // 임시 값
        
        // 새로운 flyer 시스템에서 전단지 로드 (Fog of War: 1km + 방문 기록 지역)
        final flyers = await _postService.getFlyersNearLocation(
          location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          radiusInKm: 2.0, // 기본 2km 반경으로 확장 (방문 기록 지역 포함)
          userGender: userGender,
          userAge: userAge,
          userInterests: userInterests,
          userPurchaseHistory: userPurchaseHistory,
        );
        
        setState(() {
          _posts.clear();
          _posts.addAll(flyers);
        });
        
        debugPrint('전단지 로드 완료: ${flyers.length}개 (1km 반경 내만)');
        _updateClustering();
      }
    } catch (e) {
      debugPrint('전단지 로드 오류: $e');
    }
  }



  void _addMarkerToMap(MarkerItem markerItem) {
    setState(() {
      _markerItems.add(markerItem);
      // 마커를 직접 _clusteredMarkers에 추가하지 않고 _markerItems에만 추가
      // _updateClustering()에서 모든 마커를 다시 생성
    });
    
    // Firestore에 저장
    _saveMarkerToFirestore(markerItem);
    
    // 클러스터링 업데이트로 모든 마커를 다시 생성
    _updateClustering();
    
    debugPrint('마커 추가됨: ${markerItem.title} at ${markerItem.position}');
  }

  Future<void> _saveMarkerToFirestore(MarkerItem markerItem) async {
    try {
      final markerData = {
        'title': markerItem.title,
        'price': int.parse(markerItem.price),
        'amount': int.parse(markerItem.amount),
        'userId': markerItem.userId,
        'position': GeoPoint(markerItem.position.latitude, markerItem.position.longitude),
        'remainingAmount': markerItem.remainingAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': markerItem.expiryDate,
        'isActive': true, // 활성 상태
        'isCollected': false, // 회수되지 않음
      };
      
      // 전단지 타입인 경우 추가 정보 저장
      if (markerItem.data['type'] == 'post_place') {
        markerData.addAll({
          'type': 'post_place',
          'flyerId': markerItem.data['flyerId'],
          'creatorName': markerItem.data['creatorName'],
          'description': markerItem.data['description'],
          'targetGender': markerItem.data['targetGender'],
          'targetAge': markerItem.data['targetAge'],
          'canRespond': markerItem.data['canRespond'],
          'canForward': markerItem.data['canForward'],
          'canRequestReward': markerItem.data['canRequestReward'],
          'canUse': markerItem.data['canUse'],
          'address': markerItem.data['address'],
        });
      }
      
      final docRef = await FirebaseFirestore.instance.collection('markers').add(markerData);
      debugPrint('마커 Firebase 저장 완료: ${docRef.id}');
    } catch (e) {
      debugPrint('마커 저장 오류: $e');
    }
  }

  void _handleAddMarker() async {
    if (_longPressedLatLng != null) {
      // 선택된 위치의 주소 가져오기
      try {
        final address = await LocationService.getAddressFromCoordinates(
          _longPressedLatLng!.latitude,
          _longPressedLatLng!.longitude,
        );
        
        // 롱프레스 팝업 닫기
        setState(() {
          _longPressedLatLng = null;
        });
        
        // 주소 확인 팝업 표시
        _showAddressConfirmationDialog(address);
      } catch (e) {
        // 롱프레스 팝업 닫기
        setState(() {
          _longPressedLatLng = null;
        });
        
        // 주소 가져오기 실패 시 기본 메시지로 진행
        _showAddressConfirmationDialog('주소를 가져올 수 없습니다');
      }
    }
  }

  void _showAddressConfirmationDialog(String address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('주소 확인'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '이 주소가 맞습니까?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.shade50,
                ),
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPostPlaceWithAddress(address);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupWidget() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '포스트 배포',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4D4DFF),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '선택한 위치에서 포스트를 배포합니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeploy();
                },
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text(
                  "이 위치에 뿌리기",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeployWithAddress();
                },
                icon: const Icon(Icons.home, color: Color(0xFF4D4DFF)),
                label: const Text(
                  "이 주소에 뿌리기",
                  style: TextStyle(color: Color(0xFF4D4DFF), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeployByCategory();
                },
                icon: const Icon(Icons.category, color: Color(0xFF4D4DFF)),
                label: const Text(
                  "특정 업종에 뿌리기",
                  style: TextStyle(color: Color(0xFF4D4DFF), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '수수료/반경/타겟팅 주의',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                child: const Text(
                  "취소",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPostDeploy() async {
    // 이 위치에 뿌리기 - 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'location',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostDeployWithAddress() async {
    // 이 주소에 뿌리기 - 주소 기반 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'address',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostDeployByCategory() async {
    // 특정 업종에 뿌리기 - 업종 기반 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'category',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostPlaceWithAddress(String address) async {
    // 주소 정보와 함께 포스트 화면으로 이동
    final result = await Navigator.pushNamed(
      context, 
      '/post-place',
      arguments: {
        'location': _longPressedLatLng,
        'address': address,
      },
    );
    _handlePostPlaceResult(result);
  }

  void _handlePostDeployResult(dynamic result) async {
    // 포스트 배포 결과 처리
    if (result != null && result is Map<String, dynamic>) {
      // 새로 생성된 포스트 정보를 MarkerItem으로 변환
      if (result['location'] != null && result['postId'] != null) {
        final location = result['location'] as LatLng;
        final postId = result['postId'] as String;
        final address = result['address'] as String?;
        
        try {
          // PostService에서 실제 포스트 정보 가져오기
          final post = await _postService.getPostById(postId);
          
          if (post != null) {
            // MarkerItem 생성 (실제 포스트 정보 사용)
            final markerItem = MarkerItem(
              id: postId,
              title: post.title,
              price: post.reward.toString(),
              amount: '1', // 포스트는 개별 단위
              userId: post.creatorId,
              data: {
                'address': address,
                'postId': postId,
                'type': 'post',
                'creatorName': post.creatorName,
                'description': post.description,
                'targetGender': post.targetGender,
                'targetAge': post.targetAge,
                'canRespond': post.canRespond,
                'canForward': post.canForward,
                'canRequestReward': post.canRequestReward,
                'canUse': post.canUse,
              },
              position: location,
              remainingAmount: 1, // 포스트는 개별 단위
              expiryDate: post.expiresAt,
            );
            
            // 마커 추가 (Firebase에 저장됨)
            _addMarkerToMap(markerItem);
            
            // 생성된 포스트 위치로 카메라 이동
            mapController.animateCamera(
              CameraUpdate.newLatLng(location),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('포스트 정보를 가져오는데 실패했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void _handlePostPlaceResult(dynamic result) async {
    // 전단지 생성 후 지도 새로고침
    if (result != null && result is Map<String, dynamic>) {
      // 새로 생성된 전단지 정보를 MarkerItem으로 변환
      if (result['location'] != null && result['flyerId'] != null) {
        final location = result['location'] as LatLng;
        final flyerId = result['flyerId'] as String;
        final address = result['address'] as String?;
        
        try {
          // PostService에서 실제 전단지 정보 가져오기
          final flyer = await _postService.getFlyerById(flyerId);
          
          if (flyer != null) {
            // MarkerItem 생성 (실제 전단지 정보 사용)
            final markerItem = MarkerItem(
              id: flyerId,
              title: flyer.title,
              price: flyer.reward.toString(),
              amount: '1', // 전단지는 개별 단위
              userId: flyer.creatorId,
              data: {
                'address': address,
                'flyerId': flyerId,
                'type': 'post_place',
                'creatorName': flyer.creatorName,
                'description': flyer.description,
                'targetGender': flyer.targetGender,
                'targetAge': flyer.targetAge,
                'canRespond': flyer.canRespond,
                'canForward': flyer.canForward,
                'canRequestReward': flyer.canRequestReward,
                'canUse': flyer.canUse,
              },
              position: location,
              remainingAmount: 1, // 전단지는 개별 단위
              expiryDate: flyer.expiresAt,
            );
            
            // 마커 추가 (Firebase에 저장됨)
            _addMarkerToMap(markerItem);
            
            // 생성된 전단지 위치로 카메라 이동
            mapController.animateCamera(
              CameraUpdate.newLatLng(location),
            );
            

          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('전단지 정보를 가져오는데 실패했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void goToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = Provider.of<MapFilterProvider>(context);
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
          : Stack(
        children: [
          GoogleMap(
            key: mapWidgetKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            circles: _fogOfWarCircles,
            polygons: _fogOfWarPolygons,
            onLongPress: (LatLng latLng) {
              setState(() {
                _longPressedLatLng = latLng;
              });
            },
            markers: {
              ..._clusteredMarkers,
              if (_longPressedLatLng != null)
                Marker(
                  markerId: const MarkerId('long_press_marker'),
                  position: _longPressedLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "선택한 위치"),
                ),
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              // 카메라가 멈춘 후에만 클러스터링 업데이트 (성능 향상)
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  _updateClustering();
                }
              });
            },
          ),
                     // 상단 필터 바
           Positioned(
             top: 16,
             left: 12,
             right: 12,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: const [
                   BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2)),
                 ],
               ),
               child: Row(
                 children: [
                   FilterChip(
                     label: const Text('쿠폰만'),
                     selected: filters.showCouponsOnly,
                     onSelected: (_) {
                       filters.toggleCouponsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   FilterChip(
                     label: const Text('내 포스트'),
                     selected: filters.showMyPostsOnly,
                     onSelected: (_) {
                       filters.toggleMyPostsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   if (filters.showCouponsOnly || filters.showMyPostsOnly)
                     FilterChip(
                       label: const Text('필터 초기화'),
                       selected: false,
                       onSelected: (_) {
                         filters.resetFilters();
                         _updateClustering();
                       },
                     ),
                 ],
               ),
             ),
           ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}

 