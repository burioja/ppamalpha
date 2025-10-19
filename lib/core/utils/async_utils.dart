import 'dart:async';
import 'package:flutter/foundation.dart';

/// 비동기 유틸리티
/// 
/// **제공 기능**:
/// - Debounce: 연속 이벤트 중 마지막만 실행
/// - Throttle: 일정 간격으로만 실행
/// - Cooldown: 실행 후 대기 시간 강제

// ==================== Debouncer ====================

/// Debouncer 클래스
/// 
/// **사용 예시**:
/// ```dart
/// final debouncer = Debouncer(milliseconds: 300);
/// 
/// void onMapMoved() {
///   debouncer.run(() {
///     _refreshMarkers();
///   });
/// }
/// ```
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  /// 디바운스 실행
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// 타이머 취소
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose
  void dispose() {
    _timer?.cancel();
  }
}

// ==================== Throttler ====================

/// Throttler 클래스
/// 
/// **사용 예시**:
/// ```dart
/// final throttler = Throttler(milliseconds: 100);
/// 
/// void onZoomChanged() {
///   throttler.run(() {
///     _recluster();
///   });
/// }
/// ```
class Throttler {
  final int milliseconds;
  DateTime? _lastExecutionTime;
  Timer? _timer;

  Throttler({required this.milliseconds});

  /// 스로틀 실행 (즉시 실행 방식)
  void run(VoidCallback action) {
    final now = DateTime.now();
    
    if (_lastExecutionTime == null ||
        now.difference(_lastExecutionTime!) >= Duration(milliseconds: milliseconds)) {
      _lastExecutionTime = now;
      action();
    }
  }

  /// 스로틀 실행 (지연 실행 방식)
  void runDelayed(VoidCallback action) {
    if (_timer?.isActive ?? false) return;
    
    _timer = Timer(Duration(milliseconds: milliseconds), () {
      action();
    });
  }

  /// 리셋
  void reset() {
    _lastExecutionTime = null;
    _timer?.cancel();
  }

  /// Dispose
  void dispose() {
    _timer?.cancel();
  }
}

// ==================== Cooldown ====================

/// Cooldown 클래스
/// 
/// **사용 예시**:
/// ```dart
/// final cooldown = Cooldown(seconds: 5);
/// 
/// Future<void> refreshPoints() async {
///   if (!cooldown.canExecute) {
///     print('쿨다운 중: ${cooldown.remainingSeconds}초');
///     return;
///   }
///   
///   await _loadPoints();
///   cooldown.start();
/// }
/// ```
class Cooldown {
  final int seconds;
  DateTime? _lastExecutionTime;

  Cooldown({required this.seconds});

  /// 실행 가능 여부
  bool get canExecute {
    if (_lastExecutionTime == null) return true;
    
    final elapsed = DateTime.now().difference(_lastExecutionTime!);
    return elapsed.inSeconds >= seconds;
  }

  /// 남은 쿨다운 시간 (초)
  int get remainingSeconds {
    if (_lastExecutionTime == null) return 0;
    
    final elapsed = DateTime.now().difference(_lastExecutionTime!);
    final remaining = seconds - elapsed.inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// 쿨다운 시작
  void start() {
    _lastExecutionTime = DateTime.now();
  }

  /// 리셋
  void reset() {
    _lastExecutionTime = null;
  }
}

// ==================== 헬퍼 함수 ====================

/// 디바운스 헬퍼 함수
/// 
/// **사용 예시**:
/// ```dart
/// Timer? _debounceTimer;
/// 
/// void onMapMoved() {
///   _debounceTimer = debounce(
///     timer: _debounceTimer,
///     duration: Duration(milliseconds: 300),
///     onExecute: () => _refreshMarkers(),
///   );
/// }
/// ```
Timer debounce({
  Timer? timer,
  required Duration duration,
  required VoidCallback onExecute,
}) {
  timer?.cancel();
  return Timer(duration, onExecute);
}

/// 스로틀 헬퍼 함수
/// 
/// **사용 예시**:
/// ```dart
/// DateTime? _lastThrottle;
/// 
/// void onZoomChanged() {
///   if (shouldThrottle(
///     lastTime: _lastThrottle,
///     duration: Duration(milliseconds: 100),
///   )) return;
///   
///   _lastThrottle = DateTime.now();
///   _recluster();
/// }
/// ```
bool shouldThrottle({
  DateTime? lastTime,
  required Duration duration,
}) {
  if (lastTime == null) return false;
  
  final elapsed = DateTime.now().difference(lastTime);
  return elapsed < duration;
}

// ==================== 표준 설정 ====================

/// 표준 디바운스 시간
class DebounceDurations {
  static const mapMove = Duration(milliseconds: 300);
  static const search = Duration(milliseconds: 500);
  static const input = Duration(milliseconds: 300);
  static const filter = Duration(milliseconds: 200);
}

/// 표준 스로틀 시간
class ThrottleDurations {
  static const clustering = Duration(milliseconds: 100);
  static const scroll = Duration(milliseconds: 50);
  static const zoom = Duration(milliseconds: 100);
}

/// 표준 쿨다운 시간 (초)
class CooldownDurations {
  static const pointsRefresh = 60; // 1분
  static const markerRefresh = 30; // 30초
  static const fogUpdate = 10; // 10초
}

