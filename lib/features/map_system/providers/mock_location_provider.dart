import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Mock 위치 관리 Provider
/// 
/// **책임**:
/// - Mock 모드 상태 관리
/// - Mock 위치와 GPS 위치 스위칭
/// - 이전 위치 추적 (회색 영역용)
/// - GPS 백업/복원
class MockLocationProvider extends ChangeNotifier {
  // Mock 모드 상태
  bool _isMockModeEnabled = false;
  bool _isControllerVisible = false;

  // 위치 상태
  LatLng? _mockPosition;
  LatLng? _originalGpsPosition; // GPS 위치 백업
  LatLng? _previousMockPosition; // 이전 Mock 위치 (회색 영역용)
  LatLng? _previousGpsPosition; // 이전 GPS 위치 (회색 영역용)
  LatLng? _currentGpsPosition; // 현재 실제 GPS 위치

  // Getters
  bool get isMockModeEnabled => _isMockModeEnabled;
  bool get isControllerVisible => _isControllerVisible;
  LatLng? get mockPosition => _mockPosition;
  LatLng? get originalGpsPosition => _originalGpsPosition;
  LatLng? get previousMockPosition => _previousMockPosition;
  LatLng? get previousGpsPosition => _previousGpsPosition;

  /// 현재 유효한 위치 (Mock 모드면 Mock, 아니면 GPS)
  LatLng? get effectivePosition {
    if (_isMockModeEnabled && _mockPosition != null) {
      return _mockPosition;
    }
    return _currentGpsPosition;
  }

  /// Mock 모드 토글
  void toggleMockMode() {
    _isMockModeEnabled = !_isMockModeEnabled;

    if (_isMockModeEnabled) {
      // Mock 모드 활성화
      _isControllerVisible = true;
      // 현재 GPS 위치 백업
      _originalGpsPosition = _currentGpsPosition;
      // Mock 위치가 없으면 현재 GPS 위치를 기본값으로
      if (_mockPosition == null && _currentGpsPosition != null) {
        _mockPosition = _currentGpsPosition;
      }
      debugPrint('🎭 Mock 모드 활성화 - Mock 위치: $_mockPosition');
    } else {
      // Mock 모드 비활성화
      _isControllerVisible = false;
      debugPrint('🎭 Mock 모드 비활성화 - GPS 위치로 복원: $_originalGpsPosition');
    }

    notifyListeners();
  }

  /// Mock 위치 설정
  void setMockPosition(LatLng position) {
    // 이전 위치 저장 (회색 영역용)
    _previousMockPosition = _mockPosition;

    _mockPosition = position;
    debugPrint('🎭 Mock 위치 설정: ${position.latitude}, ${position.longitude}');

    notifyListeners();
  }

  /// GPS 위치 업데이트
  void updateGpsPosition(LatLng position) {
    // 이전 위치 저장 (회색 영역용)
    _previousGpsPosition = _currentGpsPosition;

    _currentGpsPosition = position;

    // Mock 모드가 꺼져있을 때만 알림
    if (!_isMockModeEnabled) {
      notifyListeners();
    }
  }

  /// 컨트롤러 표시/숨김
  void setControllerVisibility(bool visible) {
    _isControllerVisible = visible;
    notifyListeners();
  }

  /// 컨트롤러 숨기기
  void hideController() {
    _isControllerVisible = false;
    notifyListeners();
  }

  /// Mock 모드 활성화 (외부에서 강제로)
  void enableMockMode({LatLng? initialPosition}) {
    _isMockModeEnabled = true;
    _isControllerVisible = true;
    _originalGpsPosition = _currentGpsPosition;

    if (initialPosition != null) {
      _mockPosition = initialPosition;
    } else if (_mockPosition == null && _currentGpsPosition != null) {
      _mockPosition = _currentGpsPosition;
    }

    notifyListeners();
  }

  /// Mock 모드 비활성화 (외부에서 강제로)
  void disableMockMode() {
    _isMockModeEnabled = false;
    _isControllerVisible = false;
    notifyListeners();
  }

  /// GPS 위치로 복원
  LatLng? restoreGpsPosition() {
    return _originalGpsPosition ?? _currentGpsPosition;
  }

  /// 상태 초기화
  void reset() {
    _isMockModeEnabled = false;
    _isControllerVisible = false;
    _mockPosition = null;
    _originalGpsPosition = null;
    _previousMockPosition = null;
    _previousGpsPosition = null;
    _currentGpsPosition = null;
    notifyListeners();
  }

  /// 디버그 정보
  Map<String, dynamic> getDebugInfo() {
    return {
      'isMockModeEnabled': _isMockModeEnabled,
      'isControllerVisible': _isControllerVisible,
      'mockPosition': _mockPosition?.toString(),
      'currentGpsPosition': _currentGpsPosition?.toString(),
      'effectivePosition': effectivePosition?.toString(),
      'originalGpsPosition': _originalGpsPosition?.toString(),
    };
  }
}

