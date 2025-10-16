# 🔄 Clean Architecture 마이그레이션 가이드

## 📋 마이그레이션 체크리스트

- [ ] Phase 1: Core & Shared 재구성
- [ ] Phase 2: Feature - Auth
- [ ] Phase 3: Feature - Map
- [ ] Phase 4: Feature - Post
- [ ] Phase 5: Feature - Place
- [ ] Phase 6: Feature - Dashboard
- [ ] Phase 7: Feature - Settings
- [ ] Phase 8: Config 정리
- [ ] Phase 9: 검증 및 테스트

---

## 🚀 Phase 1: Core & Shared 재구성

### 1.1 Models 이동

```bash
# User Models
mv lib/core/models/user/* lib/shared/data/models/user/

# Post Models  
mv lib/core/models/post/* lib/shared/data/models/post/

# Place Models
mv lib/core/models/place/* lib/shared/data/models/place/

# Marker Models
mv lib/core/models/marker/* lib/shared/data/models/marker/

# Map Models
mv lib/core/models/map/* lib/shared/data/models/map/
```

**Import 변경:**
```dart
// Before
import 'package:your_app/core/models/user/user_model.dart';

// After
import 'package:your_app/shared/data/models/user/user_model.dart';
```

### 1.2 Services 이동

```bash
# Auth Services
mv lib/core/services/auth/* lib/shared/services/auth/

# Data Services → Repositories/DataSources로 분리 필요
# 수동으로 리팩토링 필요
```

### 1.3 공통 Widgets 이동

```bash
# 루트 widgets → core/widgets
mv lib/widgets/network_image_fallback_*.dart lib/core/widgets/
```

### 1.4 Utils 정리

```bash
# Extensions
mv lib/utils/extensions/* lib/core/utils/extensions/

# Config
mv lib/utils/config/* lib/config/environment/

# Web utils
mv lib/utils/web/* lib/core/utils/web/
```

---

## 🔐 Phase 2: Feature - Auth

### 2.1 Screens 이동

```bash
# Auth screens
mv lib/screens/auth/login_screen.dart lib/features/auth/presentation/screens/
mv lib/screens/auth/signup_screen.dart lib/features/auth/presentation/screens/
mv lib/screens/auth/address_search_screen.dart lib/features/auth/presentation/screens/
```

**Import 변경:**
```dart
// Before
import 'package:your_app/screens/auth/login_screen.dart';

// After
import 'package:your_app/features/auth/presentation/screens/login_screen.dart';
```

---

## 🗺️ Phase 3: Feature - Map

### 3.1 Data Layer

```bash
# Models (이미 생성된 파일)
# lib/features/map_system/models/marker_item.dart
# lib/features/map_system/state/map_state.dart
# → lib/features/map/data/models/로 이동
mv lib/features/map_system/models/marker_item.dart lib/features/map/data/models/
mv lib/features/map_system/state/map_state.dart lib/features/map/data/models/
```

### 3.2 Domain Layer (Controllers → UseCases)

**변환 예시: LocationController → GetCurrentLocationUseCase**

```dart
// lib/features/map/domain/usecases/get_current_location.dart

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class GetCurrentLocationUseCase {
  Future<LatLng?> call({
    bool isMockMode = false,
    LatLng? mockPosition,
  }) async {
    if (isMockMode && mockPosition != null) {
      return mockPosition;
    }
    
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }
}
```

**모든 Controller를 UseCase로 변환:**

| Controller | UseCase 파일명 |
|-----------|---------------|
| LocationController | get_current_location.dart |
| | get_address_from_latlng.dart |
| | calculate_distance.dart |
| FogController | update_fog_of_war.dart |
| | load_user_locations.dart |
| | load_visited_locations.dart |
| MarkerController | build_clustered_markers.dart |
| | collect_marker.dart |
| PostController (map) | collect_post_from_map.dart |

### 3.3 Presentation Layer

```bash
# Providers (기존)
# lib/features/map_system/providers/* → lib/features/map/presentation/providers/
mv lib/features/map_system/providers/* lib/features/map/presentation/providers/

# Screens (기존)
mv lib/features/map_system/screens/* lib/features/map/presentation/screens/

# Widgets (기존 + 신규)
mv lib/features/map_system/widgets/* lib/features/map/presentation/widgets/
```

**Import 변경 예시:**
```dart
// Before
import '../controllers/location_controller.dart';
final position = await LocationController.getCurrentLocation();

// After  
import '../../domain/usecases/get_current_location.dart';
final useCase = GetCurrentLocationUseCase();
final position = await useCase();
```

---

## 📮 Phase 4: Feature - Post

### 4.1 Data Layer

```bash
# Models
mv lib/features/post_system/state/post_detail_state.dart lib/features/post/data/models/
```

### 4.2 Domain Layer (Controllers & Helpers → UseCases)

**Helpers 변환:**

```dart
// lib/features/post/domain/usecases/create_post.dart

class CreatePostUseCase {
  final PostRepository repository;
  
  CreatePostUseCase(this.repository);
  
  Future<String> call({
    required String creatorId,
    required String title,
    // ... 기타 파라미터
  }) async {
    // PostCreationHelper의 로직을 여기로 이동
    return await repository.createPost(...);
  }
}
```

**Controller 변환:**

| Controller/Helper | UseCase 파일명 |
|------------------|---------------|
| PostCreationHelper | create_post.dart |
| PostCollectionHelper | collect_post.dart |
| PostDetailController | delete_post.dart, recall_post.dart |
| PostStatisticsController | get_post_statistics.dart, calculate_roi.dart |
| PostPlaceController | load_places.dart, search_places.dart |
| PostDeployController | deploy_post.dart, validate_deploy_location.dart |
| PostEditController | update_post.dart, validate_post_data.dart |

### 4.3 Presentation Layer

```bash
# Screens
mv lib/features/post_system/screens/* lib/features/post/presentation/screens/

# Widgets
mv lib/features/post_system/widgets/* lib/features/post/presentation/widgets/
```

---

## 🏢 Phase 5: Feature - Place

### 5.1 Domain Layer

**PlaceController → UseCases**

```dart
// lib/features/place/domain/usecases/create_place.dart

class CreatePlaceUseCase {
  final PlaceRepository repository;
  
  CreatePlaceUseCase(this.repository);
  
  Future<String> call({
    required String creatorId,
    required String name,
    required String type,
    required String address,
    required LatLng location,
    // ... 기타 파라미터
  }) async {
    return await repository.createPlace(...);
  }
}
```

| Controller Method | UseCase |
|------------------|---------|
| createPlace | create_place.dart |
| updatePlace | update_place.dart |
| deletePlace | delete_place.dart |
| getPlace | get_place.dart |
| getUserPlaces | get_user_places.dart |

### 5.2 Presentation Layer

```bash
# Screens
mv lib/features/place_system/screens/* lib/features/place/presentation/screens/
```

---

## 📊 Phase 6: Feature - Dashboard

### 6.1 Domain Layer

**InboxController → UseCases**

```dart
// lib/features/dashboard/domain/usecases/filter_posts.dart

class FilterPostsUseCase {
  List<PostModel> call({
    required List<PostModel> posts,
    String? statusFilter,
    String? periodFilter,
  }) {
    // InboxController.filterPosts 로직 이동
    return filteredPosts;
  }
}
```

| Controller Method | UseCase |
|------------------|---------|
| filterPosts | filter_posts.dart |
| sortPosts | sort_posts.dart |
| calculateStatistics | calculate_statistics.dart |

### 6.2 Presentation Layer

```bash
# Screens (user_dashboard → dashboard)
mv lib/features/user_dashboard/screens/inbox_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/wallet_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/points_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/budget_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/main_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/search_screen.dart lib/features/dashboard/presentation/screens/
mv lib/features/user_dashboard/screens/trash_screen.dart lib/features/dashboard/presentation/screens/

# Widgets
mv lib/features/user_dashboard/widgets/* lib/features/dashboard/presentation/widgets/
```

---

## ⚙️ Phase 7: Feature - Settings

### 7.1 Domain Layer

**SettingsController → UseCases**

```dart
// lib/features/settings/domain/usecases/update_profile.dart

class UpdateProfileUseCase {
  final UserRepository repository;
  
  UpdateProfileUseCase(this.repository);
  
  Future<bool> call({
    required String userId,
    String? displayName,
    String? phoneNumber,
    // ... 기타 파라미터
  }) async {
    return await repository.updateProfile(...);
  }
}
```

| Controller Method | UseCase |
|------------------|---------|
| updateUserProfile | update_profile.dart |
| updateNotificationSettings | update_notification_settings.dart |
| changePassword | change_password.dart |
| deleteAccount | delete_account.dart |
| logout | logout.dart |

### 7.2 Presentation Layer

```bash
# Screens
mv lib/features/user_dashboard/screens/settings_screen.dart lib/features/settings/presentation/screens/
```

---

## ⚙️ Phase 8: Config 정리

### 8.1 Routes

```bash
# Routes
mv lib/routes/app_routes.dart lib/config/routes/app_router.dart
```

**Import 변경:**
```dart
// Before
import 'package:your_app/routes/app_routes.dart';

// After
import 'package:your_app/config/routes/app_router.dart';
```

### 8.2 Localization

```bash
# L10n
mv lib/l10n/app_localizations.dart lib/config/localization/
```

### 8.3 Firebase Config

```bash
# Firebase (이미 올바른 위치)
# lib/firebase_options.dart → lib/config/environment/
mv lib/firebase_options.dart lib/config/environment/
```

---

## ✅ Phase 9: 검증 및 테스트

### 9.1 Import 검증 스크립트

```bash
# 모든 Dart 파일에서 import 확인
flutter pub run import_sorter:main

# 또는
dart format .
```

### 9.2 빌드 테스트

```bash
# 빌드 확인
flutter clean
flutter pub get
flutter build apk --debug

# 또는
flutter run
```

### 9.3 린트 체크

```bash
# 린트 확인
flutter analyze

# 수정
dart fix --apply
```

### 9.4 Import 일괄 변경 (VSCode)

1. **Find in Files** (Ctrl+Shift+F)
2. 정규식 사용
3. 일괄 변경

**예시:**

```
# 찾기
import '(.*)core/models/user/(.*)';

# 바꾸기
import '$1shared/data/models/user/$2';
```

---

## 📝 Import 변경 패턴 정리

| 카테고리 | Before | After |
|----------|--------|-------|
| **User Model** | `core/models/user/` | `shared/data/models/user/` |
| **Post Model** | `core/models/post/` | `shared/data/models/post/` |
| **Place Model** | `core/models/place/` | `shared/data/models/place/` |
| **Auth Service** | `core/services/auth/` | `shared/services/auth/` |
| **Map Screen** | `features/map_system/screens/` | `features/map/presentation/screens/` |
| **Post Screen** | `features/post_system/screens/` | `features/post/presentation/screens/` |
| **Place Screen** | `features/place_system/screens/` | `features/place/presentation/screens/` |
| **Dashboard** | `features/user_dashboard/screens/` | `features/dashboard/presentation/screens/` |
| **Routes** | `routes/app_routes.dart` | `config/routes/app_router.dart` |
| **L10n** | `l10n/` | `config/localization/` |
| **Utils** | `utils/extensions/` | `core/utils/extensions/` |
| **Controllers** | `features/*/controllers/` | `features/*/domain/usecases/` |

---

## ⚠️ 주의사항

1. **한 번에 하나의 Feature씩 이동**
   - Map → Post → Place → Dashboard 순서 권장

2. **Import 변경 후 즉시 테스트**
   - 각 Phase 완료 후 빌드 확인

3. **백업 필수**
   ```bash
   git commit -m "Before Clean Architecture migration"
   git branch backup-before-migration
   ```

4. **Provider 업데이트**
   - GetIt, Riverpod 등 DI 설정 업데이트 필요

5. **기존 파일 삭제 전 확인**
   - 모든 기능이 정상 동작하는지 확인 후 삭제

---

## 🎯 완료 후 확인사항

- [ ] 모든 파일이 올바른 위치로 이동
- [ ] Import 에러 없음
- [ ] 빌드 성공
- [ ] 린트 에러 없음
- [ ] 모든 화면 정상 동작
- [ ] Hot reload 정상 작동
- [ ] 기존 기능 누락 없음

---

## 💡 팁

### VSCode에서 파일 이동 시

1. 파일 Drag & Drop 사용
2. 자동으로 import 경로 업데이트됨
3. 단, 모든 파일이 제대로 업데이트되는지 확인 필요

### 대규모 Import 변경 시

```bash
# find-and-replace 스크립트 사용
# migration_scripts/update_imports.sh

#!/bin/bash
find lib -name "*.dart" -type f -exec sed -i '' \
  's|core/models/user/|shared/data/models/user/|g' {} +
```

