part of 'map_screen.dart';

// ==================== Fog of War 관련 메서드들 ====================

/// Fog of War 재구성
void _rebuildFogWithUserLocations(LatLng currentPosition) {
  final result = FogController.rebuildFogWithUserLocations(
    currentPosition: currentPosition,
    homeLocation: _homeLocation,
    workLocations: _workLocations,
  );
  
  if (mounted) {
    setState(() {
      _ringCircles = result.$2; // ringCircles
    });
  }
}

/// 사용자 위치들 로드
Future<void> _loadUserLocations() async {
  final result = await FogController.loadUserLocations();
  
  if (mounted) {
    setState(() {
      _homeLocation = result.$1;
      _workLocations = result.$2;
    });
  }

  // 과거 방문 위치 로드
  await _loadVisitedLocations();

  // Fog of War 업데이트
  if (_currentPosition != null) {
    _rebuildFogWithUserLocations(_currentPosition!);
  }
}

/// 과거 방문 위치 로드
Future<void> _loadVisitedLocations() async {
  final grayPolygons = await FogController.loadVisitedLocations();
  
  if (mounted) {
    setState(() {
      _grayPolygons = grayPolygons;
    });
  }
}

/// 이전 위치를 포함한 회색 영역 업데이트
Future<void> _updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
  final grayPolygons = await FogController.updateGrayAreasWithPreviousPosition(
    previousPosition,
  );
  
  if (mounted) {
    setState(() {
      _grayPolygons = grayPolygons;
    });
  }
}

/// 로컬 포그레벨 1 타일 설정
void _setLevel1TileLocally(String tileId) {
  setState(() {
    _currentFogLevel1TileIds.add(tileId);
    _fogLevel1CacheTimestamp = DateTime.now();
  });
}

/// 포그레벨 1 캐시 초기화
void _clearFogLevel1Cache() {
  setState(() {
    _currentFogLevel1TileIds.clear();
    _fogLevel1CacheTimestamp = null;
  });
}

/// 만료된 포그레벨 1 캐시 확인 및 초기화
void _checkAndClearExpiredFogLevel1Cache() {
  if (_fogLevel1CacheTimestamp != null) {
    final elapsed = DateTime.now().difference(_fogLevel1CacheTimestamp!);
    if (elapsed > const Duration(minutes: 5)) {
      _clearFogLevel1Cache();
    }
  }
}

/// 포그레벨 1 캐시 타임스탬프 업데이트
void _updateFogLevel1CacheTimestamp() {
  setState(() {
    _fogLevel1CacheTimestamp = DateTime.now();
  });
}

