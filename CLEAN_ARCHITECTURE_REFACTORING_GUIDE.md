# 🏗️ Clean Architecture 리팩토링 가이드

## 📌 개요

프로젝트를 **Clean Architecture** 원칙에 맞게 리팩토링했습니다.

### 핵심 원칙

```
Widget → Provider → Service/Repository → DataSource
```

- **Provider**: "상태 + 얇은 액션"만
- **Repository**: Firebase/DB와의 통신만
- **Service**: 비즈니스 로직 (클러스터링, 계산, 필터링)
- **Widget**: Provider만 의존, Firebase 몰라야 함

---

## 📁 새로운 폴더 구조

```
lib/
  ├── core/
  │   ├── repositories/           # ✨ 새로 추가
  │   │   ├── markers_repository.dart
  │   │   ├── posts_repository.dart
  │   │   └── tiles_repository.dart
  │   │
  │   ├── datasources/            # ✨ 새로 추가 (향후 확장용)
  │   │   ├── firebase/
  │   │   └── local/
  │   │
  │   ├── models/
  │   ├── services/
  │   └── constants/
  │
  ├── features/
  │   ├── map_system/
  │   │   ├── providers/          # ✨ 강화됨
  │   │   │   ├── map_view_provider.dart      # 지도 뷰 상태
  │   │   │   ├── marker_provider.dart        # 마커 상태
  │   │   │   ├── tile_provider.dart          # Fog of War 상태
  │   │   │   └── map_filter_provider.dart    # 필터 상태 (기존)
  │   │   │
  │   │   ├── services/
  │   │   │   └── clustering/     # ✨ 새로 추가
  │   │   │       └── marker_clustering_service.dart
  │   │   │
  │   │   ├── widgets/
  │   │   └── screens/
  │   │
  │   └── post_system/
  │       └── providers/          # ✨ 새로 추가
  │           └── post_provider.dart
```

---

## 🎯 구현된 Provider & Repository

### 1. MapViewProvider

**책임**: 카메라 위치/줌, 선택된 마커, Bounds만 관리

```dart
class MapViewProvider with ChangeNotifier {
  LatLng _center;
  double _zoom;
  LatLngBounds? _bounds;
  String? _selectedMarkerId;
  
  // 얇은 액션만
  void moveCamera(LatLng newCenter, {double? newZoom});
  void selectMarker(String? markerId);
  void setBounds(LatLngBounds newBounds);
}
```

**금지사항**: ❌ Firebase 호출, ❌ 복잡한 로직

---

### 2. MarkerProvider + MarkersRepository

#### MarkerProvider (상태 관리)

```dart
class MarkerProvider with ChangeNotifier {
  final MarkersRepository _repository;
  
  List<MarkerModel> _rawMarkers = [];
  List<ClusterOrMarker> _clusters = [];
  bool _isLoading = false;
  
  // 얇은 액션
  Future<void> refreshVisibleMarkers({
    required LatLngBounds bounds,
    required UserType userType,
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
  }) async {
    // Repository에서 데이터 가져오기
    _markersSubscription = _repository
        .streamByBounds(bounds, userType)
        .listen((markers) {
          _rawMarkers = markers;
          
          // Service에서 클러스터링
          _clusters = MarkerClusteringService.performClustering(...);
          notifyListeners();
        });
  }
}
```

#### MarkersRepository (데이터 통신)

```dart
class MarkersRepository {
  final FirebaseFirestore _firestore;
  
  // 순수 데이터 조회만
  Stream<List<MarkerModel>> streamByBounds(
    LatLngBounds bounds,
    UserType userType,
  ) {
    // Firebase 쿼리
    return _firestore.collection('markers')
        .where('tileId', whereIn: tileIds)
        .snapshots()
        .map(...);
  }
  
  Future<bool> deleteMarker(String markerId);
  Future<bool> decreaseQuantity(String markerId, int amount);
}
```

#### MarkerClusteringService (비즈니스 로직)

```dart
class MarkerClusteringService {
  // 순수 계산 로직만
  static List<ClusterOrMarker> performClustering({
    required List<MarkerModel> markers,
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
  }) {
    // 클러스터링 알고리즘
    return buildProximityClusters(...);
  }
}
```

---

### 3. TileProvider + TilesRepository

#### TileProvider (Fog of War 상태)

```dart
class TileProvider with ChangeNotifier {
  final TilesRepository _repository;
  
  Map<String, FogLevel> _visitedTiles = {};
  Set<String> _visited30Days = {};
  
  Future<String> updateVisit(LatLng position) async {
    final tileId = TileUtils.getKm1TileId(...);
    await _repository.updateVisit(tileId);
    
    _visitedTiles[tileId] = FogLevel.level1;
    notifyListeners();
    return tileId;
  }
}
```

#### TilesRepository (타일 데이터)

```dart
class TilesRepository {
  Future<bool> updateVisit(String tileId);
  Future<Set<String>> getVisitedTilesLast30Days();
  Future<void> batchUpdateVisits(List<String> tileIds);
  Future<int> evictOldTiles(); // 90일 이상 정리
}
```

---

### 4. PostProvider + PostsRepository

#### PostProvider (포스트 상태)

```dart
class PostProvider with ChangeNotifier {
  final PostsRepository _repository;
  
  List<PostModel> _posts = [];
  PostModel? _selectedPost;
  
  void streamPosts({String? userId}) {
    _postsSubscription = _repository
        .streamPosts(userId: userId)
        .listen((posts) {
          _posts = posts;
          notifyListeners();
        });
  }
  
  Future<bool> collectPost({
    required String markerId,
    required String userId,
    int? rewardPoints,
  });
  
  Future<bool> confirmPost({
    required String markerId,
    required String collectionId,
  });
}
```

#### PostsRepository (포스트 데이터)

```dart
class PostsRepository {
  Stream<List<PostModel>> streamPosts({String? userId});
  Future<String> createPost(PostModel post);
  
  // 트랜잭션 처리
  Future<bool> collectPost({
    required String markerId,
    required String userId,
    int? rewardPoints,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. 마커 수량 감소
      // 2. 수령 기록 생성
      // 3. 포인트 이동
    });
  }
}
```

---

## 🔄 사용 예시

### Widget에서 Provider 사용

```dart
class MapScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapViewProvider()),
        ChangeNotifierProvider(create: (_) => MarkerProvider()),
        ChangeNotifierProvider(create: (_) => TileProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => MapFilterProvider()),
      ],
      child: _MapScreenContent(),
    );
  }
}

class _MapScreenContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ✅ Provider만 의존
    final mapView = context.watch<MapViewProvider>();
    final markers = context.watch<MarkerProvider>();
    final filters = context.watch<MapFilterProvider>();
    
    return Stack(
      children: [
        // 지도
        FlutterMap(
          options: MapOptions(
            initialCenter: mapView.center,
            initialZoom: mapView.zoom,
            onMapEvent: (event) {
              // ✅ 얇은 액션만 호출
              mapView.updateMapState(
                event.camera.center,
                event.camera.zoom,
              );
              
              // ✅ Repository/Service는 Provider 내부에서 호출
              markers.recluster(
                mapCenter: event.camera.center,
                zoom: event.camera.zoom,
                viewSize: MediaQuery.of(context).size,
              );
            },
          ),
          children: [
            TileLayer(...),
            
            // ✅ Provider에서 마커 위젯 생성
            MarkerLayer(
              markers: markers.buildMarkerWidgets(
                mapCenter: mapView.center,
                zoom: mapView.zoom,
                viewSize: MediaQuery.of(context).size,
                onTapSingle: (marker) {
                  mapView.selectMarker(marker.markerId);
                },
                onTapCluster: (clusterMarkers) {
                  // 클러스터 확대
                  final zoom = MarkerClusteringService
                      .calculateClusterZoomTarget(mapView.zoom);
                  mapView.setZoom(zoom);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## ⚡ 성능 최적화

### 1. 디바운스 (Debounce)

```dart
class MapViewProvider with ChangeNotifier {
  Timer? _debounceTimer;
  
  void onMapMoved(LatLng center, double zoom) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(milliseconds: 300),
      () {
        updateMapState(center, zoom);
        // 마커 새로고침은 여기서
      },
    );
  }
}
```

### 2. 스로틀 (Throttle)

```dart
class MarkerProvider with ChangeNotifier {
  DateTime? _lastClusterTime;
  
  void recluster({...}) {
    final now = DateTime.now();
    if (_lastClusterTime != null) {
      final diff = now.difference(_lastClusterTime!);
      if (diff.inMilliseconds < 100) return; // 100ms 스로틀
    }
    
    _lastClusterTime = now;
    _performClustering();
  }
}
```

### 3. 캐시

```dart
class MarkersRepository {
  final Map<String, List<MarkerModel>> _cache = {};
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);
  
  Stream<List<MarkerModel>> streamByBounds(...) {
    final cacheKey = _buildCacheKey(bounds);
    
    // 캐시 확인
    if (_cache.containsKey(cacheKey) && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return Stream.value(_cache[cacheKey]!);
    }
    
    // Firebase 조회
    return _firestore.collection('markers')...;
  }
}
```

---

## ✅ 체크리스트

### Provider 작성 시

- [ ] 상태 변수만 갖고 있는가?
- [ ] 액션 메서드는 얇은가? (3~10줄)
- [ ] Firebase를 직접 호출하지 않는가?
- [ ] Repository/Service를 주입받아 사용하는가?
- [ ] dispose()에서 리스너 해제하는가?

### Repository 작성 시

- [ ] Firebase/DB 호출만 담당하는가?
- [ ] UI 관련 코드가 없는가? (Flutter import 없음)
- [ ] 비즈니스 로직이 없는가?
- [ ] 트랜잭션 처리를 명확히 했는가?

### Service 작성 시

- [ ] 순수 계산 로직만 있는가?
- [ ] static 메서드로 작성했는가?
- [ ] Firebase/UI 의존성이 없는가?

---

## 🚀 다음 단계

### TODO #9: MapScreen 마이그레이션

기존 `MapScreen`을 새 Provider 구조로 전환:

1. `MultiProvider`로 모든 Provider 주입
2. Widget에서 `context.watch/read` 사용
3. Firebase 호출 제거, Provider 액션만 사용

### TODO #10: 최적화

1. **디바운스**: 지도 이동 이벤트 (300ms)
2. **스로틀**: 클러스터링 (100ms)
3. **캐시**: 마커 조회 (5분 TTL)
4. **메모리**: `unmodifiableList` 사용
5. **오프라인**: 캐시 우선 표시

---

## 📚 참고 자료

### 계층별 책임

| 계층 | 책임 | 금지 |
|------|------|------|
| **Widget** | UI 렌더링, Provider 구독 | Firebase 호출, 비즈니스 로직 |
| **Provider** | 상태 관리, 얇은 액션 | Firebase 호출, 복잡한 로직 |
| **Service** | 비즈니스 로직, 계산 | Firebase 호출, UI 의존 |
| **Repository** | 데이터 CRUD, 트랜잭션 | UI 의존, 비즈니스 로직 |
| **DataSource** | Firebase/Local IO | 모든 상위 레이어 |

### 데이터 흐름

```
사용자 액션
    ↓
Widget (onTap)
    ↓
Provider.action()
    ↓
Repository.fetchData() / Service.calculate()
    ↓
Provider.setState()
    ↓
Widget rebuild
```

---

## 🎉 완료!

이제 프로젝트는 Clean Architecture 원칙을 따릅니다:

✅ **Provider**: 상태 + 얇은 액션만  
✅ **Repository**: Firebase와 완전 분리  
✅ **Service**: 순수 비즈니스 로직  
✅ **Widget**: Provider만 의존

**유지보수성 ↑, 테스트 용이성 ↑, 확장성 ↑**

