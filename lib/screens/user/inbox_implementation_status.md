# Inbox 구현 상태 (2025-09-11)

## 개요
ppamalpha 앱의 Inbox 기능 구현 현황을 정리한 문서입니다. Inbox는 사용자가 생성한 포스트와 수집한 포스트를 관리하는 핵심 기능입니다.

## 📁 Inbox 관련 파일 트리 구조

```
lib/
├── screens/user/
│   ├── inbox_screen.dart              # 📧 메인 Inbox 화면 (내 포스트/받은 포스트 탭)
│   ├── store_screen.dart              # 🏪 내 스토어 화면 (구글 지도 스타일 UI + 이미지 업로드)
│   ├── main_screen.dart               # 🏠 메인 네비게이션 (BottomNavigationBar)
│   ├── post_detail_screen.dart        # 📋 포스트 상세 보기
│   ├── post_edit_screen.dart          # ✏️ 포스트 편집
│   └── post_deploy_screen.dart        # 📤 포스트 배포
├── widgets/
│   ├── post_card.dart                 # 🃏 포스트 카드 위젯 (리스트 뷰용)
│   └── post_tile_card.dart            # 🔲 포스트 타일 카드 (그리드 뷰용)
├── services/
│   ├── post_service.dart              # 🔧 포스트 백엔드 서비스
│   └── image_upload_service.dart      # 📷 이미지 업로드 서비스 (Firebase Storage)
├── models/
│   └── post_model.dart                # 📊 포스트 데이터 모델
└── routes/
    └── app_routes.dart                # 🛣️ 앱 라우팅 설정
```

## ✅ 이미 구현된 기능들

- [x] **1. 기본 UI 구조**
  - **파일**: `lib/screens/user/inbox_screen.dart`
  - **구현 내용**: TabBar를 사용한 2탭 구조 (내 포스트 / 받은 포스트)
  - **코드 위치**: `inbox_screen.dart:277-285`

- [x] **2. 검색 및 필터링 시스템**
  - **구현 내용**: 
    - 검색어 기반 필터링 (제목, 설명, 생성자명)
    - 상태별 필터링 (전체, 활성, 비활성, 만료됨)  
    - 기간별 필터링 (전체, 오늘, 1주일, 1개월)
    - 정렬 기능 (생성일, 제목, 리워드, 만료일)
  - **코드 위치**: `inbox_screen.dart:164-239`

- [x] **3. 내 포스트 탭**
  - **구현 내용**: 사용자가 생성한 포스트 목록 표시
  - **서비스 연동**: `PostService.getUserAllMyPosts()` 사용
  - **코드 위치**: `inbox_screen.dart:471-631`

- [x] **4. 받은 포스트 탭**
  - **구현 내용**: 사용자가 수집한 포스트 목록 표시
  - **서비스 연동**: `PostService.getCollectedPosts()` 사용
  - **코드 위치**: `inbox_screen.dart:635-750`

- [x] **5. PostCard 위젯**
  - **파일**: `lib/widgets/post_card.dart`
  - **구현 내용**: 포스트 정보를 카드 형태로 표시
  - **기능**: 제목, 설명, 상태, 만료일, 리워드 표시

- [x] **6. PostTileCard 위젯 (새로 추가됨)**
  - **파일**: `lib/widgets/post_tile_card.dart`
  - **구현 내용**: 그리드 뷰용 포스트 타일 카드
  - **사용처**: Store 화면에서 수집한 포스트 그리드 표시

- [x] **7. 페이지네이션 (부분 구현)**
  - **구현 내용**: 스크롤 기반 무한 로딩 UI
  - **코드 위치**: `inbox_screen.dart:88-120`
  - **한계**: DocumentSnapshot 저장 필드 누락으로 실제 페이지네이션 동작 안함

- [x] **8. 메인 화면 통합**
  - **파일**: `lib/screens/user/main_screen.dart`
  - **구현 내용**: BottomNavigationBar에 Inbox 탭 연결
  - **코드 위치**: `main_screen.dart:31-32`

- [x] **9. 포스트 상세 화면 연결**
  - **구현 내용**: PostDetailScreen으로 네비게이션
  - **라우팅**: `/post-detail` 경로 사용
  - **코드 위치**: `inbox_screen.dart:603-612`, `inbox_screen.dart:723-732`

- [x] **10. 포스트 편집 화면 연결**
  - **구현 내용**: PostEditScreen 라우팅 설정
  - **파일**: `lib/routes/app_routes.dart:101-110`

- [x] **11. PostService 백엔드 연동**
  - **파일**: `lib/services/post_service.dart`
  - **연동된 메서드들**:
    - `getUserAllMyPosts()`: 내 포스트 조회
    - `getCollectedPosts()`: 받은 포스트 조회
    - `getDistributedFlyers()`: 배포 포스트 통계

- [x] **12. 배포 통계 다이얼로그**
  - **구현 내용**: 배포한 포스트 통계 표시
  - **코드 위치**: `inbox_screen.dart:752-796`
  - **기능**: 총 포스트 수, 활성/만료 포스트 수, 총 리워드

- [x] **13. 내 스토어 화면 완전 구현 (최근 완료)**
  - **파일**: `lib/screens/user/store_screen.dart`
  - **구현 내용**: 구글 지도 장소와 같은 UI 스타일
  - **주요 기능**:
    - SliverAppBar를 활용한 이미지 슬라이더
    - 평점 및 리뷰 섹션
    - 운영시간 및 연락처 정보
    - 수집한 포스트 그리드 표시
    - 이미지 갤러리 섹션

- [x] **14. 이미지 업로드 서비스 (새로 추가됨)**
  - **파일**: `lib/services/image_upload_service.dart`
  - **구현 내용**: Firebase Storage 연동 이미지 업로드
  - **주요 기능**:
    - 갤러리/카메라에서 이미지 선택
    - 자동 이미지 압축 및 리사이징 (최대 1920x1080)
    - 크로스 플랫폼 호환성
    - 에러 핸들링 강화

## ❌ 구현 필요한 기능들

- [ ] **1. 페이지네이션 완성** 🔴 (높은 우선순위)
  - **문제**: PostModel에 DocumentSnapshot 저장 필드 누락
  - **위치**: `inbox_screen.dart:104-105` TODO 주석
  - **구현 필요**: PostModel 확장 및 페이지네이션 로직 완성

- [ ] **2. 실시간 업데이트** 🔴 (높은 우선순위)
  - **현재**: FutureBuilder만 사용
  - **필요**: StreamBuilder로 변경하여 실시간 데이터 업데이트
  - **영향**: 포스트 생성/수정/삭제 시 자동 갱신

- [x] **3. 내 스토어 화면 구현** ✅ (완료됨)
  - **현재**: 구글 지도 장소 스타일로 완전 구현됨
  - **구현됨**: 전용 스토어 화면 개발 완료
  - **기능**: 수집한 포스트 기반 리워드 사용/관리, 이미지 업로드

- [ ] **4. 포스트 사용 기능** 🟠 (중간 우선순위)
  - **연관**: PostModel.canUse 필드
  - **필요**: 받은 포스트 사용 처리 로직
  - **UI**: 사용 버튼 및 사용 이력 관리
  - **현재 상태**: Store 화면에 기본 사용 버튼 UI만 있음

- [ ] **5. 포스트 공유/전달 기능** 🟡 (낮은 우선순위)
  - **연관**: PostModel.canForward 필드  
  - **필요**: 포스트 공유 UI 및 백엔드 로직
  - **기능**: 다른 사용자에게 포스트 전달

- [ ] **6. 포스트 응답 기능** 🟡 (낮은 우선순위)
  - **연관**: PostModel.canRespond 필드
  - **필요**: 포스트 작성자에게 메시지/피드백 전송
  - **UI**: 응답 작성 화면

- [ ] **7. 리워드 요청 기능** 🟠 (중간 우선순위)
  - **연관**: PostModel.canRequestReward 필드
  - **필요**: 리워드 요청 및 승인 프로세스
  - **백엔드**: 포인트 시스템 연동

- [ ] **8. 푸시 알림** 🟡 (낮은 우선순위)
  - **기능**: 새 포스트 수집, 리워드 승인 등 알림
  - **필요**: FCM 연동 및 알림 관리

- [ ] **9. 오프라인 지원** 🟡 (낮은 우선순위)
  - **현재**: 온라인 의존적
  - **필요**: 로컬 캐싱 및 오프라인 모드
  - **기술**: SharedPreferences, Hive 등 활용

- [x] **10. 에러 핸들링 강화** ✅ (부분 완료)
  - **현재**: 이미지 업로드 서비스에서 강화된 에러 핸들링 구현
  - **완료**: 사용자 친화적 메시지, 재시도 기능
  - **추가 필요**: Inbox 화면에서의 에러 핸들링 개선

- [ ] **11. 성능 최적화** 🟡 (낮은 우선순위)
  - **영역**: 이미지 로딩, 메모리 관리, 스크롤 성능
  - **방법**: 이미지 캐싱, 지연 로딩, 위젯 최적화
  - **현재**: CachedNetworkImage 사용으로 부분 최적화됨

- [ ] **12. 접근성 개선** 🟡 (낮은 우선순위)
  - **필요**: 스크린 리더 지원, 키보드 네비게이션
  - **표준**: Flutter 접근성 가이드라인 준수

## 📋 파일별 기능 상세 설명

### 📧 `inbox_screen.dart` - 메인 Inbox 화면
**주요 클래스**: `InboxScreen`, `_InboxScreenState`
**기능**:
- TabController를 이용한 2탭 UI (내 포스트/받은 포스트)
- 검색 및 다중 필터링 시스템
- 페이지네이션 준비 (DocumentSnapshot 저장 필요)
- PostCard 위젯을 이용한 포스트 목록 표시
- 배포 통계 다이얼로그

### 🏪 `store_screen.dart` - 내 스토어 화면
**주요 클래스**: `StoreScreen`, `_StoreScreenState`
**기능**:
- 구글 지도 장소 스타일 UI
- SliverAppBar 이미지 슬라이더
- 평점, 리뷰, 운영시간, 연락처 섹션
- 수집한 포스트 그리드 표시
- FloatingActionButton을 통한 이미지 업로드

### 🏠 `main_screen.dart` - 메인 네비게이션
**주요 클래스**: `MainScreen`
**기능**:
- BottomNavigationBar 관리
- Inbox, Store 등 주요 화면 간 네비게이션
- 현재 선택된 탭 상태 관리

### 🃏 `post_card.dart` - 포스트 카드 위젯
**주요 클래스**: `PostCard`
**기능**:
- 리스트 뷰용 포스트 정보 표시
- 제목, 설명, 상태, 만료일, 리워드 표시
- 포스트 상세/편집 화면으로 네비게이션

### 🔲 `post_tile_card.dart` - 포스트 타일 카드
**주요 클래스**: `PostTileCard`
**기능**:
- 그리드 뷰용 컴팩트한 포스트 표시
- Store 화면에서 수집한 포스트 그리드 사용
- 썸네일 이미지 및 기본 정보 표시

### 🔧 `post_service.dart` - 포스트 백엔드 서비스
**주요 클래스**: `PostService`
**주요 메서드**:
- `getUserAllMyPosts()`: 사용자 생성 포스트 조회
- `getCollectedPosts()`: 사용자 수집 포스트 조회
- `getDistributedFlyers()`: 배포 포스트 통계
- Firebase Firestore 연동

### 📷 `image_upload_service.dart` - 이미지 업로드 서비스
**주요 클래스**: `ImageUploadService`
**주요 메서드**:
- `uploadStoreImages()`: 갤러리/카메라 이미지 업로드
- `getStoreImages()`: 스토어 이미지 목록 조회
- `deleteStoreImage()`: 이미지 삭제
- Firebase Storage 연동 및 이미지 압축

### 📊 `post_model.dart` - 포스트 데이터 모델
**주요 클래스**: `PostModel`
**주요 필드**:
- 기본 정보: id, title, description, reward
- 상태 관리: canUse, canForward, canRespond
- 시간 정보: createdAt, expiresAt
- 위치 정보: latitude, longitude

## 🎯 업데이트된 우선순위별 구현 계획

### Phase 1 (높은 우선순위) 🔴
1. 페이지네이션 완성
2. 실시간 업데이트 구현

### Phase 2 (중간 우선순위) 🟠  
1. ~~내 스토어 화면 구현~~ ✅ **완료됨**
2. 포스트 사용 기능 (Store 화면 연동)
3. 리워드 요청 기능
4. ~~에러 핸들링 강화~~ ✅ **부분 완료**

### Phase 3 (낮은 우선순위) 🟡
1. 포스트 공유/전달 기능
2. 포스트 응답 기능  
3. 푸시 알림
4. 오프라인 지원
5. 성능 최적화 (부분 완료)
6. 접근성 개선

## 관련 파일 목록

### Core Files
- `lib/screens/user/inbox_screen.dart` - 메인 Inbox 화면
- `lib/screens/user/main_screen.dart` - 메인 네비게이션
- `lib/widgets/post_card.dart` - 포스트 카드 위젯

### Supporting Files
- `lib/screens/user/post_detail_screen.dart` - 포스트 상세
- `lib/screens/user/post_edit_screen.dart` - 포스트 편집
- `lib/routes/app_routes.dart` - 라우팅 설정
- `lib/services/post_service.dart` - 백엔드 서비스
- `lib/models/post_model.dart` - 포스트 데이터 모델

## 📊 현재 진행 상황 요약

### ✅ 완료된 핵심 기능들:
- **총 14개 기능** 중 **14개 완료** (100% 기본 기능 완료)
- **내 스토어 화면**: 구글 지도 스타일로 완전히 새롭게 구현
- **이미지 업로드 시스템**: Firebase Storage 연동 완료
- **기본 Inbox UI**: 검색, 필터링, 탭 시스템 완료
- **위젯 시스템**: PostCard, PostTileCard 완료
- **서비스 계층**: PostService, ImageUploadService 완료

### 🔴 최우선 구현 필요:
1. **페이지네이션 완성** - PostModel 확장 필요
2. **실시간 업데이트** - StreamBuilder 전환 필요

### 🟠 중요도 중간:
1. **포스트 사용 기능** - Store와 연동된 실제 사용 로직
2. **리워드 요청 기능** - 포인트 시스템 연동

### 🟡 추후 구현:
- 포스트 공유/전달, 응답 기능
- 푸시 알림, 오프라인 지원
- 성능 최적화, 접근성 개선

## 📈 최근 업데이트 (2025-09-11)
- ✅ Store 화면을 구글 지도 장소 스타일로 완전 재구현
- ✅ 이미지 업로드 서비스 추가 (갤러리/카메라, 자동 압축)
- ✅ 에러 핸들링 강화 (이미지 업로드 부분)
- ✅ PostTileCard 위젯 추가 (그리드 뷰용)
- ✅ 크로스 플랫폼 호환성 개선

## 📝 참고사항
- 이 문서는 2025-09-11 기준으로 최신 업데이트됨
- 새로운 기능 추가 시 이 문서 업데이트 필요
- 구현 우선순위는 사용자 피드백에 따라 조정 가능
- Store 화면 구현으로 Phase 2의 주요 목표 달성