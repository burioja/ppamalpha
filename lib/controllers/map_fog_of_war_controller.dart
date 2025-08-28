import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

/// Fog of War를 담당하는 컨트롤러
/// 현재 위치 1km 반경은 밝게, 방문한 지역은 회색 반투명으로, 나머지는 검은색으로 표시
class MapFogOfWarController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Set<Circle> _fogOfWarCircles = {};
  final List<LatLng> _visitedLocations = [];
  LatLng? _currentPosition;
  
  static const double _currentLocationRadiusKm = 1.0; // 현재 위치 반경 1km
  static const double _visitedLocationRadiusKm = 0.5; // 방문 지역 반경 500m
  static const int _visitHistoryDays = 30; // 한달
  
  // Getters
  Set<Circle> get fogOfWarCircles => Set.unmodifiable(_fogOfWarCircles);
  List<LatLng> get visitedLocations => List.unmodifiable(_visitedLocations);
  LatLng? get currentPosition => _currentPosition;
  
  /// 현재 위치 업데이트
  void updateCurrentPosition(LatLng position) {
    _currentPosition = position;
    _updateFogOfWar();
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
      
      _visitedLocations.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        if (lat != null && lng != null) {
          _visitedLocations.add(LatLng(lat, lng));
        }
      }
      
      _updateFogOfWar();
      
    } catch (e) {
      debugPrint('Fog of War 로드 오류: $e');
    }
  }
  
  /// Fog of War 서클들을 업데이트
  void _updateFogOfWar() {
    _fogOfWarCircles.clear();
    
    // 1. 현재 위치 기반 밝은 영역 (투명)
    if (_currentPosition != null) {
      _fogOfWarCircles.add(
        Circle(
          circleId: const CircleId('current_location'),
          center: _currentPosition!,
          radius: _currentLocationRadiusKm * 1000, // km to meters
          fillColor: Colors.transparent,
          strokeColor: Colors.blue.withOpacity(0.3),
          strokeWidth: 2,
        ),
      );
    }
    
    // 2. 방문한 위치들 - 회색 반투명 (도로와 건물이 보이도록)
    for (int i = 0; i < _visitedLocations.length; i++) {
      final location = _visitedLocations[i];
      
      // 현재 위치와 겹치지 않는 방문 위치만 추가
      if (_currentPosition == null || 
          _calculateDistance(_currentPosition!, location) > _currentLocationRadiusKm) {
        
        _fogOfWarCircles.add(
          Circle(
            circleId: CircleId('visited_$i'),
            center: location,
            radius: _visitedLocationRadiusKm * 1000, // km to meters
            fillColor: Colors.grey.withOpacity(0.4), // 회색 반투명
            strokeColor: Colors.grey.withOpacity(0.6),
            strokeWidth: 1,
          ),
        );
      }
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
      
      // 로컬 리스트에도 추가
      _visitedLocations.add(location);
      _updateFogOfWar();
      
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
    _fogOfWarCircles.clear();
    _visitedLocations.clear();
    _currentPosition = null;
  }
  
  /// 메모리 정리
  void dispose() {
    reset();
  }
}
