# 🏗️ Clean Architecture 기반 프로젝트 재구성 계획

## 📊 현재 구조 분석

### 문제점
1. ❌ features 내부 구조가 일관성 없음 (일부는 controllers만, 일부는 full stack)
2. ❌ 루트 레벨에 providers, screens, routes 등이 흩어져 있음
3. ❌ core/services 구조가 복잡함
4. ❌ utils, widgets가 루트에 있어 feature와 core의 경계 모호

---

## 🎯 새로운 Clean Architecture 구조

```
lib/
├── core/                           # 공통 핵심 기능
│   ├── di/                         # Dependency Injection (GetIt 등)
│   ├── constants/                  # 상수
│   ├── errors/                     # 에러 처리
│   ├── network/                    # 네트워크 (Dio 등)
│   ├── theme/                      # 테마
│   ├── utils/                      # 공통 유틸
│   │   ├── extensions/
│   │   ├── helpers/
│   │   └── validators/
│   └── widgets/                    # 공통 위젯
│
├── shared/                         # Feature 간 공유되는 것들
│   ├── data/
│   │   ├── models/                # 공통 모델
│   │   │   ├── user/
│   │   │   ├── post/
│   │   │   ├── place/
│   │   │   ├── marker/
│   │   │   └── map/
│   │   ├── repositories/          # 공통 Repository
│   │   └── datasources/           # 공통 DataSource
│   │       ├── local/             # Hive, SharedPreferences
│   │       └── remote/            # Firebase, API
│   │
│   ├── domain/
│   │   ├── entities/              # 비즈니스 엔티티
│   │   ├── repositories/          # Repository 인터페이스
│   │   └── usecases/              # 공통 UseCase
│   │
│   └── services/                  # 공통 서비스
│       ├── auth/                  # 인증
│       ├── storage/               # 저장소
│       ├── analytics/             # 분석
│       └── notification/          # 알림
│
├── features/                       # 기능 모듈
│   ├── auth/                      # 인증 기능
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   └── datasources/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       └── widgets/
│   │
│   ├── map/                       # 지도 기능
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── marker_item.dart
│   │   │   │   └── map_state.dart
│   │   │   ├── repositories/
│   │   │   │   └── map_repository_impl.dart
│   │   │   └── datasources/
│   │   │       ├── fog_datasource.dart
│   │   │       └── tile_datasource.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   │   └── map_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_current_location.dart
│   │   │       ├── update_fog_of_war.dart
│   │   │       └── manage_markers.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── map_provider.dart
│   │       │   └── map_filter_provider.dart
│   │       ├── screens/
│   │       │   └── map_screen.dart
│   │       └── widgets/
│   │           ├── map_filter_dialog.dart
│   │           ├── fog_overlay_widget.dart
│   │           └── marker_layer_widget.dart
│   │
│   ├── post/                      # 포스트 기능
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── post_detail_state.dart
│   │   │   ├── repositories/
│   │   │   │   └── post_repository_impl.dart
│   │   │   └── datasources/
│   │   │       ├── post_remote_datasource.dart
│   │   │       └── post_local_datasource.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   │   └── post_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_post.dart
│   │   │       ├── collect_post.dart
│   │   │       ├── deploy_post.dart
│   │   │       └── get_post_statistics.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   ├── post_detail_screen.dart
│   │       │   ├── post_statistics_screen.dart
│   │       │   ├── post_deploy_screen.dart
│   │       │   ├── post_place_screen.dart
│   │       │   └── post_edit_screen.dart
│   │       └── widgets/
│   │           ├── post_image_slider_appbar.dart
│   │           ├── post_card.dart
│   │           └── coupon_usage_dialog.dart
│   │
│   ├── place/                     # 장소 기능
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── repositories/
│   │   │   └── datasources/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   │       ├── create_place.dart
│   │   │       ├── update_place.dart
│   │   │       └── get_place_statistics.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── create_place_screen.dart
│   │       │   ├── edit_place_screen.dart
│   │       │   ├── place_detail_screen.dart
│   │       │   └── place_statistics_screen.dart
│   │       └── widgets/
│   │
│   ├── dashboard/                 # 대시보드 (inbox 등)
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── filter_posts.dart
│   │   │       └── sort_posts.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── inbox_screen.dart
│   │       │   ├── wallet_screen.dart
│   │       │   ├── points_screen.dart
│   │       │   └── budget_screen.dart
│   │       └── widgets/
│   │
│   ├── settings/                  # 설정
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── update_profile.dart
│   │   │       └── manage_notifications.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── settings_screen.dart
│   │       └── widgets/
│   │
│   ├── store/                     # 스토어
│   │   └── presentation/
│   │       └── screens/
│   │           └── store_screen.dart
│   │
│   └── admin/                     # 관리자
│       └── presentation/
│           ├── screens/
│           │   └── admin_cleanup_screen.dart
│           └── widgets/
│
├── config/                        # 앱 설정
│   ├── routes/
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   ├── environment/
│   │   ├── env_config.dart
│   │   └── firebase_options.dart
│   └── localization/
│       └── app_localizations.dart
│
└── app.dart                       # 앱 진입점
```

---

## 📋 계층별 책임

### 1. **Data Layer**
- Models: API/Firebase 응답 <-> Domain Entity 변환
- Repositories: Domain의 Repository 인터페이스 구현
- DataSources: 실제 데이터 가져오기 (Firebase, API, Local DB)

### 2. **Domain Layer** (순수 비즈니스 로직)
- Entities: 비즈니스 객체
- Repositories: Repository 인터페이스 정의
- UseCases: 비즈니스 로직 (1 UseCase = 1 기능)

### 3. **Presentation Layer**
- Providers: 상태 관리 (Riverpod, Provider 등)
- Screens: 화면
- Widgets: UI 컴포넌트

---

## 🔄 마이그레이션 순서

### Phase 1: Core & Shared 재구성
1. core/ 재구성
2. shared/ 생성 및 모델 이동
3. 공통 서비스 정리

### Phase 2: Features 재구성
1. auth 모듈 재구성
2. map 모듈 재구성
3. post 모듈 재구성
4. place 모듈 재구성
5. dashboard 모듈 재구성
6. settings 모듈 재구성

### Phase 3: Config 정리
1. routes 이동
2. localization 정리
3. environment 설정

### Phase 4: 검증 및 테스트
1. Import 검증
2. 빌드 테스트
3. 린트 체크

