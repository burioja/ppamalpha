import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/tile_utils.dart';

/// Fog of War 매니저
/// 
/// 사용자의 위치 변경을 감지하고 Firestore에 방문 타일 정보를 저장합니다.
class FogOfWarManager {
  static const int _defaultZoom = 15; // 타일 추적용 기본 줌 레벨
  static const double _minMovementDistance = 50.0; // 최소 이동 거리 (미터)
  static const Duration _locationUpdateInterval = Duration(seconds: 30); // 위치 업데이트 간격
  static const double _revealRadiusKm = 0.3; // 원형 탐색 반경 (킬로미터)
  
  StreamSubscription<Position>? _positionStream;
  LatLng? _lastTrackedPosition;
  Timer? _updateTimer;
  double _currentRevealRadius = _revealRadiusKm; // 동적 반경 조정 가능
  
  bool _isTracking = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // 타일 업데이트 콜백 (FogOfWarTileProvider와 연동용)
  Function()? _onTileUpdate;
  
  /// 위치 추적 시작
  Future<void> startTracking() async {
    if (_isTracking) return;
    
    debugPrint('🎯 Fog of War 위치 추적 시작');
    
    try {
      // 위치 권한 확인
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          debugPrint('❌ 위치 권한이 거부됨');
          return;
        }
      }
      
      _isTracking = true;
      
      // 주기적 위치 업데이트 설정
      _updateTimer = Timer.periodic(_locationUpdateInterval, (timer) async {
        await _updateCurrentLocation();
      });
      
      // 즉시 한 번 실행
      await _updateCurrentLocation();
      
    } catch (e) {
      debugPrint('❌ 위치 추적 시작 오류: $e');
    }
  }
  
  /// 위치 추적 중지
  void stopTracking() {
    if (!_isTracking) return;
    
    debugPrint('🛑 Fog of War 위치 추적 중지');
    
    _positionStream?.cancel();
    _updateTimer?.cancel();
    _isTracking = false;
  }
  
  /// 탐색 반경 설정 (킬로미터)
  void setRevealRadius(double radiusKm) {
    _currentRevealRadius = radiusKm;
    debugPrint('🎯 Fog of War 탐색 반경 변경: ${radiusKm}km');
  }
  
  /// 현재 탐색 반경 반환
  double get currentRevealRadius => _currentRevealRadius;
  
  /// 타일 업데이트 콜백 설정
  void setTileUpdateCallback(Function() callback) {
    _onTileUpdate = callback;
  }
  
  /// 현재 위치 설정
  void setCurrentLocation(LatLng location) {
    _lastTrackedPosition = location;
    debugPrint('📍 FogOfWarManager 현재 위치 설정: ${location.latitude}, ${location.longitude}');
  }
  
  /// 타일 업데이트 알림
  void _notifyTileUpdate() {
    _onTileUpdate?.call();
    debugPrint('🔄 타일 캐시 무효화 요청');
  }
  
  /// 현재 위치 업데이트
  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final currentLocation = LatLng(position.latitude, position.longitude);
      
      debugPrint('📍 현재 위치: ${currentLocation.latitude}, ${currentLocation.longitude}');
      
      // 최소 이동 거리 체크
      if (_lastTrackedPosition != null) {
        final distance = TileUtils.calculateDistance(_lastTrackedPosition!, currentLocation) * 1000; // km -> m
        if (distance < _minMovementDistance) {
          debugPrint('⏭️ 최소 이동 거리 미만 ($distance m < $_minMovementDistance m)');
          return;
        }
      }
      
      // 현재 위치의 타일 정보 저장
      await _recordVisitedTiles(currentLocation);
      _lastTrackedPosition = currentLocation;
      
    } catch (e) {
      debugPrint('❌ 위치 업데이트 오류: $e');
    }
  }
  
  /// 방문한 타일들을 Firestore에 기록
  Future<void> _recordVisitedTiles(LatLng location) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      debugPrint('❌ 사용자 인증 없음');
      return;
    }
    
    try {
      // 현재 위치 중심으로 원형 반경 내의 타일들 계산
      final tiles = TileUtils.getTilesAroundLocation(location, _defaultZoom, _currentRevealRadius);
      
      debugPrint('💾 방문 타일 기록: ${tiles.length}개 타일');
      
      final batch = _firestore.batch();
      final now = Timestamp.now();
      
      for (final tile in tiles) {
        final tileRef = _firestore
            .collection('visits_tiles')
            .doc(userId)
            .collection('visited')
            .doc(tile.id);
        
        // 타일 중심점과 현재 위치의 거리 계산
        final tileBounds = TileUtils.getTileBounds(tile.x, tile.y, tile.zoom);
        final distanceToCenter = TileUtils.calculateDistance(location, tileBounds.center);
        
        // 거리에 따른 fog level 결정
        int fogLevel;
        if (distanceToCenter <= 0.1) { // 100m 이내
          fogLevel = 1; // 완전 밝음
        } else if (distanceToCenter <= 0.3) { // 300m 이내
          fogLevel = 2; // 회색
        } else {
          fogLevel = 2; // 회색 (방문한 지역)
        }
        
        batch.set(tileRef, {
          'visitedAt': now,
          'fogLevel': fogLevel,
          'location': GeoPoint(location.latitude, location.longitude),
          'distance': distanceToCenter,
        }, SetOptions(merge: true));
      }
      
      await batch.commit();
      debugPrint('✅ 방문 타일 기록 완료');
      
      // 타일 캐시 무효화 (새로운 방문 정보 반영)
      _notifyTileUpdate();
      
    } catch (e) {
      debugPrint('❌ 방문 타일 기록 오류: $e');
    }
  }
  
  /// 특정 위치를 수동으로 기록 (테스트용)
  Future<void> recordLocationManually(LatLng location, {int fogLevel = 1}) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final tile = TileUtils.latLngToTile(location.latitude, location.longitude, _defaultZoom);
      
      await _firestore
          .collection('visits_tiles')
          .doc(userId)
          .collection('visited')
          .doc(tile.id)
          .set({
        'visitedAt': Timestamp.now(),
        'fogLevel': fogLevel,
        'location': GeoPoint(location.latitude, location.longitude),
        'manual': true,
      }, SetOptions(merge: true));
      
      debugPrint('✅ 수동 위치 기록 완료: ${tile.id}');
      
    } catch (e) {
      debugPrint('❌ 수동 위치 기록 오류: $e');
    }
  }
  
  /// 오래된 방문 기록 정리 (30일 이상)
  Future<void> cleanupOldVisits() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      
      final oldVisits = await _firestore
          .collection('visits_tiles')
          .doc(userId)
          .collection('visited')
          .where('visitedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      if (oldVisits.docs.isEmpty) {
        debugPrint('🗑️ 정리할 오래된 방문 기록 없음');
        return;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in oldVisits.docs) {
        // 완전 삭제하지 않고 fog level만 변경
        batch.update(doc.reference, {'fogLevel': 2}); // 회색으로 변경
      }
      
      await batch.commit();
      debugPrint('✅ 오래된 방문 기록 정리 완료: ${oldVisits.docs.length}개');
      
    } catch (e) {
      debugPrint('❌ 방문 기록 정리 오류: $e');
    }
  }
  
  /// 사용자의 방문 통계 조회
  Future<Map<String, dynamic>> getVisitStats() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return {};
    
    try {
      final visits = await _firestore
          .collection('visits_tiles')
          .doc(userId)
          .collection('visited')
          .get();
      
      int brightTiles = 0;
      int grayTiles = 0;
      int totalTiles = visits.docs.length;
      
      for (final doc in visits.docs) {
        final fogLevel = doc.data()['fogLevel'] as int? ?? 3;
        if (fogLevel == 1) {
          brightTiles++;
        } else if (fogLevel == 2) {
          grayTiles++;
        }
      }
      
      return {
        'totalTiles': totalTiles,
        'brightTiles': brightTiles,
        'grayTiles': grayTiles,
        'explorationPercent': totalTiles > 0 ? (brightTiles + grayTiles) / totalTiles * 100 : 0,
      };
      
    } catch (e) {
      debugPrint('❌ 방문 통계 조회 오류: $e');
      return {};
    }
  }
  
  /// 리소스 정리
  void dispose() {
    stopTracking();
  }
}
