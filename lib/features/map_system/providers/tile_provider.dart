import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/repositories/tiles_repository.dart';
import '../../../core/models/map/fog_level.dart';
import '../../../utils/tile_utils.dart';

/// 타일(Fog of War) 상태 관리 Provider
/// 
/// **책임**: 
/// - 방문한 타일 상태 관리
/// - Fog Level 상태 관리
/// - 이미지 캐시 통계
/// 
/// **금지**: 
/// - Firebase 직접 호출 (Repository 사용)
/// - 복잡한 타일 계산 로직 (Utils/Service 사용)
class TileProvider with ChangeNotifier {
  final TilesRepository _repository;

  // ==================== 상태 ====================
  
  /// 방문한 타일 ID 맵 (tileId -> FogLevel)
  Map<String, FogLevel> _visitedTiles = {};
  
  /// 최근 30일 방문 타일 ID 세트
  Set<String> _visited30Days = {};
  
  /// 이미지 캐시 통계
  Map<String, dynamic> _imageCacheStats = {
    'memoryCount': 0,
    'diskCount': 0,
    'totalSize': 0,
  };
  
  /// 로딩 상태
  bool _isLoading = false;
  
  /// 에러 메시지
  String? _errorMessage;

  // ==================== Getters ====================
  
  Map<String, FogLevel> get visitedTiles => Map.unmodifiable(_visitedTiles);
  Set<String> get visited30Days => Set.unmodifiable(_visited30Days);
  Map<String, dynamic> get imageCacheStats => Map.unmodifiable(_imageCacheStats);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalVisitedTiles => _visitedTiles.length;

  // ==================== Constructor ====================
  
  TileProvider({TilesRepository? repository})
      : _repository = repository ?? TilesRepository() {
    _loadVisitedTiles();
  }

  // ==================== 액션 ====================

  /// 방문한 타일 목록 로드
  Future<void> _loadVisitedTiles() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 전체 방문 타일 (Level 1)
      final allTiles = await _repository.getAllVisitedTiles();
      
      // 최근 30일 방문 타일 (Level 2)
      final recent30Days = await _repository.getVisitedTilesLast30Days();
      
      _visitedTiles = {
        for (final tileId in allTiles) tileId: FogLevel.clear,
      };
      
      _visited30Days = recent30Days;
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('✅ 타일 로드 완료: ${allTiles.length}개 (최근 30일: ${recent30Days.length}개)');
    } catch (e) {
      _errorMessage = '타일 로드 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 타일 로드 실패: $e');
    }
  }

  /// 타일 방문 기록 업데이트
  /// 
  /// [position]: 방문 위치
  /// Returns: 타일 ID
  Future<String> updateVisit(LatLng position) async {
    final tileId = TileUtils.getKm1TileId(
      position.latitude,
      position.longitude,
    );
    
    // 이미 방문한 타일이면 스킵
    if (_visitedTiles.containsKey(tileId)) {
      return tileId;
    }

    try {
      // Repository를 통해 기록
      final success = await _repository.updateVisit(tileId);
      
      if (success) {
        _visitedTiles[tileId] = FogLevel.clear;
        _visited30Days.add(tileId);
        notifyListeners();
        
        debugPrint('✅ 타일 방문 기록: $tileId');
      }
    } catch (e) {
      debugPrint('❌ 타일 방문 기록 실패: $e');
    }
    
    return tileId;
  }

  /// 여러 타일 일괄 방문 기록
  /// 
  /// [positions]: 방문 위치 목록
  Future<void> batchUpdateVisits(List<LatLng> positions) async {
    final tileIds = positions
        .map((pos) => TileUtils.getKm1TileId(pos.latitude, pos.longitude))
        .toSet()
        .toList();
    
    try {
      await _repository.batchUpdateVisits(tileIds);
      
      for (final tileId in tileIds) {
        _visitedTiles[tileId] = FogLevel.clear;
        _visited30Days.add(tileId);
      }
      
      notifyListeners();
      debugPrint('✅ 배치 타일 방문 기록: ${tileIds.length}개');
    } catch (e) {
      debugPrint('❌ 배치 타일 방문 기록 실패: $e');
    }
  }

  /// 타일 프리패치 (다음 이동 예상 타일)
  /// 
  /// [centerPosition]: 중심 위치
  /// [radius]: 반경 (미터)
  Future<void> prefetchNearbyTiles(LatLng centerPosition, double radius) async {
    // 주변 타일 ID 계산 (간단한 그리드)
    final centerTileId = TileUtils.getKm1TileId(
      centerPosition.latitude,
      centerPosition.longitude,
    );
    
    // 주변 8방향 타일 ID 생성 (실제로는 더 정교한 계산 필요)
    final nearbyTileIds = <String>[centerTileId];
    
    try {
      final result = await _repository.prefetchTiles(nearbyTileIds);
      
      for (final entry in result.entries) {
        if (entry.value) {
          _visitedTiles[entry.key] = FogLevel.clear;
        }
      }
      
      notifyListeners();
      debugPrint('✅ 타일 프리패치 완료: ${result.length}개');
    } catch (e) {
      debugPrint('❌ 타일 프리패치 실패: $e');
    }
  }

  /// 오래된 타일 정리
  Future<int> evictOldTiles() async {
    try {
      final count = await _repository.evictOldTiles();
      
      if (count > 0) {
        // 로컬 상태도 갱신
        await _loadVisitedTiles();
      }
      
      debugPrint('✅ 오래된 타일 정리: $count개');
      return count;
    } catch (e) {
      debugPrint('❌ 타일 정리 실패: $e');
      return 0;
    }
  }

  /// 특정 타일의 Fog Level 가져오기
  FogLevel getFogLevel(String tileId) {
    return _visitedTiles[tileId] ?? FogLevel.black;
  }

  /// 위치의 Fog Level 가져오기
  FogLevel getFogLevelForPosition(LatLng position) {
    final tileId = TileUtils.getKm1TileId(
      position.latitude,
      position.longitude,
    );
    return getFogLevel(tileId);
  }

  /// 이미지 캐시 통계 업데이트
  void updateCacheStats(Map<String, dynamic> stats) {
    _imageCacheStats = stats;
    notifyListeners();
  }

  /// 타일 상태 초기화
  void reset() {
    _visitedTiles.clear();
    _visited30Days.clear();
    _imageCacheStats = {
      'memoryCount': 0,
      'diskCount': 0,
      'totalSize': 0,
    };
    notifyListeners();
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== 디버그 ====================

  Map<String, dynamic> getDebugInfo() {
    return {
      'totalVisitedTiles': _visitedTiles.length,
      'visited30Days': _visited30Days.length,
      'cacheStats': _imageCacheStats,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
    };
  }
}

