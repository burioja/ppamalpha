# 🐛 현재 맵 시스템 문제점 및 해결 방안

## 문제 1: 마커가 화면에 표시되지 않음 ❌

### 증상
로그:
```
📊 최종 반환 마커: 3개
✅ 최종 마커: 2개
📄 포스트: 2개
```
→ **마커 데이터는 있지만 화면에 안 보임**

### 원인 분석

#### 1. 마커 데이터 흐름
```
MarkerProvider.refreshByFogLevel()
    ↓
getMarkers() 호출 (Firebase에서 마커 가져옴)
    ↓
markerProvider.markers 업데이트
    ↓
⚠️ _state.markers 업데이트 안 됨!
    ↓
⚠️ _rebuildClusters() 호출 안 됨!
    ↓
❌ _state.clusteredMarkers = [] (빈 배열)
```

#### 2. 문제 코드
```dart
// lib/features/map_system/screens/map_screen.dart (291-316줄)

void _updateMarkers() {
  final markerProvider = context.read<MarkerProvider>();
  
  // ✅ MarkerProvider가 마커를 가져옴
  markerProvider.refreshByFogLevel(...);
  
  // ❌ 하지만 _state.markers를 업데이트하지 않음!
  // ❌ _rebuildClusters()를 호출하지 않음!
}
```

#### 3. MarkerLayer 렌더링
```dart
// lib/features/map_system/screens/map_screen.dart (589-594줄)

Consumer<MarkerProvider>(
  builder: (context, markerProvider, _) {
    // ❌ markerProvider.markers를 사용하지 않음!
    return MarkerLayer(markers: _state.clusteredMarkers);  // ← 이게 빈 배열
  },
),
```

### 해결 방안

#### Option 1: MarkerProvider 데이터 사용 (권장)
```dart
Consumer<MarkerProvider>(
  builder: (context, markerProvider, _) {
    // ✅ MarkerProvider의 마커 직접 사용
    final markers = markerProvider.markers.map((marker) => Marker(
      point: marker.position,
      child: _buildMarkerWidget(marker),
    )).toList();
    
    return MarkerLayer(markers: markers);
  },
),
```

#### Option 2: State 동기화
```dart
void _updateMarkers() {
  final markerProvider = context.read<MarkerProvider>();
  
  markerProvider.refreshByFogLevel(...);
  
  // ✅ Provider 변경 리스닝
  markerProvider.addListener(() {
    setState(() {
      _state.markers = markerProvider.markers;
    });
    _rebuildClusters();
  });
}
```

#### Option 3: 직접 마커 관리
```dart
void _updateMarkers() async {
  // Provider 사용하지 않고 직접 가져오기
  final markers = await MarkerController.fetchMarkers(
    currentPosition: _state.currentPosition,
    homeLocation: _state.homeLocation,
    workLocations: _state.workLocations,
    filters: {...},
  );
  
  setState(() {
    _state.markers = markers;
  });
  _rebuildClusters();
}
```

---

## 문제 2: Level 2 (회색 영역)가 제대로 표시되지 않음 🌫️

### 증상
로그:
```
🎯 Level 2 중심점: 3개 (visited30Days: 3개)
🎨 paint 호출: L1=2, L2=3
  L2: center=LatLng(latitude:36.006157, longitude:121.915965), screen=Offset(-54720.1, 20269.3)
  L2: center=LatLng(latitude:35.90648, longitude:121.668875), screen=Offset(-57598.9, 21704.0)
  L2: center=LatLng(latitude:35.972896, longitude:121.964057), screen=Offset(-54159.8, 20748.2)
```
→ **Level 2 좌표들이 화면 밖에 있음!**

### 원인 분석

#### 1. 화면 좌표 이슈
```
현재 위치: 37.374056, 126.641766
Level 2 위치: 36.006157, 121.915965 (약 450km 떨어진 중국!)

화면 좌표:
- L1: Offset(339.5, 393.5)     ← 화면 안
- L2: Offset(-54720.1, 20269.3) ← 화면 밖!
```

**Level 2 위치들이 너무 멀리 떨어져 있어서 화면에 안 보임**

#### 2. 타일 데이터 문제
```dart
// 데이터베이스의 visited_tiles
{
  "tileId": "some_tile_id",
  "lastVisitTime": Timestamp,
  // ... 하지만 위치가 중국?
}
```

**방문한 타일의 위치가 잘못 저장되었거나 타일 ID 변환에 문제가 있음**

### 해결 방안

#### 1. Level 2 타일 필터링
```dart
// UnifiedFogOverlayWidget에 전달하기 전에 필터링

final level2Centers = <LatLng>[];
for (final tileId in tileProvider.visited30Days) {
  final center = TileUtils.getKm1TileCenter(tileId);
  
  // ✅ 현재 위치에서 일정 거리 내의 타일만 포함 (예: 50km)
  if (_state.currentPosition != null) {
    final distance = MarkerService.calculateDistance(_state.currentPosition!, center);
    if (distance <= 50000) {  // 50km 내
      level2Centers.add(center);
    }
  }
}
```

#### 2. 타일 ID 검증
```dart
// TileUtils.getKm1TileCenter()에서 유효성 검증

static LatLng getKm1TileCenter(String tileId) {
  final center = ...; // 현재 계산 로직
  
  // ✅ 유효한 범위인지 확인
  if (center.latitude < -90 || center.latitude > 90 ||
      center.longitude < -180 || center.longitude > 180) {
    debugPrint('⚠️ 유효하지 않은 타일 중심점: $tileId -> $center');
    throw Exception('Invalid tile coordinates');
  }
  
  return center;
}
```

#### 3. 디버그 로그 추가
```dart
debugPrint('🎯 Level 2 중심점: ${level2Centers.length}개');
for (final center in level2Centers) {
  final distance = MarkerService.calculateDistance(
    _state.currentPosition!, 
    center
  );
  debugPrint('  - ${center.latitude}, ${center.longitude} (거리: ${distance/1000}km)');
}
```

---

## 즉시 적용 가능한 임시 해결책 🔧

### 1. 마커 표시 수정
```dart
// lib/features/map_system/screens/map_screen.dart (589-594줄)

// 기존 (작동 안 함)
Consumer<MarkerProvider>(
  builder: (context, markerProvider, _) {
    return MarkerLayer(markers: _state.clusteredMarkers);  // ❌ 빈 배열
  },
),

// 수정 (작동함)
Consumer<MarkerProvider>(
  builder: (context, markerProvider, _) {
    // ✅ Provider의 마커 직접 사용
    final markers = markerProvider.markers.map((marker) => Marker(
      point: marker.position,
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showMarkerDetails(marker),
        child: Image.asset('assets/images/ppam_work.png'),
      ),
    )).toList();
    
    return MarkerLayer(markers: markers);
  },
),
```

### 2. Level 2 필터링 추가
```dart
// lib/features/map_system/screens/map_screen.dart (550-560줄)

final level2Centers = <LatLng>[];
for (final tileId in tileProvider.visited30Days) {
  try {
    final center = TileUtils.getKm1TileCenter(tileId);
    
    // ✅ 현재 위치에서 50km 이내만 포함
    if (_state.currentPosition != null) {
      final distance = MarkerService.calculateDistance(
        _state.currentPosition!,
        center,
      );
      if (distance <= 50000) {  // 50km = 50000m
        level2Centers.add(center);
      }
    }
  } catch (e) {
    debugPrint('🔥 타일 중심점 계산 오류: $tileId - $e');
  }
}
```

---

## 근본 원인 🔍

### 마커 문제
- **MarkerProvider가 마커를 가져오지만** → _state.markers에 반영 안 됨
- **_rebuildClusters()가 호출되지 않음** → _state.clusteredMarkers가 빈 배열
- **MarkerLayer가 빈 배열을 렌더링** → 마커 안 보임

### Level 2 문제  
- **visited_tiles의 위치 데이터가 잘못됨** → 중국 좌표
- **화면에서 수만 픽셀 떨어진 곳** → 안 보임
- **거리 필터링 없음** → 먼 타일도 모두 렌더링 시도

---

## 체크리스트 ✅

### 마커 표시 확인
- [ ] MarkerProvider.markers에 데이터 있는지 확인
- [ ] _state.markers가 업데이트되는지 확인
- [ ] _rebuildClusters()가 호출되는지 확인
- [ ] _state.clusteredMarkers에 마커가 있는지 확인
- [ ] MarkerLayer에 전달되는 배열 크기 확인

### Level 2 Fog 확인
- [ ] visited30Days 타일 ID 확인
- [ ] 타일 중심점 좌표 확인
- [ ] 현재 위치에서의 거리 확인
- [ ] 화면 좌표 (Offset) 확인
- [ ] 거리 필터링 적용

---

## 다음 단계

1. ✅ **마커 문제 우선 해결**
   - Consumer에서 markerProvider.markers 직접 사용
   
2. ✅ **Level 2 필터링 추가**
   - 현재 위치에서 50km 이내만 표시

3. 🔍 **데이터 검증**
   - visited_tiles 데이터 확인
   - 타일 ID → 좌표 변환 검증

4. 🧪 **테스트**
   - 마커 표시 확인
   - Level 2 회색 영역 표시 확인


