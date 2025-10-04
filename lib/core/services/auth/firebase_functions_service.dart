import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map/fog_level.dart';

/// Firebase Functions 서비스
class FirebaseFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// 타일 포그 레벨 배치 조회
  Future<Map<String, FogLevel>> getBatchFogLevels(List<String> tileKeys) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return {};
      }
      
      final callable = _functions.httpsCallable('getBatchFogLevels');
      final result = await callable.call({
        'tileKeys': tileKeys,
        'userId': user.uid,
      });
      
      final data = result.data as Map<String, dynamic>;
      final fogLevels = <String, FogLevel>{};
      
      for (final entry in data.entries) {
        final level = entry.value as int;
        fogLevels[entry.key] = FogLevel.fromLevel(level);
      }
      
      debugPrint('✅ 배치 포그 레벨 조회: ${fogLevels.length}개 타일');
      return fogLevels;
      
    } catch (e) {
      debugPrint('❌ 배치 포그 레벨 조회 오류: $e');
      return {};
    }
  }
  
  /// 사용자 방문 기록 배치 저장
  Future<bool> saveBatchVisits(List<Map<String, dynamic>> visits) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return false;
      }
      
      final callable = _functions.httpsCallable('saveBatchVisits');
      final result = await callable.call({
        'visits': visits,
        'userId': user.uid,
      });
      
      final success = result.data['success'] as bool;
      if (success) {
        debugPrint('✅ 배치 방문 기록 저장: ${visits.length}개');
      } else {
        debugPrint('❌ 배치 방문 기록 저장 실패');
      }
      
      return success;
      
    } catch (e) {
      debugPrint('❌ 배치 방문 기록 저장 오류: $e');
      return false;
    }
  }
  
  /// 타일 통계 정보 조회
  Future<Map<String, dynamic>> getTileStats(String tileKey) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return {};
      }
      
      final callable = _functions.httpsCallable('getTileStats');
      final result = await callable.call({
        'tileKey': tileKey,
        'userId': user.uid,
      });
      
      final data = result.data as Map<String, dynamic>;
      debugPrint('✅ 타일 통계 조회: $tileKey');
      return data;
      
    } catch (e) {
      debugPrint('❌ 타일 통계 조회 오류: $e');
      return {};
    }
  }
  
  /// 사용자 포그 레벨 분포 조회
  Future<Map<String, int>> getUserFogDistribution() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return {};
      }
      
      final callable = _functions.httpsCallable('getUserFogDistribution');
      final result = await callable.call({
        'userId': user.uid,
      });
      
      final data = result.data as Map<String, dynamic>;
      final distribution = <String, int>{};
      
      for (final entry in data.entries) {
        distribution[entry.key] = entry.value as int;
      }
      
      debugPrint('✅ 사용자 포그 분포 조회: $distribution');
      return distribution;
      
    } catch (e) {
      debugPrint('❌ 사용자 포그 분포 조회 오류: $e');
      return {};
    }
  }
  
  /// 타일 접근 로그 기록
  Future<void> logTileAccess(String tileKey, FogLevel level, int zoom) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final callable = _functions.httpsCallable('logTileAccess');
      await callable.call({
        'tileKey': tileKey,
        'level': level.level,
        'zoom': zoom,
        'userId': user.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      debugPrint('❌ 타일 접근 로그 오류: $e');
    }
  }
  
  /// 사용자 활동 분석
  Future<Map<String, dynamic>> analyzeUserActivity() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return {};
      }
      
      final callable = _functions.httpsCallable('analyzeUserActivity');
      final result = await callable.call({
        'userId': user.uid,
      });
      
      final data = result.data as Map<String, dynamic>;
      debugPrint('✅ 사용자 활동 분석 완료');
      return data;
      
    } catch (e) {
      debugPrint('❌ 사용자 활동 분석 오류: $e');
      return {};
    }
  }
  
  /// 시스템 성능 메트릭 전송
  Future<void> sendPerformanceMetrics(Map<String, dynamic> metrics) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final callable = _functions.httpsCallable('sendPerformanceMetrics');
      await callable.call({
        'metrics': metrics,
        'userId': user.uid,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      debugPrint('✅ 성능 메트릭 전송 완료');
      
    } catch (e) {
      debugPrint('❌ 성능 메트릭 전송 오류: $e');
    }
  }
  
  /// 배치 타일 업데이트
  Future<bool> updateBatchTiles(List<Map<String, dynamic>> tileUpdates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return false;
      }
      
      final callable = _functions.httpsCallable('updateBatchTiles');
      final result = await callable.call({
        'tileUpdates': tileUpdates,
        'userId': user.uid,
      });
      
      final success = result.data['success'] as bool;
      if (success) {
        debugPrint('✅ 배치 타일 업데이트: ${tileUpdates.length}개');
      } else {
        debugPrint('❌ 배치 타일 업데이트 실패');
      }
      
      return success;
      
    } catch (e) {
      debugPrint('❌ 배치 타일 업데이트 오류: $e');
      return false;
    }
  }
  
  /// 사용자 위치 기반 타일 추천
  Future<List<String>> getRecommendedTiles(LatLng position, int zoom) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ 사용자 인증 필요');
        return [];
      }
      
      final callable = _functions.httpsCallable('getRecommendedTiles');
      final result = await callable.call({
        'position': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'zoom': zoom,
        'userId': user.uid,
      });
      
      final data = result.data as List<dynamic>;
      final tileKeys = data.cast<String>();
      
      debugPrint('✅ 추천 타일 조회: ${tileKeys.length}개');
      return tileKeys;
      
    } catch (e) {
      debugPrint('❌ 추천 타일 조회 오류: $e');
      return [];
    }
  }
}
