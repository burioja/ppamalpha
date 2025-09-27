# Inbox 구현 상태 (2025-09-26 업데이트)

## 📊 현재 구현 현황 - 한눈에 보기

### ✅ Phase 0: 개인정보 수정 & 포인트 히스토리 개선 (완료) 🆕
- [x] **Phase 0.1: 현대적인 개인정보 수정 UI 개선** ✅ 완료
  - [x] 프로필 헤더 카드 구현 (`profile_header_card.dart`)
  - [x] 섹션별 카드 레이아웃 구현 (`info_section_card.dart`)
  - [x] 그라데이션 배경 및 그림자 효과
  - [x] 설정 화면 전면 리팩토링 (`settings_screen.dart`)

- [x] **Phase 0.2: 독립적인 포인트 화면 생성** ✅ 완료
  - [x] 포인트 전용 화면 생성 (`points_screen.dart`)
  - [x] 포인트 요약 카드 위젯 (`points_summary_card.dart`)
  - [x] 메인 대시보드 포인트 통합
  - [x] 라우팅 설정 (`app_routes.dart`)

### 🔴 Phase 1: 최우선 - 즉시 해결 필요
- [ ] **1. Firebase 인덱스 생성** 🚨 **현재 앱 크래시 원인**
- [ ] **2. 포스트 상태 관리 시스템** - PostModel 확장
- [ ] **3. 포스트 수정 권한 제어** - 배포/만료 포스트 수정 차단
- [ ] **4. UI 그리드 최적화** - 3열 기본 표시

### 🟠 Phase 2: 중간 우선순위
- [ ] **1. 쿠폰 시스템 구현** - 포스트 생성 시 쿠폰 옵션
- [ ] **2. 상세 통계 시스템** - 배포 후 상세 분석
- [ ] **3. 포스트 생성/배포 워크플로우 분리** - Map 연동
- [ ] **4. 에러 핸들링 강화** - 사용자 친화적 에러 처리

### 🟡 Phase 3: 낮은 우선순위
- [ ] **1. 페이지네이션 완성** - DocumentSnapshot 활용
- [ ] **2. 실시간 업데이트** - StreamBuilder 전환
- [ ] **3. 포스트 공유/전달 기능**
- [ ] **4. 포스트 응답 기능**
- [ ] **5. 리워드 요청 기능**
- [ ] **6. 푸시 알림**
- [ ] **7. 오프라인 지원**
- [ ] **8. 접근성 개선**

---

## 개요
ppamalpha 앱의 Inbox 기능 구현 현황을 정리한 문서입니다. Inbox는 사용자가 생성한 포스트와 수집한 포스트를 관리하는 핵심 기능으로, **포스트 생성과 배포를 분리한 새로운 워크플로우**를 지원합니다.

## 🔄 새로운 포스트 워크플로우 (핵심 변경사항)

### 1단계: 포스트 생성 (Inbox에서) 📝
```
사용자 → Inbox → 포스트 만들기
├── 포스트 내용 작성 (제목, 설명, 이미지)
├── 단가 설정 (포인트)
├── 쿠폰 옵션 설정 (선택)
└── 저장 → 배포 대기 상태
```
- **설정 항목**: 포스트 내용 + **단가만** 설정
- **상태**: `DRAFT` (배포 대기)
- **수정 가능**: ✅ 모든 내용 변경 가능

### 2단계: 포스트 배포 (Map에서 마커 찍기) 📍
```
사용자 → Map → 마커 찍기 → 포스트 선택
├── 뿌리는 수량 설정
├── 배포 기간 설정 (시작일, 만료일)
├── 위치 확정
└── 배포 실행 → 배포됨 상태
```
- **설정 항목**: **뿌리는 수량** + **기간** + **위치**
- **상태**: `DRAFT` → `DEPLOYED` (배포됨)
- **수정 가능**: ❌ 배포 후 수정 불가능

## 📁 Inbox 관련 파일 트리 구조

```
lib/
├── screens/user/
│   ├── inbox_screen.dart              # 📧 메인 Inbox 화면 (내 포스트/받은 포스트 탭)
│   ├── store_screen.dart              # 🏪 내 스토어 화면 (구글 지도 스타일 UI + 이미지 업로드)
│   ├── main_screen.dart               # 🏠 메인 네비게이션 (BottomNavigationBar)
│   ├── post_detail_screen.dart        # 📋 포스트 상세 보기
│   ├── post_edit_screen.dart          # ✏️ 포스트 편집
│   └── post_deploy_screen.dart        # 📤 포스트 배포 (Map에서 사용)
├── features/
│   └── user_dashboard/screens/
│       └── inbox_screen.dart          # 🆕 새로운 Inbox 화면 구현
├── widgets/
│   ├── post_card.dart                 # 🃏 포스트 카드 위젯 (리스트 뷰용)
│   ├── post_tile_card.dart            # 🔲 포스트 타일 카드 (그리드 뷰용)
│   └── coupon_widget.dart             # 🎫 쿠폰 위젯 (신규 필요)
├── services/
│   ├── post_service.dart              # 🔧 포스트 백엔드 서비스
│   ├── image_upload_service.dart      # 📷 이미지 업로드 서비스 (Firebase Storage)
│   ├── coupon_service.dart            # 🎫 쿠폰 서비스 (신규 필요)
│   └── analytics_service.dart         # 📊 통계 분석 서비스 (신규 필요)
├── models/
│   ├── post_model.dart                # 📊 포스트 데이터 모델 (확장 필요)
│   └── coupon_model.dart              # 🎫 쿠폰 모델 (신규 필요)
└── routes/
    └── app_routes.dart                # 🛣️ 앱 라우팅 설정
```

## ✅ 이미 구현된 기능들

- [x] **1. 기본 UI 구조**
  - **파일**: `lib/features/user_dashboard/screens/inbox_screen.dart`
  - **구현 내용**: TabBar를 사용한 2탭 구조 (내 포스트 / 받은 포스트)
  - **코드 위치**: `inbox_screen.dart:312-321`

- [x] **2. 검색 및 필터링 시스템**
  - **구현 내용**:
    - 검색어 기반 필터링 (제목, 설명, 생성자명)
    - 상태별 필터링 (전체, 활성, 비활성, 만료됨)
    - 기간별 필터링 (전체, 오늘, 1주일, 1개월)
    - 정렬 기능 (생성일, 제목, 리워드, 만료일)
  - **코드 위치**: `inbox_screen.dart:177-252`

- [x] **3. 내 포스트 탭**
  - **구현 내용**: 사용자가 생성한 포스트 목록 표시
  - **서비스 연동**: `PostService.getUserAllMyPosts()` 사용
  - **코드 위치**: `inbox_screen.dart:511-685`

- [x] **4. 받은 포스트 탭**
  - **구현 내용**: 사용자가 수집한 포스트 목록 표시
  - **서비스 연동**: `PostService.getCollectedPosts()` 사용
  - **코드 위치**: `inbox_screen.dart:689-817`

- [x] **5. PostTileCard 위젯**
  - **파일**: `lib/widgets/post_tile_card.dart`
  - **구현 내용**: 그리드 뷰용 포스트 타일 카드
  - **사용처**: 인박스와 Store 화면에서 그리드 표시

- [x] **6. 페이지네이션 준비**
  - **구현 내용**: 스크롤 기반 무한 로딩 UI
  - **코드 위치**: `inbox_screen.dart:100-133`
  - **상태**: 기본 구조만 구현됨

- [x] **7. 메인 화면 통합**
  - **파일**: `lib/screens/user/main_screen.dart`
  - **구현 내용**: BottomNavigationBar에 Inbox 탭 연결

- [x] **8. 포스트 상세/편집 화면 연결**
  - **구현 내용**: PostDetailScreen, PostEditScreen 라우팅
  - **코드 위치**: `inbox_screen.dart:655-673`, `inbox_screen.dart:788-806`

- [x] **9. PostService 백엔드 연동**
  - **파일**: `lib/services/post_service.dart`
  - **연동된 메서드들**:
    - `getUserAllMyPosts()`: 내 포스트 조회
    - `getCollectedPosts()`: 받은 포스트 조회
    - `getDistributedPosts()`: 배포 포스트 통계

- [x] **10. 내 스토어 화면**
  - **파일**: `lib/screens/user/store_screen.dart`
  - **구현 내용**: 구글 지도 장소 스타일 UI, 수집한 포스트 그리드 표시

- [x] **11. 이미지 업로드 서비스**
  - **파일**: `lib/services/image_upload_service.dart`
  - **구현 내용**: Firebase Storage 연동, 자동 압축/리사이징

## 🚨 긴급 수정 필요사항 (2025-09-26 추가)

### 1. 포스트 상태 로직 수정 🚨
**문제**: 배포되지 않았는데 만료 포스트는 존재하지 않음
**수정 필요**:
- `PostStatus.EXPIRED` 제거
- `DRAFT` → `DEPLOYED` → (시간 경과 시 자동 삭제) 흐름으로 변경
- 만료는 배포된 포스트에서만 발생

### 2. 권한 체크 버그 수정 🚨
**문제**: 수정가능하다고 표시되지만 실제로는 수정이 막혀있음
**원인**: `PostModel.canEdit` 로직과 UI 표시 불일치
**수정 위치**:
- PostEditScreen 초기화 및 권한 체크
- PostDetailScreen 수정 버튼 표시 조건
- Inbox 화면 포스트 카드 상태 표시

### 3. 이미지 단가 시스템 미적용 🚨
**문제**: 사운드는 적용됐지만 이미지 추가 시 단가 최소값 미적용
**구현 필요**:
- 이미지 개수에 따른 단가 자동 증가
- 사운드와 동일한 로직 적용
- 미디어 타입별 단가 계산 시스템

### 4. UI 그리드 재조정 🟠
**문제**: 현재 4열로 되어있어 웹에서 너무 작음
**수정**: 다시 3열 기본으로 변경
```dart
// 수정 전: 3열 → 4열 → 5열
// 수정 후: 3열 → 3열 → 4열 (데스크톱만 4열)
```

### 5. 포스트 상세 이미지 품질 개선 🟠
**문제**: 상단 이미지가 썸네일로 표시되어 깨져보임
**수정**: 포스트 상세화면에서 원본 이미지 표시
**목표**: 고화질로 글자 등 세부사항 확인 가능

## 🔴 기존 최우선 구현 필요 기능들 (즉시 해결)

### 1. Firebase 인덱스 생성 🚨 **현재 앱 크래시 원인**
**문제**: Firestore 쿼리 인덱스 누락으로 "받은 포스트" 탭 완전 오류
**✅ 시스템 구조 정리 완료**:
```
기존 post_instances 컬렉션 → post_collections 컬렉션 사용으로 통일
DataMigrationService 제거 (불필요)
PostInstanceService → post_collections 기반으로 재작성
PostStatisticsService → post_collections 기반으로 재작성
```

**현재 Firebase 컬렉션 구조**:
```javascript
// 실제 존재하는 컬렉션들:
- posts (포스트 템플릿)
- markers (배포된 마커)
- post_collections (수집된 포스트 - 기존 컬렉션 확장 사용)
- user_points (포인트 시스템)
- users (사용자 정보)
```

**⚠️ Firebase 인덱스 상태**:
- post_collections 컬렉션에 확장 필드들이 추가되었으므로 새로운 인덱스가 필요할 수 있음
- 실제 앱 테스트 후 필요한 인덱스만 생성 예정
- **우선순위**: 🟡 **테스트 후 결정** (구조 변경으로 기존 인덱스 요구사항 변경됨)

### 2. 포스트 상태 관리 시스템
**현재 문제**: 포스트 생성과 배포 단계 미분리
**구현 필요**:
```dart
enum PostStatus {
  DRAFT,     // 배포 대기 (수정 가능)
  DEPLOYED,  // 배포됨 (수정 불가)
  DELETED    // 삭제됨
}
```
**PostModel 확장**:
```dart
class PostModel {
  // 기존 필드들...
  PostStatus status;           // 포스트 상태
  int? deployQuantity;        // 배포 수량 (배포 시 설정)
  DateTime? deployedAt;       // 배포 시점
  GeoPoint? deployLocation;   // 배포 위치
  // ...
}
```

### 3. 포스트 수정 권한 제어
**구현 필요**:
- 배포된 포스트 (`DEPLOYED`) 수정 불가
- 삭제된 포스트 (`DELETED`) 수정 불가
- 배포 대기 포스트 (`DRAFT`)만 수정 가능
**적용 위치**:
- PostEditScreen
- PostDetailScreen의 수정 버튼
- Inbox의 포스트 카드

### 4. UI 그리드 최적화 (3열 표시)
**현재**: `_getCrossAxisCount()` 함수로 반응형 그리드
**개선 필요**:
```dart
int _getCrossAxisCount(double width) {
  if (width < 500) {
    return 3; // 모바일: 3열 (기본)
  } else if (width < 800) {
    return 4; // 태블릿: 4열
  } else {
    return 5; // 데스크톱: 5열
  }
}
```
**목표**: 더 많은 포스트 정보를 한 화면에 표시

## 🟠 중간 우선순위 구현 기능들

### 5. 쿠폰 시스템
**구현 범위**:
```dart
class CouponModel {
  String couponId;
  CouponType type;      // DISCOUNT, FREE_ITEM, PERCENTAGE 등
  String title;         // 쿠폰 제목
  String description;   // 쿠폰 설명
  String? imageUrl;     // 쿠폰 이미지
  int discountValue;    // 할인값 또는 할인율
  DateTime validUntil;  // 쿠폰 유효기간
  bool isUsed;         // 사용 여부
  DateTime? usedAt;    // 사용 시점
}
```
**구현 필요**:
- 포스트 생성 시 쿠폰 옵션 설정 UI
- 쿠폰 내용 편집기 (텍스트/이미지)
- 쿠폰 사용 메뉴 및 처리 로직
- CouponService 백엔드 연동

### 6. 상세 포스트 통계 시스템
**통계 항목**:
```dart
class PostAnalytics {
  String postId;
  int totalDeployed;        // 총 배포 수량
  int totalCollected;       // 수집된 수량
  int totalUsed;           // 사용된 수량 (쿠폰)
  int totalExpired;        // 만료 회수 수량

  // 비율 계산 (자동)
  double collectionRate;   // 수집 비율
  double usageRate;       // 사용 비율 (쿠폰)
  double expiryRate;      // 만료 비율

  // 인구통계학적 분석
  Map<String, int> genderStats;  // 성별 통계
  Map<String, int> ageStats;     // 연령별 통계
  Map<String, int> locationStats; // 지역별 통계
}
```
**UI 구성**:
- 배포 통계 다이얼로그 확장
- 차트/그래프 표시 (pie chart, bar chart)
- 상세 분석 화면 (별도 스크린)

## 🟡 낮은 우선순위 구현 기능들

### 7. 페이지네이션 완성
**현재 문제**: `PostModel`에 DocumentSnapshot 저장 필드 없음
**해결책**:
```dart
class PostModel {
  // 기존 필드들...
  DocumentSnapshot? rawSnapshot;  // Firebase DocumentSnapshot 저장

  // 팩토리 메서드 수정
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    // ...기존 로직
    return PostModel(
      // ...기존 필드들
      rawSnapshot: doc,  // DocumentSnapshot 저장
    );
  }
}
```

### 8. 실시간 업데이트
**현재**: FutureBuilder만 사용
**개선**: StreamBuilder로 전환
```dart
StreamBuilder<List<PostModel>>(
  stream: _postService.getUserPostsStream(_currentUserId!),
  builder: (context, snapshot) {
    // 실시간 데이터 업데이트
  },
)
```

### 9. 포스트 공유/전달 기능
**연관 필드**: `PostModel.canForward`
**구현 필요**:
- 포스트 공유 UI
- 다른 사용자에게 전달 로직
- 공유 이력 관리

### 10. 포스트 응답 기능
**연관 필드**: `PostModel.canRespond`
**구현 필요**:
- 포스트 작성자에게 메시지/피드백 전송
- 응답 작성 화면
- 알림 시스템 연동

### 11. 리워드 요청 기능
**연관 필드**: `PostModel.canRequestReward`
**구현 필요**:
- 리워드 요청 및 승인 프로세스
- 포인트 시스템 연동
- 요청 이력 관리

## 📋 파일별 구현 상세 계획

### 📊 `post_model.dart` 확장 (최우선)
**추가 필요 필드**:
```dart
class PostModel {
  // 기존 필드들...

  // 상태 관리
  PostStatus status;           // 포스트 상태
  DateTime? deployedAt;        // 배포 시점
  int? deployQuantity;         // 배포 수량
  GeoPoint? deployLocation;    // 배포 위치

  // 쿠폰 시스템
  bool isCoupon;              // 쿠폰 여부
  CouponModel? coupon;        // 쿠폰 정보

  // 통계 추적
  int totalDeployed;          // 총 배포 수량
  int totalCollected;         // 수집된 수량
  int totalUsed;             // 사용된 수량

  // Firebase 연동
  DocumentSnapshot? rawSnapshot; // 페이지네이션용
}
```

### 🔧 `post_service.dart` 확장
**추가 필요 메서드**:
```dart
class PostService {
  // 상태별 조회
  Future<List<PostModel>> getPostsByStatus(String userId, PostStatus status);

  // 포스트 배포
  Future<void> deployPost(String postId, DeploymentConfig config);

  // 상태 변경
  Future<void> updatePostStatus(String postId, PostStatus status);

  // 통계 조회
  Future<PostAnalytics> getPostAnalytics(String postId);

  // 쿠폰 관련
  Future<void> useCoupon(String postId, String userId);
  Future<List<CouponModel>> getUserCoupons(String userId);
}
```

### 🎫 `coupon_service.dart` 신규 생성
**구현 메서드**:
```dart
class CouponService {
  Future<CouponModel> createCoupon(CouponCreateRequest request);
  Future<void> useCoupon(String couponId, String userId);
  Future<List<CouponModel>> getUserCoupons(String userId);
  Future<CouponAnalytics> getCouponAnalytics(String couponId);
}
```

### 📊 `analytics_service.dart` 신규 생성
**구현 메서드**:
```dart
class AnalyticsService {
  Future<PostAnalytics> getPostAnalytics(String postId);
  Future<UserAnalytics> getUserAnalytics(String userId);
  Future<Map<String, int>> getDemographicStats(String postId);
  Future<List<AnalyticsReport>> generateReports(AnalyticsFilter filter);
}
```


## 📊 현재 진행 상황 요약 (2025-09-26 최종 업데이트)

### ✅ 완료된 핵심 기능들:
- **Phase 4 완료** ✅: 개인정보 수정 UI 현대화 & 포인트 히스토리 독립 화면
- **Phase 5 완료** ✅: 포스트 통계 시스템 & 100만 포인트 지급 시스템
- **총 20+ 기능** 완료 (기본 Inbox UI + Phase 4 + Phase 5 추가)
- **Inbox 화면**: 검색, 필터링, 탭 시스템 + 통계 버튼 완료
- **위젯 시스템**: PostTileCard 그리드 뷰 + 카드 위젯들 + 통계 다이얼로그 완료
- **서비스 계층**: PostService, ImageUploadService, PointsService, PostStatisticsService, PostInstanceService, AdminService 완료
- **내 스토어**: 구글 지도 스타일로 완료
- **개인정보 설정**: 현대적 Material Design 3 기반 UI
- **포인트 시스템**: 독립 화면 + 메인 대시보드 통합 + 100만 포인트 보장
- **통계 시스템**: 실시간 포스트 통계 + 수집자 분석 + 활동 패턴 분석
- **포인트 플로우**: 수집 보상 + 사용 보상 + 실시간 지급 시스템

### 🔴 다음 우선순위 (Phase 1):
1. **Firebase 인덱스 생성** - 앱 정상 동작 필수
2. **포스트 상태 관리** - 생성/배포 분리
3. **수정 권한 제어** - 배포 후 수정 차단
4. **UI 최적화** - 3열 그리드 표시

### 🟠 중요도 중간 (Phase 2):
1. **쿠폰 시스템** - 새로운 핵심 기능
2. **상세 통계** - 포스트 분석 시스템

### 🟡 추후 구현 (Phase 3):
- 페이지네이션, 실시간 업데이트
- 포스트 공유/응답/리워드 기능
- 푸시 알림, 오프라인 지원

## 📈 최근 업데이트 (2025-09-26)

### 🆕 개인정보 수정 & 포인트 히스토리 개선 프로젝트 (2025-09-26 추가)
- 👤 **개인정보 수정 UI 현대화**: 기존 올드한 템플릿 스타일에서 현대적 카드 기반 레이아웃으로 전면 개편
  - **현재 문제점**: 기본 Flutter 위젯만 사용, 시각적 매력 부족, 사용성 불편
  - **개선 목표**: Material Design 3 기반, 카드 섹션 분할, 프로필 헤더, 그라데이션 효과
  - **파일**: `lib/features/user_dashboard/screens/settings_screen.dart` 전면 리팩토링

- 📊 **포인트 히스토리 접근성 개선**: 지갑 탭에서만 보던 포인트 히스토리를 독립적인 화면으로 분리
  - **현재 상황**: `wallet_screen.dart`의 첫 번째 탭에만 존재, 접근성 제한
  - **개선 계획**: 독립적인 `points_screen.dart` 생성, 메인 대시보드 통합
  - **기존 서비스**: `PointsService`, `UserPointsModel` 이미 완전 구현됨

- 🎨 **신규 위젯 컴포넌트들**:
  - `profile_header_card.dart` - 프로필 헤더 위젯
  - `info_section_card.dart` - 정보 섹션 카드 위젯
  - `points_summary_card.dart` - 포인트 요약 카드

### 🔄 기존 업데이트 (2025-09-25)
- 🔄 **포스트 워크플로우 분리**: 생성(Inbox) ↔ 배포(Map) 단계 분리
- 🎫 **쿠폰 시스템 계획**: 포스트에 쿠폰 기능 추가 계획
- 📊 **상세 통계 시스템**: 포스트 배포 후 종합 분석 기능 계획
- 🎨 **UI 개선**: 3열 그리드 기본 표시로 정보 밀도 향상
- 🐛 **Firebase 인덱스 오류**: 해결 방법 및 생성 URL 제공
- 🔒 **수정 권한 제어**: 배포/만료 포스트 수정 차단 계획

## 🎯 Phase 4: 개인정보 수정 & 포인트 히스토리 개선 (2025-09-26 완료) ✅

### ✅ 완료된 구현 사항

#### 🔥 Phase 4.1: 현대적인 개인정보 수정 UI 개선 ✅
1. **프로필 헤더 카드** 구현 ✅
   - [x] 프로필 이미지 업로드/변경 기능 (`profile_header_card.dart`)
   - [x] 사용자 기본 정보 (닉네임, 레벨) 표시
   - [x] Firebase Storage 연동으로 이미지 업로드/압축 처리

2. **섹션별 카드 레이아웃** 구현 ✅
   - [x] 개인정보 카드 (닉네임, 전화번호, 생년월일, 성별)
   - [x] 주소정보 카드 (주소, 상세주소) - 접을 수 있는 카드
   - [x] 계정정보 카드 (계좌번호) - 접을 수 있는 카드
   - [x] 근무지 카드 (동적 추가/삭제) - 접을 수 있는 카드
   - [x] 설정 카드 (콘텐츠 필터) - 접을 수 있는 카드
   - [x] `InfoSectionCard` 위젯으로 재사용 가능한 컴포넌트화

3. **UI/UX 개선사항** 구현 ✅
   - [x] 그라데이션 배경 및 그림자 효과
   - [x] Material Design 3 기반 현대적 디자인
   - [x] 적절한 간격과 타이포그래피 적용
   - [x] 로딩 상태 및 피드백 개선
   - [x] 반응형 디자인 구현

#### 🔥 Phase 4.2: 독립적인 포인트 화면 생성 ✅
1. **포인트 전용 화면 생성** (`points_screen.dart`) ✅
   - [x] 포인트 잔액 및 레벨 표시 (그라데이션 카드)
   - [x] 포인트 히스토리 탭뷰 (획득/사용 내역)
   - [x] 기존 PointsService와 UserPointsModel 활용
   - [x] 포인트 통계 요약 표시

2. **포인트 화면 접근성 개선** ✅
   - [x] 메인 대시보드에 포인트 요약 카드 추가 (`points_summary_card.dart`)
   - [x] 독립적인 포인트 화면으로 네비게이션 구현
   - [x] 지갑 화면에서 포인트 탭 유지 (기존 사용자 경험 보장)
   - [x] 클릭 시 상세 포인트 화면으로 이동

#### 🔥 Phase 4.3: 라우팅 및 통합 ✅
1. **라우팅 설정** ✅
   - [x] `/points` 경로로 독립 포인트 화면 접근 (`app_routes.dart`)
   - [x] 프로필 설정 화면 경로 최적화
   - [x] Inbox 화면에서 포인트 요약 카드 통합

2. **상태 관리 개선** ✅
   - [x] StatefulWidget으로 포인트 상태 관리
   - [x] FutureBuilder를 활용한 실시간 업데이트 구현
   - [x] 네비게이션 후 자동 새로고침

## 🎯 Phase 5: 포스트 통계 시스템 & 100만 포인트 지급 (2025-09-26 완료) ✅ 🆕

### ✅ 새로 완료된 구현 사항

#### 🔥 Phase 5.1: 포스트 통계 시스템 구현 ✅
1. **내 포스트 통계 UI** ✅
   - [x] PostTileCard에 통계 버튼 추가 (`Icons.analytics`)
   - [x] 내 포스트에서만 통계 버튼 표시 (창작자 권한)
   - [x] 통계 다이얼로그 구현 (팝업 형태)
   - [x] 반응형 다이얼로그 (최대 크기 제한)

2. **PostStatisticsService 생성** ✅
   - [x] 포스트별 상세 통계 제공 (`post_statistics_service.dart`)
   - [x] 배포 현황 (총 배포수, 배포 수량, 수집률)
   - [x] 수집 현황 (총 수집수, 사용 완료수, 사용률)
   - [x] 수집자 분석 (고유 수집자수, 평균 수집/사용자, 익명화 처리)
   - [x] 활동 패턴 (가장 활발한 시간대/요일)
   - [x] 마커별 상세 통계 기능
   - [x] 실시간 통계 스트림 기능

3. **실시간 통계 집계 시스템** ✅
   - [x] MarkerService 업데이트: 마커 생성 시 posts 컬렉션 통계 자동 업데이트
   - [x] PostInstanceService에 통계 집계 통합
   - [x] PostModel에 통계 필드 추가 (totalDeployments, totalInstances 등)
   - [x] 배치 트랜잭션으로 원자적 통계 업데이트

#### 🔥 Phase 5.2: 100만 포인트 임시 지급 시스템 ✅
1. **PointsService 확장** ✅
   - [x] 신규 가입자 자동으로 100만 포인트 지급
   - [x] 기존 사용자 100만 포인트 보장 시스템
   - [x] 포인트 히스토리 자동 기록
   - [x] 포인트 플로우 메서드 추가:
     - `rewardPostCollection()` - 수집 보상 지급
     - `rewardPostUsage()` - 사용 보상 지급
     - `deductPostCreationPoints()` - 포스트 생성 비용 차감

2. **AdminService 생성** ✅
   - [x] 모든 기존 사용자에게 100만 포인트 보장 (`admin_service.dart`)
   - [x] 임시 포인트 시스템 초기화 메서드
   - [x] 개별 사용자 포인트 보장 메서드
   - [x] 배치 처리로 성능 최적화

#### 🔥 Phase 5.3: 포인트 플로우 통합 시스템 ✅
1. **PostInstanceService에 포인트 보상 통합** ✅
   - [x] 포스트 수집 시 → 수집자에게 보상 지급
   - [x] 포스트 사용 시 → 쿠폰인 경우 추가 보상 지급 (수집 보상의 절반)
   - [x] 포인트 지급 실패해도 주요 기능은 정상 동작
   - [x] 상세한 로그 기록 시스템

2. **PostService에 포인트 시스템 준비** ✅
   - [x] PointsService 연동 준비 완료
   - [x] 포스트 생성 비용 차감 로직 준비
   - [x] 향후 확장 가능한 구조 설계

### 📁 새로 생성/수정된 파일들 (Phase 5)

#### 새로 생성한 파일들:
- `lib/core/services/data/post_statistics_service.dart` - 포스트 통계 분석 서비스 ✅
- `lib/core/services/admin/admin_service.dart` - 관리자 유틸리티 (100만 포인트 지급) ✅
- `lib/core/models/post/post_instance_model_simple.dart` - 포스트 인스턴스 모델 ✅
- `lib/core/services/data/post_instance_service.dart` - 포스트 인스턴스 관리 서비스 ✅

#### 주요 수정한 파일들:
- `lib/features/post_system/widgets/post_tile_card.dart` - 통계 버튼 추가 ✅
- `lib/features/user_dashboard/screens/inbox_screen.dart` - 통계 다이얼로그 구현 ✅
- `lib/core/services/data/points_service.dart` - 100만 포인트 지급 및 플로우 시스템 ✅
- `lib/core/services/data/marker_service.dart` - 실시간 통계 집계 시스템 ✅
- `lib/core/services/data/post_service.dart` - PointsService 연동 준비 ✅
- `lib/core/models/post/post_model.dart` - 통계 필드 추가 완료 ✅

### 🎯 포인트 플로우 테스트 방법 (지갑 시스템 없이 가능) 🆕

#### ✅ 현재 구현된 포인트 플로우:
1. **신규 가입** → 자동으로 100만 포인트 지급 ✅
2. **기존 사용자** → AdminService로 100만 포인트 보장 가능 ✅
3. **포스트 수집** → 수집자에게 포스트 리워드만큼 포인트 지급 ✅
4. **쿠폰 사용** → 사용자에게 추가 보상 지급 (리워드의 50%) ✅

#### 🧪 테스트 시나리오:
```
👤 사용자A (포스트 생성자)
├── 100만 포인트 보유 상태에서 시작
├── 포스트 생성 (리워드 1000포인트)
└── 마커로 배포 (현재는 포인트 차감 안함)

👤 사용자B (수집자)
├── 100만 포인트 보유 상태에서 시작
├── 마커 터치하여 포스트 수집
├── → +1000포인트 획득 ✅ (수집 보상)
└── 쿠폰인 경우 사용 시 +500포인트 추가 획득 ✅

📊 통계 시스템
├── 사용자A: 내 포스트에서 통계 버튼 클릭
├── → 배포 현황, 수집 현황, 수집자 분석 확인 가능 ✅
└── → 실시간 통계 업데이트 ✅
```

#### 📱 AdminService 활용 방법:
```dart
// 앱 시작 시 모든 사용자에게 100만 포인트 보장
final adminService = AdminService();
await adminService.initializeTemporaryPointsSystem();

// 특정 사용자 포인트 보장
await adminService.ensureUserHasMillionPoints(userId);
```

### ⚡ 다음 테스트 단계:
1. **포스트 생성** → 배포 → **다른 기기/계정에서 수집** 테스트 ✅ 준비완료
2. **포인트 증가 확인** → PointsService 로그 및 UI에서 확인 ✅ 준비완료
3. **통계 업데이트 확인** → 내 포스트 통계 화면에서 실시간 확인 ✅ 준비완료
4. **쿠폰 사용 테스트** → 추가 포인트 지급 확인 ✅ 준비완료

### 📁 기존 생성/수정할 파일들
- `lib/features/user_dashboard/screens/points_screen.dart` - 독립 포인트 화면
- `lib/features/user_dashboard/widgets/profile_header_card.dart` - 프로필 헤더 위젯
- `lib/features/user_dashboard/widgets/info_section_card.dart` - 정보 섹션 카드 위젯
- `lib/features/user_dashboard/widgets/points_summary_card.dart` - 포인트 요약 카드

#### 수정할 파일:
- `lib/features/user_dashboard/screens/settings_screen.dart` - 현대적 UI로 전면 개편
- `lib/routes/app_routes.dart` - 포인트 화면 라우팅 추가
- `lib/features/user_dashboard/screens/main_screen.dart` - 포인트 요약 카드 추가

### ⚡ 예상 효과
1. **사용자 경험 개선**: 직관적이고 현대적인 인터페이스
2. **정보 접근성 향상**: 체계적인 정보 구조화
3. **포인트 시스템 활용도 증가**: 독립적인 포인트 관리 화면
4. **앱 전체 일관성**: Material Design 3 기반 통합 디자인

## 📝 참고사항
- 이 문서는 2025-09-26 기준으로 최신 업데이트됨
- 새로운 포스트 워크플로우는 Map 기능과 밀접하게 연관됨
- Firebase 인덱스 생성이 앱 정상 동작의 전제조건
- 구현 우선순위는 사용자 피드백에 따라 조정 가능
- 쿠폰 및 통계 시스템은 비즈니스 모델과 직결되는 핵심 기능
- **개인정보 수정 & 포인트 히스토리 개선**: 사용자 경험 향상을 위한 필수 업데이트

## 🔧 개발 환경 설정

### Firebase 콘솔 접속 정보
- **프로젝트 ID**: `ppamproto-439623`
- **인덱스 관리**: https://console.firebase.google.com/v1/r/project/ppamproto-439623/firestore/indexes
- **필수 생성 인덱스**:
  1. `posts` 컬렉션: `creatorId` + `createdAt`
  2. `post_collections` 컬렉션: `userId` + `collectedAt`

### 개발 도구
- **Flutter**: 최신 stable 버전
- **Firebase SDK**: Firestore, Storage, Auth 연동
- **상태 관리**: Provider 패턴 활용
- **UI 컴포넌트**: Material Design 3 기반

---

**💡 다음 단계**: Firebase 인덱스 생성 → 포스트 상태 관리 구현 → UI 최적화 순서로 진행 권장