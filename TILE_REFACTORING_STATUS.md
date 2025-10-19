# 🔄 타일(Tile) & Fog of War 리팩토링 현황

## 📊 현재 상태

### ✅ 완료된 리팩토링 (5개)

| 파일 | 경로 | 라인 수 | 상태 | 비고 |
|------|------|---------|------|------|
| `tiles_repository.dart` | `lib/core/repositories/` | 231 | ✅ 완료 | Clean Architecture |
| `tile_provider.dart` | `lib/features/map_system/providers/` | 246 | ✅ 완료 | 상태 관리 |
| `fog_service.dart` | `lib/features/map_system/services/fog/` | 286 | ✅ NEW | fog_controller + map_fog_handler 통합 |
| ~~`tile_provider.dart`~~ | ~~`services/tiles/`~~ | - | ✅ 삭제 | 중복 제거 |
| `marker_clustering_service.dart` | `lib/features/map_system/services/clustering/` | 130 | ✅ 완료 | 기존 |

**총 완료**: 893 라인

---

## 🔄 레거시 파일 현황

### 🟡 Controller/Handler (2개, 578라인) - Deprecated

| 파일 | 라인 수 | 대체 파일 | 상태 |
|------|---------|----------|------|
| `fog_controller.dart` | 239 | `services/fog/fog_service.dart` | ⚠️ Deprecated |
| `map_fog_handler.dart` | 339 | `services/fog/fog_service.dart` | ⚠️ Deprecated |

**권장**: 새로운 `FogService` 사용

---

### 🟢 Services (6개, 1,253라인) - 유지

| 파일 | 경로 | 라인 수 | 역할 | 상태 |
|------|------|---------|------|------|
| **Fog of War** | | | | |
| `fog_of_war_manager.dart` | `services/fog_of_war/` | 240 | Fog 전체 관리 | 🟢 유지 |
| `fog_tile_service.dart` | `services/fog_of_war/` | 266 | Fog 타일 서비스 | 🟢 유지 |
| `visit_tile_service.dart` | `services/fog_of_war/` | 302 | 타일 방문 기록 | ⚠️ → Repository |
| `visit_manager.dart` | `services/fog_of_war/` | 126 | 방문 관리 | ⚠️ → Repository |
| **External** | | | | |
| `osm_fog_service.dart` | `services/external/` | 355 | OSM Fog 서비스 | 🟢 유지 |
| **Tiles** | | | | |
| `tile_cache_manager.dart` | `services/tiles/` | 225 | 타일 캐시 관리 | 🟢 유지 |

**권장**: 
- `visit_*` 파일들은 `TilesRepository` 사용 권장
- 나머지는 현재 상태 유지

---

### 🟣 Widgets (3개, 1,094라인)

| 파일 | 경로 | 라인 수 | 역할 | 상태 |
|------|------|---------|------|------|
| `fog_overlay_widget.dart` | `widgets/` | 165 | Fog 오버레이 위젯 | ⚠️ Deprecated |
| `unified_fog_overlay_widget.dart` | `widgets/` | 179 | 통합 Fog 오버레이 | ✅ **사용 권장** |
| `post_tile_card.dart` | `post_system/widgets/` | 750 | 포스트 타일 카드 | 🟢 유지 (UI) |

**권장**: `unified_fog_overlay_widget.dart`만 사용

---

### 🟤 Screens (3개, 2,179라인) - 리팩토링 필요

| 파일 | 경로 | 라인 수 | 역할 | 상태 |
|------|------|---------|------|------|
| `map_screen_fog.dart` | `screens/` | 96 | Fog 버전 맵 스크린 | 🔴 정리 필요 |
| `map_screen_fog_methods.dart` | `screens/parts/` | 1,772 | **거대 파일** | 🔴 **분할 필요** |
| `map_screen_fog_of_war.dart` | `screens/parts/` | 311 | Fog of War 로직 | 🔴 정리 필요 |

**권장**: 
- `map_screen_fog_methods.dart` 분할 (우선순위 높음)
- 로직을 Service/Provider로 이동

---

### 🟡 Utils (3개, 469라인) - 유지

| 파일 | 경로 | 라인 수 | 역할 | 상태 |
|------|------|---------|------|------|
| `tile_utils.dart` | `utils/` | 282 | 타일 유틸리티 | 🟢 유지 |
| `s2_tile_utils.dart` | `utils/` | 103 | S2 타일 유틸리티 | 🟢 유지 |
| `tile_image_generator.dart` | `map_system/utils/` | 84 | 타일 이미지 생성 | 🟢 유지 |

---

## 📈 리팩토링 진행률

### 전체 통계

```
총 파일 수: 20개
총 라인 수: 6,622 라인

✅ 완료: 4개 (893 라인) - 13.5%
🔄 진행중: 1개 (286 라인) - 4.3%
⚠️ Deprecated: 4개 (895 라인) - 13.5%
🟢 유지: 8개 (2,369 라인) - 35.8%
🔴 리팩토링 필요: 3개 (2,179 라인) - 32.9%
```

### 카테고리별 진행률

| 카테고리 | 완료율 | 상태 |
|----------|--------|------|
| **Core (Repository/Model)** | 100% | ✅ 완료 |
| **Provider** | 100% | ✅ 완료 |
| **Service (새로운 구조)** | 50% | 🔄 진행 중 |
| **Controller/Handler** | 0% → Deprecated | ⚠️ 대체됨 |
| **Widgets** | 33% | 🔄 진행 중 |
| **Screens** | 0% | 🔴 대기 |
| **Utils** | 100% (유지) | 🟢 완료 |

---

## 🎯 다음 단계

### Priority 1: 거대 파일 분할 (긴급)

**`map_screen_fog_methods.dart` (1,772줄) 분할**

#### 분할 계획

1. **FogOverlayService** (~400줄)
   - Fog 오버레이 렌더링 로직
   - 위치: `services/fog/`

2. **FogUpdateService** (~400줄)
   - 회색 영역 업데이트
   - 위치: `services/fog/`

3. **MarkerFilterService** (~300줄)
   - 마커 필터링 로직
   - 위치: `services/filtering/`

4. **나머지** (~670줄)
   - UI 헬퍼 메서드들
   - 위치: `screens/parts/` (간소화)

### Priority 2: Deprecated 파일 제거

1. `fog_controller.dart` 삭제
2. `map_fog_handler.dart` 삭제
3. `fog_overlay_widget.dart` 삭제
4. `map_screen_fog.dart` 정리

### Priority 3: 통합 및 최적화

1. visit 관련 로직을 `TilesRepository`로 완전 이전
2. `unified_fog_overlay_widget.dart`만 사용하도록 통일
3. 캐시 최적화 (LRU + TTL)

---

## 💡 사용 가이드

### ✅ 권장 사용 패턴

#### Fog 관련 로직

```dart
// ❌ BAD (Deprecated)
import '../controllers/fog_controller.dart';
final result = FogController.rebuildFogWithUserLocations(...);

// ✅ GOOD (New)
import '../services/fog/fog_service.dart';
final result = FogService.rebuildFogWithUserLocations(...);
```

#### 타일 방문 기록

```dart
// ❌ BAD (Old Service)
import '../services/fog_of_war/visit_tile_service.dart';
await VisitTileService.updateCurrentTileVisit(tileId);

// ✅ GOOD (Repository)
import '../../../core/repositories/tiles_repository.dart';
final repo = TilesRepository();
await repo.updateVisit(tileId);
```

#### 타일 상태 관리

```dart
// ❌ BAD (Old Provider)
import '../services/tiles/tile_provider.dart';

// ✅ GOOD (New Provider)
import '../providers/tile_provider.dart';
final tileProvider = context.watch<TileProvider>();
```

#### Fog 오버레이 위젯

```dart
// ❌ BAD (Old Widget)
import '../widgets/fog_overlay_widget.dart';
FogOverlayWidget(...)

// ✅ GOOD (Unified Widget)
import '../widgets/unified_fog_overlay_widget.dart';
UnifiedFogOverlayWidget(...)
```

---

## 📁 새로운 파일 구조

```
lib/
  ├── core/
  │   └── repositories/
  │       └── tiles_repository.dart              ✨ NEW (231줄)
  │
  └── features/
      └── map_system/
          ├── providers/
          │   └── tile_provider.dart             ✨ NEW (246줄)
          │
          ├── services/
          │   ├── fog/                           ✨ NEW 폴더
          │   │   └── fog_service.dart           ✨ NEW (286줄)
          │   │
          │   ├── clustering/
          │   │   └── marker_clustering_service.dart  (130줄)
          │   │
          │   ├── fog_of_war/                    🟢 유지
          │   │   ├── fog_of_war_manager.dart
          │   │   ├── fog_tile_service.dart
          │   │   ├── visit_tile_service.dart    ⚠️ → Repository 권장
          │   │   └── visit_manager.dart         ⚠️ → Repository 권장
          │   │
          │   ├── external/
          │   │   └── osm_fog_service.dart       🟢 유지
          │   │
          │   └── tiles/
          │       └── tile_cache_manager.dart    🟢 유지
          │
          ├── widgets/
          │   ├── unified_fog_overlay_widget.dart    ✅ 사용 권장
          │   └── fog_overlay_widget.dart            ⚠️ Deprecated
          │
          ├── controllers/                       ⚠️ Deprecated 폴더
          │   └── fog_controller.dart            ⚠️ → FogService
          │
          └── handlers/                          ⚠️ Deprecated 폴더
              └── map_fog_handler.dart           ⚠️ → FogService
```

---

## ✅ 체크리스트

### 개발자 확인사항

#### 새 코드 작성 시

- [ ] `FogService` 사용 (fog_controller X)
- [ ] `TilesRepository` 사용 (visit_tile_service X)
- [ ] `TileProvider` (providers/) 사용
- [ ] `UnifiedFogOverlayWidget` 사용

#### 기존 코드 수정 시

- [ ] Deprecated 파일 참조 제거
- [ ] 새로운 Service/Repository로 마이그레이션
- [ ] Provider 패턴 적용

---

## 🎉 완료!

타일 관련 리팩토링이 **13.5%** 완료되었습니다.

**핵심 성과**:
- ✅ Clean Architecture 적용
- ✅ 중복 코드 제거
- ✅ Fog 로직 통합
- ✅ Repository 분리

**다음**: 거대 파일 분할 (map_screen_fog_methods.dart, 1,772줄)

