import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// 사용자 방문 기록을 관리하는 서비스
class MapVisitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _visitsCollection = 'visits';
  static const String _pointsSubCollection = 'points';
  static const int _visitHistoryDays = 30;
  static const double _minDistanceForNewVisit = 50.0; // 50m 이내면 중복으로 간주
  
  final Map<String, DateTime> _visitCache = {};
  Timer? _cleanupTimer;
  
  /// 초기화 - 자동 정리 타이머 시작
  void initialize() {
    _startCleanupTimer();
  }
  
  /// 현재 위치 방문 기록 저장
  Future<void> recordCurrentLocationVisit(LatLng location) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      
      // 중복 방문 체크 (50m 이내, 1시간 이내면 저장하지 않음)
      if (await _isDuplicateVisit(location)) {
        return;
      }
      
      // Firestore에 방문 기록 저장
      await _firestore
          .collection(_visitsCollection)
          .doc(uid)
          .collection(_pointsSubCollection)
          .add({
        'lat': location.latitude,
        'lng': location.longitude,
        'ts': FieldValue.serverTimestamp(),
        'accuracy': 10.0, // 기본 정확도
      });
      
      // 캐시 업데이트
      final cacheKey = '${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
      _visitCache[cacheKey] = DateTime.now();
      
      debugPrint('방문 기록 저장: ${location.latitude}, ${location.longitude}');
      
    } catch (e) {
      debugPrint('방문 기록 저장 오류: $e');
    }
  }
  
  /// 특정 기간 동안의 방문 기록 조회
  Future<List<LatLng>> getVisitHistory({int? days}) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return [];
      
      final cutoffDays = days ?? _visitHistoryDays;
      final cutoff = DateTime.now().subtract(Duration(days: cutoffDays));
      
      final snapshot = await _firestore
          .collection(_visitsCollection)
          .doc(uid)
          .collection(_pointsSubCollection)
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .orderBy('ts', descending: true)
          .get();
      
      final visits = <LatLng>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        if (lat != null && lng != null) {
          visits.add(LatLng(lat, lng));
        }
      }
      
      return visits;
      
    } catch (e) {
      debugPrint('방문 기록 조회 오류: $e');
      return [];
    }
  }
  
  /// 특정 위치 근처의 방문 기록 조회
  Future<List<LatLng>> getVisitsNearLocation(
    LatLng center, 
    double radiusKm, {
    int? days,
  }) async {
    try {
      final allVisits = await getVisitHistory(days: days);
      
      return allVisits.where((visit) {
        final distance = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          visit.latitude,
          visit.longitude,
        ) / 1000; // meters to km
        
        return distance <= radiusKm;
      }).toList();
      
    } catch (e) {
      debugPrint('근처 방문 기록 조회 오류: $e');
      return [];
    }
  }
  
  /// 중복 방문 체크
  Future<bool> _isDuplicateVisit(LatLng location) async {
    // 캐시에서 먼저 확인
    final cacheKey = '${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}';
    final cachedTime = _visitCache[cacheKey];
    if (cachedTime != null && 
        DateTime.now().difference(cachedTime).inHours < 1) {
      return true;
    }
    
    // Firestore에서 최근 방문 확인
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;
      
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final snapshot = await _firestore
          .collection(_visitsCollection)
          .doc(uid)
          .collection(_pointsSubCollection)
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourAgo))
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['lat'] as double?;
        final lng = data['lng'] as double?;
        if (lat != null && lng != null) {
          final distance = Geolocator.distanceBetween(
            location.latitude,
            location.longitude,
            lat,
            lng,
          );
          
          if (distance <= _minDistanceForNewVisit) {
            return true; // 중복 방문
          }
        }
      }
      
      return false;
      
    } catch (e) {
      debugPrint('중복 방문 체크 오류: $e');
      return false;
    }
  }
  
  /// 자동으로 현재 위치 추적 시작
  StreamSubscription<Position>? _positionStream;
  
  void startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50, // 50m 이동시마다 업데이트
      ),
    ).listen((position) {
      recordCurrentLocationVisit(
        LatLng(position.latitude, position.longitude),
      );
    });
  }
  
  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }
  
  /// 오래된 방문 기록 정리
  Future<void> cleanupOldVisits() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      
      final cutoff = DateTime.now().subtract(Duration(days: _visitHistoryDays));
      final snapshot = await _firestore
          .collection(_visitsCollection)
          .doc(uid)
          .collection(_pointsSubCollection)
          .where('ts', isLessThan: Timestamp.fromDate(cutoff))
          .limit(500) // 한번에 500개씩 삭제
          .get();
      
      if (snapshot.docs.isEmpty) return;
      
      // 배치로 삭제
      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      debugPrint('${snapshot.docs.length}개의 오래된 방문 기록 삭제됨');
      
      // 더 삭제할 기록이 있으면 재귀 호출
      if (snapshot.docs.length == 500) {
        await cleanupOldVisits();
      }
      
    } catch (e) {
      debugPrint('방문 기록 정리 오류: $e');
    }
  }
  
  /// 자동 정리 타이머 시작 (매일 실행)
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(days: 1), (_) {
      cleanupOldVisits();
    });
  }
  
  /// 방문 통계 조회
  Future<Map<String, dynamic>> getVisitStatistics() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return {};
      
      final snapshot = await _firestore
          .collection(_visitsCollection)
          .doc(uid)
          .collection(_pointsSubCollection)
          .get();
      
      final totalVisits = snapshot.docs.length;
      
      // 최근 30일 방문
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentVisits = snapshot.docs.where((doc) {
        final timestamp = doc.data()['ts'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(thirtyDaysAgo);
      }).length;
      
      // 최근 7일 방문
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final weeklyVisits = snapshot.docs.where((doc) {
        final timestamp = doc.data()['ts'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(sevenDaysAgo);
      }).length;
      
      return {
        'totalVisits': totalVisits,
        'recentVisits30Days': recentVisits,
        'recentVisits7Days': weeklyVisits,
        'averageDailyVisits': recentVisits / 30,
      };
      
    } catch (e) {
      debugPrint('방문 통계 조회 오류: $e');
      return {};
    }
  }
  
  /// 특정 영역의 방문 빈도 계산
  Future<int> getVisitFrequency(LatLng location, double radiusKm) async {
    final visits = await getVisitsNearLocation(location, radiusKm);
    return visits.length;
  }
  
  /// 메모리 정리
  void dispose() {
    _cleanupTimer?.cancel();
    _positionStream?.cancel();
    _visitCache.clear();
  }
}
