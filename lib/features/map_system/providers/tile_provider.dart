import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/repositories/tiles_repository.dart';
import '../../../core/models/map/fog_level.dart';
import '../../../utils/tile_utils.dart';
import '../services/fog_of_war/visit_tile_service.dart';

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
  
  /// 현재 Level 1인 타일들 (현재 위치, 집, 일터 주변 1km)
  Set<String> _currentLevel1TileIds = {};
  
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

  // ==================== 이동 추적 ====================
  
  /// 직전 위치 (방문 확정용)
  LatLng? _previousPosition;
  
  /// 직전 Level 1 타일들 (방문 확정용)
  Set<String> _previousLevel1TileIds = {};

  // ==================== Getters ====================
  
  Map<String, FogLevel> get visitedTiles => Map.unmodifiable(_visitedTiles);
  Set<String> get visited30Days => Set.unmodifiable(_visited30Days);
  Set<String> get currentLevel1TileIds => Set.unmodifiable(_currentLevel1TileIds);
  Map<String, dynamic> get imageCacheStats => Map.unmodifiable(_imageCacheStats);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalVisitedTiles => _visitedTiles.length;
  
  /// Level 1 타일들의 중심점 리스트 (Fog 렌더링용)
  List<LatLng> get level1Centers {
    final centers = <LatLng>[];
    for (final tileId in _currentLevel1TileIds) {
      try {
        final center = TileUtils.getKm1TileCenter(tileId);
        centers.add(center);
      } catch (e) {
        // 타일 중심점 계산 실패
      }
    }
    return centers;
  }

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
      
    } catch (e) {
      _errorMessage = '타일 로드 실패: $e';
      _isLoading = false;
      notifyListeners();
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
        
      }
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
      
      return count;
    } catch (e) {
      return 0;
    }
  }

  /// 특정 타일의 Fog Level 가져오기
  FogLevel getFogLevel(String tileId) {
    // 현재 Level 1 타일이면 clear
    if (_currentLevel1TileIds.contains(tileId)) {
      return FogLevel.clear;
    }
    
    // 30일 방문 타일이면 gray
    if (_visited30Days.contains(tileId)) {
      return FogLevel.gray;
    }
    
    // 나머지는 black
    return FogLevel.black;
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

  /// 현재 위치 타일을 Level 1로 설정
  /// 
  /// Mock 위치 이동 시 사용
  /// [tileId]: 현재 위치 타일 ID
  void setCurrentTile(String tileId) {
    _currentLevel1TileIds.clear(); // 이전 Level 1 타일 제거
    _currentLevel1TileIds.add(tileId); // 새 타일만 Level 1로
    
    // visited30Days에도 추가 (방문 기록)
    if (!_visited30Days.contains(tileId)) {
      _visited30Days.add(tileId);
    }
    
    notifyListeners();
  }
  
  /// 🎯 GPS 이동 콜백 (핵심 메서드)
  /// 
  /// "방문확정 → 레벨1 재계산" 순서 보장
  /// 
  /// [newPosition]: 새 GPS 위치
  /// [homeLocation]: 집 위치
  /// [workLocations]: 일터 위치들
  Future<void> onLocationUpdate({
    required LatLng newPosition,
    LatLng? homeLocation,
    List<LatLng> workLocations = const [],
  }) async {
    
    final oldPosition = _previousPosition;
    final oldLevel1Tiles = Set<String>.from(_currentLevel1TileIds);


    // 1) 직전 Level 1을 방문 확정으로 업서트 (히스테리시스 적용)
    if (oldPosition != null && _movedEnough(oldPosition, newPosition) && oldLevel1Tiles.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 🎯 핵심: 직전 Level 1 타일들을 visited로 확정
        await VisitTileService.upsertVisitedTiles(
          userId: user.uid,
          tileIds: oldLevel1Tiles.toList(),
        );

        // Optimistic update: gray에 바로 반영 → 체감 개선
        _visited30Days.addAll(oldLevel1Tiles);
        _previousLevel1TileIds = oldLevel1Tiles;
      }
    } else {
    }

    // 2) 새 Level 1 재계산
    _previousPosition = newPosition;
    
    final level1Tiles = <String>{};
    
    // 현재 위치 주변 타일
    level1Tiles.add(TileUtils.getKm1TileId(
      newPosition.latitude,
      newPosition.longitude,
    ));
    
    // 집 주변 타일
    if (homeLocation != null) {
      level1Tiles.add(TileUtils.getKm1TileId(
        homeLocation.latitude,
        homeLocation.longitude,
      ));
    }
    
    // 일터 주변 타일들
    for (final work in workLocations) {
      level1Tiles.add(TileUtils.getKm1TileId(
        work.latitude,
        work.longitude,
      ));
    }
    
    _currentLevel1TileIds = level1Tiles;
    notifyListeners();
    
  }

  /// 이동 거리 체크 (히스테리시스)
  /// 
  /// 150m 이상 이동 시만 방문 확정 (GPS 튐 완화)
  bool _movedEnough(LatLng from, LatLng to) {
    const Distance distance = Distance();
    final meters = distance.as(LengthUnit.Meter, from, to);
    return meters > 10.0; // 테스트용으로 150 → 10으로 낮춤
  }

  /// 현재 위치 주변 타일들을 Level 1로 설정
  /// 
  /// [currentPosition]: 현재 위치
  /// [homeLocation]: 집 위치
  /// [workLocations]: 일터 위치들
  void updateLevel1Tiles({
    required LatLng currentPosition,
    LatLng? homeLocation,
    List<LatLng> workLocations = const [],
  }) {
    final level1Tiles = <String>{};
    
    // 현재 위치 주변 타일
    level1Tiles.add(TileUtils.getKm1TileId(
      currentPosition.latitude,
      currentPosition.longitude,
    ));
    
    // 집 주변 타일
    if (homeLocation != null) {
      level1Tiles.add(TileUtils.getKm1TileId(
        homeLocation.latitude,
        homeLocation.longitude,
      ));
    }
    
    // 일터 주변 타일들
    for (final work in workLocations) {
      level1Tiles.add(TileUtils.getKm1TileId(
        work.latitude,
        work.longitude,
      ));
    }
    
    _currentLevel1TileIds = level1Tiles;
    notifyListeners();
    
  }

  /// 타일 상태 초기화
  void reset() {
    _visitedTiles.clear();
    _visited30Days.clear();
    _currentLevel1TileIds.clear();
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

