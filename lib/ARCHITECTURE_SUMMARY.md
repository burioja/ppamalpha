# 🏛️ Clean Architecture 프로젝트 구조 요약

## 📊 현재 상태

### ✅ 완료된 작업

1. **폴더 구조 생성** ✅
   - core/, shared/, features/, config/ 전체 구조 생성
   - 8개 feature별 3계층 구조 생성

2. **Controller/Helper 분리 완료** ✅  
   - 19개 Controller & Helper 파일 생성
   - 총 2,630줄의 비즈니스 로직 분리

3. **문서화 완료** ✅
   - REFACTORING_PLAN.md
   - CLEAN_ARCHITECTURE_STRUCTURE.md
   - MIGRATION_GUIDE.md

### ⏳ 다음 단계 (사용자 작업)

1. **파일 이동** (MIGRATION_GUIDE.md 참고)
2. **Import 수정**
3. **빌드 테스트**
4. **검증**

---

## 📂 새로운 구조 (최종)

```
lib/
├── 📦 core/                        [공통 핵심]
│   ├── di/                          # Dependency Injection
│   ├── constants/                   # 상수
│   ├── errors/                      # 에러 처리
│   ├── network/                     # 네트워크
│   ├── theme/                       # 테마
│   ├── utils/                       # 유틸
│   └── widgets/                     # 공통 위젯
│
├── 🔗 shared/                      [Feature 간 공유]
│   ├── data/
│   │   ├── models/                  # User, Post, Place, Marker, Map
│   │   ├── repositories/
│   │   └── datasources/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   └── services/                    # Auth, Storage, Analytics
│
├── 🎯 features/                    [기능 모듈]
│   ├── 🔐 auth/                    [인증]
│   │   └── presentation/screens/    (3개 화면)
│   │
│   ├── 🗺️ map/                     [지도] 
│   │   ├── data/models/             (2개)
│   │   ├── domain/usecases/         (4개)
│   │   └── presentation/
│   │       ├── providers/           (2개)
│   │       ├── screens/             (1개)
│   │       └── widgets/             (8개)
│   │
│   ├── 📮 post/                    [포스트]
│   │   ├── data/models/             (1개)
│   │   ├── domain/usecases/         (7개)
│   │   └── presentation/
│   │       ├── screens/             (6개)
│   │       └── widgets/             (10개)
│   │
│   ├── 🏢 place/                   [장소]
│   │   ├── domain/usecases/         (5개)
│   │   └── presentation/
│   │       ├── screens/             (6개)
│   │       └── widgets/
│   │
│   ├── 📊 dashboard/               [대시보드]
│   │   ├── domain/usecases/         (3개)
│   │   └── presentation/
│   │       ├── screens/             (7개)
│   │       └── widgets/             (3개)
│   │
│   ├── ⚙️ settings/                [설정]
│   │   ├── domain/usecases/         (5개)
│   │   └── presentation/screens/    (1개)
│   │
│   ├── 🏪 store/                   [스토어]
│   │   └── presentation/screens/    (1개)
│   │
│   └── 👨‍💼 admin/                   [관리자]
│       └── presentation/
│           ├── screens/             (1개)
│           └── widgets/             (1개)
│
├── ⚙️ config/                      [앱 설정]
│   ├── routes/                      # 라우팅
│   ├── environment/                 # 환경 설정
│   └── localization/                # 다국어
│
└── 📱 app.dart                     [진입점]
```

---

## 📊 파일 통계

### 생성된 파일 (19개)

| 위치 | 파일 수 | 총 라인 수 |
|------|---------|------------|
| map/controllers | 4개 | 664줄 |
| map/widgets | 1개 | 360줄 |
| map/state | 1개 | 117줄 |
| map/models | 1개 | 26줄 |
| post/controllers | 5개 | 561줄 |
| post/widgets | 1개 | 303줄 |
| post/state | 1개 | 28줄 |
| place/controllers | 1개 | 143줄 |
| dashboard/controllers | 1개 | 178줄 |
| settings/controllers | 1개 | 124줄 |
| core/helpers | 2개 | 200줄 |
| **총계** | **19개** | **2,630줄** |

### 기존 파일 (이동 대상)

| 카테고리 | 파일 수 | 비고 |
|----------|---------|------|
| Screens | ~40개 | features/*/presentation/screens/ |
| Widgets | ~30개 | features/*/presentation/widgets/ 또는 core/widgets/ |
| Models | ~15개 | shared/data/models/ |
| Services | ~25개 | shared/services/ 또는 datasources/ |
| **총계** | **~110개** | **이동 필요** |

---

## 🔄 주요 변경 사항

### 1. Controller → UseCase 패턴

**Before:**
```dart
// lib/features/map_system/controllers/location_controller.dart
class LocationController {
  static Future<LatLng?> getCurrentLocation() async {
    // ...
  }
}

// 사용
final position = await LocationController.getCurrentLocation();
```

**After:**
```dart
// lib/features/map/domain/usecases/get_current_location.dart
class GetCurrentLocationUseCase {
  Future<LatLng?> call() async {
    // ...
  }
}

// 사용 (DI)
final useCase = locator<GetCurrentLocationUseCase>();
final position = await useCase();
```

### 2. 3계층 구조

```
Feature
├── Data Layer       (Models, Repositories 구현, DataSources)
├── Domain Layer     (Entities, Repositories 인터페이스, UseCases)
└── Presentation     (Providers, Screens, Widgets)
```

### 3. Import 경로 변경

| 항목 | Before | After |
|------|--------|-------|
| Models | `core/models/user/` | `shared/data/models/user/` |
| Controllers | `features/map_system/controllers/` | `features/map/domain/usecases/` |
| Screens | `features/map_system/screens/` | `features/map/presentation/screens/` |
| Widgets | `features/map_system/widgets/` | `features/map/presentation/widgets/` |

---

## 🎯 Benefits (장점)

### 1. **확장성** 📈
- 새 Feature 추가 시 기존 코드 영향 없음
- Feature별 독립 개발 가능
- 팀 단위로 Feature 분리 가능

### 2. **유지보수성** 🔧
- 각 계층의 책임이 명확
- 코드 위치를 쉽게 찾을 수 있음
- 변경 시 영향 범위가 제한적

### 3. **테스트 용이성** ✅
- UseCase는 순수 함수로 쉽게 테스트
- Repository는 Mock 가능
- Presentation은 Provider로 상태 테스트

### 4. **재사용성** ♻️
- Shared 계층을 통한 코드 재사용
- Domain 계층은 플랫폼 독립적
- UseCase를 여러 화면에서 활용

### 5. **협업** 👥
- Feature별 충돌 최소화
- 명확한 컨벤션
- 코드 리뷰 용이

---

## 📝 마이그레이션 순서

### Phase 1-3: 기반 작업 (1-2일)
1. ✅ Core & Shared 폴더 구조 생성
2. ✅ Feature별 폴더 구조 생성
3. ⏳ Models 이동 (shared/data/models/)

### Phase 4-6: Feature 재구성 (3-5일)
4. ⏳ Auth Feature 이동
5. ⏳ Map Feature 이동  
6. ⏳ Post Feature 이동

### Phase 7-9: 마무리 (2-3일)
7. ⏳ Place, Dashboard, Settings 이동
8. ⏳ Config 정리 (routes, localization)
9. ⏳ 검증 및 테스트

**총 예상 기간: 6-10일**

---

## ⚠️ 중요 체크포인트

### 각 Phase 완료 후 반드시 확인

- [ ] **빌드 성공**: `flutter build apk --debug`
- [ ] **Import 에러 없음**: `flutter analyze`
- [ ] **린트 통과**: `dart fix --apply`
- [ ] **Hot Reload 작동**: 개발 중 정상 동작 확인
- [ ] **기능 테스트**: 해당 Feature 화면 동작 확인

### 백업 필수

```bash
# 작업 전
git add .
git commit -m "Before Phase X migration"
git branch backup-phase-X

# 문제 발생 시
git checkout backup-phase-X
```

---

## 🔗 참고 문서

1. **REFACTORING_PLAN.md**
   - 전체 리팩토링 계획
   - 구조 설계 근거

2. **CLEAN_ARCHITECTURE_STRUCTURE.md**
   - 상세한 폴더 구조
   - 파일별 매핑 정보

3. **MIGRATION_GUIDE.md**
   - 단계별 마이그레이션 가이드
   - 명령어 및 코드 예시
   - Import 변경 패턴

---

## 💬 질문 & 답변

### Q1: 왜 Controller를 UseCase로 변경하나요?
**A:** Clean Architecture의 Domain Layer는 순수한 비즈니스 로직만 포함해야 합니다. UseCase는 하나의 기능을 수행하는 단일 책임 클래스로, 테스트와 재사용이 쉽습니다.

### Q2: 기존 Provider는 어떻게 되나요?
**A:** Provider는 Presentation Layer에 그대로 유지됩니다. 다만, Controller 대신 UseCase를 호출하도록 변경됩니다.

### Q3: 모든 파일을 한 번에 이동해야 하나요?
**A:** 아니요! Feature별로 단계적으로 이동하는 것을 권장합니다. 각 Phase 완료 후 테스트하세요.

### Q4: Import 경로를 일괄 변경할 수 있나요?
**A:** VSCode의 "Find in Files" (Ctrl+Shift+F)와 정규식을 사용하면 일괄 변경 가능합니다. MIGRATION_GUIDE.md 참고하세요.

### Q5: 기존 코드도 삭제해야 하나요?
**A:** 모든 마이그레이션이 완료되고 테스트가 끝난 후에 삭제하세요. 그 전까지는 백업 목적으로 유지하는 것이 안전합니다.

---

## ✅ 최종 목표

```
✨ 대규모 팀 협업에 최적화된 Clean Architecture 구조
✨ 각 Feature가 독립적으로 개발/테스트 가능
✨ 명확한 책임 분리로 유지보수 용이
✨ 새로운 Feature 추가가 쉬운 확장성
```

---

**🚀 준비 완료! MIGRATION_GUIDE.md를 참고하여 단계적으로 진행하세요!**

