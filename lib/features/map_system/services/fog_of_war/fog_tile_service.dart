import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/models/map/fog_level.dart';

/// 통합 Fog of War 타일 서비스
/// - 기존 fog_of_war_tile_provider.dart + fog_tile_provider.dart + osm_fog_service.dart 통합
class FogTileService extends TileProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 캐시 관리
  final Map<String, FogLevel> _tileCache = {};
  final Map<String, DateTime> _cacheTimestamp = {};
  final Duration _cacheExpiry = const Duration(minutes: 10);

  // 방문 기록 캐시
  final Map<String, DateTime> _visitedTiles = {};
  final Duration _visitRetention = const Duration(days: 30);

  // 현재 상태
  LatLng? _currentPosition;
  int _currentZoom = 13;

  // 디바운스 타이머
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  // 배치 요청 큐
  final List<String> _pendingTileRequests = [];
  Timer? _batchTimer;

  // 전세계 커버용 큰 사각형(경위도)
  static const List<LatLng> _worldCoverRect = [
    LatLng(85, -180),
    LatLng(85, 180),
    LatLng(-85, 180),
    LatLng(-85, -180),
  ];

  FogTileService();

  /// 현재 위치 설정
  void setCurrentPosition(LatLng position) {
    _currentPosition = position;
    _clearCache(); // 위치 변경 시 캐시 초기화
  }

  /// 현재 줌 레벨 설정
  void setCurrentZoom(int zoom) {
    _currentZoom = zoom;
  }

  /// 캐시 클리어
  void clearCache() {
    _tileCache.clear();
    _cacheTimestamp.clear();
  }

  /// 캐시 초기화
  void _clearCache() {
    _tileCache.clear();
    _cacheTimestamp.clear();
  }

  /// 타일의 포그 레벨 계산
  Future<FogLevel> getFogLevelForTile(int z, int x, int y) async {
    final tileKey = '${z}_${x}_${y}';

    // 캐시 확인
    if (_tileCache.containsKey(tileKey)) {
      final timestamp = _cacheTimestamp[tileKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _tileCache[tileKey]!;
      }
    }

    // 타일 중심점 계산
    final tileCenter = _tileToLatLng(z, x, y);

    // 현재 위치와의 거리 확인
    if (_currentPosition != null) {
      final distance = _calculateDistance(_currentPosition!, tileCenter);

      // 1km 이내면 Clear (완전 노출)
      if (distance <= 1.0) {
        final fogLevel = FogLevel.clear;
        _updateCache(tileKey, fogLevel);
        return fogLevel;
      }
    }

    // 방문 기록 확인
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final isVisited = await _checkVisitedTile(uid, tileKey);
      if (isVisited) {
        final fogLevel = FogLevel.gray;
        _updateCache(tileKey, fogLevel);
        return fogLevel;
      }
    }

    // 기본값: 미방문 지역 (검정)
    const fogLevel = FogLevel.black;
    _updateCache(tileKey, fogLevel);
    return fogLevel;
  }

  /// 방문한 타일인지 확인
  Future<bool> _checkVisitedTile(String uid, String tileKey) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .doc(tileKey)
          .get();

      if (doc.exists) {
        final timestamp = (doc.data()?['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null) {
          final age = DateTime.now().difference(timestamp);
          return age <= _visitRetention; // 30일 이내
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ 방문 타일 확인 오류: $e');
      return false;
    }
  }

  /// 캐시 업데이트
  void _updateCache(String tileKey, FogLevel fogLevel) {
    _tileCache[tileKey] = fogLevel;
    _cacheTimestamp[tileKey] = DateTime.now();
  }

  /// 1km 원형 홀 생성
  static List<LatLng> makeCircleHole(LatLng center, double radiusMeters, {int sides = 180}) {
    const earth = 6378137.0; // 지구 반지름 (미터)
    final d = radiusMeters / earth;
    final lat = center.latitude * pi / 180;
    final lng = center.longitude * pi / 180;
    final result = <LatLng>[];

    for (int i = 0; i < sides; i++) {
      final brng = 2 * pi * i / sides;
      final lat2 = asin(sin(lat) * cos(d) + cos(lat) * sin(d) * cos(brng));
      final lng2 = lng + atan2(sin(brng) * sin(d) * cos(lat), cos(d) - sin(lat) * sin(lat2));
      result.add(LatLng(lat2 * 180 / pi, lng2 * 180 / pi));
    }
    return result;
  }

  /// Fog of War 폴리곤 생성 (단일 위치)
  static Polygon createFogPolygon(LatLng currentPosition) {
    final circleHole = makeCircleHole(currentPosition, 1000); // 1km

    return Polygon(
      points: _worldCoverRect,
      holePointsList: [circleHole], // 원형 홀
      isFilled: true,
      color: Colors.black.withOpacity(1.0), // 완전 검정
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// Fog of War 폴리곤 생성 (여러 위치)
  static Polygon createFogPolygonWithMultipleHoles(List<LatLng> positions) {
    final circleHoles = positions.map((pos) => makeCircleHole(pos, 1000)).toList();

    return Polygon(
      points: _worldCoverRect,
      holePointsList: circleHoles, // 여러 원형 홀
      isFilled: true,
      color: Colors.black.withOpacity(1.0),
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 그레이 포그 폴리곤 생성 (방문한 지역용)
  static Polygon createGrayFogPolygon(List<LatLng> visitedPositions) {
    final circleHoles = visitedPositions.map((pos) => makeCircleHole(pos, 1000)).toList();

    return Polygon(
      points: _worldCoverRect,
      holePointsList: circleHoles,
      isFilled: true,
      color: Colors.grey.withOpacity(0.3), // 반투명 회색
      borderColor: Colors.transparent,
      borderStrokeWidth: 0,
    );
  }

  /// 타일 좌표를 LatLng로 변환
  LatLng _tileToLatLng(int z, int x, int y) {
    final n = pow(2.0, z);
    final lonDeg = x / n * 360.0 - 180.0;
    final latRad = atan((exp(pi * (1 - 2 * y / n)) - exp(-pi * (1 - 2 * y / n))) / 2);
    final latDeg = latRad * 180.0 / pi;
    return LatLng(latDeg, lonDeg);
  }

  /// 두 점 사이의 거리 계산 (km)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  /// 방문한 위치들 가져오기
  Future<List<LatLng>> getVisitedPositions() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];

      final cutoffDate = DateTime.now().subtract(_visitRetention);

      final query = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        final geoPoint = data['location'] as GeoPoint;
        return LatLng(geoPoint.latitude, geoPoint.longitude);
      }).toList();
    } catch (e) {
      debugPrint('❌ 방문 위치 조회 오류: $e');
      return [];
    }
  }

  /// 배치 요청 처리
  void _processBatchRequests() {
    if (_pendingTileRequests.isNotEmpty) {
      debugPrint('📦 배치 처리: ${_pendingTileRequests.length}개 타일');
      _pendingTileRequests.clear();
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // TileProvider 구현 - 필요시 타일 이미지 생성
    throw UnimplementedError('FogTileService는 직접 타일 이미지를 제공하지 않습니다.');
  }

  /// 리소스 정리
  void dispose() {
    _debounceTimer?.cancel();
    _batchTimer?.cancel();
    _clearCache();
  }
}