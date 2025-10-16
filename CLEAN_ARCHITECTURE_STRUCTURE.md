# 🏛️ Clean Architecture 기반 프로젝트 구조

## 📂 전체 폴더 구조

```
lib/
├── core/                                    # 핵심 공통 기능
│   ├── di/                                  # Dependency Injection
│   │   └── injection_container.dart         # GetIt 설정
│   ├── constants/                           # 상수
│   │   └── app_constants.dart               # ✅ 기존 유지
│   ├── errors/                              # 에러 처리
│   │   ├── failures.dart                    # 에러 추상화
│   │   └── exceptions.dart                  # 예외 정의
│   ├── network/                             # 네트워크
│   │   ├── network_info.dart                # 네트워크 상태
│   │   └── api_client.dart                  # API 클라이언트
│   ├── theme/                               # 테마
│   │   ├── app_theme.dart                   # 앱 테마
│   │   └── app_colors.dart                  # 색상 정의
│   ├── utils/                               # 공통 유틸
│   │   ├── extensions/                      # ✅ 기존에서 이동
│   │   │   └── context_extensions.dart
│   │   ├── helpers/                         # 헬퍼 함수
│   │   └── validators/                      # 검증 함수
│   └── widgets/                             # 공통 위젯
│       ├── network_image_fallback_*.dart    # ✅ 기존에서 이동
│       └── loading_indicator.dart
│
├── shared/                                  # Feature 간 공유
│   ├── data/
│   │   ├── models/                          # 공통 모델
│   │   │   ├── user/                        # ✅ core/models/user에서 이동
│   │   │   │   ├── user_model.dart
│   │   │   │   └── user_points_model.dart
│   │   │   ├── post/                        # ✅ core/models/post에서 이동
│   │   │   │   ├── post_model.dart
│   │   │   │   ├── post_deployment_model.dart
│   │   │   │   ├── post_instance_model.dart
│   │   │   │   ├── post_template_model.dart
│   │   │   │   └── post_usage_model.dart
│   │   │   ├── place/                       # ✅ core/models/place에서 이동
│   │   │   │   └── place_model.dart
│   │   │   ├── marker/                      # ✅ core/models/marker에서 이동
│   │   │   │   └── marker_model.dart
│   │   │   └── map/                         # ✅ core/models/map에서 이동
│   │   │       └── fog_level.dart
│   │   ├── repositories/                    # Repository 구현
│   │   └── datasources/
│   │       ├── local/                       # 로컬 저장소
│   │       │   └── cache_manager.dart
│   │       └── remote/                      # 원격 데이터
│   │           └── firebase_datasource.dart
│   ├── domain/
│   │   ├── entities/                        # 비즈니스 엔티티
│   │   ├── repositories/                    # Repository 인터페이스
│   │   └── usecases/                        # 공통 UseCase
│   └── services/                            # 공통 서비스
│       ├── auth/                            # ✅ core/services/auth에서 이동
│       │   ├── firebase_service.dart
│       │   └── firebase_functions_service.dart
│       ├── storage/                         # 저장소
│       │   └── image_upload_service.dart    # ✅ features/shared_services에서 이동
│       └── analytics/                       # 분석
│
├── features/                                # 기능 모듈
│   ├── auth/                                # 🔐 인증
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── login_screen.dart        # ✅ screens/auth에서 이동
│   │       │   ├── signup_screen.dart       # ✅ screens/auth에서 이동
│   │       │   └── address_search_screen.dart
│   │       └── widgets/
│   │
│   ├── map/                                 # 🗺️ 지도
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── marker_item.dart         # ✅ NEW
│   │   │   │   └── map_state.dart           # ✅ NEW
│   │   │   ├── repositories/
│   │   │   │   └── map_repository_impl.dart
│   │   │   └── datasources/
│   │   │       ├── fog_datasource.dart
│   │   │       └── tile_datasource.dart
│   │   ├── domain/
│   │   │   ├── repositories/
│   │   │   │   └── map_repository.dart
│   │   │   └── usecases/
│   │   │       ├── get_current_location.dart   # ✅ LocationController → UseCase
│   │   │       ├── update_fog_of_war.dart      # ✅ FogController → UseCase
│   │   │       ├── manage_markers.dart         # ✅ MarkerController → UseCase
│   │   │       └── collect_post_from_map.dart  # ✅ PostController → UseCase
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── map_provider.dart
│   │       │   └── map_filter_provider.dart # ✅ 기존
│   │       ├── screens/
│   │       │   └── map_screen.dart          # ✅ 기존
│   │       └── widgets/
│   │           ├── map_filter_dialog.dart   # ✅ NEW
│   │           ├── fog_overlay_widget.dart  # ✅ 기존
│   │           ├── unified_fog_overlay_widget.dart  # ✅ 기존
│   │           ├── map_display_widget.dart  # ✅ 기존
│   │           ├── map_filter_widget.dart   # ✅ 기존
│   │           ├── marker_layer_widget.dart # ✅ 기존
│   │           ├── receive_carousel.dart    # ✅ 기존
│   │           └── cluster_widgets.dart     # ✅ 기존
│   │
│   ├── post/                                # 📮 포스트
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── post_detail_state.dart   # ✅ NEW
│   │   │   ├── repositories/
│   │   │   │   └── post_repository_impl.dart
│   │   │   └── datasources/
│   │   │       ├── post_remote_datasource.dart
│   │   │       └── post_local_datasource.dart
│   │   ├── domain/
│   │   │   ├── repositories/
│   │   │   │   └── post_repository.dart
│   │   │   └── usecases/
│   │   │       ├── create_post.dart            # ✅ post_creation_helper → UseCase
│   │   │       ├── collect_post.dart           # ✅ post_collection_helper → UseCase
│   │   │       ├── deploy_post.dart            # ✅ PostDeployController → UseCase
│   │   │       ├── edit_post.dart              # ✅ PostEditController → UseCase
│   │   │       ├── delete_post.dart            # ✅ PostDetailController → UseCase
│   │   │       ├── get_post_statistics.dart    # ✅ PostStatisticsController → UseCase
│   │   │       └── select_post_place.dart      # ✅ PostPlaceController → UseCase
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       │   ├── post_detail_screen.dart     # ✅ 기존
│   │       │   ├── post_statistics_screen.dart # ✅ 기존
│   │       │   ├── post_deploy_screen.dart     # ✅ 기존
│   │       │   ├── post_place_screen.dart      # ✅ 기존
│   │       │   ├── post_edit_screen.dart       # ✅ 기존
│   │       │   └── my_posts_statistics_dashboard_screen.dart  # ✅ 기존
│   │       └── widgets/
│   │           ├── post_image_slider_appbar.dart  # ✅ NEW
│   │           ├── post_card.dart              # ✅ 기존
│   │           ├── post_tile_card.dart         # ✅ 기존
│   │           ├── coupon_usage_dialog.dart    # ✅ 기존
│   │           ├── address_search_dialog.dart  # ✅ 기존
│   │           └── ... (기타 위젯들)
│   │
│   ├── place/                               # 🏢 장소
│   │   ├── data/
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── create_place.dart           # ✅ PlaceController → UseCase
│   │   │       ├── update_place.dart           # ✅ PlaceController → UseCase
│   │   │       ├── delete_place.dart           # ✅ PlaceController → UseCase
│   │   │       └── get_place_statistics.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── create_place_screen.dart    # ✅ 기존
│   │       │   ├── edit_place_screen.dart      # ✅ 기존
│   │       │   ├── place_detail_screen.dart    # ✅ 기존
│   │       │   ├── place_statistics_screen.dart # ✅ 기존
│   │       │   ├── my_places_screen.dart       # ✅ 기존
│   │       │   └── place_search_screen.dart    # ✅ 기존
│   │       └── widgets/
│   │
│   ├── dashboard/                           # 📊 대시보드
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── filter_posts.dart           # ✅ InboxController → UseCase
│   │   │       ├── sort_posts.dart             # ✅ InboxController → UseCase
│   │   │       └── calculate_statistics.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   ├── main_screen.dart            # ✅ 기존
│   │       │   ├── inbox_screen.dart           # ✅ 기존
│   │       │   ├── wallet_screen.dart          # ✅ 기존
│   │       │   ├── points_screen.dart          # ✅ 기존
│   │       │   ├── budget_screen.dart          # ✅ 기존
│   │       │   ├── search_screen.dart          # ✅ 기존
│   │       │   └── trash_screen.dart           # ✅ 기존
│   │       └── widgets/
│   │           ├── info_section_card.dart      # ✅ 기존
│   │           ├── points_summary_card.dart    # ✅ 기존
│   │           └── profile_header_card.dart    # ✅ 기존
│   │
│   ├── settings/                            # ⚙️ 설정
│   │   ├── domain/
│   │   │   └── usecases/
│   │   │       ├── update_profile.dart         # ✅ SettingsController → UseCase
│   │   │       ├── update_notifications.dart   # ✅ SettingsController → UseCase
│   │   │       ├── change_password.dart        # ✅ SettingsController → UseCase
│   │   │       └── delete_account.dart         # ✅ SettingsController → UseCase
│   │   └── presentation/
│   │       └── screens/
│   │           └── settings_screen.dart        # ✅ 기존
│   │
│   ├── store/                               # 🏪 스토어
│   │   └── presentation/
│   │       └── screens/
│   │           └── store_screen.dart           # ✅ 기존
│   │
│   ├── admin/                               # 👨‍💼 관리자
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── admin_cleanup_screen.dart   # ✅ 기존
│   │       └── widgets/
│   │           └── user_point_grant_dialog.dart  # ✅ 기존
│   │
│   └── performance/                         # 📈 성능 모니터링
│       ├── domain/
│       └── presentation/
│
├── config/                                  # ⚙️ 앱 설정
│   ├── routes/
│   │   ├── app_router.dart                     # ✅ routes/app_routes에서 이동
│   │   └── route_guards.dart
│   ├── environment/
│   │   ├── env_config.dart                     # ✅ utils/config에서 이동
│   │   └── firebase_options.dart               # ✅ 기존
│   └── localization/
│       └── app_localizations.dart              # ✅ l10n에서 이동
│
├── providers/                               # 🔄 루트 Providers (임시)
│   ├── screen_provider.dart                    # ✅ 기존
│   ├── search_provider.dart                    # ✅ 기존
│   ├── user_provider.dart                      # ✅ 기존
│   └── wallet_provider.dart                    # ✅ 기존
│
└── app.dart                                    # 앱 진입점
```

---

## 🔄 마이그레이션 매핑

### Controllers → UseCases

| 기존 Controller | 새 UseCase 위치 | Feature |
|----------------|----------------|---------|
| LocationController | features/map/domain/usecases/get_current_location.dart | Map |
| FogController | features/map/domain/usecases/update_fog_of_war.dart | Map |
| MarkerController | features/map/domain/usecases/manage_markers.dart | Map |
| PostController (map) | features/map/domain/usecases/collect_post_from_map.dart | Map |
| PostDetailController | features/post/domain/usecases/delete_post.dart | Post |
| PostStatisticsController | features/post/domain/usecases/get_post_statistics.dart | Post |
| PostPlaceController | features/post/domain/usecases/select_post_place.dart | Post |
| PostDeployController | features/post/domain/usecases/deploy_post.dart | Post |
| PostEditController | features/post/domain/usecases/edit_post.dart | Post |
| PlaceController | features/place/domain/usecases/create_place.dart 등 | Place |
| InboxController | features/dashboard/domain/usecases/filter_posts.dart | Dashboard |
| SettingsController | features/settings/domain/usecases/update_profile.dart 등 | Settings |

### Helpers → UseCases

| 기존 Helper | 새 UseCase 위치 | Feature |
|------------|----------------|---------|
| PostCreationHelper | features/post/domain/usecases/create_post.dart | Post |
| PostCollectionHelper | features/post/domain/usecases/collect_post.dart | Post |

### Models 이동

| 기존 위치 | 새 위치 | 비고 |
|----------|---------|------|
| core/models/* | shared/data/models/* | 공통 모델 |
| features/*/models/* | features/*/data/models/* | Feature 모델 |
| features/*/state/* | features/*/data/models/* | State도 Model |

### Services 이동

| 기존 위치 | 새 위치 | 비고 |
|----------|---------|------|
| core/services/auth/* | shared/services/auth/* | 인증 서비스 |
| core/services/data/* | shared/data/repositories/* 또는 datasources/* | 데이터 서비스 |
| features/shared_services/* | shared/services/* | 공유 서비스 |

### Screens 이동

| 기존 위치 | 새 위치 | 비고 |
|----------|---------|------|
| screens/auth/* | features/auth/presentation/screens/* | 인증 화면 |
| features/*/screens/* | features/*/presentation/screens/* | 기능 화면 |

### Widgets 이동

| 기존 위치 | 새 위치 | 비고 |
|----------|---------|------|
| widgets/* (공통) | core/widgets/* | 공통 위젯 |
| features/*/widgets/* | features/*/presentation/widgets/* | Feature 위젯 |

---

## 📝 주요 특징

### 1. **명확한 계층 분리**
- Data: 데이터 소스 및 모델
- Domain: 비즈니스 로직 (순수 Dart)
- Presentation: UI 및 상태 관리

### 2. **의존성 방향**
```
Presentation → Domain ← Data
      ↓          ↓       ↓
    Shared   Shared   Shared
      ↓          ↓       ↓
             Core
```

### 3. **Feature 독립성**
- 각 Feature는 독립적으로 동작
- Shared를 통해서만 Feature 간 통신
- Feature 추가/제거가 용이

### 4. **테스트 용이성**
- UseCase는 순수 함수로 테스트 쉬움
- Repository는 인터페이스로 Mock 가능
- Presentation은 Provider로 상태 테스트

---

## ✅ 이점

1. **확장성**: 새 Feature 추가 시 기존 코드 영향 없음
2. **유지보수성**: 각 계층의 책임이 명확
3. **테스트**: 계층별 독립적 테스트 가능
4. **협업**: Feature별로 팀 분리 가능
5. **재사용성**: Shared 계층 활용

