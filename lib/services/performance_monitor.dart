import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:latlong2/latlong.dart';
import '../models/fog_level.dart';
import 'firebase_functions_service.dart';

/// 성능 모니터링 시스템
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();
  
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebasePerformance _performance = FirebasePerformance.instance;
  final FirebaseFunctionsService _functionsService = FirebaseFunctionsService();
  
  // 성능 메트릭 저장
  final Map<String, dynamic> _metrics = {};
  final Map<String, DateTime> _startTimes = {};
  final List<Map<String, dynamic>> _pendingMetrics = [];
  
  /// 타일 로드 시간 측정
  void startTileLoadTimer(String tileKey) {
    _startTimes['tile_$tileKey'] = DateTime.now();
  }
  
  /// 타일 로드 완료 기록
  void endTileLoadTimer(String tileKey, FogLevel level, bool cacheHit) {
    final startTime = _startTimes['tile_$tileKey'];
    if (startTime == null) return;
    
    final loadTime = DateTime.now().difference(startTime);
    final loadTimeMs = loadTime.inMilliseconds;
    
    // 로컬 메트릭 저장
    _metrics['tile_load_time_$tileKey'] = {
      'tileKey': tileKey,
      'loadTimeMs': loadTimeMs,
      'level': level.level,
      'cacheHit': cacheHit,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Firebase Analytics 이벤트
    _analytics.logEvent(
      name: 'tile_load_time',
      parameters: {
        'tile_key': tileKey,
        'load_time_ms': loadTimeMs,
        'fog_level': level.level,
        'cache_hit': cacheHit,
      },
    );
    
    // Firebase Performance 추적
    _trackTileLoadPerformance(tileKey, loadTimeMs, level, cacheHit);
    
    _startTimes.remove('tile_$tileKey');
    
    debugPrint('📊 타일 로드 시간: $tileKey - ${loadTimeMs}ms (${cacheHit ? '캐시' : '네트워크'})');
  }
  
  /// 포그 레벨 분포 추적
  void trackFogLevelDistribution(Map<FogLevel, int> distribution) {
    final totalTiles = distribution.values.fold(0, (sum, count) => sum + count);
    
    for (final entry in distribution.entries) {
      final level = entry.key;
      final count = entry.value;
      final percentage = totalTiles > 0 ? (count / totalTiles * 100).toStringAsFixed(1) : '0.0';
      
      _analytics.logEvent(
        name: 'fog_level_distribution',
        parameters: {
          'level': level.level,
          'count': count,
          'percentage': double.parse(percentage),
          'total_tiles': totalTiles,
        },
      );
    }
    
    debugPrint('📊 포그 레벨 분포: Clear=${distribution[FogLevel.clear] ?? 0}, Gray=${distribution[FogLevel.gray] ?? 0}, Black=${distribution[FogLevel.black] ?? 0}');
  }
  
  /// 사용자 위치 업데이트 성능 추적
  void trackLocationUpdate(LatLng position, int zoom, Duration updateTime) {
    _analytics.logEvent(
      name: 'location_update',
      parameters: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'zoom': zoom,
        'update_time_ms': updateTime.inMilliseconds,
      },
    );
    
    debugPrint('📍 위치 업데이트: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} - ${updateTime.inMilliseconds}ms');
  }
  
  /// 캐시 성능 추적
  void trackCachePerformance(int hitCount, int missCount, int totalSize) {
    final hitRate = hitCount + missCount > 0 ? (hitCount / (hitCount + missCount) * 100).toStringAsFixed(1) : '0.0';
    
    _analytics.logEvent(
      name: 'cache_performance',
      parameters: {
        'hit_count': hitCount,
        'miss_count': missCount,
        'hit_rate': double.parse(hitRate),
        'total_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      },
    );
    
    debugPrint('💾 캐시 성능: 히트율 ${hitRate}% (${hitCount}/${hitCount + missCount})');
  }
  
  /// Prefetch 성능 추적
  void trackPrefetchPerformance(int prefetchedTiles, Duration prefetchTime) {
    _analytics.logEvent(
      name: 'prefetch_performance',
      parameters: {
        'prefetched_tiles': prefetchedTiles,
        'prefetch_time_ms': prefetchTime.inMilliseconds,
        'tiles_per_second': prefetchedTiles / (prefetchTime.inMilliseconds / 1000.0),
      },
    );
    
    debugPrint('🚀 Prefetch 성능: ${prefetchedTiles}개 타일 - ${prefetchTime.inMilliseconds}ms');
  }
  
  /// 메모리 사용량 추적
  void trackMemoryUsage(int memoryUsageMB) {
    _analytics.logEvent(
      name: 'memory_usage',
      parameters: {
        'memory_mb': memoryUsageMB,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    debugPrint('🧠 메모리 사용량: ${memoryUsageMB}MB');
  }
  
  /// 배터리 상태 추적
  void trackBatteryStatus(int batteryLevel, bool isLowPowerMode) {
    _analytics.logEvent(
      name: 'battery_status',
      parameters: {
        'battery_level': batteryLevel,
        'low_power_mode': isLowPowerMode,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    debugPrint('🔋 배터리 상태: ${batteryLevel}% (절전모드: ${isLowPowerMode ? 'ON' : 'OFF'})');
  }
  
  /// 네트워크 상태 추적
  void trackNetworkStatus(String connectionType, int latency) {
    _analytics.logEvent(
      name: 'network_status',
      parameters: {
        'connection_type': connectionType,
        'latency_ms': latency,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    debugPrint('🌐 네트워크 상태: $connectionType - ${latency}ms');
  }
  
  /// 사용자 행동 패턴 추적
  void trackUserBehavior(String action, Map<String, dynamic> parameters) {
    _analytics.logEvent(
      name: 'user_behavior',
      parameters: {
        'action': action,
        ...parameters,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    
    debugPrint('👤 사용자 행동: $action');
  }
  
  /// Firebase Performance 추적
  void _trackTileLoadPerformance(String tileKey, int loadTimeMs, FogLevel level, bool cacheHit) {
    try {
      final trace = _performance.newTrace('tile_load_$tileKey');
      trace.start();
      
      // Firebase Performance API가 변경되었으므로 간단한 추적만 수행
      trace.putAttribute('cache_hit', cacheHit.toString());
      trace.putAttribute('tile_key', tileKey);
      trace.putAttribute('fog_level', level.level.toString());
      
      trace.stop();
    } catch (e) {
      debugPrint('❌ Performance 추적 오류: $e');
    }
  }
  
  /// 배치 메트릭 전송
  Future<void> sendBatchMetrics() async {
    if (_pendingMetrics.isEmpty) return;
    
    try {
      await _functionsService.sendPerformanceMetrics({
        'metrics': _pendingMetrics,
        'batch_size': _pendingMetrics.length,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _pendingMetrics.clear();
      debugPrint('✅ 배치 메트릭 전송 완료');
      
    } catch (e) {
      debugPrint('❌ 배치 메트릭 전송 오류: $e');
    }
  }
  
  /// 메트릭을 배치에 추가
  void addToBatch(Map<String, dynamic> metric) {
    _pendingMetrics.add(metric);
    
    // 배치 크기가 50개에 도달하면 전송
    if (_pendingMetrics.length >= 50) {
      sendBatchMetrics();
    }
  }
  
  /// 성능 리포트 생성
  Map<String, dynamic> generatePerformanceReport() {
    return {
      'metrics': _metrics,
      'pending_metrics_count': _pendingMetrics.length,
      'active_timers': _startTimes.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// 메트릭 초기화
  void clearMetrics() {
    _metrics.clear();
    _startTimes.clear();
    _pendingMetrics.clear();
    debugPrint('🗑️ 성능 메트릭 초기화 완료');
  }
  
  /// 주기적 메트릭 전송 시작
  Timer? _metricsTimer;
  void startPeriodicMetricsSending() {
    _metricsTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      sendBatchMetrics();
    });
    debugPrint('⏰ 주기적 메트릭 전송 시작 (5분 간격)');
  }
  
  /// 주기적 메트릭 전송 중지
  void stopPeriodicMetricsSending() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
    debugPrint('⏹️ 주기적 메트릭 전송 중지');
  }
  
  /// 리소스 정리
  void dispose() {
    stopPeriodicMetricsSending();
    clearMetrics();
  }
}
