# 🔍 Level 2 타일 휘발성 문제 분석

## ❌ 현재 상황: 앱 재시작 시 Level 2 초기화됨

**증상:**
- 앱 실행 중에는 Level 2 (회색 영역) 정상 표시
- 앱을 종료하고 다시 실행하면 Level 2 사라짐
- 마치 메모리에만 저장되는 것처럼 동작

---

## 🔍 근본 원인 분석

### 1. TileProvider의 초기화 로직

**파일:** `lib/features/map_system/providers/tile_provider.dart` (65-103줄)

```dart
TileProvider({TilesRepository? repository})
    : _repository = repository ?? TilesRepository() {
  _loadVisitedTiles();  // ✅ 생성자에서 호출
}

Future<void> _loadVisitedTiles() async {
  _isLoading = true;
  notifyListeners();

  try {
    // 전체 방문 타일 (Level 1)
    final allTiles = await _repository.getAllVisitedTiles();
    
    // 최근 30일 방문 타일 (Level 2) ← 여기서 로드
    final recent30Days = await _repository.getVisitedTilesLast30Days();
    
    _visitedTiles = {
      for (final tileId in allTiles) tileId: FogLevel.clear,
    };
    
    _visited30Days = recent30Days;  // ← 여기에 저장
    
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    
    debugPrint('✅ 타일 로드 완료: ${allTiles.length}개 (최근 30일: ${recent30Days.length}개)');
  } catch (e) {
    _errorMessage = '타일 로드 실패: $e';
    _isLoading = false;
    notifyListeners();
    debugPrint('❌ 타일 로드 실패: $e');  // ← 이 로그가 나오는지 확인 필요!
  }
}
```

**핵심:**
- ✅ TileProvider 생성 시 자동으로 Firebase에서 로드
- ✅ `_visited30Days` 변수에 저장
- ⚠️ 하지만 **로드가 실패하거나 호출되지 않으면** 초기화됨

---

### 2. TilesRepository 구현 확인 필요

**의존성:** `TileProvider` → `TilesRepository` → Firebase

```dart
final allTiles = await _repository.getAllVisitedTiles();
final recent30Days = await _repository.getVisitedTilesLast30Days();
```

**확인 필요:**
- `TilesRepository.getVisitedTilesLast30Days()` 구현이 올바른가?
- Firebase에서 제대로 읽어오는가?

---

### 3. 가능한 원인들

#### 원인 A: TileProvider가 초기화되지 않음 🔴
```dart
// MapScreen에서 TileProvider를 사용하는가?
Consumer<TileProvider>(
  builder: (context, tileProvider, _) {
    // tileProvider.visited30Days 사용
  },
)
```

**확인 필요:**
- MapScreen에서 실제로 `TileProvider`를 Consumer로 사용하는가?
- Provider가 앱 시작 시 생성되는가?

#### 원인 B: TilesRepository 로직 오류 🔴
```dart
// getVisitedTilesLast30Days() 구현이 잘못됨
Future<Set<String>> getVisitedTilesLast30Days() async {
  // ❌ 빈 Set 반환?
  // ❌ 쿼리 조건이 잘못됨?
  // ❌ 필드명이 다름? (lastVisitTime vs timestamp)
}
```

#### 원인 C: Provider 초기화 타이밍 🟡
```dart
// TileProvider 생성자 호출 → _loadVisitedTiles()
// 하지만 Firebase 인증 전에 호출되어 user == null?
```

#### 원인 D: 메모리 캐시만 사용 🔴
```dart
// Optimistic update (290줄)
_visited30Days.addAll(oldLevel1Tiles);  // ← 메모리에만 추가
// Firebase 저장은 upsertVisitedTiles()에서 함
```

**하지만:**
```dart
await VisitTileService.upsertVisitedTiles(...);  // ← Firebase에 저장
```

**의문:**
- Firebase에 저장은 되는데 로드가 안 되는 건가?

---

## 🔬 디버깅 방법

### 1. TileProvider 초기화 로그 확인

**현재 로그에 나와야 할 것:**
```
✅ 타일 로드 완료: X개 (최근 30일: Y개)
```

**나오지 않으면:**
```
❌ 타일 로드 실패: [에러 메시지]
```

### 2. Firebase Console 확인

**경로:** `users/{uid}/visited_tiles`

**확인 사항:**
- 타일 ID가 실제로 저장되어 있는가?
- `lastVisitTime` 필드가 있는가?
- 30일 이내 데이터인가?

### 3. TilesRepository 구현 확인

**파일:** `lib/core/repositories/tiles_repository.dart`

**확인 필요:**
```dart
Future<Set<String>> getVisitedTilesLast30Days() async {
  // 이 함수가 제대로 구현되어 있는가?
}
```

---

## 🎯 예상되는 문제와 해결책

### 시나리오 1: TileProvider가 생성 안 됨

**문제:**
```dart
// main.dart 또는 app.dart에서
MultiProvider(
  providers: [
    // ❌ TileProvider()가 없음!
  ],
)
```

**해결:**
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => TileProvider()),  // ✅ 추가
  ],
)
```

---

### 시나리오 2: TilesRepository가 빈 데이터 반환

**문제:**
```dart
Future<Set<String>> getVisitedTilesLast30Days() async {
  return {};  // ❌ 항상 빈 Set 반환
}
```

**해결:**
```dart
Future<Set<String>> getVisitedTilesLast30Days() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};

  final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
  
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('visited_tiles')
      .where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
      .get();

  return snapshot.docs.map((doc) => doc.id).toSet();
}
```

---

### 시나리오 3: 필드명 불일치

**문제:**
```dart
// 저장 시
'lastVisitTime': FieldValue.serverTimestamp()  // ✅

// 로드 시
.where('timestamp', isGreaterThan: ...)  // ❌ 다른 필드명!
```

**해결:**
```dart
// 필드명 통일
.where('lastVisitTime', isGreaterThanOrEqualTo: ...)  // ✅
```

---

### 시나리오 4: Provider 초기화 타이밍

**문제:**
```dart
// TileProvider 생성자 호출
TileProvider() {
  _loadVisitedTiles();  // ← 이때 user == null?
}
```

**해결:**
```dart
// 앱 초기화 순서 확인
1. Firebase.initializeApp()  ✅
2. FirebaseAuth 자동 로그인  ⏱️ (시간 걸림)
3. TileProvider 생성  ⚠️ (user null 가능)
```

**수정 방법:**
```dart
// MapScreen initState에서 명시적으로 새로고침
@override
void initState() {
  super.initState();
  
  // 로그인 확인 후 타일 로드
  final tileProvider = context.read<TileProvider>();
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      tileProvider.refreshVisited30Days();  // ✅ 명시적 새로고침
    }
  });
}
```

---

## 🧪 즉시 테스트 방법

### 1. 로그 확인 (가장 중요!)

**앱 시작 직후 로그에서 찾아야 할 것:**
```
✅ 타일 로드 완료: X개 (최근 30일: Y개)
```

**만약 이 로그가 없다면:**
- TileProvider가 생성되지 않았거나
- _loadVisitedTiles()가 호출되지 않음

**만약 Y=0이라면:**
- Repository가 빈 데이터 반환
- 또는 Firebase 쿼리 조건 오류

### 2. Firebase Console 확인

```
Firestore Database
└── users
    └── {your-uid}
        └── visited_tiles
            ├── tile_37566_126978
            │   ├── tileId: "tile_37566_126978"
            │   ├── lastVisitTime: [Timestamp]
            │   └── visitCount: 1
            └── tile_37567_126979
                └── ...
```

**확인:**
- 타일 문서가 실제로 존재하는가?
- `lastVisitTime` 필드가 있는가?

### 3. TileProvider 강제 새로고침 추가

**임시 테스트 코드:**
```dart
// MapScreen initState()
@override
void initState() {
  super.initState();
  
  // 5초 후 강제 새로고침
  Future.delayed(Duration(seconds: 5), () {
    final tileProvider = context.read<TileProvider>();
    tileProvider.refreshVisited30Days();
    debugPrint('🔄 TileProvider 강제 새로고침');
  });
}
```

---

## 💡 가장 가능성 높은 원인

### ⚠️ TilesRepository.getVisitedTilesLast30Days() 미구현

```dart
// TilesRepository에서 이 함수가:
Future<Set<String>> getVisitedTilesLast30Days() async {
  // TODO: 구현 필요
  return {};  // ← 빈 Set 반환!
}
```

**증거:**
- `TileProvider._loadVisitedTiles()`는 호출됨
- 하지만 `_visited30Days`가 비어있음
- Repository에서 데이터를 못 가져옴

---

## 🔧 다음 조치사항

1. **TilesRepository 확인** (최우선)
   - `lib/core/repositories/tiles_repository.dart` 파일 열기
   - `getVisitedTilesLast30Days()` 구현 확인

2. **로그 추가**
   - TileProvider 초기화 시 상세 로그
   - Repository 쿼리 결과 로그

3. **Provider 등록 확인**
   - main.dart 또는 app.dart에서 TileProvider 등록 확인

**지금 바로 확인해야 할 것:**
→ `lib/core/repositories/tiles_repository.dart` 파일 내용

