# 🎯 Controller & Helper 사용 가이드

## 📚 목차
1. [기본 사용법](#기본-사용법)
2. [실전 예제](#실전-예제)
3. [기존 코드 개선 예제](#기존-코드-개선-예제)
4. [새 화면 만들 때](#새-화면-만들-때)

---

## 🚀 기본 사용법

### ✅ Controller 사용법

```dart
// 1. Import
import '../controllers/location_controller.dart';

// 2. 호출 (static 메서드)
final position = await LocationController.getCurrentLocation();

// 3. 결과 사용
if (position != null) {
  print('현재 위치: ${position.latitude}, ${position.longitude}');
}
```

**간단하죠?** 클래스 생성 없이 바로 사용!

---

## 💡 실전 예제

### 예제 1: 위치 가져오기 (LocationController)

#### Before (기존 코드 - 100줄)
```dart
Future<void> _getCurrentLocation() async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
    
    // 주소 변환
    try {
      final address = await NominatimService.reverseGeocode(_currentPosition!);
      setState(() => _currentAddress = address);
    } catch (e) {
      setState(() => _currentAddress = '주소 변환 실패');
    }
    
    // 타일 방문 기록
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    await VisitTileService.updateCurrentTileVisit(tileId);
    
    // ... 더 많은 로직
  } catch (e) {
    setState(() => _errorMessage = '위치를 가져올 수 없습니다');
  }
}
```

#### After (Controller 사용 - 10줄!)
```dart
import '../controllers/location_controller.dart';

Future<void> _getCurrentLocation() async {
  // 1. 위치 가져오기
  final position = await LocationController.getCurrentLocation(
    isMockMode: _isMockModeEnabled,
    mockPosition: _mockPosition,
  );
  
  if (position == null) {
    setState(() => _errorMessage = '위치를 가져올 수 없습니다');
    return;
  }
  
  setState(() => _currentPosition = position);
  
  // 2. 주소 가져오기
  final address = await LocationController.getAddressFromLatLng(position);
  setState(() => _currentAddress = address);
  
  // 3. 타일 방문 기록
  await LocationController.updateTileVisit(position);
}
```

**라인 수: 100줄 → 15줄 (85% 감소!)**

---

### 예제 2: 포스트 수집 (PostController)

#### Before (기존 - 80줄)
```dart
Future<void> _collectPost(PostModel post) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    // 거리 확인
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('현재 위치를 확인할 수 없습니다')),
      );
      return;
    }
    
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      post.location.latitude,
      post.location.longitude,
    );
    
    if (distance > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('200m 이내로 접근해주세요')),
      );
      return;
    }
    
    // 포스트 수집
    await PostService().collectPost(
      postId: post.postId,
      userId: user.uid,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('포스트를 수령했습니다! 🎉'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오류: $e')),
    );
  }
}
```

#### After (Controller 사용 - 20줄!)
```dart
import '../../map_system/controllers/post_controller.dart' as map_post;

Future<void> _collectPost(PostModel post) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    _showError('로그인이 필요합니다');
    return;
  }
  
  if (_currentPosition == null) {
    _showError('현재 위치를 확인할 수 없습니다');
    return;
  }
  
  // Controller가 모든 검증 + 수집 처리!
  final (success, reward, message) = await map_post.PostController.collectPost(
    postId: post.postId,
    userId: user.uid,
  );
  
  if (success) {
    _showSuccess(message ?? '포스트 수령 완료!');
  } else {
    _showError(message ?? '수집 실패');
  }
}

void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(msg)),
);

void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(msg), backgroundColor: Colors.green),
);
```

**라인 수: 80줄 → 30줄 (62% 감소!)**

---

### 예제 3: 마커에서 포스트 수집

#### Before (기존 - 120줄)
```dart
Future<void> _collectPostFromMarker(MarkerModel marker) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { /* 에러 */ return; }
    if (_currentPosition == null) { /* 에러 */ return; }
    
    // 거리 확인
    final canCollect = MarkerService.canCollectMarker(
      _currentPosition!,
      LatLng(marker.position.latitude, marker.position.longitude),
    );
    if (!canCollect) { /* 에러 */ return; }
    
    // 수량 확인
    if (marker.quantity <= 0) { /* 에러 */ return; }
    
    // postId 검증 (복잡한 로직 50줄)
    String actualPostId = marker.postId;
    if (actualPostId == marker.markerId || actualPostId.isEmpty) {
      final markerDoc = await FirebaseFirestore.instance
          .collection('markers')
          .doc(marker.markerId)
          .get();
      // ... 검증 로직 ...
    }
    
    // 수집
    await PostService().collectPost(postId: actualPostId, userId: user.uid);
    
    // 성공 처리
    ScaffoldMessenger.of(context).showSnackBar(/* ... */);
    
    // 마커 새로고침 (30줄)
    setState(() {
      _markers.removeWhere((m) => m.postId == actualPostId);
      _updateMarkers();
    });
    
  } catch (e) { /* 에러 처리 */ }
}
```

#### After (Controller 사용 - 25줄!)
```dart
import '../../map_system/controllers/post_controller.dart' as map_post;

Future<void> _collectPostFromMarker(MarkerModel marker) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _currentPosition == null) {
    _showError('준비되지 않았습니다');
    return;
  }
  
  // Controller가 모든 검증 + postId 체크 + 수집까지 처리!
  final (success, reward, message) = await map_post.PostController.collectPostFromMarker(
    marker: marker,
    userId: user.uid,
    currentPosition: _currentPosition!,
  );
  
  if (success) {
    _showSuccess(message);
    
    // 마커 새로고침
    setState(() {
      _markers.removeWhere((m) => m.postId == marker.postId);
      _updateMarkers();
    });
  } else {
    _showError(message);
  }
}
```

**라인 수: 120줄 → 25줄 (79% 감소!)**

---

### 예제 4: Fog of War 업데이트

#### Before (기존 - 200줄)
```dart
void _rebuildFogWithUserLocations(LatLng currentPosition) {
  final allPositions = <LatLng>[currentPosition];
  final ringCircles = <CircleMarker>[];
  
  // 현재 위치
  ringCircles.add(OSMFogService.createRingCircle(currentPosition));
  
  // 집 위치
  if (_homeLocation != null) {
    allPositions.add(_homeLocation!);
    ringCircles.add(OSMFogService.createRingCircle(_homeLocation!));
  }
  
  // 일터 위치들
  for (int i = 0; i < _workLocations.length; i++) {
    final workLocation = _workLocations[i];
    allPositions.add(workLocation);
    ringCircles.add(OSMFogService.createRingCircle(workLocation));
  }
  
  setState(() {
    _ringCircles = ringCircles;
  });
  
  // ... 더 많은 로직
}

Future<void> _loadUserLocations() async {
  // 100줄의 복잡한 Firebase 로직...
}
```

#### After (Controller 사용 - 15줄!)
```dart
import '../controllers/fog_controller.dart';

void _rebuildFogWithUserLocations(LatLng currentPosition) {
  // Controller가 모든 Fog 로직 처리!
  final (allPositions, ringCircles) = FogController.rebuildFogWithUserLocations(
    currentPosition: currentPosition,
    homeLocation: _homeLocation,
    workLocations: _workLocations,
  );
  
  setState(() {
    _ringCircles = ringCircles;
  });
}

Future<void> _loadUserLocations() async {
  final (home, work) = await FogController.loadUserLocations();
  
  setState(() {
    _homeLocation = home;
    _workLocations = work;
  });
}
```

**라인 수: 200줄 → 20줄 (90% 감소!)**

---

## 🆕 새 화면 만들 때

### 예: 새로운 지도 화면

```dart
import 'package:flutter/material.dart';
import '../controllers/location_controller.dart';
import '../controllers/fog_controller.dart';
import '../controllers/marker_controller.dart';

class NewMapScreen extends StatefulWidget {
  @override
  State<NewMapScreen> createState() => _NewMapScreenState();
}

class _NewMapScreenState extends State<NewMapScreen> {
  LatLng? _currentPosition;
  List<MarkerModel> _markers = [];
  
  @override
  void initState() {
    super.initState();
    _init();
  }
  
  Future<void> _init() async {
    // 1. 위치 가져오기 - Controller 사용!
    final position = await LocationController.getCurrentLocation();
    if (position != null) {
      setState(() => _currentPosition = position);
    }
    
    // 2. Fog 업데이트 - Controller 사용!
    final (home, work) = await FogController.loadUserLocations();
    
    // 3. 완료!
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(/* ... */),
    );
  }
}
```

**깔끔하죠?** Controller 덕분에 새 화면이 100줄 이하!

---

## 🔧 기존 화면 개선 방법

### 단계별 Controller 적용

#### 1단계: Import 추가
```dart
// 기존 파일 맨 위에 추가
import '../controllers/location_controller.dart';
import '../controllers/fog_controller.dart';
import '../controllers/marker_controller.dart';
import '../controllers/post_controller.dart' as map_post;
```

#### 2단계: 메서드 하나씩 교체

**원칙:** 한 번에 하나씩, 테스트하면서!

```dart
// 첫 번째: _getCurrentLocation 교체
Future<void> _getCurrentLocation() async {
  final position = await LocationController.getCurrentLocation(
    isMockMode: _isMockModeEnabled,
    mockPosition: _mockPosition,
  );
  
  if (position != null) {
    setState(() => _currentPosition = position);
  }
}

// 테스트 → OK면 다음 메서드
```

#### 3단계: 점진적 확대

```dart
// 두 번째: _loadUserLocations 교체
Future<void> _loadUserLocations() async {
  final (home, work) = await FogController.loadUserLocations();
  setState(() {
    _homeLocation = home;
    _workLocations = work;
  });
}

// 세 번째: _collectPost 교체
// ...
```

#### 4단계: 결과 확인

```
✅ 원본: 4,939줄
✅ 개선 후: ~2,000줄 (60% 감소!)
✅ 기능: 100% 유지
✅ 안정성: 높음
```

---

## 📋 Controller별 사용 예제

### 🗺️ LocationController

```dart
// 현재 위치
final pos = await LocationController.getCurrentLocation();

// 주소 변환
final address = await LocationController.getAddressFromLatLng(pos);

// 거리 계산
final distance = LocationController.calculateDistance(from, to);

// 수집 가능 거리 확인
final canCollect = LocationController.isWithinCollectionRange(userPos, targetPos);

// 타일 방문 기록
await LocationController.updateTileVisit(position);

// 현재 위치 마커 생성
final marker = LocationController.createCurrentLocationMarker(position);
```

### 🌫️ FogController

```dart
// Fog of War 재구성
final (positions, circles) = FogController.rebuildFogWithUserLocations(
  currentPosition: currentPos,
  homeLocation: home,
  workLocations: workList,
);

// 사용자 위치 로드
final (home, work) = await FogController.loadUserLocations();

// 방문 기록 로드
final grayAreas = await FogController.loadVisitedLocations();

// 회색 영역 업데이트
final updated = await FogController.updateGrayAreasWithPreviousPosition(prevPos);
```

### 🎯 MarkerController

```dart
// 클러스터링 마커 생성
final clustered = MarkerController.buildClusteredMarkers(
  markers: _markers,
  visibleMarkerModels: _visibleModels,
  mapCenter: _mapCenter,
  mapZoom: _mapZoom,
  viewSize: MediaQuery.of(context).size,
  onTapSingle: (marker) => _showDetail(marker),
  onTapCluster: (cluster) => _zoomIn(cluster),
);

// 마커 수집 가능 확인
final canCollect = MarkerController.canCollectMarker(userPos, markerPos);

// 원본 마커 찾기
final original = MarkerController.findOriginalMarker(clusterMarker, _markers);
```

### 📮 PostController

```dart
// 포스트 수집
final (success, reward, msg) = await map_post.PostController.collectPost(
  postId: post.id,
  userId: user.uid,
);

// 마커에서 포스트 수집 (검증 포함)
final (success, reward, msg) = await map_post.PostController.collectPostFromMarker(
  marker: marker,
  userId: user.uid,
  currentPosition: _currentPosition!,
);
```

### 🏢 PlaceController

```dart
// 플레이스 생성
final placeId = await PlaceController.createPlace(
  creatorId: user.uid,
  name: name,
  type: type,
  address: address,
  location: location,
);

// 플레이스 수정
await PlaceController.updatePlace(
  placeId: placeId,
  name: newName,
  address: newAddress,
);

// 플레이스 조회
final place = await PlaceController.getPlace(placeId);

// 내 플레이스 목록
final places = await PlaceController.getUserPlaces(user.uid);
```

### 📊 InboxController

```dart
// 포스트 필터링
final filtered = InboxController.filterPosts(
  posts: allPosts,
  statusFilter: '배포됨',
  periodFilter: '이번 주',
);

// 포스트 정렬
final sorted = InboxController.sortPosts(
  posts: filtered,
  sortBy: '날짜',
  ascending: false,
);

// 통계 계산
final stats = InboxController.calculateStatistics(posts);
print('총 ${stats['total']}개, 배포 ${stats['deployed']}개');
```

### ⚙️ SettingsController

```dart
// 프로필 업데이트
final success = await SettingsController.updateUserProfile(
  userId: user.uid,
  displayName: newName,
  phoneNumber: newPhone,
);

// 비밀번호 변경
final changed = await SettingsController.changePassword(
  currentPassword: oldPw,
  newPassword: newPw,
);

// 로그아웃
await SettingsController.logout();
```

### 🔧 Helpers

```dart
// 포스트 생성 데이터 준비
final postData = PostCreationHelper.createPostTemplate(
  creatorId: user.uid,
  title: title,
  reward: reward,
  // ... 기타 파라미터
);

// 사용자 인증 확인
final isVerified = await PostCreationHelper.checkUserVerification(user.uid);

// 수집 기록 생성
final collectionId = await PostCollectionHelper.createCollectionRecord(
  postId: postId,
  userId: userId,
  creatorId: creatorId,
  reward: reward,
);
```

---

## 🎯 실전 적용 순서

### 1️⃣ **가장 쉬운 것부터**

```dart
// 위치 관련 메서드부터 교체 (가장 독립적)
_getCurrentLocation() → LocationController 사용
_getAddress() → LocationController 사용
_calculateDistance() → LocationController 사용
```

### 2️⃣ **다음 단계**

```dart
// Fog 관련
_loadUserLocations() → FogController 사용
_rebuildFog() → FogController 사용
```

### 3️⃣ **마지막**

```dart
// 복잡한 것들
_collectPost() → PostController 사용
_buildClusters() → MarkerController 사용
```

---

## ✅ 효과 요약

| 메서드 | Before | After | 감소율 |
|--------|--------|-------|--------|
| _getCurrentLocation | 100줄 | 15줄 | 85% ↓ |
| _collectPost | 80줄 | 30줄 | 62% ↓ |
| _collectPostFromMarker | 120줄 | 25줄 | 79% ↓ |
| _rebuildFog | 200줄 | 20줄 | 90% ↓ |
| **총계** | **500줄** | **90줄** | **82% ↓** |

---

## 🚀 지금 바로 시작!

```dart
// 1. Import 추가 (1분)
import '../controllers/location_controller.dart';

// 2. 메서드 하나 교체 (5분)
final pos = await LocationController.getCurrentLocation();

// 3. 테스트 (2분)
flutter run

// 4. 다음 메서드로! (반복)
```

**간단하죠?** 이게 Controller의 진짜 가치입니다! ✨

