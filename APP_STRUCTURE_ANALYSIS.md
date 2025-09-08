# PPAMPROTO 앱 구조 분석

## 📱 앱 개요
PPAMPROTO는 Flutter 기반의 위치 기반 앱으로, Firebase 백엔드를 활용한 모바일 애플리케이션입니다. 사용자의 위치 정보를 기반으로 한 지도 서비스와 지갑 기능을 제공합니다.

## 🏗️ 전체 아키텍처

### 기술 스택
- **Frontend**: Flutter 3.10.4 + Dart 241.18808
- **Backend**: Google Firebase
- **인증**: Firebase Auth
- **데이터베이스**: Cloud Firestore
- **상태 관리**: Provider 패턴
- **지도**: Google Maps Flutter
- **위치 서비스**: Geolocator, Geocoding

### 프로젝트 구조
```ppamproto/
├── lib/                    # 메인 Dart 코드
│   ├── main.dart          # 앱 진입점 (108 lines)
│   ├── config/            # 설정 파일들
│   │   └── config.dart    # 앱 설정 (Google API Key 등)
│   ├── providers/         # 상태 관리 (Provider)
│   │   ├── user_provider.dart      # 사용자 정보 관리 (199 lines)
│   │   ├── status_provider.dart    # 앱 상태 관리 (12 lines)
│   │   ├── search_provider.dart    # 검색 상태 관리 (24 lines)
│   │   ├── screen_provider.dart    # 화면 전환 상태 (13 lines)
│   │   └── wallet_provider.dart    # 지갑 상태 관리
│   ├── screens/           # UI 화면들
│   │   ├── main_screen.dart        # 메인 화면 (탭 기반) (347 lines)
│   │   ├── login_screen.dart       # 로그인 (171 lines)
│   │   ├── signup_screen.dart      # 회원가입 (256 lines)
│   │   ├── map_screen.dart         # 지도 화면 (946 lines)
│   │   ├── search_screen.dart      # 검색 (55 lines)
│   │   ├── wallet_screen.dart      # 지갑 (539 lines)
│   │   ├── settings_screen.dart    # 설정 (156 lines)
│   │   ├── budget_screen.dart      # 예산 (13 lines)
│   │   └── map_search_screen.dart  # 지도 검색 (42 lines)
│   ├── services/          # 비즈니스 로직 서비스
│   │   ├── firebase_service.dart   # Firebase 연동 (37 lines)
│   │   ├── location_service.dart   # 위치 서비스 (56 lines)
│   │   ├── user_service.dart       # 사용자 서비스
│   │   ├── track_service.dart      # 트랙 서비스
│   └── widgets/           # 재사용 가능한 UI 컴포넌트
│       ├── user_status_widget.dart     # 사용자 상태 (84 lines)
│       ├── mode_switcher.dart          # 모드 전환 (60 lines)
│       ├── status_bar.dart             # 상태 바 (46 lines)
│       ├── current_status_display.dart # 현재 상태 표시 (21 lines)
│       └── address_search_widget.dart  # 주소 검색 (69 lines)
├── assets/                # 리소스 파일들
│   ├── images/            # 이미지 리소스
│   ├── workplaces.json    # 직장 데이터
│   ├── map_style.json     # 지도 스타일
│   └── country_codes.json # 국가 코드
├── android/               # Android 플랫폼 설정
├── ios/                   # iOS 플랫폼 설정
└── firebase_options.dart  # Firebase 설정 (87 lines)
```

## 🔧 핵심 컴포넌트 분석

### 1. main.dart - 앱 진입점
```dart
// 주요 기능:
- Firebase 초기화 및 설정
- Provider 설정 (4개 Provider)
- 인증 상태 감지 (AuthWrapper)
- 라우팅 설정
- 위치 기반 서비스 초기화
```

**Provider 구성:**
- `StatusProvider`: 앱 전반 상태 관리
- `UserProvider`: 사용자 정보 및 프로필 관리 (199 lines)
- `SearchProvider`: 검색 기능 상태 관리
- `ScreenProvider`: 화면 전환 상태 관리
- `WalletProvider`: 지갑 상태 관리

### 2. 인증 시스템 (Authentication)
- **AuthWrapper**: Firebase Auth 상태를 감지하여 자동 로그인/로그아웃 처리
- **LoginScreen**: 로그인 화면 (171 lines)
- **SignupScreen**: 회원가입 화면 (256 lines)
- **MainScreen**: 인증 후 메인 화면 (316 lines)

### 3. 메인 화면 구조 (MainScreen)
**탭 기반 네비게이션:**
1. **Map** (Icons.map) - 지도 화면
2. **Wallet** (Icons.account_balance_wallet) - 지갑 화면

**특별 기능:**
- **ModeSwitcher**: Work/Life 모드 전환
- **위치 표시**: 현재 위치 주소 표시
- **예산 아이콘**: 예산 화면 이동

### 4. 사용자 관리 (UserProvider)
**관리하는 사용자 데이터:**
- 기본 정보: email, phoneNumber, address, nickName
- 프로필: profileImageUrl, birthDate, gender
- 소셜: followers, following, connections
- 금융: balance, bankAccount
- 직장: workPlaces (List<Map<String, String>>)

**주요 메서드:**
- `fetchUserData()`: Firebase에서 사용자 데이터 로드
- `updateUserData()`: Firebase에 사용자 데이터 업데이트
- `addWorkPlace()`, `removeWorkPlace()`, `updateWorkPlace()`: 직장 정보 관리

### 5. 화면별 기능 분석

#### 지도 관련
- **MapScreen**: Google Maps 연동 (946 lines)
- **MapSearchScreen**: 지도 기반 검색 (42 lines)
- **LocationService**: 위치 정보 처리 (56 lines)

#### 검색 기능
- **SearchScreen**: 일반 검색 (55 lines)
- **SearchProvider**: 검색 상태 관리 (24 lines)
- **AddressSearchWidget**: 주소 검색 (69 lines)

#### 금융 관련
- **WalletScreen**: 지갑 기능 (539 lines)
- **BudgetScreen**: 예산 관리 (13 lines)

#### 설정 및 관리
- **SettingsScreen**: 사용자 설정 (156 lines)
- **UserStatusWidget**: 사용자 상태 표시 (84 lines)

### 6. 서비스 레이어 (Services)

#### FirebaseService
```dart
// 주요 기능:
- workplaces.json 데이터를 Firebase에 업로드
- Firestore 컬렉션 관리
- 중복 데이터 방지 로직
```

#### LocationService
```dart
// 주요 기능:
- 현재 위치 가져오기
- 주소 변환 (Geocoding)
- 위치 권한 처리
```

### 7. UI 컴포넌트 (Widgets)

#### ModeSwitcher (60 lines)
- Work/Life 모드 전환 UI
- 상태에 따른 색상 변경

#### UserStatusWidget (84 lines)
- 사용자 프로필 표시
- 상태 정보 표시

#### StatusBar (46 lines)
- 앱 상태 표시
- 현재 모드 표시

#### AddressSearchWidget (69 lines)
- 주소 검색 기능
- 자동완성 기능

## 🔄 데이터 플로우

### 1. 앱 시작 플로우
```
main.dart → Firebase 초기화 → Provider 설정 → AuthWrapper → 인증 상태 확인 → MainScreen/LoginScreen
```

### 2. 인증 플로우
```
LoginScreen → Firebase Auth → AuthWrapper → MainScreen
```

### 3. 사용자 데이터 플로우
```
UserProvider → Firebase Firestore → UI 업데이트
```

### 4. 위치 서비스 플로우
```
LocationService → Geolocator → Geocoding → UI 표시
```

## 📦 의존성 분석 (pubspec.yaml)

### 주요 패키지
```yaml
# Firebase 관련
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
firebase_storage: ^12.3.6

# 지도 및 위치
google_maps_flutter: ^2.9.0
geolocator: ^12.0.0
geocoding: ^3.0.0
google_maps_cluster_manager: ^3.1.0

# 상태 관리
provider: ^6.1.2

# UI 관련
flutter_spinkit: ^5.2.1
carousel_slider: ^5.0.0
image_picker: ^1.0.7

# 기타
http: ^1.2.2
flutter_dotenv: ^5.1.0
intl: ^0.18.1
```

## 🎯 앱의 주요 기능

### 1. 위치 기반 서비스
- 현재 위치 표시
- 지도 기반 검색
- 주소 자동완성

### 2. 소셜 커뮤니티
- 게시글 작성/조회
- 사용자 프로필 관리
- 팔로우/팔로잉 시스템

### 3. 모드 전환
- Work/Life 모드
- 모드별 다른 UI/기능

### 4. 금융 기능
- 지갑 관리
- 예산 관리
- 쇼핑/스토어 기능

### 5. 검색 기능
- 일반 검색
- 지도 기반 검색
- 주소 검색

## 🔧 개발 환경

### 기술 스택 버전
- **Flutter**: 3.10.4 (현재 사용 중)
- **Dart**: 241.18808
- **Android API**: 34
- **Java**: 17

### 개발 도구
- **IDE**: Cursor
- **Android Studio**: 2024.1.1

### Firebase 설정
- `firebase_options.dart`: Firebase 프로젝트 설정
- `google-services.json`: Android Firebase 설정
- `firebase.json`: Firebase 프로젝트 설정
- `firestore.rules`: Firestore 보안 규칙

## 📝 다음 분석 단계

1. **세부 화면 분석**: 각 화면의 구체적인 기능과 UI 구조
2. **데이터 모델 분석**: Firestore 데이터 구조 및 스키마
3. **API 연동 분석**: Firebase 서비스별 연동 방식
4. **상태 관리 상세**: Provider별 상태 관리 로직
5. **UI/UX 분석**: 위젯 컴포넌트별 역할과 재사용성
6. **성능 최적화**: 앱 성능 분석 및 개선점

---

*이 문서는 PPAMPROTO 앱의 전체적인 구조를 파악하기 위한 초기 분석입니다. 각 섹션별로 더 상세한 분석이 필요할 때 추가 업데이트하겠습니다.*

**마지막 업데이트**: 2024년 12월
**분석 기준**: main.dart 및 전체 프로젝트 구조 기반