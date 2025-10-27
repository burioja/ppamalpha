# PPAM Alpha 프로젝트 구조 최적화 가이드

프로젝트의 현재 구조를 분석하고, 효율적이고 확장 가능한 구조로 개선하기 위한 종합 가이드입니다.

## 목차
1. [현재 프로젝트 구조 분석](#1-현재-프로젝트-구조-분석)
2. [프로젝트 리더 제안 구조](#2-프로젝트-리더-제안-구조)
3. [최적화된 구조 제안](#3-최적화된-구조-제안)
4. [데이터베이스 구조](#4-데이터베이스-구조)
5. [구조 비교 분석](#5-구조-비교-분석)
6. [마이그레이션 로드맵](#6-마이그레이션-로드맵)

---

## 1. 현재 프로젝트 구조 분석

### 1.1 실제 lib/ 구조

현재 ppam 프로젝트는 **하이브리드 구조**를 사용하고 있습니다:

```
lib/
├── core/                          # 공통 비즈니스 로직 (부분적 Clean Architecture)
│   ├── constants/
│   ├── datasources/
│   │   └── firebase/              # Firebase 데이터 소스
│   ├── models/                    # 도메인 모델
│   │   ├── map/                   # FogLevel
│   │   ├── marker/                # MarkerModel
│   │   ├── place/                 # PlaceModel
│   │   ├── post/                  # PostModel, PostInstanceModel 등
│   │   └── user/                  # UserModel, UserPointsModel
│   ├── repositories/              # Repository 패턴
│   └── services/                  # 비즈니스 서비스
│       ├── admin/
│       ├── auth/
│       ├── cache/
│       ├── data/
│       ├── location/
│       ├── migration/
│       └── storage/
├── features/                      # Feature 기반 모듈 (권장)
│   ├── admin/
│   │   └── widgets/
│   ├── map_system/                # 지도 시스템
│   │   ├── controllers/
│   │   ├── handlers/
│   │   ├── helpers/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   │   ├── clustering/
│   │   │   ├── filtering/
│   │   │   ├── fog/
│   │   │   ├── fog_of_war/
│   │   │   ├── interaction/
│   │   │   ├── markers/
│   │   │   └── tiles/
│   │   ├── state/
│   │   ├── utils/
│   │   └── widgets/
│   ├── performance_system/
│   │   ├── services/
│   │   ├── utils/
│   │   └── widgets/
│   ├── place_system/              # 장소 시스템
│   │   ├── constants/
│   │   ├── controllers/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── post_system/               # 포스트 시스템
│   │   ├── controllers/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── state/
│   │   ├── utils/
│   │   └── widgets/
│   ├── user_dashboard/            # 사용자 대시보드
│   │   ├── controllers/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── state/
│   │   └── widgets/
│   └── shared_services/
├── screens/                       # 레거시 화면 (마이그레이션 필요)
│   ├── auth/                      # → features/auth_system/
│   ├── place/                     # → features/place_system/
│   └── shared/
├── providers/                     # 레거시 Provider (마이그레이션 필요)
├── services/                      # 레거시 서비스 (마이그레이션 필요)
├── widgets/                       # 레거시 위젯 (마이그레이션 필요)
├── utils/                         # 유틸리티
│   ├── config/
│   ├── extensions/
│   ├── helpers/
│   └── web/
├── routes/                        # 라우팅
├── di/                            # 의존성 주입
├── l10n/                          # 다국어
├── app.dart
├── main.dart
└── firebase_options.dart
```

### 1.2 functions/ 구조 (Cloud Functions)

```
functions/
├── src/
│   ├── index.ts                   # 메인 진입점
│   ├── postIndexing.ts            # 포스트 인덱싱
│   ├── postReceipt.ts             # 포스트 수령 처리
│   └── queryPosts.ts              # 포스트 쿼리
├── package.json
└── tsconfig.json
```

### 1.3 현재 구조의 문제점

#### 심각한 문제
1. **레거시 혼재**: `lib/screens/`, `lib/providers/`, `lib/services/` vs `lib/features/`
2. **구조 불일치**: 일부는 features 기반, 일부는 레거시 구조
3. **중복 코드**: `core/services/` vs `features/*/services/`
4. **모델 위치 혼란**: `core/models/` vs `features/*/models/`

#### 개선 필요
1. **의존성 방향**: 명확한 레이어 분리 부족
2. **테스트 어려움**: 강결합으로 인한 테스트 복잡도
3. **확장성 제한**: 새 기능 추가 시 구조 고민 필요
4. **AI 코딩 비효율**: 일관되지 않은 패턴으로 AI가 혼란

---

## 2. 프로젝트 리더 제안 구조

프로젝트 리더가 제안한 구조는 **Clean Architecture + DDD (Domain-Driven Design)** 패턴입니다:

```
lib/
├── infrastructure/                # 인프라 레이어
│   ├── network/
│   │   ├── dio_client.dart
│   │   └── interceptors/
│   ├── storage/
│   │   ├── secure_storage.dart
│   │   └── kv_store.dart
│   └── logging/
│       └── logger.dart
├── shared/                        # 공유 레이어
│   ├── result.dart
│   ├── failures.dart
│   ├── mixins/
│   ├── extensions/
│   ├── widgets/
│   └── theme/
│       └── tokens/                # Design Tokens
│           ├── color.tokens.json
│           ├── typography.tokens.json
│           ├── spacing.tokens.json
│           ├── radius.tokens.json
│           ├── shadow.tokens.json
│           └── motion.tokens.json
├── features/                      # Feature 모듈 (DDD)
│   ├── auth_system/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   ├── data/
│   │   │   ├── repositories/
│   │   │   ├── datasources/
│   │   │   ├── dto/
│   │   │   └── mappers/
│   │   └── application/
│   │       └── services/
│   ├── map_system/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   ├── providers/
│   │   │   ├── widgets/
│   │   │   └── wrappers/
│   │   ├── domain/
│   │   ├── data/
│   │   └── application/
│   ├── place_system/
│   ├── post_system/
│   ├── dashboard_system/
│   ├── search_system/
│   └── analytics_system/
└── app.dart
```

### 2.1 리더 제안의 장점

1. **명확한 레이어 분리**: Presentation → Application → Domain → Data → Infrastructure
2. **의존성 역전 원칙**: Domain이 중심, Infrastructure는 주변부
3. **테스트 용이성**: 각 레이어 독립적 테스트 가능
4. **확장성**: 새 기능 추가 시 명확한 구조
5. **Design Tokens 통합**: Figma와 일관성 유지

### 2.2 리더 제안의 단점 (현실적 한계)

1. **과도한 보일러플레이트**: 작은 기능에도 많은 파일 필요
2. **러닝 커브**: 팀원 전체가 DDD/Clean Architecture 이해 필요
3. **마이그레이션 부담**: 현재 코드 전체 재작성 필요
4. **Flutter 커뮤니티 관행과 차이**: Flutter는 보통 더 실용적인 구조 선호
5. **AI 코딩 복잡도**: 너무 많은 레이어로 AI가 혼란

---

## 3. 최적화된 구조 제안

**현실적이고 AI 바이브 코딩에 최적화된 하이브리드 구조**를 제안합니다.

### 3.1 핵심 원칙

1. **점진적 개선**: 전체 재작성 없이 단계적 마이그레이션
2. **실용주의**: 필요한 만큼만 추상화
3. **AI 친화적**: 일관되고 예측 가능한 패턴
4. **레퍼런스 통합**: TouristAssist, Spot, Deliverzler 패턴 참고

### 3.2 최적화 구조

```
lib/
├── core/                          # 핵심 비즈니스 로직 (현재 유지 + 개선)
│   ├── domain/                    # 도메인 레이어 (신규)
│   │   ├── entities/              # 비즈니스 엔티티
│   │   │   ├── user/
│   │   │   ├── post/
│   │   │   ├── marker/
│   │   │   ├── place/
│   │   │   └── analytics/
│   │   ├── repositories/          # Repository 인터페이스
│   │   │   ├── user_repository.dart
│   │   │   ├── post_repository.dart
│   │   │   ├── marker_repository.dart
│   │   │   └── place_repository.dart
│   │   └── services/              # 도메인 서비스
│   │       ├── auth_service.dart
│   │       └── location_service.dart
│   ├── data/                      # 데이터 레이어 (신규 정리)
│   │   ├── datasources/
│   │   │   ├── remote/            # Firebase, API
│   │   │   │   ├── firebase/
│   │   │   │   └── api/
│   │   │   └── local/             # Cache, Storage
│   │   │       ├── cache/
│   │   │       └── storage/
│   │   ├── repositories/          # Repository 구현
│   │   │   ├── user_repository_impl.dart
│   │   │   ├── post_repository_impl.dart
│   │   │   ├── marker_repository_impl.dart
│   │   │   └── place_repository_impl.dart
│   │   ├── models/                # DTO (Data Transfer Objects)
│   │   │   ├── user_dto.dart
│   │   │   ├── post_dto.dart
│   │   │   └── marker_dto.dart
│   │   └── mappers/               # DTO ↔ Entity 변환
│   │       ├── user_mapper.dart
│   │       ├── post_mapper.dart
│   │       └── marker_mapper.dart
│   ├── infrastructure/            # 인프라 레이어 (신규)
│   │   ├── network/
│   │   │   ├── dio_client.dart
│   │   │   └── interceptors/
│   │   ├── storage/
│   │   │   ├── secure_storage.dart
│   │   │   └── shared_preferences.dart
│   │   └── logging/
│   │       └── logger.dart
│   └── constants/                 # 상수 (유지)
│       └── app_constants.dart
├── shared/                        # 공유 컴포넌트 (신규 정리)
│   ├── theme/                     # Design System
│   │   ├── tokens/                # Figma Design Tokens
│   │   │   ├── colors.dart
│   │   │   ├── typography.dart
│   │   │   ├── spacing.dart
│   │   │   ├── radius.dart
│   │   │   └── shadows.dart
│   │   ├── app_theme.dart
│   │   └── theme_extensions.dart
│   ├── widgets/                   # Atomic Design
│   │   ├── atoms/                 # 기본 요소
│   │   │   ├── buttons/
│   │   │   ├── inputs/
│   │   │   ├── icons/
│   │   │   └── texts/
│   │   ├── molecules/             # 조합 컴포넌트
│   │   │   ├── cards/
│   │   │   ├── list_items/
│   │   │   └── dialogs/
│   │   └── organisms/             # 복잡한 컴포넌트
│   │       ├── headers/
│   │       ├── footers/
│   │       └── forms/
│   ├── utils/                     # 유틸리티
│   │   ├── extensions/
│   │   ├── helpers/
│   │   ├── validators/
│   │   └── formatters/
│   ├── models/                    # 공유 모델
│   │   ├── result.dart
│   │   ├── failure.dart
│   │   └── paginated_response.dart
│   └── mixins/                    # 공유 Mixin
├── features/                      # Feature 모듈 (간소화된 Clean Architecture)
│   ├── auth/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── signup_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart
│   │   │   └── widgets/
│   │   │       ├── login_form.dart
│   │   │       └── social_login_buttons.dart
│   │   └── application/           # 간소화: domain 제거, application으로 통합
│   │       ├── usecases/
│   │       │   ├── login_usecase.dart
│   │       │   └── signup_usecase.dart
│   │       └── services/
│   │           └── auth_validator.dart
│   ├── map/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── map_screen.dart
│   │   │   │   └── map_filter_screen.dart
│   │   │   ├── providers/
│   │   │   │   ├── map_provider.dart
│   │   │   │   ├── fog_provider.dart
│   │   │   │   └── marker_provider.dart
│   │   │   └── widgets/
│   │   │       ├── map_view.dart
│   │   │       ├── marker_cluster.dart
│   │   │       └── fog_overlay.dart
│   │   └── application/
│   │       ├── usecases/
│   │       │   ├── load_markers_usecase.dart
│   │       │   ├── collect_post_usecase.dart
│   │       │   └── update_fog_usecase.dart
│   │       └── services/
│   │           ├── clustering_service.dart
│   │           ├── fog_service.dart
│   │           └── tile_service.dart
│   ├── place/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── place_list_screen.dart
│   │   │   │   └── place_detail_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── place_provider.dart
│   │   │   └── widgets/
│   │   │       ├── place_card.dart
│   │   │       └── place_filter.dart
│   │   └── application/
│   │       └── usecases/
│   │           ├── search_places_usecase.dart
│   │           └── get_nearby_places_usecase.dart
│   ├── post/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── create_post_screen.dart
│   │   │   │   ├── post_detail_screen.dart
│   │   │   │   └── deploy_marker_screen.dart
│   │   │   ├── providers/
│   │   │   │   ├── post_provider.dart
│   │   │   │   └── post_instance_provider.dart
│   │   │   └── widgets/
│   │   │       ├── post_card.dart
│   │   │       ├── post_form.dart
│   │   │       └── marker_deployment_form.dart
│   │   └── application/
│   │       └── usecases/
│   │           ├── create_post_template_usecase.dart
│   │           ├── deploy_marker_usecase.dart
│   │           └── collect_post_instance_usecase.dart
│   ├── dashboard/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── inbox_screen.dart
│   │   │   │   ├── my_posts_screen.dart
│   │   │   │   └── received_posts_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── dashboard_provider.dart
│   │   │   └── widgets/
│   │   │       ├── post_list.dart
│   │   │       └── inbox_tabs.dart
│   │   └── application/
│   │       └── usecases/
│   │           ├── get_my_posts_usecase.dart
│   │           └── get_received_posts_usecase.dart
│   ├── analytics/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── analytics_dashboard_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── analytics_provider.dart
│   │   │   └── widgets/
│   │   │       ├── metrics_chart.dart
│   │   │       └── stats_card.dart
│   │   └── application/
│   │       └── usecases/
│   │           └── get_analytics_usecase.dart
│   └── search/
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── search_screen.dart
│       │   ├── providers/
│       │   │   └── search_provider.dart
│       │   └── widgets/
│       │       └── search_bar.dart
│       └── application/
│           └── usecases/
│               └── search_usecase.dart
├── config/                        # 앱 설정 (신규)
│   ├── routes/
│   │   └── app_routes.dart
│   ├── di/                        # 의존성 주입
│   │   ├── injection.dart
│   │   └── modules/
│   └── environment/
│       ├── env.dart
│       └── env_config.dart
├── l10n/                          # 다국어 (유지)
├── app.dart
├── main.dart
└── firebase_options.dart
```

### 3.3 최적화 구조의 특징

#### 장점
1. **점진적 마이그레이션 가능**: 현재 코드와 공존 가능
2. **적절한 추상화**: 과도하지 않은 레이어 분리
3. **AI 친화적**: 예측 가능한 폴더 구조
4. **레퍼런스 패턴**: TouristAssist, Deliverzler 참고
5. **Design Tokens 통합**: Figma 연동 준비

#### 개선 사항
1. **3-Layer 아키텍처**: Presentation → Application → Core (Data + Domain)
2. **Feature별 독립성**: 각 feature는 독립 실행 가능
3. **Atomic Design**: UI 컴포넌트 체계적 관리
4. **명확한 의존성**: Core ← Features → Shared

---

## 4. 데이터베이스 구조

### 4.1 현재 Firestore 컬렉션

#### 핵심 컬렉션

##### `users`
```javascript
{
  "userId": "user_abc123",
  "email": "user@example.com",
  "displayName": "김철수",
  "photoUrl": "https://...",
  "createdAt": Timestamp,
  "points": 1500,
  "level": 3,
  "visited_tiles": [...]  // 서브컬렉션
}
```

##### `posts` - 포스트 템플릿
```javascript
{
  "postId": "post_12345",
  "creatorId": "user_abc123",
  "creatorName": "김철수",
  "createdAt": Timestamp,

  // 콘텐츠
  "title": "맛있는 치킨집 할인쿠폰",
  "description": "오늘 하루만 20% 할인!",
  "reward": 500,

  // 미디어
  "mediaType": ["image"],
  "mediaUrl": ["https://..."],
  "thumbnailUrl": ["https://..."],

  // 타겟팅
  "targetAge": [20, 40],
  "targetGender": "all",
  "targetInterest": ["음식"],

  // 상태
  "status": "active",
  "isActive": true,
  "totalDeployments": 5,
  "totalInstances": 23
}
```

##### `markers` - 배포된 마커
```javascript
{
  "markerId": "marker_67890",
  "postId": "post_12345",
  "creatorId": "user_abc123",

  // 위치
  "location": GeoPoint(37.5665, 126.9780),
  "radius": 1000,

  // 수량
  "totalQuantity": 10,
  "remainingQuantity": 7,
  "collectedQuantity": 3,

  // 기간
  "startDate": Timestamp,
  "endDate": Timestamp,
  "createdAt": Timestamp,

  // 지리 인덱싱
  "tileId": "tile_123_456",
  "s2_10": "s2cell_...",
  "s2_12": "s2cell_...",

  // 상태
  "isActive": true,
  "status": "active"
}
```

##### `post_instances` - 수집된 포스트
```javascript
{
  "instanceId": "instance_xyz789",
  "postId": "post_12345",
  "markerId": "marker_67890",
  "userId": "user_def456",

  // 수집 정보
  "collectedAt": Timestamp,
  "collectedLocation": GeoPoint,

  // 사용 정보
  "usedAt": null,
  "isUsed": false,

  // 템플릿 스냅샷 (수집 시점 복사)
  "title": "맛있는 치킨집 할인쿠폰",
  "description": "...",
  "reward": 500,
  "mediaUrl": ["..."],
  "expiresAt": Timestamp,

  // 상태
  "status": "collected"
}
```

##### `post_usage` - 포인트 사용 기록
```javascript
{
  "usageId": "usage_...",
  "userId": "user_...",
  "postId": "post_...",
  "instanceId": "instance_...",
  "timestamp": Timestamp,
  "pointsEarned": 500,
  "action": "collect" // collect, use, forward
}
```

#### 보조 컬렉션

##### `places` - 장소 정보
```javascript
{
  "placeId": "place_...",
  "name": "치킨집",
  "location": GeoPoint,
  "category": "restaurant",
  "address": "서울시...",
  "phoneNumber": "02-...",
  "openingHours": {...}
}
```

##### `post_collections` (레거시 - 점진적 제거)
```javascript
// post_instances로 대체 예정
{
  "collectionId": "...",
  "userId": "...",
  "postId": "...",
  "collectedAt": Timestamp
}
```

### 4.2 Firestore 인덱스

현재 설정된 복합 인덱스 (`firestore.indexes.json`):

#### posts 인덱스
```javascript
{ "creatorId": ASC, "status": ASC, "createdAt": DESC }
{ "creatorId": ASC, "createdAt": DESC }
{ "status": ASC, "createdAt": DESC }
{ "creatorId": ASC, "isActive": ASC, "createdAt": DESC }
```

#### markers 인덱스
```javascript
{ "isActive": ASC, "expiresAt": ASC, "remainingQuantity": ASC }
{ "isActive": ASC, "expiresAt": ASC, "s2_10": ASC }
{ "postId": ASC, "isActive": ASC, "createdAt": DESC }
{ "creatorId": ASC, "isActive": ASC, "createdAt": DESC }
{ "isActive": ASC, "isSuperMarker": ASC, "expiresAt": ASC }
{ "isActive": ASC, "isCoupon": ASC, "expiresAt": ASC }
{ "isActive": ASC, "reward": ASC, "expiresAt": ASC }
```

#### post_collections 인덱스
```javascript
{ "userId": ASC, "status": ASC, "collectedAt": DESC }
{ "userId": ASC, "collectedAt": DESC }
```

#### post_usage 인덱스
```javascript
{ "userId": ASC, "timestamp": DESC }
{ "postId": ASC, "timestamp": DESC }
```

#### visited_tiles 인덱스
```javascript
{ "lastVisitTime": ASC }
{ "tileId": ASC, "lastVisitTime": ASC }
```

### 4.3 추가 필요 인덱스

#### post_instances (신규)
```javascript
{ "userId": ASC, "collectedAt": DESC }
{ "userId": ASC, "status": ASC, "collectedAt": DESC }
{ "postId": ASC, "collectedAt": DESC }
{ "markerId": ASC, "collectedAt": DESC }
{ "userId": ASC, "isUsed": ASC, "expiresAt": ASC }
```

### 4.4 보안 규칙 개선

현재 보안 규칙은 **임시 설정** (2024-11-04 만료):

```javascript
// 현재 (보안 취약)
match /{document=**} {
  allow read, write: if request.time < timestamp.date(2024, 11, 4);
}
```

**개선된 보안 규칙 제안**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 사용자 컬렉션
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;

      // 방문한 타일 서브컬렉션
      match /visited_tiles/{tileId} {
        allow read, write: if request.auth.uid == userId;
      }
    }

    // 포스트 템플릿
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.creatorId == request.auth.uid;
      allow update, delete: if request.auth != null
                           && resource.data.creatorId == request.auth.uid;
    }

    // 마커
    match /markers/{markerId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.creatorId == request.auth.uid;
      allow update: if request.auth != null
                   && (resource.data.creatorId == request.auth.uid
                       || request.resource.data.keys().hasOnly(['remainingQuantity', 'collectedQuantity']));
      allow delete: if request.auth != null
                   && resource.data.creatorId == request.auth.uid;
    }

    // 포스트 인스턴스
    match /post_instances/{instanceId} {
      allow read: if request.auth != null
                  && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null
                   && resource.data.userId == request.auth.uid;
      allow delete: if false; // 삭제 불가
    }

    // 포스트 사용 기록
    match /post_usage/{usageId} {
      allow read: if request.auth != null
                  && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;
      allow update, delete: if false; // 수정/삭제 불가 (감사 기록)
    }

    // 장소
    match /places/{placeId} {
      allow read: if request.auth != null;
      allow write: if false; // 관리자만 (Admin SDK)
    }
  }
}
```

### 4.5 데이터베이스 구조 개선 제안

#### 즉시 적용
1. **보안 규칙 업데이트**: 임시 규칙 → 프로덕션 규칙
2. **post_instances 인덱스 추가**: 새 컬렉션 인덱싱
3. **만료된 마커 정리 Cloud Function**: 주기적 정리

#### 단계적 적용
1. **post_collections 마이그레이션**: → post_instances
2. **통계 집계 최적화**: 실시간 집계 → 배치 처리
3. **캐싱 전략**: 자주 조회되는 데이터 Redis 캐싱

---

## 5. 구조 비교 분석

### 5.1 비교표

| 구분 | 현재 구조 | 리더 제안 | 최적화 제안 |
|------|----------|----------|------------|
| **아키텍처** | 하이브리드 (혼재) | Clean Architecture + DDD | 실용적 Clean Architecture |
| **레이어 수** | 불명확 (2-4) | 5개 (Presentation/Application/Domain/Data/Infrastructure) | 3개 (Presentation/Application/Core) |
| **복잡도** | 중간 (일관성 부족) | 높음 (보일러플레이트 많음) | 중간 (적절한 균형) |
| **학습 곡선** | 낮음 (레거시 혼재로 혼란) | 높음 (DDD 이해 필요) | 중간 (Flutter 커뮤니티 관행) |
| **마이그레이션** | - | 전체 재작성 필요 | 점진적 가능 |
| **AI 코딩** | 비효율 (패턴 불일치) | 어려움 (복잡도) | 효율적 (예측 가능) |
| **테스트** | 어려움 (강결합) | 매우 쉬움 | 쉬움 |
| **확장성** | 제한적 | 매우 높음 | 높음 |
| **Design Tokens** | 없음 | 있음 | 있음 |
| **레퍼런스 호환** | 낮음 | 중간 | 높음 (TouristAssist 유사) |

### 5.2 Feature별 파일 수 비교

**간단한 기능 (Login)** 기준:

| 구조 | 파일 수 | 주요 파일 |
|------|---------|----------|
| **현재** | 3-5개 | login_screen.dart, auth_service.dart, user_model.dart |
| **리더 제안** | 10-15개 | login_screen.dart, login_provider.dart, login_usecase.dart, auth_service.dart, user_entity.dart, user_dto.dart, user_mapper.dart, user_repository.dart, user_repository_impl.dart, firebase_auth_ds.dart 등 |
| **최적화** | 5-8개 | login_screen.dart, auth_provider.dart, login_usecase.dart, auth_service.dart, user_entity.dart, user_dto.dart, user_mapper.dart |

### 5.3 의존성 방향 비교

#### 현재 구조
```
screens/ → services/ → models/
         ↘ providers/ ↗
         (순환 의존성 가능)
```

#### 리더 제안
```
Presentation → Application → Domain ← Data ← Infrastructure
(엄격한 단방향)
```

#### 최적화 제안
```
Features (Presentation + Application) → Core (Domain + Data) → Infrastructure
                ↓
              Shared
(실용적 단방향)
```

---

## 6. 마이그레이션 로드맵

### Phase 1: 기반 구조 정리 (1-2주)

#### 1.1 폴더 구조 생성
```bash
# 새 폴더 구조 생성
mkdir -p lib/core/{domain,data,infrastructure}
mkdir -p lib/shared/{theme/tokens,widgets/{atoms,molecules,organisms},utils}
mkdir -p lib/config/{routes,di,environment}
```

#### 1.2 Design Tokens 설정
- Figma Variables Export → `lib/shared/theme/tokens/`
- Theme 통합 파일 생성: `app_theme.dart`
- VIBE_CODING_RULES 문서의 Figma 워크플로우 참고

#### 1.3 레거시 마킹
```dart
// lib/screens/ → @deprecated 마킹
// lib/providers/ → @deprecated 마킹
// lib/services/ → @deprecated 마킹
```

### Phase 2: Core 레이어 마이그레이션 (2-3주)

#### 2.1 Domain 레이어 생성
```dart
// core/domain/entities/user/user_entity.dart
class UserEntity {
  final String userId;
  final String email;
  final String displayName;
  // 비즈니스 로직만 포함
}

// core/domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<Result<UserEntity>> getUser(String userId);
  Future<Result<void>> updateUser(UserEntity user);
}
```

#### 2.2 Data 레이어 구현
```dart
// core/data/models/user_dto.dart
class UserDto {
  final String userId;
  final String email;
  final String displayName;

  // Firestore ↔ DTO 변환
  factory UserDto.fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore();
}

// core/data/mappers/user_mapper.dart
class UserMapper {
  static UserEntity toEntity(UserDto dto) { ... }
  static UserDto toDto(UserEntity entity) { ... }
}

// core/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final FirebaseDataSource _dataSource;

  @override
  Future<Result<UserEntity>> getUser(String userId) async {
    try {
      final dto = await _dataSource.getUser(userId);
      final entity = UserMapper.toEntity(dto);
      return Result.success(entity);
    } catch (e) {
      return Result.failure(Failure.fromException(e));
    }
  }
}
```

#### 2.3 Infrastructure 레이어
```dart
// core/infrastructure/network/dio_client.dart
class DioClient {
  final Dio _dio;

  DioClient() : _dio = Dio() {
    _dio.interceptors.add(LogInterceptor());
    _dio.interceptors.add(AuthInterceptor());
  }
}

// core/infrastructure/logging/logger.dart
class AppLogger {
  static void debug(String message) { ... }
  static void error(String message, [dynamic error]) { ... }
}
```

### Phase 3: Features 마이그레이션 (4-6주)

**우선순위 순서**:

#### 3.1 auth (1주)
```
features/auth/
├── presentation/
│   ├── screens/
│   ├── providers/
│   └── widgets/
└── application/
    ├── usecases/
    └── services/
```

**마이그레이션 작업**:
- `lib/screens/auth/` → `features/auth/presentation/screens/`
- `lib/providers/` (auth 관련) → `features/auth/presentation/providers/`
- `lib/core/services/auth/` → `features/auth/application/services/`

#### 3.2 map (2주)
```
features/map/
├── presentation/
│   ├── screens/
│   ├── providers/
│   └── widgets/
└── application/
    ├── usecases/
    └── services/
```

**마이그레이션 작업**:
- `lib/features/map_system/` → 새 구조로 재정리
- Fog of War 서비스 통합
- 레퍼런스: Deliverzler의 맵 구조 참고

#### 3.3 place (1주)
```
features/place/
├── presentation/
└── application/
```

**마이그레이션 작업**:
- `lib/features/place_system/` → 새 구조
- `lib/screens/place/` → 통합
- 레퍼런스: **TouristAssist** 구조 참고 (최우선)

#### 3.4 post (2주)
```
features/post/
├── presentation/
└── application/
```

**마이그레이션 작업**:
- `lib/features/post_system/` → 새 구조
- PostModel, PostInstanceModel 분리
- 레퍼런스: **Spot** 구조 참고 (지오태그 콘텐츠)

#### 3.5 dashboard (1주)
```
features/dashboard/
├── presentation/
└── application/
```

**마이그레이션 작업**:
- `lib/features/user_dashboard/` → 새 구조

### Phase 4: Shared 컴포넌트 정리 (1-2주)

#### 4.1 Atomic Design 적용
```dart
// shared/widgets/atoms/buttons/primary_button.dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary, // Design Token
        padding: EdgeInsets.all(AppSpacing.md), // Design Token
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(label, style: AppTypography.button),
    );
  }
}

// shared/widgets/molecules/cards/place_card.dart
class PlaceCard extends StatelessWidget {
  final PlaceEntity place;
  // Atoms 조합
}

// shared/widgets/organisms/forms/login_form.dart
class LoginForm extends StatelessWidget {
  // Molecules 조합
}
```

#### 4.2 위젯 카탈로그 생성
```dart
// lib/widget_catalog_screen.dart (개발용)
class WidgetCatalogScreen extends StatelessWidget {
  // 모든 Shared 위젯 시각화
  // Storybook 개념
}
```

### Phase 5: 레거시 제거 (1주)

#### 5.1 점진적 제거
```dart
// 1. @deprecated 마킹 확인
// 2. 사용처 검색 (0건 확인)
// 3. 파일 삭제
// 4. 테스트 통과 확인
```

#### 5.2 최종 정리
```bash
# 레거시 폴더 제거
rm -rf lib/screens/
rm -rf lib/providers/ (일부)
rm -rf lib/services/ (일부)
rm -rf lib/widgets/ (일부)

# 빈 폴더 정리
find lib -type d -empty -delete
```

### Phase 6: 문서화 및 최적화 (1주)

#### 6.1 문서 업데이트
- Architecture 문서 작성: `/docs/ARCHITECTURE.md`
- Feature별 README 작성: `features/*/README.md`
- API 문서 자동 생성: dartdoc

#### 6.2 성능 최적화
- 번들 크기 분석
- 불필요한 의존성 제거
- Lazy loading 적용

#### 6.3 AI 프롬프트 템플릿 업데이트
```markdown
# Feature 추가 템플릿
다음 기능을 구현해줘:

구조:
- features/[feature_name]/
  - presentation/ (UI)
  - application/ (비즈니스 로직)

레퍼런스:
- @features/place/ 구조 참고
- @shared/widgets/atoms/ 재사용

체크리스트:
- @docs/checklists/feature-implementation.md
```

---

## 7. 실행 전략

### 7.1 전체 타임라인

```
Week 1-2:  Phase 1 - 기반 구조
Week 3-5:  Phase 2 - Core 레이어
Week 6-11: Phase 3 - Features (auth → map → place → post → dashboard)
Week 12-13: Phase 4 - Shared 컴포넌트
Week 14:    Phase 5 - 레거시 제거
Week 15:    Phase 6 - 문서화

총 15주 (약 4개월)
```

### 7.2 병렬 작업 가능 영역

동시 진행 가능:
- Phase 2 (Core) + Phase 4 (Shared) 일부
- Phase 3 각 Feature는 독립적으로 진행 가능

### 7.3 위험 관리

#### 리스크
1. **기존 기능 영향**: 마이그레이션 중 버그 발생 가능
2. **학습 곡선**: 새 패턴 적응 시간 필요
3. **일정 지연**: 예상보다 복잡한 의존성

#### 완화 방안
1. **Feature Flag**: 새 구조와 레거시 병행 운영
2. **점진적 롤아웃**: Feature별 단계적 적용
3. **철저한 테스트**: 각 Phase마다 테스트 통과 확인
4. **문서화**: 변경사항 즉시 기록

### 7.4 성공 지표

각 Phase별 완료 기준:
- [ ] 새 구조 폴더 생성 완료
- [ ] 기존 코드 100% 마이그레이션
- [ ] 모든 테스트 통과
- [ ] 성능 저하 없음
- [ ] 문서 업데이트 완료
- [ ] AI 프롬프트 템플릿 작성

---

## 8. AI 바이브 코딩 최적화

### 8.1 AI 친화적 구조 특징

#### 예측 가능한 패턴
```
features/[feature_name]/
  presentation/
    screens/           # 항상 여기
    providers/         # 항상 여기
    widgets/           # 항상 여기
  application/
    usecases/          # 항상 여기
    services/          # 항상 여기
```

AI에게 전달:
```
"features/place/ 구조와 동일하게 features/review/를 생성해줘"
```

#### 명확한 책임 분리
```dart
// Presentation: UI만
class PlaceListScreen extends ConsumerWidget { ... }

// Application: 비즈니스 로직만
class SearchPlacesUsecase {
  Future<Result<List<PlaceEntity>>> execute(String query) { ... }
}

// Data: 데이터 처리만
class PlaceRepositoryImpl implements PlaceRepository { ... }
```

### 8.2 AI 프롬프트 템플릿

#### 새 Feature 추가
```markdown
다음 기능을 구현해줘:

Feature: review (리뷰 시스템)

구조:
- features/review/
  - presentation/screens/review_list_screen.dart
  - presentation/providers/review_provider.dart
  - presentation/widgets/review_card.dart
  - application/usecases/get_reviews_usecase.dart

레퍼런스:
- @features/place/ 구조 동일하게
- @shared/widgets/molecules/cards/ 의 card 패턴 참고
- @reference-projects/TouristAssist/ 의 리뷰 로직 참고

데이터:
- core/domain/entities/review/review_entity.dart 사용
- core/data/repositories/review_repository.dart 연동

체크리스트:
- @docs/checklists/feature-implementation.md 확인
```

#### UI 컴포넌트 추가
```markdown
다음 위젯을 구현해줘:

위젯: RatingStars (별점 표시)
위치: shared/widgets/atoms/rating_stars.dart

디자인:
- Figma: [링크]
- Design Tokens: @shared/theme/tokens/ 사용
- 색상: AppColors.starYellow
- 크기: AppSpacing.sm

참고:
- @shared/widgets/atoms/buttons/primary_button.dart 패턴 따라하기
```

### 8.3 레퍼런스 활용 전략

#### Feature별 레퍼런스 매핑

| ppam Feature | 레퍼런스 프로젝트 | 참고 부분 |
|-------------|----------------|----------|
| **place** | TouristAssist | 가이드 검색 → 장소 검색 |
| **post** | Spot | 지오태그 비디오 → 지오태그 포스트 |
| **map** | Deliverzler | 실시간 추적 → Fog of War |
| **auth** | Deliverzler | 인증 구조 |
| **dashboard** | TouristAssist | 사용자 대시보드 |

#### AI 프롬프트 예시
```
"@reference-projects/TouristAssist/lib/screens/guide_list_screen.dart 를 참고하여
ppam의 PlaceListScreen을 구현해줘.

차이점:
- TouristAssist의 가이드 → ppam의 장소
- 검색 필터링 로직은 동일
- UI는 ppam Design Tokens 사용"
```

---

## 9. 결론 및 권장사항

### 9.1 최종 권장 구조

**최적화 제안 구조**를 채택할 것을 권장합니다.

**이유**:
1. **현실적**: 전체 재작성 없이 점진적 개선
2. **실용적**: 과도한 추상화 없이 필요한 만큼만
3. **AI 친화적**: 일관되고 예측 가능한 패턴
4. **레퍼런스 호환**: TouristAssist, Spot, Deliverzler 패턴과 유사
5. **확장 가능**: 향후 요구사항 대응 용이

### 9.2 즉시 적용 가능한 개선

**이번 주 내**:
1. 폴더 구조 생성 (`core/`, `shared/`, `config/`)
2. Design Tokens 기본 파일 생성
3. 보안 규칙 업데이트 (임시 규칙 제거)

**다음 주**:
1. auth Feature 마이그레이션 시작
2. Shared Widgets 정리 시작
3. AI 프롬프트 템플릿 작성

### 9.3 장기 비전

**6개월 후**:
- 모든 Features가 새 구조로 마이그레이션 완료
- Design System 완전 통합 (Figma ↔ Flutter)
- AI 바이브 코딩 효율 2배 향상
- 테스트 커버리지 80% 이상

**1년 후**:
- 멀티플랫폼 확장 (Web, Desktop) 용이
- 새 개발자 온보딩 시간 50% 감소
- 기술 부채 최소화
- 프로덕션 레벨 품질 달성

---

## 부록

### A. 폴더 생성 스크립트

```bash
#!/bin/bash
# create_structure.sh

# Core
mkdir -p lib/core/{domain/{entities/{user,post,marker,place},repositories,services},data/{datasources/{remote/{firebase,api},local/{cache,storage}},repositories,models,mappers},infrastructure/{network,storage,logging},constants}

# Shared
mkdir -p lib/shared/{theme/tokens,widgets/{atoms/{buttons,inputs,icons,texts},molecules/{cards,list_items,dialogs},organisms/{headers,footers,forms}},utils/{extensions,helpers,validators,formatters},models,mixins}

# Features
mkdir -p lib/features/{auth,map,place,post,dashboard,analytics,search}/{presentation/{screens,providers,widgets},application/{usecases,services}}

# Config
mkdir -p lib/config/{routes,di/modules,environment}

echo "✅ 폴더 구조 생성 완료"
```

### B. 체크리스트

#### Feature 마이그레이션 체크리스트
- [ ] 새 폴더 구조 생성
- [ ] Entity 정의
- [ ] Repository 인터페이스 정의
- [ ] Repository 구현
- [ ] Usecase 구현
- [ ] Provider 구현
- [ ] Screen 구현
- [ ] Widget 구현
- [ ] 레거시 코드 @deprecated 마킹
- [ ] 테스트 작성
- [ ] 문서 업데이트
- [ ] AI 프롬프트 템플릿 작성

---

**문서 버전**: v1.0
**작성일**: 2025-10-27
**다음 리뷰**: 2025-11-27
**작성자**: AI Session (Claude Code)

**참고 문서**:
- `/docs/251027_VIBE_CODING_RULES.md`
- `/docs/251027_REFERENCE_PROJECTS.md`
- `/docs/DATABASE_STRUCTURE_REVISED.md`
