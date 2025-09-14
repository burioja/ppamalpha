# PPAM Alpha - 전체 리팩토링 계획

## 🚀 진행 현황 체크리스트

### Phase 0: 사전 정리 작업 ✅ COMPLETED
- [x] status_provider.dart 제거 (미사용 Provider)
- [x] address_search_widget.dart 제거 (미사용 Widget)
- [x] app.dart에서 StatusProvider 등록 해제
- [x] Git 커밋 및 푸시

### Phase 1: 핵심 모델 및 서비스 정리 ✅ COMPLETED
- [x] **Models 재구성**
  - [x] `lib/core/models/` 디렉토리 생성
  - [x] `user/` 폴더 생성 및 user_model.dart, user_points_model.dart 이동
  - [x] `post/` 폴더 생성 및 post_model.dart, post_usage_model.dart 이동
  - [x] `place/` 폴더 생성 및 place_model.dart 이동
  - [x] `map/` 폴더 생성 및 fog_level.dart 이동
- [x] **Core Services 정리**
  - [x] `lib/core/services/` 디렉토리 생성
  - [x] `auth/` 폴더 생성 및 firebase_service.dart, firebase_functions_service.dart 이동
  - [x] `data/` 폴더 생성 및 user_service.dart, post_service.dart, place_service.dart 이동
  - [x] `location/` 폴더 생성 및 location_service.dart, location_manager.dart, nominatim_service.dart 이동
- [x] **Import 경로 업데이트**
  - [x] 전체 프로젝트의 import 경로 수정 (30+ 파일)
  - [x] 상대 경로에서 core 구조 기반 절대 경로로 변경
- [x] **테스트 및 검증**
  - [x] Flutter analyze 실행 (치명적 오류 없음 확인)
  - [x] Flutter 앱 실행 테스트 완료 (정상 동작 확인)
- [x] Git 커밋 및 문서화

### Phase 2: Map System 리팩토링 ✅ COMPLETED
- [x] **Fog of War 통합**
  - [x] 5개 서비스를 3개로 통합 (fog_of_war_manager.dart 유지, fog_tile_service.dart 통합, visit_manager.dart 분리)
  - [x] fog_tile_service.dart 생성 (fog_of_war_tile_provider.dart + fog_tile_provider.dart + osm_fog_service.dart 통합)
  - [x] 통합 인터페이스 정의 및 구현
- [x] **Map Screen 분할**
  - [x] 2352라인을 위젯 기반으로 분할
  - [x] Widget 기반으로 컴포넌트 분리
  - [x] map_display_widget.dart, fog_overlay_widget.dart, marker_layer_widget.dart, map_filter_widget.dart 생성
- [x] **Tile System 최적화**
  - [x] 4개 타일 서비스를 2개로 통합 (custom_tile_provider.dart + tile_prefetcher.dart → tile_provider.dart, tile_cache_manager.dart 유지)
  - [x] 캐싱 및 성능 최적화 구현
- [x] **Directory 구조 생성**
  - [x] features/map_system/ 디렉토리 생성
  - [x] screens/, services/fog_of_war/, services/tiles/, services/markers/, providers/, widgets/, utils/ 폴더 생성
- [x] **파일 이동 및 Import 경로 업데이트**
  - [x] Map 관련 파일들을 새로운 구조로 이동
  - [x] 전체 프로젝트의 import 경로 업데이트 (30+ 파일)
- [x] **테스트 및 검증**
  - [x] Flutter analyze 실행 완료
  - [x] 앱 실행 테스트 완료
- [x] **Git 커밋**
  - [x] Phase 2 완료 커밋 (7a1285b): 38 files changed, 2410 insertions(+), 1289 deletions(-)

### Phase 3: Feature 모듈 분리 ✅ COMPLETED
- [x] **Post System 모듈화**
  - [x] features/post_system/ 디렉토리 생성
  - [x] Map에서 Post 배포 로직 분리 (PostDeploymentController 생성)
  - [x] Post 관련 화면 5개 이동 (deploy, detail, edit, place, place_selection)
  - [x] Post 관련 Widget 6개 이동 (post_card, post_tile_card, price_calculator, gender_checkbox_group, period_slider_with_input, range_slider_with_input)
- [x] **Place System 정리**
  - [x] features/place_system/ 디렉토리 생성
  - [x] Place 관련 화면 4개 모듈화 (create, detail, image_viewer, search)
- [x] **User Dashboard 통합**
  - [x] features/user_dashboard/ 디렉토리 생성
  - [x] 사용자 관련 화면 8개 정리 (main, inbox, budget, search, settings, store, wallet, location_picker)
- [x] **Import 경로 업데이트**
  - [x] app_routes.dart 완전 재구성 (새로운 features/ 구조 반영)
  - [x] 50+ 파일의 import 경로 수정
  - [x] Map Screen에서 PostDeploymentController 연동
- [x] **테스트 및 검증**
  - [x] Flutter analyze 실행 완료
  - [x] Map → Post 배포 플로우 유지 확인
- [x] **Git 커밋**
  - [x] Phase 3 완료 커밋 (98f6167): 30 files changed, 205 insertions(+), 112 deletions(-)

### Phase 4: 최적화 및 테스트 ⏳ PENDING
- [ ] **Performance 모듈 분리**
  - [ ] features/performance/ 디렉토리 생성
  - [ ] 성능 관련 서비스들 별도 모듈로 분리
  - [ ] optimization_service.dart, performance_monitor.dart, benchmark_service.dart 등 이동
- [ ] **Import 최적화**
  - [ ] Barrel exports 추가 (index.dart 파일들)
  - [ ] Import 경로 단순화
- [ ] **테스트 코드 정리**
  - [ ] 새로운 구조에 맞춰 테스트 재구성
- [ ] 최종 성능 테스트 및 문서화
- [ ] Git 커밋 및 릴리즈

## 📋 개요

현재 코드베이스의 구조 분석 후, 기능별로 유사한 파일들을 그룹화하고 직관적인 구조로 재구성하는 리팩토링 계획입니다.
특히 Map Screen과 관련된 Fog Level, Post 배포 기능들을 중점적으로 분석했습니다.

## 🎯 주요 발견사항

### 현재 구조의 문제점
1. **Map 관련 기능이 여러 폴더에 분산**
   - Fog of War 관련 서비스가 5개로 분산
   - Map Screen이 20+개의 import 필요
   - Post 배포와 Map이 강결합되어 있음

2. **중복된 서비스와 모델**
   - 타일 관련 서비스 4개 (중복 기능)
   - Location 관련 서비스 3개
   - User 관련 모델과 서비스 분산

3. **복잡한 의존성**
   - Map Screen이 너무 많은 책임을 가짐 (600+ 라인)
   - 포스트 배포가 Map에 강결합
   - Fog of War 시스템이 여러 서비스에 분산

## 🗺️ 현재 기능별 플로우 차트

### 1. Map Screen 진입점 및 연결 파일

```
main.dart
    ↓
app.dart → routes/app_routes.dart
    ↓
screens/user/main_screen.dart
    ↓
screens/user/map_screen.dart (핵심 진입점)
    ├── models/post_model.dart
    ├── models/fog_level.dart
    ├── services/post_service.dart
    ├── services/marker_service.dart
    ├── services/osm_fog_service.dart
    ├── services/visit_tile_service.dart
    ├── services/nominatim_service.dart
    ├── services/location_service.dart
    ├── utils/tile_utils.dart
    └── providers/map_filter_provider.dart
```

### 2. Fog of War 시스템 아키텍처

```
Fog of War 시스템
├── models/fog_level.dart (레벨 정의)
├── services/fog_of_war_manager.dart (메인 매니저)
├── services/fog_of_war_tile_provider.dart
├── services/fog_tile_provider.dart
├── services/osm_fog_service.dart
├── services/visit_tile_service.dart
├── services/tile_cache_manager.dart
├── services/custom_tile_provider.dart
├── utils/fog_tile_generator.dart
└── utils/tile_utils.dart
```

### 3. Post 배포 워크플로우

```
Map Screen (장소 선택)
    ↓
screens/user/post_deploy_screen.dart
    ├── models/post_model.dart
    ├── services/post_service.dart
    ├── services/marker_service.dart
    ├── services/visit_tile_service.dart
    └── utils/tile_utils.dart
    ↓
Post 생성/배포 완료
    ↓
Map Screen 업데이트
```

### 4. 사용자 인증 및 설정 플로우

```
screens/auth/login_screen.dart
    ↓
screens/auth/signup_screen.dart
    ↓ (선택적)
screens/auth/address_search_screen.dart
    ↓
screens/user/main_screen.dart
```

### 5. Place 관리 시스템

```
screens/place/place_search_screen.dart
    ↓
screens/place/create_place_screen.dart
    ↓
screens/place/place_detail_screen.dart
    ↓
screens/place/place_image_viewer_screen.dart
```

## 🔄 제안된 리팩토링 구조

### 새로운 폴더 구조

```
lib/
├── core/                           # 핵심 기능
│   ├── models/                     # 통합된 모델
│   │   ├── user/
│   │   │   ├── user_model.dart
│   │   │   └── user_points_model.dart
│   │   ├── post/
│   │   │   ├── post_model.dart
│   │   │   └── post_usage_model.dart
│   │   ├── place/
│   │   │   └── place_model.dart
│   │   └── map/
│   │       └── fog_level.dart
│   ├── services/                   # 핵심 서비스
│   │   ├── auth/
│   │   │   ├── firebase_service.dart
│   │   │   └── firebase_functions_service.dart
│   │   ├── location/
│   │   │   ├── location_service.dart
│   │   │   ├── location_manager.dart
│   │   │   └── nominatim_service.dart
│   │   └── data/
│   │       ├── user_service.dart
│   │       ├── post_service.dart
│   │       └── place_service.dart
│   └── providers/                  # 상태 관리
│       ├── user_provider.dart
│       ├── search_provider.dart
│       ├── status_provider.dart
│       └── wallet_provider.dart
├── features/                       # 기능별 모듈
│   ├── authentication/             # 인증 모듈
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── address_search_screen.dart
│   │   └── widgets/
│   │       └── address_search_widget.dart
│   ├── map_system/                 # 지도 시스템 (핵심)
│   │   ├── screens/
│   │   │   ├── map_screen.dart
│   │   │   └── location_picker_screen.dart
│   │   ├── services/
│   │   │   ├── fog_of_war/
│   │   │   │   ├── fog_manager.dart (통합)
│   │   │   │   ├── fog_tile_service.dart (통합)
│   │   │   │   └── visit_manager.dart
│   │   │   ├── tiles/
│   │   │   │   ├── tile_provider.dart (통합)
│   │   │   │   ├── tile_cache_manager.dart
│   │   │   │   └── tile_prefetcher.dart
│   │   │   └── markers/
│   │   │       └── marker_service.dart
│   │   ├── providers/
│   │   │   └── map_filter_provider.dart
│   │   ├── widgets/
│   │   │   ├── map_widgets/
│   │   │   └── filter_widgets/
│   │   └── utils/
│   │       ├── tile_utils.dart
│   │       ├── fog_tile_generator.dart
│   │       └── tile_image_generator.dart
│   ├── post_system/                # 포스트 시스템
│   │   ├── screens/
│   │   │   ├── post_deploy_screen.dart
│   │   │   ├── post_detail_screen.dart
│   │   │   ├── post_edit_screen.dart
│   │   │   ├── post_place_screen.dart
│   │   │   └── post_place_selection_screen.dart
│   │   └── widgets/
│   │       ├── post_card.dart
│   │       ├── post_tile_card.dart
│   │       ├── price_calculator.dart
│   │       ├── gender_checkbox_group.dart
│   │       ├── period_slider_with_input.dart
│   │       └── range_slider_with_input.dart
│   ├── place_system/               # 장소 시스템
│   │   ├── screens/
│   │   │   ├── create_place_screen.dart
│   │   │   ├── place_detail_screen.dart
│   │   │   ├── place_image_viewer_screen.dart
│   │   │   └── place_search_screen.dart
│   │   └── widgets/
│   ├── user_dashboard/             # 사용자 대시보드
│   │   ├── screens/
│   │   │   ├── main_screen.dart
│   │   │   ├── inbox_screen.dart
│   │   │   ├── budget_screen.dart
│   │   │   ├── search_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── store_screen.dart
│   │   │   └── wallet_screen.dart
│   │   └── widgets/
│   └── performance/                # 성능 최적화
│       ├── services/
│       │   ├── optimization_service.dart
│       │   ├── performance_monitor.dart
│       │   ├── benchmark_service.dart
│       │   ├── load_testing_service.dart
│       │   ├── production_service.dart
│       │   └── track_service.dart
│       └── utils/
├── shared/                         # 공통 구성요소
│   ├── widgets/
│   │   ├── network_image_fallback_*.dart
│   │   └── common_widgets/
│   ├── utils/
│   │   ├── constants.dart
│   │   ├── helpers.dart
│   │   └── web_dom*.dart
│   └── services/
│       └── image_upload_service.dart
├── app/                           # 앱 설정
│   ├── app.dart
│   ├── routes/
│   │   └── app_routes.dart
│   └── l10n/
└── main.dart
```

## 🎯 주요 리팩토링 제안

### 1. Map System 통합 및 단순화

#### 현재 문제:
- Map Screen이 600+ 라인으로 너무 복잡
- Fog of War 관련 서비스 5개가 분산
- 20+개의 import 필요

#### 제안사항:
```dart
// 새로운 구조
features/map_system/
├── screens/map_screen.dart (300라인 이하로 분할)
├── services/fog_of_war/
│   └── fog_manager.dart (5개 서비스 통합)
├── services/tiles/
│   └── tile_provider.dart (4개 서비스 통합)
└── widgets/
    ├── map_display_widget.dart
    ├── fog_overlay_widget.dart
    └── marker_layer_widget.dart
```

### 2. Fog of War 시스템 통합

#### 통합할 서비스들:
- `fog_of_war_manager.dart` → 메인 관리자 유지
- `fog_of_war_tile_provider.dart` + `fog_tile_provider.dart` + `osm_fog_service.dart` → `fog_tile_service.dart`로 통합
- `custom_tile_provider.dart` + `visit_tile_service.dart` → `tile_provider.dart`로 통합

#### 새로운 인터페이스:
```dart
abstract class FogTileProvider {
  Future<List<Polygon>> getFogPolygons(LatLng center, double zoom);
  Future<void> markVisited(LatLng location);
}

class UnifiedFogManager implements FogTileProvider {
  // 모든 Fog 관련 기능 통합
}
```

### 3. Post System 모듈화

#### 현재 문제:
- Post 배포가 Map Screen에 강결합
- Post 관련 화면들이 user 폴더에 혼재

#### 제안사항:
```dart
features/post_system/
├── controllers/
│   └── post_controller.dart (비즈니스 로직 분리)
├── screens/
└── widgets/
    └── post_deployment_widget.dart (Map에서 분리)
```

### 4. Location Services 통합

#### 통합할 서비스들:
- `location_service.dart` + `location_manager.dart` + `nominatim_service.dart`
- 단일 `LocationManager` 클래스로 통합

### 5. Performance Services 분리

#### 새로운 모듈:
```dart
features/performance/
├── monitoring/
├── optimization/
└── testing/
```

## 📋 단계별 마이그레이션 계획

### Phase 1: 핵심 모델 및 서비스 정리 (1주)
1. **Models 재구성**
   - `lib/core/models/` 생성
   - 기능별 하위 폴더 생성
   - 모델 파일들 이동

2. **Core Services 정리**
   - 인증 관련 서비스 `core/services/auth/`로 이동
   - 데이터 서비스 `core/services/data/`로 이동

### Phase 2: Map System 리팩토링 (2주)
1. **Fog of War 통합**
   - 5개 서비스를 2-3개로 통합
   - 인터페이스 정의 및 구현

2. **Map Screen 분할**
   - 600라인을 300라인 이하로 분할
   - Widget 기반으로 컴포넌트 분리

3. **Tile System 최적화**
   - 4개 타일 서비스 통합
   - 캐싱 및 성능 최적화

### Phase 3: Feature 모듈 분리 (2주)
1. **Post System 모듈화**
   - Map에서 Post 배포 로직 분리
   - 독립적인 Post 모듈 생성

2. **Place System 정리**
   - Place 관련 화면들 모듈화

3. **User Dashboard 통합**
   - 사용자 관련 화면들 정리

### Phase 4: 최적화 및 테스트 (1주)
1. **Performance 모듈 분리**
   - 성능 관련 서비스들 별도 모듈로 분리

2. **Import 최적화**
   - Barrel exports 추가
   - Import 경로 단순화

3. **테스트 코드 정리**
   - 새로운 구조에 맞춰 테스트 재구성

## 🔧 주요 통합 대상

### 즉시 통합 가능한 파일들:

#### 1. Fog of War Services (5개 → 2개)
```
현재:
- fog_of_war_manager.dart (유지)
- fog_of_war_tile_provider.dart
- fog_tile_provider.dart          } → fog_tile_service.dart
- osm_fog_service.dart           }
- visit_tile_service.dart → tile_provider.dart와 통합
```

#### 2. Tile Services (4개 → 2개)
```
현재:
- custom_tile_provider.dart
- tile_cache_manager.dart        } → tile_provider.dart
- tile_prefetcher.dart          }
- visit_tile_service.dart       }
```

#### 3. Location Services (3개 → 1개)
```
현재:
- location_service.dart
- location_manager.dart         } → location_manager.dart
- nominatim_service.dart       }
```

#### 4. Performance Services (분리)
```
현재: services/ 폴더에 혼재
새로운: features/performance/ 모듈로 분리
- optimization_service.dart
- performance_monitor.dart
- benchmark_service.dart
- load_testing_service.dart
- production_service.dart
- track_service.dart
```

## 🎯 기대효과

### 1. 유지보수성 향상
- 관련 기능들이 한 곳에 모여 있어 수정이 용이
- 의존성 관계가 명확해짐
- 코드 중복 제거

### 2. 성능 개선
- Import 최적화로 빌드 시간 단축
- 통합된 서비스로 메모리 사용량 감소
- 캐싱 및 최적화 로직 통합

### 3. 개발 효율성
- 새로운 개발자도 구조를 쉽게 이해
- 기능별 모듈화로 병렬 개발 가능
- 테스트 코드 작성 용이

### 4. 확장성
- 새로운 기능 추가 시 명확한 위치
- 모듈 간 독립성으로 안전한 확장
- 마이크로서비스 아키텍처로의 전환 준비

## 🗑️ 제거 대상 파일들

### 즉시 제거 가능한 불필요한 코드:

#### 1. status_provider.dart
- **위치**: `lib/providers/status_provider.dart`
- **상태**: 구현되어 있지만 실제 사용되지 않음
- **이유**: 어떤 화면에서도 StatusProvider를 사용하지 않음
- **조치**: app.dart에서 Provider 등록 해제 후 파일 삭제

#### 2. address_search_widget.dart
- **위치**: `lib/widgets/address_search_widget.dart`
- **상태**: 구현되어 있지만 실제 import/사용되지 않음
- **이유**: 어떤 화면에서도 AddressSearchWidget을 import하지 않음
- **조치**: 파일 삭제 (69라인의 완성된 위젯이지만 사용되지 않음)

### 제거 작업 우선순위:
1. **Phase 0 (사전작업)**: 불필요한 파일들 제거
   - status_provider.dart 제거
   - address_search_widget.dart 제거
   - app.dart에서 StatusProvider 등록 해제

2. **정리 후 메인 리팩토링 시작**

## ⚠️ 주의사항

1. **점진적 마이그레이션**: 한 번에 모든 것을 변경하지 말고 단계별로 진행
2. **테스트 우선**: 각 단계마다 충분한 테스트 후 다음 단계 진행
3. **백업**: 각 Phase 시작 전 Git 브랜치 생성
4. **문서화**: 변경사항을 실시간으로 문서화
5. **팀 동의**: 큰 변경사항은 팀과 충분한 논의 후 진행

이 리팩토링 계획을 통해 PPAM Alpha 프로젝트의 구조가 더욱 직관적이고 유지보수하기 쉬운 형태로 발전할 것입니다.