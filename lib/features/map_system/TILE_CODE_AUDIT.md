# 🔍 타일 코드 감사 보고서

## 📊 전체 현황

### 타일 관련 파일 구조
```
lib/
├── utils/
│   └── tile_utils.dart ✅ 핵심 타일 유틸리티
├── features/map_system/
    ├── services/fog_of_war/
    │   ├── visit_tile_service.dart ✅ 주요 사용 중
    │   ├── fog_tile_service.dart ⚠️ 사용 안 함 (중복)
    │   ├── fog_of_war_manager.dart ⚠️ 사용 안 함 (중복)
    │   └── visit_manager.dart ⚠️ 사용 안 함 (중복)
    ├── providers/
    │   └── tile_provider.dart ✅ 주요 사용 중
    ├── controllers/
    │   └── location_controller.dart ✅ 사용 중
    └── handlers/
        └── map_location_handler.dart ✅ 사용 중
```

---

## ⚠️ 발견된 문제점

### 1. **중복 코드 - 타일 변환 로직** 🔴

#### A. `VisitTileService._centerFromAnyTileId()` vs `TileUtils.getKm1TileCenter()`

**VisitTileService (93-130줄):**
```dart
static LatLng _centerFromAnyTileId(String tileId) {
  if (tileId.startsWith('tile_')) {
    final parts = tileId.split('_');
    final tileLat = int.tryParse(parts[1]);
    final tileLng = int.tryParse(parts[2]);
    
    // ❌ 잘못된 로직 (구버전)
    const double approxTileSize = 0.009;
    final centerLat = tileLat * approxTileSize + (approxTileSize / 2);
    
    return LatLng(
      tileLat * actualTileSize + (actualTileSize / 2),  // ← 중국 좌표!
      tileLng * actualTileSize + (actualTileSize / 2),
    );
  }
  // ... Web Mercator 형식도 처리
}
```

**TileUtils (190-207줄):**
```dart
static LatLng getKm1TileCenter(String tileId) {
  final parts = tileId.split('_');
  final tileLat = int.parse(parts[1]);
  final tileLng = int.parse(parts[2]);
  
  // ✅ 올바른 로직 (수정됨)
  final latitude = tileLat / 1000.0 + 0.0005;
  final longitude = tileLng / 1000.0 + 0.0005;
  
  return LatLng(latitude, longitude);
}
```

**문제:**
- `VisitTileService._centerFromAnyTileId()`가 **구버전 로직**을 사용 중
- 이 함수는 **현재 사용되지 않는 것으로 보임**
- 하지만 혼란을 줄 수 있음

**조치 필요:**
- ✅ `_centerFromAnyTileId()` 삭제 또는 `TileUtils.getKm1TileCenter()` 호출하도록 변경

---

### 2. **사용하지 않는 서비스 파일들** 🟡

#### A. `fog_tile_service.dart` (242줄)
**사용 여부:** ❌ 사용 안 함
**검증:**
```bash
grep "FogTileService" lib/features/map_system/**/*.dart
# 결과: import만 있고 실제 사용 없음
```

**내용:**
- TileProvider 구현
- 타일별 Fog 레벨 계산
- 캐시 관리

**문제:**
- 전혀 사용되지 않음
- `TileProvider` (현재 사용 중)와 기능 중복

**조치 필요:**
- 🗑️ 파일 삭제 권장

---

#### B. `fog_of_war_manager.dart` (250줄+)
**사용 여부:** ❌ 사용 안 함
**검증:**
```bash
grep "FogOfWarManager" lib/features/map_system/**/*.dart
# 결과: 사용처 없음
```

**내용:**
- Geolocator 기반 위치 추적
- 방문 타일 기록
- z_x_y 형식 타일 ID 사용 (구버전)

**문제:**
- Web Mercator 타일 형식 (z_x_y) 사용 → 현재는 1km 타일 (tile_lat_lng) 사용
- 완전히 다른 시스템
- 전혀 사용되지 않음

**조치 필요:**
- 🗑️ 파일 삭제 권장

---

#### C. `visit_manager.dart` (100줄+)
**사용 여부:** ❌ 사용 안 함
**검증:**
```bash
grep "VisitManager" lib/features/map_system/**/*.dart
# 결과: import 오류 (잘못된 경로)
```

**내용:**
- 방문 기록 관리
- `TileUtils.latLngToTile()` 사용 (존재하지 않는 함수!)

**문제:**
- import 경로가 잘못됨: `import '../features/map_system/utils/tile_utils.dart';`
- 존재하지 않는 함수 호출
- 전혀 사용되지 않음

**조치 필요:**
- 🗑️ 파일 삭제 권장

---

### 3. **타일 형식 혼용** 🔴

현재 프로젝트에 **3가지 타일 형식**이 혼재:

#### Format 1: 1km 타일 (현재 주요 사용)
```
형식: tile_37566_126978
저장 위치: TileProvider, VisitTileService
생성: TileUtils.getKm1TileId()
변환: TileUtils.getKm1TileCenter()
```

#### Format 2: Web Mercator XYZ (구버전, 사용 안 함)
```
형식: 18_213456_98765
저장 위치: fog_of_war_manager.dart (사용 안 함)
생성: TileUtils.getTileId()
변환: TileUtils.getTileCenter()
```

#### Format 3: 혼합 형식 (fog_tile_service.dart)
```
형식: z_x_y 또는 tile_lat_lng 둘 다 처리
저장 위치: fog_tile_service.dart (사용 안 함)
```

**문제:**
- 코드 혼란 가중
- 실제로는 Format 1만 사용 중

**조치 필요:**
- 📝 Format 2, 3 관련 코드 정리

---

### 4. **타일 저장 방식 불일치** 🟡

#### 방식 A: `updateCurrentTileVisit()` (단일 타일)
```dart
// 사용처: LocationController, MapLocationHandler
await VisitTileService.updateCurrentTileVisit(tileId);

// 필드:
{
  'tileId': 'tile_37566_126978',
  'lastVisitTime': ServerTimestamp,
  'visitCount': Increment(1),
}
```

#### 방식 B: `upsertVisitedTiles()` (배치)
```dart
// 사용처: TileProvider
await VisitTileService.upsertVisitedTiles(
  userId: uid,
  tileIds: ['tile_37566_126978', 'tile_37567_126979', ...],
);

// 필드: 방식 A와 동일
```

#### 방식 C: fog_of_war_manager.dart (구버전, 사용 안 함)
```dart
// 필드:
{
  'timestamp': Timestamp,
  'z': 13,
  'x': 12345,
  'y': 67890,
  'location': GeoPoint(37.5665, 126.9780),
}
```

**문제:**
- 방식 A, B는 정상 (같은 형식)
- 방식 C는 다른 형식이지만 **사용 안 함**

**조치 필요:**
- ✅ 방식 A, B 유지 (정상)
- 🗑️ 방식 C 코드 삭제

---

### 5. **미사용 함수들** 🟡

#### `VisitTileService.getVisitedTilesInRadius()` (270-310줄)
```dart
static Future<List<String>> getVisitedTilesInRadius(...)
```
**사용 여부:** ❌ 사용 안 함
**문제:**
```dart
// 타일 ID 파싱이 잘못됨
final parts = tileId.split('_');  // tile_37566_126978
final tileLat = double.parse(parts[0]);  // ❌ "tile" 파싱 시도
```

**조치 필요:**
- 🗑️ 삭제 또는 수정

---

#### `VisitTileService._centerFromAnyTileId()` (93-130줄)
**사용 여부:** ❌ 사용 안 함
**문제:** 구버전 변환 로직 (중국 좌표 생성)

**조치 필요:**
- 🗑️ 삭제 권장

---

#### `VisitTileService.getVisitedTilePositions()` (244-267줄)
**사용 여부:** ❌ 사용 안 함
**내용:** 모든 방문 타일 가져오기

**조치 필요:**
- 🗑️ 삭제 또는 유지 (향후 통계용 가능)

---

## ✅ 정상 작동 중인 코드

### 1. **TileUtils (utils/tile_utils.dart)**
```dart
✅ getKm1TileId()           // 좌표 → 타일 ID
✅ getKm1TileCenter()       // 타일 ID → 좌표 (수정됨)
✅ getKm1TileBounds()       // 타일 ID → 경계
✅ getKm1SurroundingTiles() // 주변 타일 목록
✅ validateKm1TileConversion() // 검증 함수
```

### 2. **VisitTileService**
```dart
✅ updateCurrentTileVisit()     // 단일 타일 업데이트
✅ upsertVisitedTiles()         // 배치 타일 업데이트
✅ getFogLevelForTile()         // 타일 Fog 레벨 조회
✅ getFogLevel1TileIdsCached()  // 30일 타일 목록
```

### 3. **TileProvider**
```dart
✅ updatePosition()          // 위치 업데이트 및 타일 저장
✅ refreshVisited30Days()    // 30일 타일 새로고침
✅ visited30Days getter      // Level 2 타일 목록
✅ currentLevel1TileIds getter // Level 1 타일 목록
```

### 4. **LocationController**
```dart
✅ getCurrentLocation()      // 위치 가져오기
✅ updateCurrentAddress()    // 주소 업데이트
// ✅ 타일 업데이트 호출 (85줄)
```

---

## 🗑️ 삭제 권장 파일 목록

### 우선순위 1 (즉시 삭제 가능)
1. **`fog_of_war_manager.dart`** (250줄+)
   - 완전히 사용 안 함
   - 구버전 Web Mercator 타일 시스템
   - TileProvider와 완전 중복

2. **`visit_manager.dart`** (100줄+)
   - 완전히 사용 안 함
   - import 경로 오류
   - 존재하지 않는 함수 호출

3. **`fog_tile_service.dart`** (242줄)
   - 완전히 사용 안 함
   - TileProvider와 중복

### 우선순위 2 (함수 단위 정리)
4. **`VisitTileService._centerFromAnyTileId()`**
   - 사용 안 함
   - 구버전 변환 로직

5. **`VisitTileService.getVisitedTilesInRadius()`**
   - 사용 안 함
   - 파싱 로직 오류

6. **`VisitTileService.getVisitedTilePositions()`**
   - 사용 안 함
   - 향후 통계용으로 유지 가능

---

## 🔄 중복 코드 분석

### 타일 ID → 좌표 변환 (3곳에 중복)

#### 1. TileUtils.getKm1TileCenter() ✅ 주요 사용
```dart
// lib/utils/tile_utils.dart (190-207줄)
static LatLng getKm1TileCenter(String tileId) {
  final tileLat = int.parse(parts[1]);
  final tileLng = int.parse(parts[2]);
  final latitude = tileLat / 1000.0 + 0.0005;  // ✅ 수정됨
  final longitude = tileLng / 1000.0 + 0.0005;
  return LatLng(latitude, longitude);
}
```

#### 2. VisitTileService._centerFromAnyTileId() ❌ 사용 안 함
```dart
// lib/features/map_system/services/fog_of_war/visit_tile_service.dart (93-130줄)
static LatLng _centerFromAnyTileId(String tileId) {
  // ❌ 구버전 로직 - 중국 좌표 생성
  final centerLat = tileLat * approxTileSize + (approxTileSize / 2);
  return LatLng(...);  // 잘못된 계산
}
```

#### 3. map_fog_handler.dart._extractPositionFromTileId() ⚠️ 사용 중
```dart
// ppamalpha/lib/features/map_system/handlers/map_fog_handler.dart (181-202줄)
LatLng? _extractPositionFromTileId(String tileId) {
  if (tileId.startsWith('tile_')) {
    final parts = tileId.split('_');
    final tileLat = int.tryParse(parts[1]);
    final tileLng = int.tryParse(parts[2]);
    
    // ❌ 구버전 로직
    const double tileSize = 0.009;
    return LatLng(
      tileLat * tileSize + (tileSize / 2),  // ← 중국 좌표!
      tileLng * tileSize + (tileSize / 2),
    );
  }
}
```

**조치 필요:**
- 🔧 3번 함수를 `TileUtils.getKm1TileCenter()` 호출로 변경
- 🗑️ 2번 함수 삭제

---

### 타일 저장 (2가지 방식 - 정상)

#### 방식 1: 실시간 업데이트
```dart
// LocationController, MapLocationHandler
await VisitTileService.updateCurrentTileVisit(tileId);
```

#### 방식 2: 배치 업데이트
```dart
// TileProvider (히스테리시스 적용)
await VisitTileService.upsertVisitedTiles(userId, tileIds);
```

**상태:** ✅ 정상 (두 방식 모두 사용 중)
**조치:** 유지

---

## 🎯 권장 조치사항

### 즉시 수정 필요 🔴

#### 1. `map_fog_handler.dart._extractPositionFromTileId()` 수정
```dart
// 현재 (잘못됨)
LatLng? _extractPositionFromTileId(String tileId) {
  const double tileSize = 0.009;
  return LatLng(
    tileLat * tileSize + (tileSize / 2),  // ❌
    tileLng * tileSize + (tileSize / 2),
  );
}

// 수정 (올바름)
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    return TileUtils.getKm1TileCenter(tileId);  // ✅
  } catch (e) {
    debugPrint('타일 ID 변환 실패: $tileId - $e');
    return null;
  }
}
```

**영향:** 🔴 **이 함수가 사용 중이라면 중국 좌표 문제 원인!**

---

### 파일 삭제 권장 🟡

#### 1. `fog_tile_service.dart` 삭제
- 완전히 사용 안 함
- 242줄 절약

#### 2. `fog_of_war_manager.dart` 삭제
- 완전히 사용 안 함
- 구버전 시스템
- 250줄+ 절약

#### 3. `visit_manager.dart` 삭제
- 완전히 사용 안 함
- import 오류
- 100줄+ 절약

**총 절약:** ~600줄

---

### 함수 정리 🟡

#### VisitTileService에서 삭제
```dart
// 1. _centerFromAnyTileId() (93-130줄) - 사용 안 함, 구버전 로직
// 2. getVisitedTilesInRadius() (270-310줄) - 사용 안 함, 파싱 오류
// 3. getVisitedTilePositions() (244-267줄) - 사용 안 함 (향후 통계용 유지 가능)
```

---

## 📋 사용 중인 타일 호출 경로

### 타일 저장 흐름
```
1. 사용자 위치 변경
   ↓
2. TileProvider.updatePosition()
   ↓
3. TileUtils.getKm1TileId() 호출
   ↓
4. VisitTileService.upsertVisitedTiles() 호출
   ↓
5. Firebase: users/{uid}/visited_tiles/{tileId}
```

### 타일 로드 흐름
```
1. 화면 초기화
   ↓
2. TileProvider.refreshVisited30Days()
   ↓
3. VisitTileService.getFogLevel1TileIdsCached()
   ↓
4. visited30Days 업데이트
   ↓
5. UnifiedFogOverlayWidget 렌더링
   ↓
6. TileUtils.getKm1TileCenter() 호출
```

---

## 🚨 긴급 확인 필요

### `map_fog_handler.dart`의 `_extractPositionFromTileId()` 사용 여부

**파일 위치:**
- `ppamalpha/lib/features/map_system/handlers/map_fog_handler.dart`

**확인 필요:**
```dart
// 이 함수가 실제로 호출되는지?
// 호출된다면 → 중국 좌표 문제의 또 다른 원인!
```

**grep 결과 확인:**
```bash
grep "_extractPositionFromTileId" ppamalpha/lib/**/*.dart
```

---

## 📝 정리 요약

### 삭제 가능 (사용 안 함)
- ❌ `fog_tile_service.dart` (242줄)
- ❌ `fog_of_war_manager.dart` (250줄+)
- ❌ `visit_manager.dart` (100줄+)
- ❌ `VisitTileService._centerFromAnyTileId()`
- ❌ `VisitTileService.getVisitedTilesInRadius()`
- ⚠️ `VisitTileService.getVisitedTilePositions()` (통계용 유지 가능)

### 수정 필요 (사용 중)
- 🔧 `map_fog_handler._extractPositionFromTileId()` → `TileUtils.getKm1TileCenter()` 사용

### 정상 작동 (유지)
- ✅ `TileUtils.getKm1TileId()`
- ✅ `TileUtils.getKm1TileCenter()` (수정됨)
- ✅ `VisitTileService.updateCurrentTileVisit()`
- ✅ `VisitTileService.upsertVisitedTiles()`
- ✅ `VisitTileService.getFogLevel1TileIdsCached()`
- ✅ `TileProvider`

---

## 💬 다음 조치

**수정을 진행할까요?**

1. ✅ **긴급**: `map_fog_handler._extractPositionFromTileId()` 수정
2. 🗑️ **권장**: 미사용 파일 3개 삭제
3. 🧹 **선택**: 미사용 함수들 정리


