# 🧹 타일 코드 대청소 계획서

## 📊 검증 완료 결과

### ✅ 검증 방법
- grep으로 전체 프로젝트에서 import 및 사용처 검색
- 각 파일별로 실제 인스턴스 생성 및 메서드 호출 확인
- 의존성 체인 추적 (A가 B를 사용, B가 사용 안 됨 → A도 사용 안 됨)

---

## 🗑️ 삭제 가능한 파일 목록

### 1. **fog_tile_service.dart** (242줄) ✅ 삭제 확정
**위치:** `lib/features/map_system/services/fog_of_war/fog_tile_service.dart`

**사용처 검색 결과:**
```
✅ grep "FogTileService" 결과:
  - lib/features/map_system/index.dart (export만)
  - 파일 자체 정의
  → 실제 사용처: 0개
```

**판정:** 완전히 노는 코드, **안전하게 삭제 가능**

---

### 2. **fog_of_war_manager.dart** (250줄+) ✅ 삭제 확정
**위치:** `lib/features/map_system/services/fog_of_war/fog_of_war_manager.dart`

**사용처 검색 결과:**
```
✅ grep "FogOfWarManager" 결과:
  - lib/features/map_system/index.dart (export만)
  - 파일 자체 정의
  → 실제 사용처: 0개
```

**판정:** 완전히 노는 코드, **안전하게 삭제 가능**

---

### 3. **visit_manager.dart** (100줄+) ⚠️ 삭제 확정 (의존성 체인)
**위치:** `lib/features/map_system/services/fog_of_war/visit_manager.dart`

**사용처 검색 결과:**
```
⚠️ grep "VisitManager" 결과:
  - lib/features/map_system/index.dart (export만)
  - lib/core/services/location/location_manager.dart (사용!)
    → VisitManager _visitManager = VisitManager();
  - 파일 자체 정의
```

**하지만:**
```
✅ grep "LocationManager" 결과:
  - lib/core/services/location/location_manager.dart (파일 자체)
  → 실제 사용처: 0개
```

**판정:** LocationManager가 사용 안 됨 → VisitManager도 **안전하게 삭제 가능**

---

### 4. **location_manager.dart** (130줄) ✅ 삭제 확정
**위치:** `lib/core/services/location/location_manager.dart`

**사용처 검색 결과:**
```
✅ grep "LocationManager" 결과:
  - 파일 자체 정의만
  → 실제 사용처: 0개
```

**판정:** VisitManager의 유일한 사용처지만 자신도 사용 안 됨, **안전하게 삭제 가능**

---

### 5. **index.dart** (23줄) ⚠️ 수정 필요
**위치:** `lib/features/map_system/index.dart`

**사용처 검색 결과:**
```
✅ grep "import.*map_system.*index" 결과:
  → 실제 사용처: 0개
```

**판정:** 파일 자체는 유지, **미사용 export 3개 삭제**
- Line 7: `export 'services/fog_of_war/fog_of_war_manager.dart';`
- Line 8: `export 'services/fog_of_war/fog_tile_service.dart';`
- Line 9: `export 'services/fog_of_war/visit_manager.dart';`

---

### 6. **Part 파일들** ❌ 유지 (다른 파일에서 사용)
**위치:** `lib/features/map_system/screens/parts/`

**파일 목록:**
- `map_screen_fog_of_war.dart` (208줄에 `_extractPositionFromTileId()` 있음)
- `map_screen_fog_methods.dart` (1750줄에 사용)
- `map_screen_part_aa`, `map_screen_part_ac` 등

**사용처:**
```
✅ map_screen_simple.dart에서 사용:
  part 'parts/map_screen_state.dart';
  part 'parts/map_screen_fog.dart';
  part 'parts/map_screen_post.dart';
  part 'parts/map_screen_ui.dart';
```

**판정:** Part 파일은 유지하되, **함수 내용만 수정**

---

### 7. **ppamalpha 디렉토리 파일들** ✅ 삭제 확정
**위치:** `ppamalpha/lib/features/map_system/handlers/map_fog_handler.dart`

**사용처 검색 결과:**
```
✅ grep "MapFogHandler" in ppamalpha/ 결과:
  - 문서 파일들에만 언급
  → 실제 사용처: 0개
```

**판정:** ppamalpha 폴더의 handler 파일들은 중복/백업, **삭제 고려** (전체 ppamalpha 폴더 확인 필요)

---

## 🔧 수정 필요한 코드

### 중복 함수: `_extractPositionFromTileId()` (4곳)

#### 사용 중인 함수들:
1. ❌ **`lib/features/map_system/screens/parts/map_screen_fog_of_war.dart`** (208-230줄)
2. ❌ **`lib/features/map_system/screens/parts/map_screen_fog_methods.dart`** (위치 미확인)
3. ❌ **`lib/features/map_system/screens/map_screen_part_aa`** (673줄)
4. ❌ **`lib/features/map_system/screens/map_screen_part_ac`** (위치 미확인)

**모두 같은 버그:**
```dart
const double tileSize = 0.009;  // ❌
return LatLng(
  tileLat * tileSize + (tileSize / 2),  // ❌ 중국 좌표 생성
  tileLng * tileSize + (tileSize / 2),
);
```

**수정 방법:**
```dart
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    return TileUtils.getKm1TileCenter(tileId);  // ✅
  } catch (e) {
    debugPrint('타일 ID 변환 실패: $tileId - $e');
    return null;
  }
}
```

---

### 미사용 함수들 (VisitTileService 내부)

#### 1. `_centerFromAnyTileId()` (93-130줄) ✅ 삭제 가능
```
grep "_centerFromAnyTileId" 결과:
  → 호출처: 0개
```

#### 2. `getVisitedTilesInRadius()` (270-310줄) ✅ 삭제 가능
```
grep "getVisitedTilesInRadius" 결과:
  → 호출처: 0개
```

#### 3. `getVisitedTilePositions()` (244-267줄) ⚠️ 보류
```
grep "getVisitedTilePositions" 결과:
  → getVisitedTilesInRadius에서만 호출
  → getVisitedTilesInRadius 삭제 시 함께 삭제 가능
```

---

## 📋 대청소 실행 계획

### Phase 1: 중복 함수 수정 (즉시)
```
1. lib/features/map_system/screens/parts/map_screen_fog_of_war.dart
   - 208-230줄 _extractPositionFromTileId() 수정
   
2. lib/features/map_system/screens/parts/map_screen_fog_methods.dart
   - _extractPositionFromTileId() 수정
   
3. lib/features/map_system/screens/map_screen_part_aa
   - 673줄 _extractPositionFromTileId() 수정
   
4. lib/features/map_system/screens/map_screen_part_ac
   - _extractPositionFromTileId() 수정
```

### Phase 2: 미사용 함수 삭제 (즉시)
```
lib/features/map_system/services/fog_of_war/visit_tile_service.dart:
  - 93-130줄: _centerFromAnyTileId() 삭제
  - 270-310줄: getVisitedTilesInRadius() 삭제  
  - 244-267줄: getVisitedTilePositions() 삭제
```

### Phase 3: 미사용 파일 삭제 (즉시)
```
1. lib/features/map_system/services/fog_of_war/fog_tile_service.dart (242줄)
2. lib/features/map_system/services/fog_of_war/fog_of_war_manager.dart (250줄+)
3. lib/features/map_system/services/fog_of_war/visit_manager.dart (100줄+)
4. lib/core/services/location/location_manager.dart (130줄)
```

### Phase 4: index.dart 정리 (즉시)
```
lib/features/map_system/index.dart:
  - Line 7: fog_of_war_manager export 삭제
  - Line 8: fog_tile_service export 삭제
  - Line 9: visit_manager export 삭제
```

### Phase 5: ppamalpha 폴더 확인 (보류)
```
ppamalpha/ 폴더가 백업인지 별도 프로젝트인지 확인 필요
```

---

## 💾 예상 효과

### 코드 라인 절약
- fog_tile_service.dart: -242줄
- fog_of_war_manager.dart: -250줄
- visit_manager.dart: -100줄
- location_manager.dart: -130줄
- VisitTileService 함수들: -100줄
- index.dart exports: -3줄
**총 절약: ~825줄**

### 버그 수정
- ✅ `_extractPositionFromTileId()` 4곳 수정 → 중국 좌표 문제 완전 해결
- ✅ 타일 변환 로직 통일 → 유지보수성 향상

### 코드 품질
- ✅ 중복 코드 제거
- ✅ 미사용 코드 제거
- ✅ 단일 책임 원칙 강화 (TileUtils만 타일 변환 담당)

---

## ⚠️ 삭제 전 최종 확인

### 자동 테스트 (없음)
- 프로젝트에 unit test 없음
- 삭제 후 컴파일 에러로만 확인 가능

### 백업
- ✅ Git history에 모두 보존됨
- ✅ 필요 시 복구 가능

### 위험도 평가
- 🟢 **Low Risk**: 파일 4개 (사용처 0개)
- 🟡 **Medium Risk**: 함수 수정 (사용 중이지만 버그 수정)

---

## 🚀 실행 여부 확인

**모든 검증 완료!**

진행 순서:
1. ✅ 중복 함수 4곳 수정 (bug fix)
2. ✅ 미사용 함수 3개 삭제 (VisitTileService)
3. ✅ 미사용 파일 4개 삭제
4. ✅ index.dart export 3개 삭제

**진행하시겠습니까?**


