import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
// import 'package:provider/provider.dart';
// import '../../providers/map_filter_provider.dart';

// ===== 지오해시 유틸리티 =====
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const _bits = [16, 8, 4, 2, 1];

String geohashEncode(double lat, double lng, {int precision = 7}) {
  var isEven = true;
  var bit = 0;
  var ch = 0;
  String hash = '';

  double latMin = -90.0, latMax = 90.0;
  double lngMin = -180.0, lngMax = 180.0;

  while (hash.length < precision) {
    if (isEven) {
      final mid = (lngMin + lngMax) / 2;
      if (lng > mid) {
        ch |= _bits[bit];
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat > mid) {
        ch |= _bits[bit];
        latMin = mid;
      } else {
        latMax = mid;
      }
    }

    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      hash += _base32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}

class _LatLng { 
  final double lat, lng; 
  const _LatLng(this.lat, this.lng); 
}

class _BBox { 
  final double minLat, maxLat, minLng, maxLng; 
  const _BBox(this.minLat, this.maxLat, this.minLng, this.maxLng); 
}

class _CellSize { 
  final double w, h; 
  const _CellSize(this.w, this.h); 
}

// 지오해시 정밀도별 셀 크기 (미터)
Map<int, _CellSize> _cellSizes = {
  1: _CellSize(5009400, 4992600),
  2: _CellSize(1252300, 624100),
  3: _CellSize(156500, 156000),
  4: _CellSize(39100, 19500),
  5: _CellSize(4890, 4890),
  6: _CellSize(1220, 610),
  7: _CellSize(153, 153),
  8: _CellSize(38, 19),
  9: _CellSize(4.8, 4.8),
  10: _CellSize(1.2, 0.6),
};

_CellSize cellSizeForPrecision(int p) => _cellSizes[p] ?? _CellSize(1.2, 0.6);

class GeohashRange { 
  final String start, end; 
  GeohashRange(this.start, this.end); 
}

// 지오해시 범위 쿼리 최적화
List<GeohashRange> rangesFromCells(List<String> cells) {
  final set = cells.toSet().toList()..sort();
  return set.map((c) => GeohashRange(c, '${c}\uf8ff')).toList();
}

// 반경에 맞는 최적 정밀도 선택
int pickPrecisionForRadiusKm(double radiusKm) {
  if (radiusKm > 250) return 3;        // ~156km
  if (radiusKm > 60) return 4;         // ~39km
  if (radiusKm > 8) return 5;          // ~4.9km
  if (radiusKm > 2) return 6;          // ~1.2km
  if (radiusKm > 0.5) return 7;        // ~153m
  return 8;                             // ~38m
}

// 원 경계 → BBox 변환
_BBox circleBBox(_LatLng c, double radiusMeters) {
  const R = 6371000.0;
  final d = radiusMeters / R;
  final lat = c.lat * pi / 180.0;
  final lng = c.lng * pi / 180.0;

  final latMin = (lat - d) * 180.0 / pi;
  final latMax = (lat + d) * 180.0 / pi;

  final dLng = asin(sin(d) / cos(lat));
  final lngMin = (lng - dLng) * 180.0 / pi;
  final lngMax = (lng + dLng) * 180.0 / pi;

  return _BBox(latMin, latMax, _wrapLng(lngMin), _wrapLng(lngMax));
}

double _wrapLng(double lng) {
  while (lng > 180.0) lng -= 360.0;
  while (lng < -180.0) lng += 360.0;
  return lng;
}

bool _lngLe(double a, double b) {
  if (b >= a) return a <= b;
  return (a <= 180.0) || (_wrapLng(a) <= _wrapLng(b));
}

double _incLng(double lng, double step) {
  lng += step;
  if (lng > 180.0) lng -= 360.0;
  return lng;
}

// BBox를 덮는 지오해시 셀 생성
List<String> geohashCoverBBox(_BBox b, {int precision = 7}) {
  final cs = cellSizeForPrecision(precision);
  const mPerDegLat = 111320.0;
  final centerLat = (b.minLat + b.maxLat) / 2.0;
  final mPerDegLng = (mPerDegLat * cos(centerLat * pi / 180.0)).abs().clamp(1.0, mPerDegLat);

  final dLat = cs.h / mPerDegLat;
  final dLng = cs.w / mPerDegLng;

  final cells = <String>{};
  for (double lat = b.minLat; lat <= b.maxLat; lat += dLat) {
    for (double lng = b.minLng; _lngLe(lng, b.maxLng); lng = _incLng(lng, dLng)) {
      cells.add(geohashEncode(lat.clamp(-90.0, 90.0), _wrapLng(lng), precision: precision));
    }
  }
  cells.add(geohashEncode(b.maxLat, b.maxLng, precision: precision));
  return cells.toList();
}

// 주차 버킷 생성
String _weekBucket(DateTime t) {
  final y = t.year;
  final first = DateTime(t.year, 1, 1);
  final week = (t.difference(first).inDays / 7).floor() + 1;
  return '$y-W$week';
}

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

// ===== 고성능 Fog of War 컨트롤러 =====
class FogOfWarController {
  FogOfWarController(this._map);

  final GoogleMapController _map;
  final polygons = <Polygon>{};
  Timer? _debounce;

  // 캐시 시스템
  final Map<String, List<LatLng>> _cellCache = {};
  final Map<String, DateTime> _cellFetchedAt = {};
  static const _ttl = Duration(minutes: 8);

  // 최적화 파라미터
  static const _days = 30;
  static const _dedupMeters = 100.0;
  static const _visitedRadius = 1000.0;
  static const _currentRadius = 1000.0;
  static const _debounceMs = 280;

  // 외부에서 호출 (카메라 정지 시)
  void onCameraIdle({required LatLng current}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () async {
      final bounds = await _map.getVisibleRegion();
      final zoom = await _map.getZoomLevel();
      await _rebuild(current: current, bounds: bounds, zoom: zoom);
    });
  }

  Future<void> _rebuild({
    required LatLng current,
    required LatLngBounds bounds,
    required double zoom,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1) 뷰포트 중심과 최적 반경 계산
      final center = LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        _midLng(bounds.southwest.longitude, bounds.northeast.longitude),
      );
      final radiusKm = max(0.3, _radiusToCoverBoundsKm(bounds, center));

      // 2) 최근 30일 주차 버킷 생성
      final weekBuckets = _recentWeekBuckets(_days);

      // 3) 지오해시 + 주차버킷 결합 쿼리
      final docs = await _geoTsBucketQuery(
        uid: uid,
        centerLat: center.latitude,
        centerLng: center.longitude,
        radiusKm: radiusKm,
        weekBuckets: weekBuckets,
        hardLimitPerRange: 1000,
      );

      // 4) 클라이언트 최종 필터 (30일 + bounds)
      final cutoff = DateTime.now().subtract(const Duration(days: _days));
      final raw = <LatLng>[];
      
      for (final d in docs) {
        final data = d.data();
        final ts = (data['ts'] as Timestamp?)?.toDate();
        final gp = data['position'] as GeoPoint?;
        if (gp == null || ts == null || ts.isBefore(cutoff)) continue;
        final p = LatLng(gp.latitude, gp.longitude);
        if (!_inBounds(bounds, p)) continue;
        raw.add(p);
      }

      // 5) 100m 격자 dedup (Isolate)
      final deduped = await compute(_dedupGrid, _DedupInput(
        points: raw, 
        meters: _dedupMeters, 
        bounds: bounds,
      ));
      final visited = deduped.take(600).toList(); // 폴리곤 수 제한

      // 6) 폴리곤 생성 (3단계 구조)
      final seg = _segmentsForZoom(zoom);
      await _buildPolygons(current, visited, seg);

    } catch (e) {
      debugPrint('❌ Fog of War 오류: $e');
    }
  }

  // 지오해시 + 주차버킷 결합 쿼리 (핵심 최적화)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _geoTsBucketQuery({
    required String uid,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    required List<String> weekBuckets,
    int? hardLimitPerRange,
  }) async {
    final col = FirebaseFirestore.instance
        .collection('visits').doc(uid).collection('points');

    // 1) 원을 덮는 지오해시 셀 생성
    final precision = pickPrecisionForRadiusKm(radiusKm);
    final bbox = circleBBox(_LatLng(centerLat, centerLng), radiusKm * 1000.0);
    final cells = geohashCoverBBox(bbox, precision: precision);
    final ranges = rangesFromCells(cells);

    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    // 2) 각 지오해시 범위 × 주차버킷 결합 쿼리
    for (final r in ranges) {
      try {
        Query<Map<String, dynamic>> q = col
            .where('geohash', isGreaterThanOrEqualTo: r.start)
            .where('geohash', isLessThanOrEqualTo: r.end)
            .where('tsW', whereIn: weekBuckets)
            .orderBy('geohash');

        if (hardLimitPerRange != null) {
          q = q.limit(hardLimitPerRange);
        }

        final snap = await q.get();
        results.addAll(snap.docs);
      } catch (e) {
        debugPrint('⚠️ 지오해시 쿼리 실패 (${r.start}): $e');
        // 개별 쿼리 실패해도 전체는 계속 진행
      }
    }

    return results;
  }

  // 폴리곤 구축 (3단계 Fog of War)
  Future<void> _buildPolygons(LatLng current, List<LatLng> visited, int segments) async {
    // 월드 폴리곤 (전체 지구 덮기)
    final world = <LatLng>[
      const LatLng(90, -180),   // 북극, 서쪽 끝
      const LatLng(90, 180),    // 북극, 동쪽 끝  
      const LatLng(-90, 180),   // 남극, 동쪽 끝
      const LatLng(-90, -180),  // 남극, 서쪽 끝
    ];

    // 구멍 생성 (현재 위치 + 방문지)
    final holes = <List<LatLng>>[];
    holes.add(_circlePath(current, _currentRadius, segments: segments));
    for (final p in visited) {
      holes.add(_circlePath(p, _visitedRadius, segments: segments));
    }

    final polys = <Polygon>{
      // 3단계: 검은 포그 (holes로 구멍 뚫기)
      Polygon(
        polygonId: const PolygonId('fog_black'),
        points: world,
        holes: holes,
        strokeWidth: 0,
        fillColor: Colors.black.withOpacity(0.95), // 거의 완전한 검은색
        zIndex: 1,
        consumeTapEvents: false,
      ),
    };

    // 2단계: 방문지 회색 틴트 (현재 위치 제외)
    for (int i = 0; i < visited.length; i++) {
      polys.add(
        Polygon(
          polygonId: PolygonId('visited_gray_$i'),
          points: _circlePath(visited[i], _visitedRadius, segments: segments),
          strokeWidth: 0,
          fillColor: Colors.transparent, // 완전 투명 (밝은 상태 유지)
          zIndex: 2,
          consumeTapEvents: false,
        ),
      );
    }

    // 결과 적용
    polygons
      ..clear()
      ..addAll(polys);
  }

  // === 유틸리티 메서드들 ===

  bool _inBounds(LatLngBounds b, LatLng p) {
    final sw = b.southwest;
    final ne = b.northeast;
    final crosses = ne.longitude < sw.longitude; // antimeridian
    final lngOk = crosses
        ? (p.longitude >= sw.longitude || p.longitude <= ne.longitude)
        : (p.longitude >= sw.longitude && p.longitude <= ne.longitude);
    final latOk = p.latitude >= sw.latitude && p.latitude <= ne.latitude;
    return latOk && lngOk;
  }

  double _radiusToCoverBoundsKm(LatLngBounds b, LatLng c) {
    final corners = [
      b.southwest,
      LatLng(b.southwest.latitude, b.northeast.longitude),
      b.northeast,
      LatLng(b.northeast.latitude, b.southwest.longitude),
    ];
    var maxD = 0.0;
    for (final v in corners) {
      maxD = max(maxD, _haversineKm(c.latitude, c.longitude, v.latitude, v.longitude));
    }
    return maxD * 1.05; // 5% 여유
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // 지구 반지름 (km)
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_toRad(lat1))*cos(_toRad(lat2))*sin(dLon/2)*sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _midLng(double a, double b) {
    if (b < a) b += 360;
    var m = (a + b) / 2;
    if (m > 180) m -= 360;
    return m;
  }

  int _segmentsForZoom(double z) {
    if (z < 8) return 24;   // 낮은 줌: 적은 버텍스
    if (z < 12) return 32;
    if (z < 15) return 40;
    return 48;              // 높은 줌: 많은 버텍스 (매끄러움)
  }

  List<LatLng> _circlePath(LatLng center, double radiusMeters, {int segments = 36}) {
    const earth = 6378137.0;
    final dByR = radiusMeters / earth;
    final lat = _toRad(center.latitude);
    final lng = _toRad(center.longitude);
    final pts = <LatLng>[];
    
    for (int i = 0; i < segments; i++) {
      final theta = 2 * pi * i / segments;
      final latOffset = asin(sin(lat) * cos(dByR) + cos(lat) * sin(dByR) * cos(theta));
      final lngOffset = lng + atan2(
        sin(theta) * sin(dByR) * cos(lat),
        cos(dByR) - sin(lat) * sin(latOffset),
      );
      pts.add(LatLng(_toDeg(latOffset), _toDeg(lngOffset)));
    }
    return pts;
  }

  double _toRad(double d) => d * pi / 180.0;
  double _toDeg(double r) => r * 180.0 / pi;

  List<String> _recentWeekBuckets(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final set = <String>{};
    DateTime t = start;
    while (!t.isAfter(now)) {
      set.add(_weekBucket(t));
      t = t.add(const Duration(days: 7));
    }
    final list = set.toList()..sort();
    return list.take(6).toList(); // 최대 6개 (whereIn 제한 고려)
  }
}

// === Isolate용 dedup 입력/함수 ===
class _DedupInput {
  _DedupInput({required this.points, required this.meters, required this.bounds});
  final List<LatLng> points;
  final double meters;
  final LatLngBounds bounds;
}

Future<List<LatLng>> _dedupGrid(_DedupInput input) async {
  const mPerDegLat = 111320.0;
  final centerLat = (input.bounds.southwest.latitude + input.bounds.northeast.latitude) / 2.0;
  final mPerDegLng = (mPerDegLat * cos(centerLat * pi / 180.0)).abs().clamp(1.0, mPerDegLat);
  final dLat = input.meters / mPerDegLat;
  final dLng = input.meters / mPerDegLng;
  
  final seen = <String, LatLng>{};
  for (final p in input.points) {
    final ky = '${(p.latitude / dLat).floor()}:${(p.longitude / dLng).floor()}';
    seen.putIfAbsent(ky, () => p);
  }
  return seen.values.toList(growable: false);
}

class MapScreen extends StatefulWidget {
  MapScreen({super.key});
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
  // 최적화된 Fog of War 시스템
  FogOfWarController? _fogController;
  final Set<Polygon> _fogOfWarPolygons = {};
  LatLng? _lastTrackedPosition;
  Timer? _movementTracker;
  static const double _movementThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _loadCustomMarker();
    _setInitialLocation();
    _loadMarkersFromFirestore();
    _loadPostsFromFirestore();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    // 실시간 리스너 정리
    _markersListener?.cancel();
    // 이동 추적 타이머 정리
    _movementTracker?.cancel();
    super.dispose();
  }

  // 사용자 이동 추적 시작 (최적화된 버전)
  void _startMovementTracking() {
    _movementTracker?.cancel();
    _movementTracker = Timer.periodic(const Duration(seconds: 10), (timer) async {
      await _trackUserMovement();
    });
  }

  // 사용자 이동 감지 및 방문 위치 저장
  Future<void> _trackUserMovement() async {
    try {
      final currentPos = await LocationService.getCurrentPosition();
      if (currentPos == null) return;

      final current = LatLng(currentPos.latitude, currentPos.longitude);
      
      // 현재 위치 업데이트
      if (mounted) {
        setState(() {
          _currentPosition = current;
        });
      }

      // 이동 거리 체크 (50m 이상 이동 시에만 저장)
      if (_lastTrackedPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastTrackedPosition!.latitude,
          _lastTrackedPosition!.longitude,
          current.latitude,
          current.longitude,
        );
        
        if (distance < _movementThreshold) return; // 거리 부족
      }

      // 방문 위치 저장 (지오해시 + 주차버킷 포함)
      await _saveVisitedLocation(current);
      _lastTrackedPosition = current;

      // Fog of War 업데이트 (새로운 최적화된 컨트롤러 사용)
      if (_fogController != null) {
        _fogController!.onCameraIdle(current: current);
        setState(() {
          _fogOfWarPolygons
            ..clear()
            ..addAll(_fogController!.polygons);
        });
      }

      debugPrint('🚶 사용자 이동 추적: ${current.latitude}, ${current.longitude}');
    } catch (e) {
      debugPrint('❌ 사용자 이동 추적 오류: $e');
    }
  }

  // 최적화된 방문 저장 (지오해시 + 주차버킷 포함)
  Future<void> _saveVisitedLocation(LatLng position) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final now = DateTime.now();
      final geohash = geohashEncode(position.latitude, position.longitude, precision: 7);
      final weekBucket = _weekBucket(now);

      await FirebaseFirestore.instance
          .collection('visits')
          .doc(uid)
          .collection('points')
          .add({
        'ts': Timestamp.fromDate(now),
        'tsW': weekBucket,                    // 주차 버킷 (쿼리 최적화용)
        'position': GeoPoint(position.latitude, position.longitude),
        'geohash': geohash,                   // 지오해시 (범위 쿼리용)
      });

      debugPrint('✅ 방문 위치 저장: ${position.latitude}, ${position.longitude} (geohash: $geohash, week: $weekBucket)');
    } catch (e) {
      debugPrint('❌ 방문 위치 저장 실패: $e');
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // 스타일 로드 실패 시 무시
    }
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(37.495872, 127.025046);
      });
      
      // 현재 위치가 설정되면 즉시 Fog of War 업데이트
      if (_currentPosition != null) {
        _lastTrackedPosition = _currentPosition;
        // 최적화된 Fog of War 업데이트
        if (_fogController != null) {
          _fogController!.onCameraIdle(current: _currentPosition!);
          setState(() {
            _fogOfWarPolygons
              ..clear()
              ..addAll(_fogController!.polygons);
          });
        }
        _startMovementTracking();
      }
    } catch (_) {
      setState(() {
        _currentPosition = const LatLng(37.492894, 127.012469);
      });
      
      // 기본 위치라도 Fog of War 업데이트
      if (_currentPosition != null) {
        _lastTrackedPosition = _currentPosition;
        // 최적화된 Fog of War 업데이트
        if (_fogController != null) {
          _fogController!.onCameraIdle(current: _currentPosition!);
          setState(() {
            _fogOfWarPolygons
              ..clear()
              ..addAll(_fogController!.polygons);
          });
        }
        _startMovementTracking();
      }
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



  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
    
    // 최적화된 Fog of War 컨트롤러 초기화
    _fogController = FogOfWarController(controller);
    
    // 초기 위치가 설정되어 있다면 즉시 Fog of War 업데이트
    if (_currentPosition != null) {
      _fogController!.onCameraIdle(current: _currentPosition!);
    }
  }

  void _updateClustering() {
    // 줌 레벨에 따라 클러스터링 결정
    if (_currentZoom < 12.0) {
      _clusterMarkers();
    } else {
      _showIndividualMarkers();
    }
    
    // 디버그 정보 출력
    debugPrint('클러스터링 업데이트: 줌=${_currentZoom}, 클러스터링=${_isClustered}, 마커 수=${_clusteredMarkers.length}');
    debugPrint('마커 아이템 수: ${_markerItems.length}, 포스트 수: ${_posts.length}');
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
                  _collectPostAsCreator(flyer);
                },
                child: const Text('회수'),
              ),
            // 조건에 맞는 사용자는 수령 가능
            if (userId != null && userId != flyer.creatorId && flyer.canRequestReward)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectUserPost(flyer);
                },
                child: const Text('수령'),
              ),
          ],
        );
      },
    );
  }

  // 발행자가 포스트 회수
  Future<void> _collectPostAsCreator(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectPostAsCreator(
          postId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('포스트를 회수했습니다!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 회수에 실패했습니다: $e')),
        );
      }
    }
  }

  // 일반 사용자가 포스트 수령
  Future<void> _collectUserPost(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectPost(
          postId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('포스트를 수령했습니다! ${flyer.reward}원 리워드가 지급되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 수령에 실패했습니다: $e')),
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
    // final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = false; // filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = false; // filter?.showMyPostsOnly ?? false;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    const double clusterRadius = 0.01; // 약 1km
    
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
    // final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = false; // filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = false; // filter?.showMyPostsOnly ?? false;
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

  /// 원을 다각형으로 근사하는 헬퍼 함수
  List<LatLng> _circlePath(LatLng center, double radiusMeters, {int segments = 60}) {
    const earthRadius = 6378137.0;
    final lat = center.latitude * (pi / 180.0);
    final lng = center.longitude * (pi / 180.0);
    final dByR = radiusMeters / earthRadius;

    final pts = <LatLng>[];
    for (int i = 0; i < segments; i++) {
      final theta = 2 * pi * i / segments;
      final latOffset = asin(sin(lat) * cos(dByR) + cos(lat) * sin(dByR) * cos(theta));
      final lngOffset = lng + atan2(sin(theta) * sin(dByR) * cos(lat),
                                    cos(dByR) - sin(lat) * sin(latOffset));
      pts.add(LatLng(latOffset * 180.0 / pi, lngOffset * 180.0 / pi));
    }
    return pts;
  }

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
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
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
                    _handlePostCollection(item);
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
                    _handlePostCollection(item); // 모든 마커에서 포스트 수령 가능
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
          title: const Text('클러스터 정보'),
          content: Text('이 지역에 $count개의 마커가 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
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

  // 포스트 수령 처리
  void _handlePostCollection(MarkerItem item) async {
    try {
      debugPrint('🔄 _handlePostCollection 호출: 마커 ID=${item.id}, 제목=${item.title}');
      debugPrint('📊 마커 데이터: ${item.data}');
      
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // 마커 데이터에서 postId 또는 flyerId 가져오기
        String? postId = item.data['postId'] ?? item.data['flyerId'];
        
        if (postId != null) {
          // 기존 포스트가 있는 경우
          debugPrint('📝 기존 포스트 수령: postId=$postId');
          
          try {
            // PostService를 통해 포스트 수령
            await _postService.collectPost(
              postId: postId,
              userId: currentUserId,
            );
            debugPrint('✅ PostService.collectPost 성공');
          } catch (e) {
            debugPrint('⚠️ 기존 포스트 수령 실패, 새 포스트 생성: $e');
            // 기존 포스트가 없으면 새로 생성
            postId = null;
          }
        }
        
        if (postId == null) {
          // 새 포스트 생성
          debugPrint('🆕 새 포스트 생성 중...');
          
          final newPost = {
            'title': item.title,
            'description': item.data['description'] ?? '마커에서 수령한 포스트',
            'reward': int.parse(item.price),
            'creatorId': item.data['userId'] ?? 'unknown',
            'creatorName': item.data['creatorName'] ?? '알 수 없음',
            'location': GeoPoint(item.position.latitude, item.position.longitude),
            'address': item.data['address'] ?? '',
            'targetGender': item.data['targetGender'] ?? 'all',
            'targetAge': item.data['targetAge'] ?? [18, 65],
            'canRespond': item.data['canRespond'] ?? false,
            'canForward': item.data['canForward'] ?? false,
            'canRequestReward': true,
            'canUse': item.data['canUse'] ?? false,
            'isDistributed': false,
            'isCollected': true,
            'collectedBy': currentUserId,
            'collectedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': item.expiryDate ?? Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
          };
          
          final postRef = await FirebaseFirestore.instance.collection('posts').add(newPost);
          postId = postRef.id;
          debugPrint('✅ 새 포스트 생성 완료: $postId');
        }
        
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(item.id).update({
          'isCollected': true,
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
          'postId': postId, // 생성된 포스트 ID 저장
        });
        
        debugPrint('✅ 마커 상태 업데이트 성공');
        
        // 마커 목록에서 제거
        setState(() {
          _markerItems.removeWhere((marker) => marker.id == item.id);
        });
        
        // 클러스터링 업데이트
        _updateClustering();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('포스트를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        debugPrint('🎉 포스트 수령 완료!');
      }
    } catch (e) {
      debugPrint('❌ 포스트 수령 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포스트 수령에 실패했습니다: $e'),
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
      
      _markerItems.add(markerItem);
      debugPrint('마커 로드됨: ${markerItem.title} at ${markerItem.position}, 타입: ${data['type']}');
    }
    
    debugPrint('마커 처리 완료: 총 ${_markerItems.length}개 마커 로드됨');
    
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
        
        // 새로운 flyer 시스템에서 전단지 로드
        final flyers = await _postService.getFlyersNearLocation(
          location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          radiusInKm: 5.0, // 5km 반경 내 전단지 조회
          userGender: userGender,
          userAge: userAge,
          userInterests: userInterests,
          userPurchaseHistory: userPurchaseHistory,
        );
        
        setState(() {
          _posts.clear();
          _posts.addAll(flyers);
        });
        
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

  void goToCurrentLocation() async {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
      
      // 현재 위치 방문 기록 저장
      await _recordCurrentLocationVisit();
    }
  }

  // 중복 함수 제거됨 - 위에 정의된 최적화된 버전 사용

  // 중복 함수 제거됨 - 위에 정의된 최적화된 버전 사용

  // 중복 함수 제거됨 - 위에 정의된 최적화된 버전 사용

  /// 현재 위치 방문 기록 저장 (수동 호출용)
  Future<void> _recordCurrentLocationVisit() async {
    if (_currentPosition != null) {
      await _saveVisitedLocation(_currentPosition!);
      await _loadVisitsAndBuildFog();
      debugPrint('📍 현재 위치 방문 기록 저장 완료');
    }
  }

  @override
  Widget build(BuildContext context) {
    // final filters = Provider.of<MapFilterProvider>(context);
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
          : Stack(
        children: [
          GestureDetector(
            onSecondaryTapDown: (TapDownDetails details) {
              // 크롬에서 오른쪽 클릭 시 포스트 뿌리기 메뉴 표시
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              
              // 지도 좌표로 변환 (대략적인 계산)
              final mapWidth = renderBox.size.width;
              final mapHeight = renderBox.size.height;
              final latRatio = localPosition.dy / mapHeight;
              final lngRatio = localPosition.dx / mapWidth;
              
              final lat = _currentPosition!.latitude + (0.01 * (0.5 - latRatio));
              final lng = _currentPosition!.longitude + (0.01 * (lngRatio - 0.5));
              
              setState(() {
                _longPressedLatLng = LatLng(lat, lng);
              });
            },
            child: Stack(
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
              polygons: _fogOfWarPolygons, // 최적화된 Fog of War 폴리곤
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
                _updateClustering(); // 줌 변경 시 클러스터링 업데이트
              },
              onCameraIdle: () {
                // 카메라 정지 시 Fog of War 업데이트 (디바운스 포함)
                if (_fogController != null && _currentPosition != null) {
                  _fogController!.onCameraIdle(current: _currentPosition!);
                  setState(() {
                    _fogOfWarPolygons
                      ..clear()
                      ..addAll(_fogController!.polygons);
                  });
                }
              },
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
            ),
                // CustomPaint 오버레이 제거 - Google Maps Circle로 대체
              ],
            ),
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
                     selected: false, // filters.showCouponsOnly,
                     onSelected: (_) {
                       // filters.toggleCouponsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   FilterChip(
                     label: const Text('내 포스트'),
                     selected: false, // filters.showMyPostsOnly,
                     onSelected: (_) {
                       // filters.toggleMyPostsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   // if (filters.showCouponsOnly || filters.showMyPostsOnly)
                     // FilterChip(
                       // label: const Text('필터 초기화'),
                       // selected: false,
                       // onSelected: (_) {
                         // filters.resetFilters();
                         // _updateClustering();
                       // },
                     // ),
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

 