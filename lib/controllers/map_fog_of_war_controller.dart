import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/map_fog_painter.dart';

/// Fog of War를 담당하는 컨트롤러 (마스크 기반)
/// CustomPainter를 사용하여 효율적인 Fog of War 구현
class MapFogOfWarController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 마스크 기반 데이터
  final List<CircleSpec> _recentCircles = [];
  CircleSpec? _hereCircle;
  final List<LatLng> _visitedLocations = [];
  LatLng? _currentPosition;
  
  static const double _currentLocationRadiusKm = 1.0; // 현재 위치 반경 1km
  static const double _visitedLocationRadiusKm = 1.0; // 방문 지역 반경 1km (통일)
  static const int _visitHistoryDays = 30; // 한달
  
  // 성능 최적화 설정
  static const int _maxCirclesOnScreen = 200; // 화면 내 최대 원 개수
  static const double _clusterDistanceMeters = 500.0; // 클러스터링 거리
  
  // Getters
  List<CircleSpec> get recentCircles => List.unmodifiable(_recentCircles);
  CircleSpec? get hereCircle => _hereCircle;
  List<LatLng> get visitedLocations => List.unmodifiable(_visitedLocations);
  LatLng? get currentPosition => _currentPosition;
  
  /// 현재 위치 업데이트
  void updateCurrentPosition(LatLng position) {
    _currentPosition = position;
    _updateHereCircle();
  }
  
  /// 방문 기록을 로드하고 Fog of War 구성
  Future<void> loadVisitsAndBuildFog() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      
      final cutoff = DateTime.now().subtract(Duration(days: _visitHistoryDays));
      final snapshot = await _firestore
          .collection('visits')
          .doc(uid)
          .collection('points')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();
      
      // 원시 위치 데이터 수집
      final rawLocations = <LatLng>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        if (lat != null && lng != null) {
          rawLocations.add(LatLng(lat, lng));
        }
      }
      
      // 클러스터링으로 성능 최적화
      _visitedLocations.clear();
      _visitedLocations.addAll(
        LocationClusterer.clusterLocations(rawLocations, _clusterDistanceMeters)
      );
      
      _updateRecentCircles();
      _updateHereCircle();
      
    } catch (e) {
      debugPrint('Fog of War 로드 오류: $e');
    }
  }
  
  /// 최근 방문 지역 원들 업데이트
  void _updateRecentCircles() {
    _recentCircles.clear();
    
    // 성능 최적화: 원 개수 제한
    final locationsToShow = _visitedLocations.take(_maxCirclesOnScreen).toList();
    
    for (final location in locationsToShow) {
      // 현재 위치와 너무 가까운 곳은 제외 (중복 방지)
      if (_currentPosition != null && 
          _calculateDistance(_currentPosition!, location) < 100) {
        continue;
      }
      
      _recentCircles.add(
        CircleSpec(
          center: location,
          radiusMeters: _visitedLocationRadiusKm * 1000, // km to meters
        ),
      );
    }
  }
  
  /// 현재 위치 원 업데이트
  void _updateHereCircle() {
    if (_currentPosition != null) {
      _hereCircle = CircleSpec(
        center: _currentPosition!,
        radiusMeters: _currentLocationRadiusKm * 1000, // km to meters
        strokeColor: Colors.blue.withOpacity(0.8), // 테두리 강조
        strokeWidth: 3.0,
      );
    } else {
      _hereCircle = null;
    }
  }
  
  /// 새로운 방문 위치 추가
  Future<void> addVisitLocation(LatLng location) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      
      // Firestore에 방문 기록 저장
      await _firestore
          .collection('visits')
          .doc(uid)
          .collection('points')
          .add({
        'lat': location.latitude,
        'lng': location.longitude,
        'ts': FieldValue.serverTimestamp(),
      });
      
      // 로컬 리스트에도 추가하고 클러스터링
      _visitedLocations.add(location);
      _visitedLocations.clear();
      _visitedLocations.addAll(
        LocationClusterer.clusterLocations(_visitedLocations, _clusterDistanceMeters)
      );
      _updateRecentCircles();
      
    } catch (e) {
      debugPrint('방문 위치 저장 오류: $e');
    }
  }
  
  /// 특정 위치가 방문 가능한 영역인지 확인 (현재 위치 또는 방문한 위치 근처)
  bool isLocationVisible(LatLng location) {
    // 현재 위치 1km 반경 내
    if (_currentPosition != null && 
        _calculateDistance(_currentPosition!, location) <= _currentLocationRadiusKm) {
      return true;
    }
    
    // 방문한 위치 500m 반경 내
    for (final visitedLocation in _visitedLocations) {
      if (_calculateDistance(visitedLocation, location) <= _visitedLocationRadiusKm) {
        return true;
      }
    }
    
    return false;
  }
  
  /// 두 지점 간의 거리 계산 (km)
  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    ) / 1000; // meters to km
  }
  
  /// 자동으로 현재 위치 주변 방문 기록 생성 (테스트용)
  Future<void> recordCurrentLocationVisit() async {
    if (_currentPosition != null) {
      await addVisitLocation(_currentPosition!);
    }
  }
  
  /// 방문 기록 정리 (30일 이상 된 기록 삭제)
  Future<void> cleanupOldVisits() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      
      final cutoff = DateTime.now().subtract(Duration(days: _visitHistoryDays));
      final snapshot = await _firestore
          .collection('visits')
          .doc(uid)
          .collection('points')
          .where('ts', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      
      // 배치로 삭제
      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      debugPrint('${snapshot.docs.length}개의 오래된 방문 기록 삭제됨');
      
    } catch (e) {
      debugPrint('방문 기록 정리 오류: $e');
    }
  }
  
  /// 초기화
  void reset() {
    _recentCircles.clear();
    _hereCircle = null;
    _visitedLocations.clear();
    _currentPosition = null;
  }
  
  /// 메모리 정리
  void dispose() {
    reset();
  }
}
