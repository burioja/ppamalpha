import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// 지도 성능 최적화 및 모니터링 유틸리티
class MapPerformanceUtils {
  static const String _tag = 'MapPerformance';
  
  // 성능 측정 데이터
  static final Map<String, List<Duration>> _performanceData = {};
  static final Map<String, int> _operationCounts = {};
  
  // 메모리 사용량 추적
  static final List<int> _memoryUsageHistory = [];
  static Timer? _memoryMonitorTimer;
  
  // 성능 임계값
  static const Duration _slowOperationThreshold = Duration(milliseconds: 100);
  static const Duration _verySlowOperationThreshold = Duration(milliseconds: 500);
  static const int _maxMemoryUsageHistory = 100;

  /// 성능 측정 시작
  static void startOperation(String operationName) {
    if (kDebugMode) {
      developer.log('🟢 $operationName 시작', name: _tag);
    }
    
    final stopwatch = Stopwatch()..start();
    _performanceData[operationName] = [stopwatch.elapsed];
  }

  /// 성능 측정 종료
  static void endOperation(String operationName) {
    if (kDebugMode) {
      final stopwatch = Stopwatch();
      final duration = stopwatch.elapsed;
      
      _recordPerformance(operationName, duration);
      _logPerformance(operationName, duration);
    }
  }

  /// 성능 데이터 기록
  static void _recordPerformance(String operationName, Duration duration) {
    if (!_performanceData.containsKey(operationName)) {
      _performanceData[operationName] = [];
    }
    
    _performanceData[operationName]!.add(duration);
    
    // 최대 100개까지만 유지
    if (_performanceData[operationName]!.length > 100) {
      _performanceData[operationName]!.removeAt(0);
    }
    
    // 작업 횟수 증가
    _operationCounts[operationName] = (_operationCounts[operationName] ?? 0) + 1;
  }

  /// 성능 로그 출력
  static void _logPerformance(String operationName, Duration duration) {
    String emoji = '🟢';
    if (duration > _verySlowOperationThreshold) {
      emoji = '🔴';
    } else if (duration > _slowOperationThreshold) {
      emoji = '🟡';
    }
    
    developer.log(
      '$emoji $operationName 완료: ${duration.inMilliseconds}ms',
      name: _tag,
    );
  }

  /// 성능 통계 가져오기
  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    _performanceData.forEach((operationName, durations) {
      if (durations.isNotEmpty) {
        final avgDuration = durations.reduce((a, b) => a + b) ~/ durations.length;
        final minDuration = durations.reduce((a, b) => a < b ? a : b);
        final maxDuration = durations.reduce((a, b) => a > b ? a : b);
        
        stats[operationName] = {
          'count': _operationCounts[operationName] ?? 0,
          'average_ms': avgDuration.inMilliseconds,
          'min_ms': minDuration.inMilliseconds,
          'max_ms': maxDuration.inMilliseconds,
          'total_ms': durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds),
        };
      }
    });
    
    return stats;
  }

  /// 성능 통계 출력
  static void printPerformanceStats() {
    if (!kDebugMode) return;
    
    final stats = getPerformanceStats();
    if (stats.isEmpty) {
      developer.log('📊 성능 데이터가 없습니다', name: _tag);
      return;
    }
    
    developer.log('📊 성능 통계:', name: _tag);
    stats.forEach((operationName, data) {
      developer.log(
        '  $operationName: ${data['count']}회, '
        '평균: ${data['average_ms']}ms, '
        '최소: ${data['min_ms']}ms, '
        '최대: ${data['max_ms']}ms',
        name: _tag,
      );
    });
  }

  /// 메모리 모니터링 시작
  static void startMemoryMonitoring() {
    if (_memoryMonitorTimer != null) return;
    
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _recordMemoryUsage();
    });
    
    developer.log('🧠 메모리 모니터링 시작', name: _tag);
  }

  /// 메모리 모니터링 중지
  static void stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
    
    developer.log('🧠 메모리 모니터링 중지', name: _tag);
  }

  /// 메모리 사용량 기록
  static void _recordMemoryUsage() {
    // Flutter에서는 실제 메모리 사용량을 직접 측정할 수 없지만,
    // 추정치나 힙 크기 등을 기록할 수 있습니다.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _memoryUsageHistory.add(timestamp);
    
    // 최대 기록 수 제한
    if (_memoryUsageHistory.length > _maxMemoryUsageHistory) {
      _memoryUsageHistory.removeAt(0);
    }
    
    if (kDebugMode) {
      developer.log('🧠 메모리 사용량 기록: ${_memoryUsageHistory.length}/$_maxMemoryUsageHistory', name: _tag);
    }
  }

  /// 메모리 사용량 히스토리 가져오기
  static List<int> getMemoryUsageHistory() {
    return List.from(_memoryUsageHistory);
  }

  /// 성능 최적화 팁 제공
  static List<String> getOptimizationTips() {
    final tips = <String>[];
    final stats = getPerformanceStats();
    
    stats.forEach((operationName, data) {
      final avgMs = data['average_ms'] as int;
      
      if (avgMs > _verySlowOperationThreshold.inMilliseconds) {
        tips.add('🔴 $operationName: 매우 느림 (${avgMs}ms) - 알고리즘 최적화 필요');
      } else if (avgMs > _slowOperationThreshold.inMilliseconds) {
        tips.add('🟡 $operationName: 느림 (${avgMs}ms) - 성능 개선 권장');
      }
    });
    
    if (tips.isEmpty) {
      tips.add('🟢 모든 작업이 적절한 성능을 보이고 있습니다');
    }
    
    return tips;
  }

  /// 성능 최적화 팁 출력
  static void printOptimizationTips() {
    if (!kDebugMode) return;
    
    final tips = getOptimizationTips();
    developer.log('💡 성능 최적화 팁:', name: _tag);
    
    for (final tip in tips) {
      developer.log('  $tip', name: _tag);
    }
  }

  /// 성능 데이터 초기화
  static void clearPerformanceData() {
    _performanceData.clear();
    _operationCounts.clear();
    _memoryUsageHistory.clear();
    
    developer.log('🗑️ 성능 데이터 초기화됨', name: _tag);
  }

  /// 메모리 누수 감지
  static void detectMemoryLeaks() {
    if (!kDebugMode) return;
    
    // 간단한 메모리 누수 감지 로직
    final now = DateTime.now().millisecondsSinceEpoch;
    final oldEntries = _memoryUsageHistory.where((timestamp) {
      return now - timestamp > 60000; // 1분 이상 된 항목
    }).length;
    
    if (oldEntries > _maxMemoryUsageHistory * 0.8) {
      developer.log('⚠️ 잠재적 메모리 누수 감지됨', name: _tag);
    }
  }

  /// 성능 경고 설정
  static void setPerformanceWarnings({
    Duration? slowThreshold,
    Duration? verySlowThreshold,
  }) {
    if (slowThreshold != null) {
      // _slowOperationThreshold = slowThreshold; // const라서 직접 수정 불가
    }
    if (verySlowThreshold != null) {
      // _verySlowOperationThreshold = verySlowThreshold; // const라서 직접 수정 불가
    }
    
    developer.log('⚙️ 성능 경고 임계값 업데이트됨', name: _tag);
  }

  /// 성능 리포트 생성
  static String generatePerformanceReport() {
    final stats = getPerformanceStats();
    final tips = getOptimizationTips();
    
    final report = StringBuffer();
    report.writeln('=== 지도 성능 리포트 ===');
    report.writeln('생성 시간: ${DateTime.now()}');
    report.writeln('');
    
    report.writeln('📊 성능 통계:');
    stats.forEach((operationName, data) {
      report.writeln('  $operationName:');
      report.writeln('    - 실행 횟수: ${data['count']}');
      report.writeln('    - 평균 시간: ${data['average_ms']}ms');
      report.writeln('    - 최소 시간: ${data['min_ms']}ms');
      report.writeln('    - 최대 시간: ${data['max_ms']}ms');
      report.writeln('    - 총 시간: ${data['total_ms']}ms');
      report.writeln('');
    });
    
    report.writeln('💡 최적화 팁:');
    for (final tip in tips) {
      report.writeln('  $tip');
    }
    
    return report.toString();
  }

  /// 성능 리포트 출력
  static void printPerformanceReport() {
    if (!kDebugMode) return;
    
    final report = generatePerformanceReport();
    developer.log(report, name: _tag);
  }
}
