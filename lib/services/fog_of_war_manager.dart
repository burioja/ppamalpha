import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 포그 오브 워 매니저 - 위치 추적 및 방문 기록 관리
class FogOfWarManager {
  // 위치 추적
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;
  double _revealRadius = 1.0; // 1km 반경
  
  // 콜백 함수
  VoidCallback? _onTileUpdate;
  
  // 설정값

  static const int _locationUpdateDistance = 10; // 10m 이동 시 업데이트
  static const Duration _visitRetention = Duration(days: 30);

  /// 현재 위치 설정
  void setCurrentLocation(LatLng location) {
    _currentLocation = location;
    debugPrint('📍 FogOfWarManager 위치 설정: ${location.latitude}, ${location.longitude}');
  }

  /// 반경 설정 (km)
  void setRevealRadius(double radius) {
    _revealRadius = radius;
    debugPrint('📍 FogOfWarManager 반경 설정: ${radius}km');
  }

  /// 타일 업데이트 콜백 설정
  void setTileUpdateCallback(VoidCallback callback) {
    _onTileUpdate = callback;
  }

  /// 위치 추적 시작
  void startTracking() {
    debugPrint('🚀 FogOfWarManager 위치 추적 시작');
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _locationUpdateDistance,
      ),
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        debugPrint('❌ 위치 추적 오류: $error');
      },
    );
  }

  /// 위치 업데이트 처리
  void _onLocationUpdate(Position position) {
    final newLocation = LatLng(position.latitude, position.longitude);
    
    // 위치가 변경되었는지 확인
    if (_currentLocation != null) {
      final distance = _calculateDistance(_currentLocation!, newLocation);
      if (distance < _locationUpdateDistance / 1000.0) { // km 단위로 변환
        return; // 거의 이동하지 않았으면 무시
      }
    }

    _currentLocation = newLocation;
    debugPrint('📍 위치 업데이트: ${newLocation.latitude}, ${newLocation.longitude}');
    
    // 방문 기록 업데이트
    _recordVisit(newLocation);
    
    // 타일 업데이트 콜백 호출
    _onTileUpdate?.call();
  }

  /// 방문 기록 저장
  Future<void> _recordVisit(LatLng location) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // 현재 줌 레벨에서 주변 타일들 계산 (기본 줌 13)
      final tiles = _getTilesInRadius(location, _revealRadius, 13);
      
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      for (final tile in tiles) {
        final tileKey = '${tile.z}_${tile.x}_${tile.y}';
        
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('visited_tiles')
            .doc(tileKey);
        
        batch.set(docRef, {
          'timestamp': Timestamp.fromDate(now),
          'z': tile.z,
          'x': tile.x,
          'y': tile.y,
          'location': GeoPoint(location.latitude, location.longitude),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('✅ 방문 기록 저장 완료: ${tiles.length}개 타일');
    } catch (e) {
      debugPrint('❌ 방문 기록 저장 오류: $e');
    }
  }

  /// 반경 내의 타일들 계산
  List<TileCoordinate> _getTilesInRadius(LatLng center, double radiusKm, int zoom) {
    final tiles = <TileCoordinate>[];
    
    // 반경을 도 단위로 변환 (대략적)
    final radiusDeg = radiusKm / 111.0; // 1도 ≈ 111km
    
    // 타일 크기 계산
    final tileSize = 360.0 / pow(2, zoom);
    
    // 중심 타일
    final centerTile = _latLngToTile(center, zoom);
    
    // 반경 내 타일들 계산
    final tileRadius = (radiusDeg / tileSize).ceil();
    
    for (int dx = -tileRadius; dx <= tileRadius; dx++) {
      for (int dy = -tileRadius; dy <= tileRadius; dy++) {
        final tileX = centerTile.x + dx;
        final tileY = centerTile.y + dy;
        
        // 타일 중심점 계산
        final tileCenter = _tileToLatLng(zoom, tileX, tileY);
        
        // 거리 확인
        if (_calculateDistance(center, tileCenter) <= radiusKm) {
          tiles.add(TileCoordinate(zoom, tileX, tileY));
        }
      }
    }
    
    return tiles;
  }

  /// LatLng를 타일 좌표로 변환
  TileCoordinate _latLngToTile(LatLng point, int zoom) {
    final n = pow(2.0, zoom);
    final x = ((point.longitude + 180.0) / 360.0 * n).floor();
    final latRad = point.latitude * pi / 180.0;
    final y = ((1.0 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2.0 * n).floor();
    return TileCoordinate(zoom, x, y);
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

  /// 오래된 방문 기록 정리
  Future<void> cleanupOldVisits() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final cutoffDate = DateTime.now().subtract(_visitRetention);
      
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      if (query.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in query.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        debugPrint('✅ 오래된 방문 기록 정리 완료: ${query.docs.length}개');
      }
    } catch (e) {
      debugPrint('❌ 방문 기록 정리 오류: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _positionStream?.cancel();
    _positionStream = null;
    _onTileUpdate = null;
  }
}

/// 타일 좌표 클래스
class TileCoordinate {
  final int z;
  final int x;
  final int y;

  TileCoordinate(this.z, this.x, this.y);

  @override
  String toString() => 'Tile($z, $x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TileCoordinate &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => z.hashCode ^ x.hashCode ^ y.hashCode;
}