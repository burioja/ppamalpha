# 📁 lib 폴더 파일 구조 및 역할 (총 227개 파일)

## 🎯 루트 파일 (2개)

| 파일 | 역할 |
|------|------|
| `app.dart` | 앱 전체 설정 및 MultiProvider 구성 |
| `main.dart` | 앱 진입점, Firebase 초기화 |

---

## 🔷 Core - Models (13개)

### Map Models (1개)
| 파일 | 역할 |
|------|------|
| `core/models/map/fog_level.dart` | Fog of War 레벨 enum 정의 (none, level1, level2) |

### Marker Models (1개)
| 파일 | 역할 |
|------|------|
| `core/models/marker/marker_model.dart` | 지도 마커 데이터 모델 (위치, 보상, 수량 등) |

### Place Models (1개)
| 파일 | 역할 |
|------|------|
| `core/models/place/place_model.dart` | 장소 정보 모델 (건물명, 주소, 운영시간, 통계 등) |

### Post Models (6개)
| 파일 | 역할 |
|------|------|
| `core/models/post/post_deployment_model.dart` | 포스트 배포 정보 모델 |
| `core/models/post/post_instance_model.dart` | 배포된 포스트 인스턴스 모델 (전체 정보) |
| `core/models/post/post_instance_model_simple.dart` | 배포된 포스트 인스턴스 모델 (간략 버전) |
| `core/models/post/post_model.dart` | 포스트 템플릿 모델 (제목, 설명, 보상, 조건 등) |
| `core/models/post/post_template_model.dart` | 포스트 템플릿 기본 구조 |
| `core/models/post/post_usage_model.dart` | 포스트 사용 내역 모델 |

### User Models (2개)
| 파일 | 역할 |
|------|------|
| `core/models/user/user_model.dart` | 사용자 정보 모델 (이메일, 타입, 인증 여부 등) |
| `core/models/user/user_points_model.dart` | 사용자 포인트 정보 모델 |

---

## 🔶 Core - Repositories (3개) ✨ NEW

| 파일 | 역할 |
|------|------|
| `core/repositories/markers_repository.dart` | Firebase 마커 데이터 CRUD (Clean Architecture) |
| `core/repositories/posts_repository.dart` | Firebase 포스트 데이터 CRUD + 트랜잭션 |
| `core/repositories/tiles_repository.dart` | Firebase Fog of War 타일 방문 기록 관리 |

---

## 🔵 Core - Services (19개)

### Admin Services (2개)
| 파일 | 역할 |
|------|------|
| `core/services/admin/admin_service.dart` | 관리자 기능 서비스 |
| `core/services/admin/cleanup_service.dart` | 데이터 정리 서비스 (오래된 데이터 삭제) |

### Auth Services (2개)
| 파일 | 역할 |
|------|------|
| `core/services/auth/firebase_functions_service.dart` | Firebase Cloud Functions 호출 서비스 |
| `core/services/auth/firebase_service.dart` | Firebase 인증 서비스 |

### Data Services (11개)
| 파일 | 역할 |
|------|------|
| `core/services/data/helpers/post_collection_helper.dart` | 포스트 수집 헬퍼 함수 |
| `core/services/data/helpers/post_creation_helper.dart` | 포스트 생성 헬퍼 함수 |
| `core/services/data/marker_service.dart` | 마커 비즈니스 로직 (배포, 수집, 거리 계산) |
| `core/services/data/place_service.dart` | 장소 CRUD 서비스 |
| `core/services/data/place_statistics_service.dart` | 장소 통계 서비스 |
| `core/services/data/points_service.dart` | 포인트 지급/차감 서비스 |
| `core/services/data/post_collection_service.dart` | 포스트 수집 서비스 |
| `core/services/data/post_deployment_service.dart` | 포스트 배포 서비스 |
| `core/services/data/post_instance_service.dart` | 포스트 인스턴스 관리 서비스 |
| `core/services/data/post_search_service.dart` | 포스트 검색 서비스 (MeiliSearch) |
| `core/services/data/post_service.dart` | 포스트 메인 서비스 (CRUD) |
| `core/services/data/post_statistics_service.dart` | 포스트 통계 서비스 |
| `core/services/data/user_service.dart` | 사용자 정보 서비스 |

### Location Services (3개)
| 파일 | 역할 |
|------|------|
| `core/services/location/location_manager.dart` | 위치 관리자 (권한, GPS) |
| `core/services/location/location_service.dart` | 위치 서비스 (현재 위치 조회, 주소 변환) |
| `core/services/location/nominatim_service.dart` | Nominatim 지오코딩 서비스 (주소 ↔ 좌표) |

### Other Services (2개)
| 파일 | 역할 |
|------|------|
| `core/services/osm_geocoding_service.dart` | OpenStreetMap 지오코딩 서비스 |
| `core/services/storage/storage_service.dart` | Firebase Storage 파일 업로드 서비스 |

---

## 🟢 Core - Utils (4개)

| 파일 | 역할 |
|------|------|
| `core/utils/file_helper.dart` | 파일 처리 헬퍼 (인터페이스) |
| `core/utils/file_helper_io.dart` | 파일 처리 구현 (모바일/데스크톱) |
| `core/utils/file_helper_web.dart` | 파일 처리 구현 (웹) |
| `core/utils/logger.dart` | 로깅 유틸리티 |

---

## 🟡 Core - Constants (1개)

| 파일 | 역할 |
|------|------|
| `core/constants/app_constants.dart` | 앱 전역 상수 (반경, 임계값, 색상 등) |

---

## 🎨 Features - Map System (48개)

### Providers (5개) ✨ Clean Architecture
| 파일 | 역할 |
|------|------|
| `map_system/providers/map_filter_provider.dart` | 필터 상태 관리 (카테고리, 거리, 보상) |
| `map_system/providers/map_view_provider.dart` | ✨ 지도 뷰 상태 (카메라, 줌, Bounds) |
| `map_system/providers/marker_provider.dart` | ✨ 마커 상태 + 클러스터링 |
| `map_system/providers/tile_provider.dart` | ✨ Fog of War 타일 상태 |

### Services (14개)
| 파일 | 역할 |
|------|------|
| `map_system/services/clustering/marker_clustering_service.dart` | ✨ 마커 클러스터링 비즈니스 로직 |
| `map_system/services/external/osm_fog_service.dart` | OSM Fog of War 외부 서비스 |
| `map_system/services/fog/fog_service.dart` | ✨ Fog of War 계산 로직 통합 |
| `map_system/services/fog_of_war/fog_of_war_manager.dart` | Fog of War 전체 관리자 |
| `map_system/services/fog_of_war/fog_tile_service.dart` | Fog 타일 서비스 |
| `map_system/services/fog_of_war/visit_manager.dart` | 방문 기록 관리 |
| `map_system/services/fog_of_war/visit_tile_service.dart` | 타일 방문 서비스 |
| `map_system/services/interaction/marker_interaction_service.dart` | ✨ 마커 상호작용 로직 (선택, 수집) |
| `map_system/services/markers/marker_service.dart` | 마커 메인 서비스 |
| `map_system/services/tiles/tile_cache_manager.dart` | 타일 캐시 관리 |

### Controllers (4개)
| 파일 | 역할 |
|------|------|
| `map_system/controllers/fog_controller.dart` | ⚠️ Deprecated - FogService 사용 권장 |
| `map_system/controllers/location_controller.dart` | 위치 컨트롤러 (GPS, 주소) |
| `map_system/controllers/marker_controller.dart` | 마커 컨트롤러 (클러스터링, 수집) |
| `map_system/controllers/post_controller.dart` | 포스트 컨트롤러 (배포, 수령) |

### Handlers (6개)
| 파일 | 역할 |
|------|------|
| `map_system/handlers/map_filter_handler.dart` | 맵 필터 핸들러 |
| `map_system/handlers/map_fog_handler.dart` | ⚠️ Deprecated - FogService 사용 권장 |
| `map_system/handlers/map_location_handler.dart` | 맵 위치 핸들러 |
| `map_system/handlers/map_marker_handler.dart` | 맵 마커 핸들러 |
| `map_system/handlers/map_post_handler.dart` | 맵 포스트 핸들러 |
| `map_system/handlers/map_ui_helper.dart` | 맵 UI 헬퍼 |

### Screens (17개)
| 파일 | 역할 |
|------|------|
| `map_system/screens/map_screen.dart` | ✅ 메인 맵 스크린 (리팩토링 완료, 714줄) |
| `map_system/screens/map_screen_backup_original.dart` | 백업 (5,189줄) |
| `map_system/screens/map_screen_BACKUP.dart` | 백업 (5,189줄) |
| `map_system/screens/map_screen_clean.dart` | Clean 버전 (100줄) |
| `map_system/screens/map_screen_fog.dart` | Fog 버전 (96줄) |
| `map_system/screens/map_screen_helpers.dart` | 헬퍼 함수들 |
| `map_system/screens/map_screen_new.dart` | New 버전 |
| `map_system/screens/map_screen_OLD_BACKUP.dart` | 오래된 백업 (4,840줄) |
| `map_system/screens/map_screen_refactored.dart` | 리팩토링 중간 버전 |
| `map_system/screens/map_screen_refactored_v2.dart` | 리팩토링 v2 |
| `map_system/screens/map_screen_simple.dart` | 간단한 버전 |
| `map_system/screens/simple_map_example.dart` | 맵 예제 |
| `map_system/screens/parts/map_screen_fog_methods.dart` | 🔴 거대 파일 (1,772줄) - 분할 필요 |
| `map_system/screens/parts/map_screen_fog_of_war.dart` | Fog of War 로직 |
| `map_system/screens/parts/map_screen_init.dart` | 초기화 로직 |
| `map_system/screens/parts/map_screen_initialization.dart` | 초기화 로직 v2 |
| `map_system/screens/parts/map_screen_markers.dart` | 마커 로직 |
| `map_system/screens/parts/map_screen_ui_methods.dart` | UI 메서드들 (1,517줄) |

### Widgets (17개)
| 파일 | 역할 |
|------|------|
| `map_system/widgets/cluster_widgets.dart` | 클러스터 위젯 (단일, 클러스터 도트) |
| `map_system/widgets/fog_overlay_widget.dart` | ⚠️ Deprecated - unified 버전 사용 권장 |
| `map_system/widgets/map_display_widget.dart` | 맵 디스플레이 위젯 |
| `map_system/widgets/map_filter_bar_widget.dart` | ✅ 맵 상단 필터 바 (내 포스트, 쿠폰, 스탬프 등) |
| `map_system/widgets/map_filter_dialog.dart` | 맵 필터 다이얼로그 |
| `map_system/widgets/map_filter_dialog_widget.dart` | 맵 필터 다이얼로그 위젯 |
| `map_system/widgets/map_filter_widget.dart` | 맵 필터 위젯 |
| `map_system/widgets/map_location_buttons_widget.dart` | 위치 이동 버튼 (집, 일터, 현재위치) |
| `map_system/widgets/map_longpress_menu_widget.dart` | 지도 롱프레스 메뉴 |
| `map_system/widgets/map_main_widget.dart` | 맵 메인 위젯 |
| `map_system/widgets/map_marker_detail_widget.dart` | 마커 상세 정보 위젯 |
| `map_system/widgets/map_user_location_markers_widget.dart` | 사용자 위치 마커 (집, 일터) |
| `map_system/widgets/marker_layer_widget.dart` | 마커 레이어 위젯 |
| `map_system/widgets/mock_location_controller.dart` | Mock 위치 컨트롤러 (테스트용) |
| `map_system/widgets/receive_carousel.dart` | 수령 캐러셀 위젯 |
| `map_system/widgets/unified_fog_overlay_widget.dart` | ✅ 통합 Fog 오버레이 위젯 (사용 권장) |

### Utils (4개)
| 파일 | 역할 |
|------|------|
| `map_system/utils/client_cluster.dart` | 클라이언트 사이드 클러스터링 |
| `map_system/utils/client_side_cluster.dart` | 클라이언트 사이드 클러스터링 v2 |
| `map_system/utils/tile_image_generator.dart` | 타일 이미지 생성기 |

### Models (2개)
| 파일 | 역할 |
|------|------|
| `map_system/models/marker_item.dart` | 마커 아이템 모델 |
| `map_system/models/receipt_item.dart` | 수령 아이템 모델 |

### State (1개)
| 파일 | 역할 |
|------|------|
| `map_system/state/map_state.dart` | 맵 스크린 상태 관리 클래스 |

---

## 📮 Features - Post System (35개)

### Providers (1개) ✨ Clean Architecture
| 파일 | 역할 |
|------|------|
| `post_system/providers/post_provider.dart` | ✨ 포스트 상태 관리 (CRUD, 수령, 확정) |

### Controllers (4개)
| 파일 | 역할 |
|------|------|
| `post_system/controllers/post_deploy_controller.dart` | 포스트 배포 컨트롤러 |
| `post_system/controllers/post_deployment_controller.dart` | 포스트 배포 관리 컨트롤러 |
| `post_system/controllers/post_detail_controller.dart` | 포스트 상세 컨트롤러 |
| `post_system/controllers/post_edit_controller.dart` | 포스트 편집 컨트롤러 |
| `post_system/controllers/post_place_controller.dart` | 포스트 장소 선택 컨트롤러 |
| `post_system/controllers/post_statistics_controller.dart` | 포스트 통계 컨트롤러 |

### Screens (9개)
| 파일 | 역할 |
|------|------|
| `post_system/screens/deployment_statistics_dashboard_screen.dart` | 배포 통계 대시보드 화면 |
| `post_system/screens/my_posts_statistics_dashboard_screen.dart` | 내 포스트 통계 대시보드 |
| `post_system/screens/post_deploy_design_demo.dart` | 포스트 배포 디자인 데모 |
| `post_system/screens/post_deploy_screen.dart` | 포스트 배포 화면 |
| `post_system/screens/post_detail_screen.dart` | 포스트 상세 화면 |
| `post_system/screens/post_detail_screen_new.dart` | 포스트 상세 화면 (새 버전) |
| `post_system/screens/post_edit_screen.dart` | 포스트 편집 화면 |
| `post_system/screens/post_place_screen.dart` | 포스트 장소 선택 화면 |
| `post_system/screens/post_place_screen_design_demo.dart` | 포스트 장소 디자인 데모 |
| `post_system/screens/post_place_selection_screen.dart` | 포스트 장소 선택 화면 v2 |
| `post_system/screens/post_statistics_screen.dart` | 포스트 통계 화면 |

### Widgets (21개)
| 파일 | 역할 |
|------|------|
| `post_system/widgets/address_search_dialog.dart` | 주소 검색 다이얼로그 |
| `post_system/widgets/building_unit_selector.dart` | 건물 동/호 선택 위젯 |
| `post_system/widgets/coupon_usage_dialog.dart` | 쿠폰 사용 다이얼로그 |
| `post_system/widgets/gender_checkbox_group.dart` | 성별 체크박스 그룹 |
| `post_system/widgets/period_slider_with_input.dart` | 기간 슬라이더 + 입력 위젯 |
| `post_system/widgets/post_card.dart` | 포스트 카드 위젯 |
| `post_system/widgets/post_deploy_helpers.dart` | 포스트 배포 헬퍼 함수들 |
| `post_system/widgets/post_deploy_widgets.dart` | 포스트 배포 위젯들 |
| `post_system/widgets/post_detail_helpers.dart` | 포스트 상세 헬퍼 함수들 |
| `post_system/widgets/post_detail_image_widgets.dart` | 포스트 이미지 위젯들 |
| `post_system/widgets/post_detail_ui_widgets.dart` | 포스트 상세 UI 위젯들 (1,001줄) |
| `post_system/widgets/post_edit_helpers.dart` | 포스트 편집 헬퍼 함수들 |
| `post_system/widgets/post_edit_media_handler.dart` | 포스트 미디어 핸들러 |
| `post_system/widgets/post_edit_widgets.dart` | 포스트 편집 위젯들 |
| `post_system/widgets/post_image_slider_appbar.dart` | 포스트 이미지 슬라이더 앱바 |
| `post_system/widgets/post_place_helpers.dart` | 포스트 장소 헬퍼 함수들 |
| `post_system/widgets/post_place_widgets.dart` | 포스트 장소 위젯들 |
| `post_system/widgets/post_statistics_charts.dart` | 포스트 통계 차트 (997줄) |
| `post_system/widgets/post_statistics_helpers.dart` | 포스트 통계 헬퍼 함수들 |
| `post_system/widgets/post_statistics_tabs.dart` | 포스트 통계 탭들 |
| `post_system/widgets/post_tile_card.dart` | 포스트 타일 카드 (750줄) |
| `post_system/widgets/price_calculator.dart` | 가격 계산기 위젯 |
| `post_system/widgets/range_slider_with_input.dart` | 범위 슬라이더 + 입력 위젯 |

### State (1개)
| 파일 | 역할 |
|------|------|
| `post_system/state/post_detail_state.dart` | 포스트 상세 상태 관리 |

---

## 🏢 Features - Place System (17개)

### Controllers (1개)
| 파일 | 역할 |
|------|------|
| `place_system/controllers/place_controller.dart` | 장소 컨트롤러 (CRUD, 통계) |

### Screens (7개)
| 파일 | 역할 |
|------|------|
| `place_system/screens/create_place_design_demo.dart` | 장소 생성 디자인 데모 |
| `place_system/screens/create_place_screen.dart` | 장소 생성 화면 (1,662줄) |
| `place_system/screens/edit_place_screen.dart` | 장소 편집 화면 (479줄) |
| `place_system/screens/edit_place_screen_fields.dart` | 장소 편집 필드들 |
| `place_system/screens/my_places_screen.dart` | 내 장소 목록 화면 |
| `place_system/screens/place_detail_screen.dart` | 장소 상세 화면 |
| `place_system/screens/place_image_viewer_screen.dart` | 장소 이미지 뷰어 |
| `place_system/screens/place_search_screen.dart` | 장소 검색 화면 |
| `place_system/screens/place_statistics_screen.dart` | 장소 통계 화면 (950줄) |

### Widgets (9개)
| 파일 | 역할 |
|------|------|
| `place_system/widgets/edit_place_helpers.dart` | 장소 편집 헬퍼 함수들 |
| `place_system/widgets/edit_place_widgets.dart` | 장소 편집 위젯들 |
| `place_system/widgets/place_detail_helpers.dart` | 장소 상세 헬퍼 함수들 |
| `place_system/widgets/place_detail_widgets.dart` | 장소 상세 위젯들 (750줄) |

---

## 👤 Features - User Dashboard (11개)

### Controllers (2개)
| 파일 | 역할 |
|------|------|
| `user_dashboard/controllers/inbox_controller.dart` | 받은편지함 컨트롤러 |
| `user_dashboard/controllers/settings_controller.dart` | 설정 컨트롤러 |

### Screens (9개)
| 파일 | 역할 |
|------|------|
| `user_dashboard/screens/budget_screen.dart` | 예산 화면 |
| `user_dashboard/screens/inbox_screen.dart` | 받은편지함 화면 (2,127줄) |
| `user_dashboard/screens/location_picker_screen.dart` | 위치 선택 화면 |
| `user_dashboard/screens/main_screen.dart` | 메인 대시보드 화면 |
| `user_dashboard/screens/points_screen.dart` | 포인트 화면 |
| `user_dashboard/screens/search_screen.dart` | 검색 화면 |
| `user_dashboard/screens/settings_screen.dart` | 설정 화면 (559줄) |
| `user_dashboard/screens/store_screen.dart` | 스토어 화면 (1,000줄) |
| `user_dashboard/screens/trash_screen.dart` | 휴지통 화면 |
| `user_dashboard/screens/wallet_screen.dart` | 지갑 화면 (874줄) |

### Widgets (4개)
| 파일 | 역할 |
|------|------|
| `user_dashboard/widgets/info_section_card.dart` | 정보 섹션 카드 |
| `user_dashboard/widgets/points_summary_card.dart` | 포인트 요약 카드 |
| `user_dashboard/widgets/profile_header_card.dart` | 프로필 헤더 카드 |
| `user_dashboard/widgets/settings_helpers.dart` | 설정 헬퍼 함수들 |
| `user_dashboard/widgets/settings_widgets.dart` | 설정 위젯들 |

---

## 🔐 Features - Admin (2개)

| 파일 | 역할 |
|------|------|
| `features/admin/admin_cleanup_screen.dart` | 관리자 데이터 정리 화면 |
| `features/admin/widgets/user_point_grant_dialog.dart` | 사용자 포인트 지급 다이얼로그 |

---

## 🎯 Features - Performance System (4개)

| 파일 | 역할 |
|------|------|
| `performance_system/services/benchmark_service.dart` | 벤치마크 서비스 (성능 측정) |
| `performance_system/services/load_testing_service.dart` | 부하 테스트 서비스 |
| `performance_system/services/optimization_service.dart` | 최적화 서비스 |
| `performance_system/services/performance_monitor.dart` | 성능 모니터링 서비스 |

---

## 🤝 Features - Shared Services (3개)

| 파일 | 역할 |
|------|------|
| `shared_services/image_upload_service.dart` | 이미지 업로드 서비스 (Firebase Storage) |
| `shared_services/production_service.dart` | 프로덕션 서비스 |
| `shared_services/track_service.dart` | 트래킹 서비스 (사용자 행동 분석) |

---

## 🎨 Providers (6개)

| 파일 | 역할 |
|------|------|
| `providers/auth_provider.dart` | ✨ 사용자 인증 상태 관리 (로그인, 회원가입, 사용자 정보) |
| `providers/screen_provider.dart` | 화면 상태 관리 |
| `providers/search_provider.dart` | 검색 상태 관리 |
| `providers/user_provider.dart` | 사용자 정보 상태 관리 |
| `providers/wallet_provider.dart` | 지갑 상태 관리 |

---

## 🖼️ Screens (3개)

### Auth Screens (3개)
| 파일 | 역할 |
|------|------|
| `screens/auth/address_search_screen.dart` | 주소 검색 화면 |
| `screens/auth/login_screen.dart` | 로그인 화면 |
| `screens/auth/signup_screen.dart` | 회원가입 화면 (944줄) |

---

## 🧩 Widgets (4개)

| 파일 | 역할 |
|------|------|
| `widgets/network_image_fallback_stub.dart` | 네트워크 이미지 Fallback Stub |
| `widgets/network_image_fallback_web.dart` | 네트워크 이미지 Fallback (웹) |
| `widgets/network_image_fallback_with_data.dart` | 네트워크 이미지 Fallback + 데이터 |

---

## 🛠️ Utils (6개)

| 파일 | 역할 |
|------|------|
| `utils/admin_point_grant.dart` | 관리자 포인트 지급 유틸리티 |
| `utils/config/config.dart` | 앱 설정 |
| `utils/extensions/context_extensions.dart` | Context 확장 함수 |
| `utils/s2_tile_utils.dart` | S2 타일 유틸리티 (103줄) |
| `utils/tile_utils.dart` | 타일 유틸리티 (282줄) |
| `utils/web/web_dom.dart` | 웹 DOM 유틸리티 |
| `utils/web/web_dom_stub.dart` | 웹 DOM Stub |

---

## 🌍 Localization (1개)

| 파일 | 역할 |
|------|------|
| `l10n/app_localizations.dart` | 앱 다국어 지원 (현재는 한국어만) |

---

## 🗄️ Backup Files (10개) - 삭제 가능

| 파일 | 역할 |
|------|------|
| `backup_before_split/edit_place_screen.dart` | 장소 편집 화면 백업 (1,602줄) |
| `backup_before_split/place_detail_screen.dart` | 장소 상세 백업 (1,518줄) |
| `backup_before_split/post_deploy_screen.dart` | 포스트 배포 백업 (1,897줄) |
| `backup_before_split/post_detail_screen.dart` | 포스트 상세 백업 (3,039줄) |
| `backup_before_split/post_detail_screen_original.dart` | 포스트 상세 원본 백업 (3,039줄) |
| `backup_before_split/post_edit_screen.dart` | 포스트 편집 백업 (1,310줄) |
| `backup_before_split/post_place_screen.dart` | 포스트 장소 백업 (1,949줄) |
| `backup_before_split/post_service.dart` | 포스트 서비스 백업 (2,161줄) |
| `backup_before_split/post_statistics_screen.dart` | 포스트 통계 백업 (3,019줄) |
| `backup_before_split/settings_screen.dart` | 설정 백업 (1,608줄) |

**총 백업 라인**: 21,142 라인 (정리 권장)

---

## 🔧 Other Files (3개)

| 파일 | 역할 |
|------|------|
| `debug_firebase_check.dart` | Firebase 연결 디버그 체크 |
| `firebase_options.dart` | Firebase 설정 옵션 (자동 생성) |
| `routes/app_routes.dart` | 앱 라우팅 설정 |

---

## 📊 요약 통계

### 파일 개수
```
총 파일: 227개

Core: 41개
  ├─ Models: 13개
  ├─ Repositories: 3개 ✨
  ├─ Services: 19개
  ├─ Utils: 4개
  └─ Constants: 1개

Features: 120개
  ├─ Map System: 48개
  ├─ Post System: 35개
  ├─ Place System: 17개
  ├─ User Dashboard: 11개
  ├─ Admin: 2개
  ├─ Performance: 4개
  └─ Shared: 3개

Providers: 6개 (5개 ✨ Clean Architecture)
Screens: 3개 (Auth)
Widgets: 4개
Utils: 7개
Localization: 1개
Backup: 10개 (삭제 권장)
Other: 3개
```

### Clean Architecture 적용 현황
```
✅ Provider: 6개 (100%)
✅ Repository: 3개 (100%)
✅ Service: 3개 (진행 중)
⚠️ Deprecated: ~10개 파일 (정리 필요)
```

### 거대 파일 (1,000줄 이상)
```
🔴 긴급 분할 필요:
  - map_screen_fog_methods.dart (1,772줄)
  - inbox_screen.dart (2,127줄)
  - create_place_screen.dart (1,662줄)
  - map_screen_ui_methods.dart (1,517줄)
  
⚠️ 분할 권장:
  - post_detail_ui_widgets.dart (1,001줄)
  - store_screen.dart (1,000줄)
  - post_statistics_charts.dart (997줄)
```

---

**생성일**: 2025-10-18
**총 코드**: ~106,000 라인
**Clean Architecture 진행률**: 약 15% 완료

