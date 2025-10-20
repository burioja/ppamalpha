# 🎯 Level 2 타일 휘발성 문제 - 완전 정리

## ❌ 문제: 앱 재시작 시 Level 2 초기화

**현상:**
- 앱 실행 중: Level 2 (회색 영역) 정상 표시 ✅
- 앱 종료 후 재실행: Level 2 사라짐 ❌
- 마치 휘발성 메모리처럼 동작

---

## 🔍 근본 원인: 필드명 불일치

### Firebase 필드명이 2가지로 혼용됨

#### 저장 시스템 1: VisitTileService (주 사용)
```dart
// lib/features/map_system/services/fog_of_war/visit_tile_service.dart (24-28줄)

await _doc(user.uid, tileId).set({
  'tileId': tileId,
  'lastVisitTime': FieldValue.serverTimestamp(),  // ✅ lastVisitTime
  'visitCount': FieldValue.increment(1),
}, SetOptions(merge: true));
```

**사용처:**
- TileProvider.updatePosition() (284줄)
- LocationController
- MapLocationHandler

---

#### 저장 시스템 2: TilesRepository (부분 사용)
```dart
// lib/core/repositories/tiles_repository.dart (48-50줄, 160줄)

await visitRef.set({
  'tileId': tileId,
  'firstVisitedAt': FieldValue.serverTimestamp(),
  'lastVisitedAt': FieldValue.serverTimestamp(),  // ❌ lastVisitedAt (다름!)
  'visitCount': 1,
});
```

**사용처:**
- 거의 사용 안 됨 (batchUpdateVisits만)

---

#### 로드 시스템: TilesRepository
```dart
// lib/core/repositories/tiles_repository.dart (81줄)

final snapshot = await _firestore
    .collection('users')
    .doc(user.uid)
    .collection('visitedTiles')
    .where('lastVisitedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)  // ❌ lastVisitedAt
    .get();
```

**문제:**
- Firebase에는 `lastVisitTime` 필드로 저장됨
- 하지만 `lastVisitedAt` 필드로 조회
- → **쿼리 결과 0개!**
- → `_visited30Days = {}` (빈 Set)
- → Level 2 타일 없음

---

## 🔬 증거

### Firebase 실제 데이터:
```json
users/{uid}/visited_tiles/tile_37566_126978
{
  "tileId": "tile_37566_126978",
  "lastVisitTime": Timestamp(2025-01-20 10:30:00),  // ← 이 필드명
  "visitCount": 5
}
```

### Repository 쿼리:
```dart
.where('lastVisitedAt', isGreaterThanOrEqualTo: ...)  // ← 다른 필드명 찾음
```

**결과:**
```
쿼리 결과: 0개 문서
_visited30Days: {} (빈 Set)
Level 2 타일: 표시 안 됨
```

---

## ✅ 해결 방법

### Option 1: Repository 쿼리 수정 (권장)
```dart
// lib/core/repositories/tiles_repository.dart (81줄)

// Before
.where('lastVisitedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)  // ❌

// After
.where('lastVisitTime', isGreaterThanOrEqualTo: thirtyDaysAgo)  // ✅
```

**이유:**
- VisitTileService가 주로 사용되므로 `lastVisitTime`이 표준
- TilesRepository를 표준에 맞추는 것이 간단

---

### Option 2: VisitTileService 필드명 변경 (비권장)
```dart
// lib/features/map_system/services/fog_of_war/visit_tile_service.dart (26줄)

// Before
'lastVisitTime': FieldValue.serverTimestamp(),  // ✅

// After
'lastVisitedAt': FieldValue.serverTimestamp(),  // ❌ 기존 데이터 호환 깨짐
```

**문제:**
- 기존에 저장된 모든 타일 데이터가 `lastVisitTime` 필드 사용
- 변경하면 기존 데이터 못 읽음
- 데이터 마이그레이션 필요

---

## 🎯 최종 판단: Option 1 적용

### 수정할 파일: `tiles_repository.dart` (2곳)

#### 1. getVisitedTilesLast30Days() (81줄)
```dart
// Before
.where('lastVisitedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)

// After
.where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
```

#### 2. evictOldTiles() (217줄)
```dart
// Before
.where('lastVisitedAt', isLessThan: ninetyDaysAgo)

// After
.where('lastVisitTime', isLessThan: Timestamp.fromDate(ninetyDaysAgo))
```

---

## 📊 수정 후 예상 동작

### 앱 시작 시:
```
1. TileProvider 생성자 호출
   ↓
2. _loadVisitedTiles() 호출
   ↓
3. TilesRepository.getVisitedTilesLast30Days()
   ↓
4. Firebase 쿼리: lastVisitTime >= 30일 전  ✅
   ↓
5. 쿼리 결과: 10개 타일 (예시)
   ↓
6. _visited30Days = {tile_37566_126978, ...}  ✅
   ↓
7. notifyListeners()
   ↓
8. UnifiedFogOverlayWidget 렌더링
   ↓
9. Level 2 회색 영역 표시  ✅
```

**로그:**
```
✅ 타일 로드 완료: 50개 (최근 30일: 10개)
🎯 Level 2 중심점: 10개 (visited30Days: 10개)
```

---

## 🔧 추가 개선사항

### 1. 컬렉션명도 통일 필요

**현재:**
- `visitedTiles` (TilesRepository)
- `visited_tiles` (VisitTileService)

**Firebase는 대소문자 구분!**

**확인 필요:**
- 실제 Firebase에 어느 컬렉션이 사용되고 있는가?
- 두 개 다 존재하는가?

### 2. Timestamp 타입 변환

```dart
// ✅ 올바른 방법
.where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))

// ❌ 잘못된 방법
.where('lastVisitTime', isGreaterThanOrEqualTo: thirtyDaysAgo)  // DateTime 직접 사용
```

---

## 📝 수정 요약

**1개 파일, 2곳 수정:**
- `lib/core/repositories/tiles_repository.dart`
  - Line 81: `lastVisitedAt` → `lastVisitTime`
  - Line 217: `lastVisitedAt` → `lastVisitTime`

**예상 효과:**
- ✅ 앱 재시작 시 Level 2 타일 정상 로드
- ✅ 30일 방문 기록 지속성 확보
- ✅ 더 이상 휘발성 아님

