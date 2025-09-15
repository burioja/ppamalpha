import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../features/map_system/utils/tile_utils.dart';
import '../core/models/map/fog_level.dart';
import 'performance_monitor.dart';
import 'firebase_functions_service.dart';

/// 부하 테스트 서비스
class LoadTestingService {
  static final LoadTestingService _instance = LoadTestingService._internal();
  factory LoadTestingService() => _instance;
  LoadTestingService._internal();
  
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final FirebaseFunctionsService _functionsService = FirebaseFunctionsService();
  
  // 테스트 설정
  static const int _maxConcurrentUsers = 10000; // 최대 동시 사용자
  static const int _testDurationMinutes = 30; // 테스트 지속 시간
  static const int _requestsPerSecond = 1000; // 초당 요청 수
  
  // 테스트 상태
  bool _isRunning = false;
  int _currentUsers = 0;
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  final List<Duration> _responseTimes = [];
  final Map<String, int> _errorCounts = {};
  
  // 테스트 결과
  final Map<String, dynamic> _testResults = {};
  
  /// 부하 테스트 시작
  Future<Map<String, dynamic>> startLoadTest({
    int concurrentUsers = 1000,
    int durationMinutes = 10,
    int requestsPerSecond = 100,
  }) async {
    if (_isRunning) {
      throw Exception('부하 테스트가 이미 실행 중입니다');
    }
    
    _isRunning = true;
    _currentUsers = 0;
    _totalRequests = 0;
    _successfulRequests = 0;
    _failedRequests = 0;
    _responseTimes.clear();
    _errorCounts.clear();
    _testResults.clear();
    
    debugPrint('🚀 부하 테스트 시작: ${concurrentUsers}명 동시 사용자, ${durationMinutes}분');
    
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: durationMinutes));
    
    // 사용자 시뮬레이션 시작
    final userTasks = <Future>[];
    for (int i = 0; i < concurrentUsers; i++) {
      userTasks.add(_simulateUser(i, endTime, requestsPerSecond));
    }
    
    // 모든 사용자 시뮬레이션 완료 대기
    await Future.wait(userTasks);
    
    final testDuration = DateTime.now().difference(startTime);
    final testResults = _generateTestResults(testDuration);
    
    _isRunning = false;
    debugPrint('✅ 부하 테스트 완료: ${testResults['total_requests']}개 요청 처리');
    
    return testResults;
  }
  
  /// 개별 사용자 시뮬레이션
  Future<void> _simulateUser(int userId, DateTime endTime, int requestsPerSecond) async {
    _currentUsers++;
    
    // 사용자별 랜덤 위치 생성
    LatLng userPosition = _generateRandomPosition();
    final userZoom = Random().nextInt(5) + 10; // 줌 레벨 10-14
    
    try {
      while (DateTime.now().isBefore(endTime)) {
        // 요청 간격 계산 (초당 요청 수에 따라)
        final requestInterval = Duration(milliseconds: 1000 ~/ requestsPerSecond);
        await Future.delayed(requestInterval);
        
        // 랜덤 타일 요청
        await _simulateTileRequest(userId, userPosition, userZoom);
        
        // 사용자 위치 업데이트 (랜덤 이동)
        if (Random().nextDouble() < 0.1) { // 10% 확률로 위치 변경
          final newLat = userPosition.latitude + (Random().nextDouble() - 0.5) * 0.01;
          final newLng = userPosition.longitude + (Random().nextDouble() - 0.5) * 0.01;
          userPosition = LatLng(newLat, newLng);
        }
      }
    } catch (e) {
      debugPrint('❌ 사용자 $userId 시뮬레이션 오류: $e');
    } finally {
      _currentUsers--;
    }
  }
  
  /// 타일 요청 시뮬레이션
  Future<void> _simulateTileRequest(int userId, LatLng position, int zoom) async {
    final startTime = DateTime.now();
    
    try {
      // 랜덤 타일 좌표 생성
      final tile = TileUtils.latLngToTile(position, zoom);
      final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
      
      // 포그 레벨 조회 시뮬레이션
      final fogLevel = _determineFogLevel(tile, position, zoom);
      
      // 성공적인 요청 처리
      _totalRequests++;
      _successfulRequests++;
      
      final responseTime = DateTime.now().difference(startTime);
      _responseTimes.add(responseTime);
      
      // 성능 메트릭 기록
      _performanceMonitor.trackUserBehavior('tile_request', {
        'user_id': userId,
        'tile_key': tileKey,
        'fog_level': fogLevel.level,
        'response_time_ms': responseTime.inMilliseconds,
        'zoom': zoom,
      });
      
    } catch (e) {
      _totalRequests++;
      _failedRequests++;
      _errorCounts[e.toString()] = (_errorCounts[e.toString()] ?? 0) + 1;
      
      debugPrint('❌ 타일 요청 실패 (사용자 $userId): $e');
    }
  }
  
  /// 랜덤 위치 생성
  LatLng _generateRandomPosition() {
    // 한국 지역 내 랜덤 위치 생성
    final lat = 37.5 + (Random().nextDouble() - 0.5) * 1.0; // 37.0 ~ 38.0
    final lng = 127.0 + (Random().nextDouble() - 0.5) * 1.0; // 126.5 ~ 127.5
    return LatLng(lat, lng);
  }
  
  /// 포그 레벨 결정 (시뮬레이션)
  FogLevel _determineFogLevel(Coords tile, LatLng position, int zoom) {
    // 실제 구현에서는 사용자 위치와 방문 기록을 고려
    // 여기서는 랜덤하게 포그 레벨 결정
    final random = Random().nextDouble();
    
    if (random < 0.3) {
      return FogLevel.clear;
    } else if (random < 0.6) {
      return FogLevel.gray;
    } else {
      return FogLevel.black;
    }
  }
  
  /// 테스트 결과 생성
  Map<String, dynamic> _generateTestResults(Duration testDuration) {
    final avgResponseTime = _responseTimes.isNotEmpty
        ? _responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / _responseTimes.length
        : 0.0;
    
    final minResponseTime = _responseTimes.isNotEmpty
        ? _responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b)
        : 0;
    
    final maxResponseTime = _responseTimes.isNotEmpty
        ? _responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b)
        : 0;
    
    final successRate = _totalRequests > 0 ? (_successfulRequests / _totalRequests * 100) : 0.0;
    final requestsPerSecond = _totalRequests / testDuration.inSeconds;
    
    return {
      'test_duration_minutes': testDuration.inMinutes,
      'total_requests': _totalRequests,
      'successful_requests': _successfulRequests,
      'failed_requests': _failedRequests,
      'success_rate_percent': successRate.toStringAsFixed(2),
      'requests_per_second': requestsPerSecond.toStringAsFixed(2),
      'avg_response_time_ms': avgResponseTime.toStringAsFixed(2),
      'min_response_time_ms': minResponseTime,
      'max_response_time_ms': maxResponseTime,
      'error_counts': _errorCounts,
      'concurrent_users': _currentUsers,
    };
  }
  
  /// 실시간 테스트 상태 조회
  Map<String, dynamic> getCurrentStatus() {
    return {
      'is_running': _isRunning,
      'current_users': _currentUsers,
      'total_requests': _totalRequests,
      'successful_requests': _successfulRequests,
      'failed_requests': _failedRequests,
      'success_rate_percent': _totalRequests > 0 
          ? (_successfulRequests / _totalRequests * 100).toStringAsFixed(2)
          : '0.00',
    };
  }
  
  /// 테스트 중지
  void stopTest() {
    _isRunning = false;
    debugPrint('⏹️ 부하 테스트 중지됨');
  }
  
  /// 테스트 결과 초기화
  void resetResults() {
    _totalRequests = 0;
    _successfulRequests = 0;
    _failedRequests = 0;
    _responseTimes.clear();
    _errorCounts.clear();
    _testResults.clear();
    debugPrint('🗑️ 테스트 결과 초기화 완료');
  }
  
  /// 스트레스 테스트 (극한 상황 시뮬레이션)
  Future<Map<String, dynamic>> runStressTest() async {
    debugPrint('🔥 스트레스 테스트 시작: 극한 상황 시뮬레이션');
    
    return await startLoadTest(
      concurrentUsers: 5000,
      durationMinutes: 5,
      requestsPerSecond: 500,
    );
  }
  
  /// 스파이크 테스트 (갑작스러운 트래픽 증가)
  Future<Map<String, dynamic>> runSpikeTest() async {
    debugPrint('⚡ 스파이크 테스트 시작: 갑작스러운 트래픽 증가');
    
    // 단계별 사용자 수 증가
    final results = <Map<String, dynamic>>[];
    
    for (int users in [100, 500, 1000, 2000, 5000]) {
      debugPrint('📈 사용자 수 증가: $users명');
      
      final result = await startLoadTest(
        concurrentUsers: users,
        durationMinutes: 2,
        requestsPerSecond: users * 2,
      );
      
      results.add({
        'concurrent_users': users,
        'result': result,
      });
      
      // 잠시 대기
      await Future.delayed(const Duration(seconds: 5));
    }
    
    return {
      'spike_test_results': results,
      'summary': _generateSpikeTestSummary(results),
    };
  }
  
  /// 스파이크 테스트 요약 생성
  Map<String, dynamic> _generateSpikeTestSummary(List<Map<String, dynamic>> results) {
    double maxResponseTime = 0;
    double minSuccessRate = 100;
    int maxConcurrentUsers = 0;
    
    for (final result in results) {
      final data = result['result'] as Map<String, dynamic>;
      final responseTime = double.parse(data['avg_response_time_ms']);
      final successRate = double.parse(data['success_rate_percent']);
      final users = result['concurrent_users'] as int;
      
      if (responseTime > maxResponseTime) {
        maxResponseTime = responseTime;
      }
      
      if (successRate < minSuccessRate) {
        minSuccessRate = successRate;
      }
      
      if (users > maxConcurrentUsers) {
        maxConcurrentUsers = users;
      }
    }
    
    return {
      'max_response_time_ms': maxResponseTime.toStringAsFixed(2),
      'min_success_rate_percent': minSuccessRate.toStringAsFixed(2),
      'max_concurrent_users': maxConcurrentUsers,
      'system_stability': minSuccessRate > 95 ? 'Excellent' : 
                         minSuccessRate > 90 ? 'Good' : 
                         minSuccessRate > 80 ? 'Fair' : 'Poor',
    };
  }
}
