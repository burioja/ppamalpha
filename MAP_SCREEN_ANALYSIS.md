# 🗺️ map_screen.dart 기능 분석 보고서

## 📊 파일 정보
- **파일명**: lib/features/map_system/screens/map_screen.dart
- **라인 수**: 4,939줄
- **State 변수**: 60개 이상
- **메서드**: 54개 이상

---

## 🎯 주요 기능 분류

### 1️⃣ **Fog of War 시스템** (15개 메서드, ~1,200줄)

#### State 변수
```dart
List<Polygon> _grayPolygons          // 과거 방문 위치 (회색)
List<CircleMarker> _ringCircles      // 1km 밝은 영역
Set<String> _currentFogLevel1TileIds // Fog Level 1 타일 캐시
DateTime? _fogLevel1CacheTimestamp   // 캐시 타임스탬프
Map<String, int> _tileFogLevels      // 타일별 Fog 레벨
Set<String> _lastFogLevel1Tiles      // 이전 Fog 타일들
```

#### 주요 메서드
```dart
_rebuildFogWithUserLocations()      // Fog 재구성
_loadVisitedLocations()             // 과거 방문 위치 로드
_updateGrayAreasWithPreviousPosition() // 회색 영역 업데이트
_setLevel1TileLocally()             // 로컬 캐시 설정
_clearFogLevel1Cache()              // 캐시 초기화
_checkAndClearExpiredFogLevel1Cache() // 만료 캐시 정리
_getCurrentFogLevel1Tiles()         // Fog Level 1 타일 계산
_filterPostsByFogLevel()            // Fog 레벨 기반 필터링
_checkFogLevelAndShowMenu()         // Fog 레벨 확인
_updateFogOfWar()                   // Fog 업데이트
_updateOSMFogOfWar()                // OSM Fog 업데이트
```

#### 기능
- ✅ 1km 반경 밝은 영역 (현재위치/집/일터)
- ✅ 과거 방문 위치 회색 표시
- ✅ Fog Level 1/2/3 시스템
- ✅ 타일 기반 방문 기록
- ✅ 5분 캐시 시스템

---

### 2️⃣ **위치 시스템** (12개 메서드, ~800줄)

#### State 변수
```dart
LatLng? _currentPosition             // 현재 GPS 위치
LatLng? _homeLocation                // 집 위치
List<LatLng> _workLocations          // 일터 위치들
String _currentAddress               // 현재 주소
LatLng? _mockPosition                // Mock 위치 (테스트용)
bool _isMockModeEnabled              // Mock 모드
```

#### 주요 메서드
```dart
_initializeLocation()               // 위치 초기화
_getCurrentLocation()               // 현재 위치 가져오기
_createCurrentLocationMarker()      // 현재 위치 마커 생성
_loadUserLocations()                // 집/일터 위치 로드
_updateCurrentAddress()             // 주소 업데이트
_moveToHome()                       // 집으로 이동
_moveToWorkplace()                  // 일터로 이동
_toggleMockMode()                   // Mock 모드 토글
_moveMockPosition()                 // Mock 위치 이동
_showMockPositionInputDialog()      // Mock 위치 입력
```

#### 기능
- ✅ 실시간 GPS 위치 추적
- ✅ 집/일터 위치 관리
- ✅ 주소 변환 (좌표 ↔ 주소)
- ✅ 위치 권한 관리
- ✅ Mock 위치 (개발/테스트)
- ✅ 일터 변경 실시간 감지

---

### 3️⃣ **마커 & 클러스터링** (10개 메서드, ~900줄)

#### State 변수
```dart
List<MarkerModel> _markers           // 마커 목록
List<Marker> _clusteredMarkers       // 클러스터링된 마커
List<ClusterMarkerModel> _visibleMarkerModels // 보이는 마커
Size _lastMapSize                    // 지도 크기
LatLng _mapCenter                    // 지도 중심
double _mapZoom                      // 줌 레벨
Timer? _clusterDebounceTimer         // 디바운스 타이머
```

#### 주요 메서드
```dart
_updateMarkers()                    // 마커 업데이트
_rebuildClusters()                  // 클러스터 재구성
_onTapSingleMarker()                // 단일 마커 탭
_zoomIntoCluster()                  // 클러스터 확대
_isSuperMarker()                    // 슈퍼 마커 확인
_showMarkerDetails()                // 마커 상세 표시
_showMarkerDetail()                 // 마커 상세 (다이얼로그)
_collectMarker()                    // 마커 수집
_removeMarker()                     // 마커 회수
_latLngToScreen()                   // 좌표 변환
```

#### 기능
- ✅ 마커 클러스터링 (근접도 기반)
- ✅ 줌 레벨에 따른 클러스터 임계값
- ✅ 슈퍼 마커 (고액 보상)
- ✅ 마커 탭/확대
- ✅ 마커 수집/회수
- ✅ 실시간 마커 업데이트

---

### 4️⃣ **포스트 관리** (18개 메서드, ~1,500줄)

#### State 변수
```dart
List<PostModel> _posts               // 포스트 목록
int _receivablePostCount             // 수령 가능 개수
bool _isReceiving                    // 수령 중 상태
Set<String> _visiblePostIds          // 보이는 포스트 ID
```

#### 주요 메서드
```dart
_setupPostStreamListener()          // 포스트 스트림 설정
_updatePostsBasedOnFogLevel()       // Fog 기반 포스트 업데이트
_filterPostsByFogLevel()            // Fog 레벨 필터링
_loadPosts()                        // 포스트 로드
_showPostDetail()                   // 포스트 상세
_collectPost()                      // 포스트 수집
_collectPostFromMarker()            // 마커에서 포스트 수집
_removePost()                       // 포스트 제거
_receiveNearbyPosts()               // 주변 포스트 일괄 수령
_updateReceivablePosts()            // 수령 가능 개수 업데이트
_playReceiveEffects()               // 수령 효과 (진동/사운드)
_showPostReceivedCarousel()         // 수령 포스트 캐러셀
_showUnconfirmedPostsDialog()       // 미확인 포스트 다이얼로그
_confirmUnconfirmedPost()           // 미확인 포스트 확인
_deleteUnconfirmedPost()            // 미확인 포스트 삭제
```

#### 기능
- ✅ Fog 레벨 기반 포스트 표시
- ✅ 포스트 수집/확인
- ✅ 일괄 수령 (200m 이내)
- ✅ 미확인 포스트 관리
- ✅ 수령 효과 (진동/사운드)
- ✅ 포스트 캐러셀 UI

---

### 5️⃣ **필터 시스템** (8개 메서드, ~600줄)

#### State 변수
```dart
String _selectedCategory             // 카테고리 (전체/쿠폰)
double _maxDistance                  // 검색 반경 (1km/3km)
int _minReward                       // 최소 리워드
bool _showCouponsOnly                // 쿠폰만
bool _showMyPostsOnly                // 내 포스트만
bool _showUrgentOnly                 // 마감임박만
bool _showVerifiedOnly               // 인증만
bool _showUnverifiedOnly             // 미인증만
bool _isPremiumUser                  // 프리미엄 사용자
UserType _userType                   // 사용자 타입
```

#### 주요 메서드
```dart
_showFilterDialog()                 // 필터 다이얼로그
_resetFilters()                     // 필터 초기화
_buildFilterChip()                  // 필터 칩 빌더
_checkPremiumStatus()               // 프리미엄 상태 확인
```

#### 기능
- ✅ 카테고리 필터 (전체/쿠폰)
- ✅ 거리 필터 (일반 1km, 프리미엄 3km)
- ✅ 리워드 필터
- ✅ 내 포스트 필터
- ✅ 마감임박 필터
- ✅ 인증/미인증 필터
- ✅ 프리미엄 회원 지원

---

### 6️⃣ **지도 이벤트 & 상호작용** (12개 메서드, ~700줄)

#### State 변수
```dart
MapController? _mapController        // 지도 컨트롤러
Timer? _mapMoveTimer                 // 지도 이동 타이머
LatLng? _lastMapCenter               // 마지막 지도 중심
bool _isUpdatingPosts                // 업데이트 중
LatLng? _longPressedLatLng           // 롱프레스 위치
```

#### 주요 메서드
```dart
_onMapMoved()                       // 지도 이동 감지
_updateMapState()                   // 지도 상태 업데이트
_handleMapMoveComplete()            // 지도 이동 완료
_onMapReady()                       // 지도 준비 완료
_showLongPressMenu()                // 롱프레스 메뉴
_showRestrictedLongPressMenu()      // 제한된 롱프레스 메뉴
_showBlockedLongPressMessage()      // 차단 메시지
_canLongPressAtLocation()           // 롱프레스 가능 확인
_navigateToPostPlace()              // 포스트 장소로 이동
_navigateToPostAddress()            // 포스트 주소로 이동
_navigateToPostDeploy()             // 포스트 배포
```

#### 기능
- ✅ 지도 이동/줌 감지
- ✅ 롱프레스로 포스트 배포
- ✅ 200m 이내에서만 배포 가능
- ✅ Fog 레벨 확인
- ✅ 디바운스 최적화
- ✅ 실시간 마커 업데이트

---

### 7️⃣ **사용자 데이터 & 리스너** (5개 메서드, ~300줄)

#### State 변수
```dart
StreamSubscription? _workplaceSubscription // 일터 리스너
```

#### 주요 메서드
```dart
_setupUserDataListener()            // 사용자 데이터 리스너
_setupWorkplaceListener()           // 일터 변경 리스너
_setupMarkerListener()              // 마커 리스너
```

#### 기능
- ✅ 사용자 프로필 실시간 감지
- ✅ 일터 변경 실시간 감지
- ✅ 사용자 타입 업데이트
- ✅ 프리미엄 상태 동기화

---

### 8️⃣ **UI 빌더들** (20개 메서드, ~1,500줄)

#### 주요 메서드
```dart
build()                             // 메인 빌드
_buildReceiveFab()                  // 수령 FAB
_buildFilterChip()                  // 필터 칩
_buildPostCarouselPage()            // 포스트 캐러셀 페이지
_showFilterDialog()                 // 필터 다이얼로그
_showToast()                        // 토스트 메시지
_showLocationPermissionDialog()     // 위치 권한 다이얼로그
```

#### UI 구성요소
- ✅ FlutterMap (지도)
- ✅ TileLayer (OSM 타일)
- ✅ UnifiedFogOverlayWidget (Fog 오버레이)
- ✅ MarkerLayer (마커들)
- ✅ 필터 칩들 (상단)
- ✅ 위치 이동 버튼들 (하단)
- ✅ 수령 FAB (중앙 하단)
- ✅ Mock 컨트롤러 (개발용)
- ✅ 로딩/에러 표시

---

## 📋 세부 기능 목록

### 🌫️ **Fog of War 기능**
1. ✅ Level 1: 1km 밝은 영역 (현재/집/일터)
2. ✅ Level 2: 과거 방문 영역 (회색)
3. ✅ Level 3: 미방문 영역 (검정)
4. ✅ 타일 기반 시스템 (1km x 1km 그리드)
5. ✅ 방문 기록 자동 저장
6. ✅ 30일 이내 방문 기록 표시
7. ✅ 5분 로컬 캐시
8. ✅ Fog 레벨별 포스트 표시 제한

### 📍 **위치 기능**
1. ✅ 실시간 GPS 위치
2. ✅ 집/일터 관리
3. ✅ 좌표 ↔ 주소 변환
4. ✅ 위치 권한 관리
5. ✅ Mock 위치 (테스트)
6. ✅ 일터 변경 실시간 동기화
7. ✅ 이전 위치 추적

### 🎯 **마커 기능**
1. ✅ 마커 클러스터링
2. ✅ 줌 레벨별 임계값
3. ✅ 슈퍼 마커 (고액)
4. ✅ 일반 마커
5. ✅ 마커 탭/상세보기
6. ✅ 마커 수집 (200m 이내)
7. ✅ 마커 회수 (내 마커만)
8. ✅ 실시간 마커 업데이트
9. ✅ Fog 레벨 기반 마커 표시

### 📮 **포스트 기능**
1. ✅ 포스트 로드 (Fog 기반)
2. ✅ 포스트 수집/확인
3. ✅ 일괄 수령 (200m 이내 전체)
4. ✅ 미확인 포스트 관리
5. ✅ 포스트 캐러셀
6. ✅ 포스트 배포 (롱프레스)
7. ✅ 포스트 상세보기
8. ✅ 수령 효과 (진동/사운드)

### 🔍 **필터 기능**
1. ✅ 전체/쿠폰 카테고리
2. ✅ 거리 필터 (1km/3km)
3. ✅ 리워드 필터
4. ✅ 내 포스트만
5. ✅ 쿠폰만
6. ✅ 마감임박만
7. ✅ 인증/미인증 필터
8. ✅ 프리미엄 혜택

### 🎨 **UI/UX 기능**
1. ✅ 로딩 인디케이터
2. ✅ 에러 메시지 표시
3. ✅ 필터 칩 (상단)
4. ✅ 위치 버튼 (집/일터/현재)
5. ✅ 수령 FAB
6. ✅ Mock 컨트롤러
7. ✅ 토스트 메시지
8. ✅ 다이얼로그들

---

## 📊 라인 수 분포 (추정)

| 기능 영역 | 라인 수 | 비율 |
|----------|---------|------|
| **Fog of War** | ~1,200줄 | 24% |
| **UI 빌더들** | ~1,500줄 | 30% |
| **포스트 관리** | ~1,000줄 | 20% |
| **마커/클러스터** | ~700줄 | 14% |
| **위치 시스템** | ~400줄 | 8% |
| **필터/설정** | ~200줄 | 4% |
| **총계** | **4,939줄** | **100%** |

---

## 🎯 분리 가능한 파일 구조

```
map_screen.dart (메인, 500줄)
├── State 변수들
├── initState/dispose
├── build() 메서드
└── Import들

독립 파일들:
├── map_fog_handler.dart (1,200줄) - Fog of War 전체
├── map_marker_handler.dart (900줄) - 마커/클러스터링
├── map_post_handler.dart (1,000줄) - 포스트 관리
├── map_location_handler.dart (400줄) - 위치 관리
├── map_filter_handler.dart (200줄) - 필터
└── map_ui_builders.dart (800줄) - UI 빌더들
```

**총계: 5,000줄 (기존과 동일하지만 파일 7개로 분리)**

---

## 💡 Controller 활용 시 예상 라인 감소

이미 만든 Controller를 사용하면:

| 메서드 | 현재 | Controller 사용 | 감소 |
|--------|------|----------------|------|
| _rebuildFogWithUserLocations | 40줄 | 5줄 | 87% |
| _loadUserLocations | 120줄 | 10줄 | 92% |
| _getCurrentLocation | 80줄 | 10줄 | 87% |
| _updateMarkers | 30줄 | 5줄 | 83% |
| _collectPostFromMarker | 100줄 | 15줄 | 85% |

**전체 예상: 4,939줄 → 1,500줄 (70% 감소!)**

---

## 🚀 리팩토링 방향

### **즉시 가능:**
Controller를 사용해서 메서드들을 간소화

### **중기:**
독립 Handler 파일들로 분리

### **장기:**
Clean Architecture 완전 적용

**분석 완료!** ✅

