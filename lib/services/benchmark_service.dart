import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../utils/tile_utils.dart';
import '../models/fog_level.dart';
import 'performance_monitor.dart';
import 'tile_cache_manager.dart';
import 'firebase_functions_service.dart';

/// 성능 벤치마크 서비스
class BenchmarkService {
  static final BenchmarkService _instance = BenchmarkService._internal();
  factory BenchmarkService() => _instance;
  BenchmarkService._internal();
  
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final TileCacheManager _cacheManager = TileCacheManager();
  final FirebaseFunctionsService _functionsService = FirebaseFunctionsService();
  
  // 벤치마크 결과 저장
  final Map<String, List<Duration>> _benchmarkResults = {};
  final Map<String, dynamic> _systemMetrics = {};
  
  /// 종합 벤치마크 실행
  Future<Map<String, dynamic>> runComprehensiveBenchmark() async {
    debugPrint('🏁 종합 벤치마크 시작');
    
    final results = <String, dynamic>{};
    
    // 1. 타일 로드 성능 벤치마크
    results['tile_load_performance'] = await _benchmarkTileLoadPerformance();
    
    // 2. 캐시 성능 벤치마크
    results['cache_performance'] = await _benchmarkCachePerformance();
    
    // 3. 포그 레벨 계산 성능 벤치마크
    results['fog_level_calculation'] = await _benchmarkFogLevelCalculation();
    
    // 4. Firebase Functions 성능 벤치마크
    results['firebase_functions'] = await _benchmarkFirebaseFunctions();
    
    // 5. 메모리 사용량 벤치마크
    results['memory_usage'] = await _benchmarkMemoryUsage();
    
    // 6. 배터리 효율성 벤치마크
    results['battery_efficiency'] = await _benchmarkBatteryEfficiency();
    
    // 7. 네트워크 성능 벤치마크
    results['network_performance'] = await _benchmarkNetworkPerformance();
    
    // 종합 점수 계산
    results['overall_score'] = _calculateOverallScore(results);
    
    debugPrint('✅ 종합 벤치마크 완료: ${results['overall_score']}점');
    
    return results;
  }
  
  /// 타일 로드 성능 벤치마크
  Future<Map<String, dynamic>> _benchmarkTileLoadPerformance() async {
    debugPrint('📊 타일 로드 성능 벤치마크 시작');
    
    final testPositions = _generateTestPositions(100);
    final loadTimes = <Duration>[];
    
    for (final position in testPositions) {
      for (int zoom in [10, 12, 14, 16]) {
        final startTime = DateTime.now();
        
        // 타일 로드 시뮬레이션
        final tile = TileUtils.latLngToTile(position, zoom);
        final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
        
        // 캐시에서 확인
        final cachedFile = await _cacheManager.getCachedTile(tileKey);
        
        final loadTime = DateTime.now().difference(startTime);
        loadTimes.add(loadTime);
      }
    }
    
    return _calculatePerformanceMetrics(loadTimes, '타일 로드');
  }
  
  /// 캐시 성능 벤치마크
  Future<Map<String, dynamic>> _benchmarkCachePerformance() async {
    debugPrint('💾 캐시 성능 벤치마크 시작');
    
    final testTiles = _generateTestTiles(1000);
    final hitTimes = <Duration>[];
    final missTimes = <Duration>[];
    int hitCount = 0;
    int missCount = 0;
    
    // 캐시 미스 시나리오 (첫 번째 실행)
    for (final tileKey in testTiles) {
      final startTime = DateTime.now();
      final cachedFile = await _cacheManager.getCachedTile(tileKey);
      final loadTime = DateTime.now().difference(startTime);
      
      if (cachedFile == null) {
        missTimes.add(loadTime);
        missCount++;
        
        // 캐시에 저장
        await _cacheManager.cacheFogTile(tileKey, FogLevel.clear);
      }
    }
    
    // 캐시 히트 시나리오 (두 번째 실행)
    for (final tileKey in testTiles) {
      final startTime = DateTime.now();
      final cachedFile = await _cacheManager.getCachedTile(tileKey);
      final loadTime = DateTime.now().difference(startTime);
      
      if (cachedFile != null) {
        hitTimes.add(loadTime);
        hitCount++;
      }
    }
    
    final hitRate = testTiles.length > 0 ? (hitCount / testTiles.length * 100) : 0;
    
    return {
      'cache_hit_rate_percent': hitRate.toStringAsFixed(2),
      'cache_hit_avg_time_ms': _calculateAverageTime(hitTimes).toStringAsFixed(2),
      'cache_miss_avg_time_ms': _calculateAverageTime(missTimes).toStringAsFixed(2),
      'total_tiles_tested': testTiles.length,
      'hit_count': hitCount,
      'miss_count': missCount,
    };
  }
  
  /// 포그 레벨 계산 성능 벤치마크
  Future<Map<String, dynamic>> _benchmarkFogLevelCalculation() async {
    debugPrint('🌫️ 포그 레벨 계산 성능 벤치마크 시작');
    
    final testPositions = _generateTestPositions(500);
    final calculationTimes = <Duration>[];
    
    for (final position in testPositions) {
      for (int zoom in [10, 12, 14, 16]) {
        final startTime = DateTime.now();
        
        // 포그 레벨 계산 시뮬레이션
        final tile = TileUtils.latLngToTile(position, zoom);
        final fogLevel = _calculateFogLevel(tile, position, zoom);
        
        final calculationTime = DateTime.now().difference(startTime);
        calculationTimes.add(calculationTime);
      }
    }
    
    return _calculatePerformanceMetrics(calculationTimes, '포그 레벨 계산');
  }
  
  /// Firebase Functions 성능 벤치마크
  Future<Map<String, dynamic>> _benchmarkFirebaseFunctions() async {
    debugPrint('☁️ Firebase Functions 성능 벤치마크 시작');
    
    final testTileKeys = _generateTestTiles(100);
    final functionTimes = <Duration>[];
    int successCount = 0;
    int failureCount = 0;
    
    for (final tileKey in testTileKeys) {
      final startTime = DateTime.now();
      
      try {
        // Firebase Functions 호출 시뮬레이션
        final fogLevels = await _functionsService.getBatchFogLevels([tileKey]);
        
        final functionTime = DateTime.now().difference(startTime);
        functionTimes.add(functionTime);
        successCount++;
        
      } catch (e) {
        failureCount++;
        debugPrint('❌ Firebase Functions 호출 실패: $e');
      }
    }
    
    final successRate = testTileKeys.length > 0 ? (successCount / testTileKeys.length * 100) : 0;
    
    return {
      'success_rate_percent': successRate.toStringAsFixed(2),
      'avg_response_time_ms': _calculateAverageTime(functionTimes).toStringAsFixed(2),
      'total_requests': testTileKeys.length,
      'success_count': successCount,
      'failure_count': failureCount,
    };
  }
  
  /// 메모리 사용량 벤치마크
  Future<Map<String, dynamic>> _benchmarkMemoryUsage() async {
    debugPrint('🧠 메모리 사용량 벤치마크 시작');
    
    final memorySnapshots = <int>[];
    
    // 초기 메모리 사용량
    memorySnapshots.add(_getCurrentMemoryUsage());
    
    // 타일 로드 후 메모리 사용량
    for (int i = 0; i < 100; i++) {
      final tileKey = 'test_tile_$i';
      await _cacheManager.cacheFogTile(tileKey, FogLevel.clear);
      
      if (i % 10 == 0) {
        memorySnapshots.add(_getCurrentMemoryUsage());
      }
    }
    
    final initialMemory = memorySnapshots.first;
    final finalMemory = memorySnapshots.last;
    final memoryIncrease = finalMemory - initialMemory;
    
    return {
      'initial_memory_mb': (initialMemory / (1024 * 1024)).toStringAsFixed(2),
      'final_memory_mb': (finalMemory / (1024 * 1024)).toStringAsFixed(2),
      'memory_increase_mb': (memoryIncrease / (1024 * 1024)).toStringAsFixed(2),
      'memory_efficiency': memoryIncrease < 50 * 1024 * 1024 ? 'Excellent' : 
                          memoryIncrease < 100 * 1024 * 1024 ? 'Good' : 'Poor',
    };
  }
  
  /// 배터리 효율성 벤치마크
  Future<Map<String, dynamic>> _benchmarkBatteryEfficiency() async {
    debugPrint('🔋 배터리 효율성 벤치마크 시작');
    
    final startTime = DateTime.now();
    final startBattery = _getCurrentBatteryLevel();
    
    // 배터리 집약적인 작업 수행
    for (int i = 0; i < 1000; i++) {
      final position = _generateRandomPosition();
      final tile = TileUtils.latLngToTile(position, 14);
      _calculateFogLevel(tile, position, 14);
    }
    
    final endTime = DateTime.now();
    final endBattery = _getCurrentBatteryLevel();
    
    final duration = endTime.difference(startTime);
    final batteryConsumption = startBattery - endBattery;
    
    return {
      'test_duration_seconds': duration.inSeconds,
      'battery_consumption_percent': batteryConsumption.toStringAsFixed(2),
      'battery_efficiency': batteryConsumption < 1 ? 'Excellent' : 
                           batteryConsumption < 3 ? 'Good' : 'Poor',
    };
  }
  
  /// 네트워크 성능 벤치마크
  Future<Map<String, dynamic>> _benchmarkNetworkPerformance() async {
    debugPrint('🌐 네트워크 성능 벤치마크 시작');
    
    final testTileKeys = _generateTestTiles(50);
    final networkTimes = <Duration>[];
    int successCount = 0;
    
    for (final tileKey in testTileKeys) {
      final startTime = DateTime.now();
      
      try {
        // 네트워크 요청 시뮬레이션
        await _simulateNetworkRequest(tileKey);
        
        final networkTime = DateTime.now().difference(startTime);
        networkTimes.add(networkTime);
        successCount++;
        
      } catch (e) {
        debugPrint('❌ 네트워크 요청 실패: $e');
      }
    }
    
    final successRate = testTileKeys.length > 0 ? (successCount / testTileKeys.length * 100) : 0;
    
    return {
      'success_rate_percent': successRate.toStringAsFixed(2),
      'avg_response_time_ms': _calculateAverageTime(networkTimes).toStringAsFixed(2),
      'total_requests': testTileKeys.length,
      'success_count': successCount,
    };
  }
  
  /// 성능 메트릭 계산
  Map<String, dynamic> _calculatePerformanceMetrics(List<Duration> times, String testName) {
    if (times.isEmpty) {
      return {'error': 'No data available for $testName'};
    }
    
    final avgTime = _calculateAverageTime(times);
    final minTime = times.map((d) => d.inMicroseconds).reduce((a, b) => a < b ? a : b) / 1000;
    final maxTime = times.map((d) => d.inMicroseconds).reduce((a, b) => a > b ? a : b) / 1000;
    
    return {
      'test_name': testName,
      'avg_time_ms': avgTime.toStringAsFixed(2),
      'min_time_ms': minTime.toStringAsFixed(2),
      'max_time_ms': maxTime.toStringAsFixed(2),
      'total_operations': times.length,
      'performance_rating': _getPerformanceRating(avgTime),
    };
  }
  
  /// 평균 시간 계산
  double _calculateAverageTime(List<Duration> times) {
    if (times.isEmpty) return 0.0;
    
    final totalMicroseconds = times.fold(0, (sum, duration) => sum + duration.inMicroseconds);
    return totalMicroseconds / times.length / 1000; // 밀리초로 변환
  }
  
  /// 성능 등급 계산
  String _getPerformanceRating(double avgTimeMs) {
    if (avgTimeMs < 10) return 'Excellent';
    if (avgTimeMs < 50) return 'Good';
    if (avgTimeMs < 100) return 'Fair';
    return 'Poor';
  }
  
  /// 종합 점수 계산
  double _calculateOverallScore(Map<String, dynamic> results) {
    double totalScore = 0;
    int categoryCount = 0;
    
    // 각 카테고리별 점수 계산
    for (final category in results.keys) {
      if (category == 'overall_score') continue;
      
      final categoryData = results[category] as Map<String, dynamic>;
      final score = _calculateCategoryScore(category, categoryData);
      
      if (score > 0) {
        totalScore += score;
        categoryCount++;
      }
    }
    
    return categoryCount > 0 ? totalScore / categoryCount : 0;
  }
  
  /// 카테고리별 점수 계산
  double _calculateCategoryScore(String category, Map<String, dynamic> data) {
    switch (category) {
      case 'tile_load_performance':
        final avgTime = double.tryParse(data['avg_time_ms'] ?? '0') ?? 0;
        return avgTime < 50 ? 100 : avgTime < 100 ? 80 : avgTime < 200 ? 60 : 40;
      
      case 'cache_performance':
        final hitRate = double.tryParse(data['cache_hit_rate_percent'] ?? '0') ?? 0;
        return hitRate > 90 ? 100 : hitRate > 80 ? 80 : hitRate > 70 ? 60 : 40;
      
      case 'fog_level_calculation':
        final avgTime = double.tryParse(data['avg_time_ms'] ?? '0') ?? 0;
        return avgTime < 10 ? 100 : avgTime < 20 ? 80 : avgTime < 50 ? 60 : 40;
      
      case 'firebase_functions':
        final successRate = double.tryParse(data['success_rate_percent'] ?? '0') ?? 0;
        return successRate > 95 ? 100 : successRate > 90 ? 80 : successRate > 80 ? 60 : 40;
      
      case 'memory_usage':
        final efficiency = data['memory_efficiency'] as String? ?? 'Poor';
        return efficiency == 'Excellent' ? 100 : efficiency == 'Good' ? 80 : efficiency == 'Fair' ? 60 : 40;
      
      case 'battery_efficiency':
        final efficiency = data['battery_efficiency'] as String? ?? 'Poor';
        return efficiency == 'Excellent' ? 100 : efficiency == 'Good' ? 80 : efficiency == 'Fair' ? 60 : 40;
      
      case 'network_performance':
        final successRate = double.tryParse(data['success_rate_percent'] ?? '0') ?? 0;
        return successRate > 95 ? 100 : successRate > 90 ? 80 : successRate > 80 ? 60 : 40;
      
      default:
        return 0;
    }
  }
  
  /// 테스트 위치 생성
  List<LatLng> _generateTestPositions(int count) {
    final positions = <LatLng>[];
    for (int i = 0; i < count; i++) {
      positions.add(_generateRandomPosition());
    }
    return positions;
  }
  
  /// 테스트 타일 키 생성
  List<String> _generateTestTiles(int count) {
    final tiles = <String>[];
    for (int i = 0; i < count; i++) {
      final zoom = Random().nextInt(5) + 10;
      final x = Random().nextInt(1000);
      final y = Random().nextInt(1000);
      tiles.add(TileUtils.generateTileKey(zoom, x, y));
    }
    return tiles;
  }
  
  /// 랜덤 위치 생성
  LatLng _generateRandomPosition() {
    final lat = 37.5 + (Random().nextDouble() - 0.5) * 1.0;
    final lng = 127.0 + (Random().nextDouble() - 0.5) * 1.0;
    return LatLng(lat, lng);
  }
  
  /// 포그 레벨 계산 (시뮬레이션)
  FogLevel _calculateFogLevel(Coords tile, LatLng position, int zoom) {
    final random = Random().nextDouble();
    if (random < 0.3) return FogLevel.clear;
    if (random < 0.6) return FogLevel.gray;
    return FogLevel.black;
  }
  
  /// 현재 메모리 사용량 조회 (시뮬레이션)
  int _getCurrentMemoryUsage() {
    // 실제 구현에서는 ProcessInfo.currentRss 등을 사용
    return Random().nextInt(100 * 1024 * 1024) + 50 * 1024 * 1024; // 50-150MB
  }
  
  /// 현재 배터리 레벨 조회 (시뮬레이션)
  int _getCurrentBatteryLevel() {
    // 실제 구현에서는 battery_plus 등의 패키지 사용
    return Random().nextInt(20) + 80; // 80-100%
  }
  
  /// 네트워크 요청 시뮬레이션
  Future<void> _simulateNetworkRequest(String tileKey) async {
    // 실제 네트워크 지연 시뮬레이션
    await Future.delayed(Duration(milliseconds: Random().nextInt(100) + 50));
  }
}
