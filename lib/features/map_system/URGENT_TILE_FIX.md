# 🚨 긴급 타일 수정 사항

## 발견된 문제

### ❌ **중국 좌표 생성의 진짜 원인**

`ppamalpha/lib/features/map_system/handlers/map_fog_handler.dart` (167줄, 181-202줄)

```dart
// loadVisitedLocations()에서 호출
for (final doc in visitedTiles.docs) {
  final tileId = doc.id;
  final position = _extractPositionFromTileId(tileId);  // ← 여기!
  if (position != null) {
    visitedPositions.add(position);  // ← 중국 좌표 추가됨!
  }
}

// _extractPositionFromTileId() - 구버전 로직
LatLng? _extractPositionFromTileId(String tileId) {
  final tileLat = int.tryParse(parts[1]);  // 예: 37566
  final tileLng = int.tryParse(parts[2]);  // 예: 126978
  
  const double tileSize = 0.009;  // ❌ 잘못된 상수
  return LatLng(
    tileLat * tileSize + (tileSize / 2),     // 37566 * 0.009 = 338.094 ❌
    tileLng * tileSize + (tileSize / 2),     // 126978 * 0.009 = 1142.802 ❌
  );
}
```

**결과:**
- `tile_37566_126978` (서울)
- → `LatLng(338.094, 1142.802)` (잘못됨!)
- → 이후 계산에서 이상한 값으로 변환됨

## ✅ 수정 방법

### 수정 1: `map_fog_handler.dart` (181-202줄)

**Before:**
```dart
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    if (tileId.startsWith('tile_')) {
      final parts = tileId.split('_');
      if (parts.length == 3) {
        final tileLat = int.tryParse(parts[1]);
        final tileLng = int.tryParse(parts[2]);
        if (tileLat != null && tileLng != null) {
          const double tileSize = 0.009;  // ❌
          return LatLng(
            tileLat * tileSize + (tileSize / 2),  // ❌
            tileLng * tileSize + (tileSize / 2),  // ❌
          );
        }
      }
    }
    return null;
  } catch (e) {
    debugPrint('타일 ID에서 좌표 추출 실패: $e');
    return null;
  }
}
```

**After:**
```dart
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    // ✅ TileUtils의 표준 메서드 사용
    return TileUtils.getKm1TileCenter(tileId);
  } catch (e) {
    debugPrint('타일 ID에서 좌표 추출 실패: $tileId - $e');
    return null;
  }
}
```

---

### 수정 2: 다른 파일들도 확인

#### 파일들:
1. `lib/features/map_system/screens/parts/map_screen_fog_of_war.dart` (208줄)
2. `lib/features/map_system/screens/parts/map_screen_fog_methods.dart`
3. `lib/features/map_system/screens/map_screen_part_aa`
4. `lib/features/map_system/screens/map_screen_part_ac`

**모두 같은 문제:**
```dart
LatLng? _extractPositionFromTileId(String tileId) {
  const double tileSize = 0.009;  // ❌ 잘못된 로직
  return LatLng(
    tileLat * tileSize + (tileSize / 2),
    tileLng * tileSize + (tileSize / 2),
  );
}
```

**통일된 수정:**
```dart
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    return TileUtils.getKm1TileCenter(tileId);
  } catch (e) {
    return null;
  }
}
```

---

## 🎯 수정 우선순위

### 🔴 긴급 (즉시)
1. **`ppamalpha/lib/features/map_system/handlers/map_fog_handler.dart`**
   - 181-202줄 `_extractPositionFromTileId()` 수정
   - **영향도: 높음** (현재 사용 중)

### 🟡 중요 (가능하면)
2. **`lib/features/map_system/screens/parts/` 파일들**
   - 모두 같은 함수 수정
   - **영향도: 중간** (part 파일들 사용 여부 불명확)

### 🟢 정리 (나중에)
3. **미사용 파일 삭제**
   - `fog_tile_service.dart`
   - `fog_of_war_manager.dart`
   - `visit_manager.dart`
   - **영향도: 없음** (사용 안 함)

---

## 📊 예상 효과

수정 후:
```
타일 ID: tile_37566_126978
  ↓ (Before)
좌표: 338.094, 1142.802 ❌ (중국 밖)
  ↓ (After)
좌표: 37.5665, 126.9785 ✅ (서울)
```

**Level 2 fog:**
- Before: 화면 밖 (중국 좌표) → 안 보임
- After: 실제 방문 위치 → 정상 표시


