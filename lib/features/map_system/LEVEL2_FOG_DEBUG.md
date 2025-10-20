# 🌫️ Level 2 Fog (회색 영역) 펀칭 문제 해결

## 🔍 현재 상황

로그 분석:
```
🎯 Level 2 중심점: 3개 (visited30Days: 3개)
L2: center=LatLng(latitude:36.006157, longitude:121.915965), screen=Offset(-54720.1, 20269.3)
L2: center=LatLng(latitude:35.90648, longitude:121.668875), screen=Offset(-57598.9, 21704.0)
L2: center=LatLng(latitude:35.972896, longitude:121.964057), screen=Offset(-54159.8, 20748.2)

현재 위치: 37.374056, 126.641766 (서울 인천)
Level 2 위치: 36.00°, 121.91° (중국 산둥성!)
거리: 약 450km
```

## ❌ 문제점

### 1. 타일 데이터가 잘못 저장됨
- **visited_tiles**에 중국 좌표가 저장되어 있음
- 실제 방문한 곳이 아닌 잘못된 타일 ID

### 2. 거리 필터링으로 모두 제외됨
```dart
if (distance <= 50000) {  // 50km
  level2Centers.add(center);
} else {
  filteredCount++;  // ← 중국 타일들 모두 여기서 제외됨
}
```
결과: **level2Centers = [] (빈 배열)**

### 3. 빈 배열로 인해 펀칭 안 됨
```dart
if (level2Centers.isNotEmpty) {  // ← false
  final grayMinusL1 = ...;       // ← 실행 안 됨
  canvas.drawPath(grayMinusL1, grayPaint);
}
```

## 🔧 즉시 해결 방안

### Option 1: 거리 제한 늘리기 (임시)
```dart
// 50km → 1000km로 확대
if (distance <= 1000000) {  // 1000km
  level2Centers.add(center);
}
```
→ **중국 타일도 표시되지만 펀칭은 됨**

### Option 2: 타일 데이터 정리 (권장)
```dart
// 잘못된 타일 데이터 삭제
Future<void> cleanupInvalidTiles() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  
  final visitedTiles = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('visited_tiles')
      .get();
  
  for (final doc in visitedTiles.docs) {
    final tileId = doc.id;
    final center = TileUtils.getKm1TileCenter(tileId);
    
    // 한국 영역 체크 (위도 33-39, 경도 124-132)
    if (center.latitude < 33 || center.latitude > 39 ||
        center.longitude < 124 || center.longitude > 132) {
      debugPrint('🗑️ 잘못된 타일 삭제: $tileId ($center)');
      await doc.reference.delete();
    }
  }
}
```

### Option 3: 타일 검증 강화
```dart
// TileUtils.getKm1TileCenter()에서 검증
static LatLng getKm1TileCenter(String tileId) {
  final parts = tileId.split('_');
  final lat = double.parse(parts[0]);
  final lng = double.parse(parts[1]);
  
  // ✅ 한국 영역 검증
  if (lat < 33 || lat > 39 || lng < 124 || lng > 132) {
    throw Exception('Invalid tile: $tileId outside Korea bounds');
  }
  
  return LatLng(lat, lng);
}
```

## 🎯 권장 해결 순서

### 1단계: 임시 거리 제한 해제 (바로 테스트)
```dart
// 거리 필터 일시적으로 비활성화
if (_state.currentPosition != null) {
  final distance = _calculateDistance(_state.currentPosition!, center);
  debugPrint('  타일 거리: ${(distance/1000).toStringAsFixed(1)}km');
  // if (distance <= 50000) {  // ← 주석 처리
    level2Centers.add(center);
  // }
}
```
→ **이렇게 하면 Level 2 펀칭이 작동하는지 확인 가능**

### 2단계: 타일 데이터 확인
```dart
// visited_tiles 컬렉션 확인
debugPrint('📋 Visited Tiles:');
for (final tileId in tileProvider.visited30Days) {
  debugPrint('  - $tileId');
  final center = TileUtils.getKm1TileCenter(tileId);
  debugPrint('    → ${center.latitude}, ${center.longitude}');
}
```

### 3단계: 잘못된 데이터 정리
- Firebase Console에서 `visited_tiles` 확인
- 잘못된 타일 ID 삭제
- 또는 `cleanupInvalidTiles()` 함수 실행

## 🧪 테스트 방법

### 1. 거리 필터 비활성화하여 테스트
```dart
// 모든 Level 2 타일 표시 (거리 무관)
level2Centers.add(center);  // 필터링 없이
```

**예상 결과:**
- ✅ 회색 영역이 보임 (중국에도)
- ✅ 펀칭 작동 확인
- ⚠️ 화면 밖 타일도 렌더링 (성능 저하 가능)

### 2. 타일 ID 로그 확인
```dart
debugPrint('📋 원본 타일 ID: ${tileProvider.visited30Days}');
```

**체크 포인트:**
- 타일 ID 형식이 맞는지
- 좌표 변환이 정확한지
- 한국 영역 내 좌표인지

### 3. 수동으로 Level 2 추가 (테스트용)
```dart
// 현재 위치 근처에 테스트 Level 2 추가
final testLevel2 = LatLng(
  _state.currentPosition!.latitude + 0.01,  // 약 1km 북쪽
  _state.currentPosition!.longitude + 0.01, // 약 1km 동쪽
);
level2Centers.add(testLevel2);
```

**예상 결과:**
- ✅ 회색 원형 영역 표시
- ✅ Level 1과 겹치는 부분은 밝게 유지

## 💡 빠른 해결책 (지금 바로 적용)

```dart
// lib/features/map_system/screens/map_screen.dart

// 1. 거리 제한 일시 해제
final distance = _calculateDistance(_state.currentPosition!, center);
debugPrint('  타일 거리: ${(distance/1000).toStringAsFixed(1)}km');
level2Centers.add(center);  // ← 필터링 없이 모두 추가

// 2. 또는 거리 제한 대폭 완화
if (distance <= 500000) {  // 500km (한반도 전체 커버)
  level2Centers.add(center);
}
```

## 🔍 근본 원인 찾기

### 타일 ID가 잘못 생성되는 경우

```dart
// 타일 ID 생성 시 검증 추가
static String getKm1TileId(double lat, double lng) {
  // ✅ 입력값 검증
  if (lat < -90 || lat > 90) {
    throw ArgumentError('Invalid latitude: $lat');
  }
  if (lng < -180 || lng > 180) {
    throw ArgumentError('Invalid longitude: $lng');
  }
  
  final latInt = (lat * 1000).round();
  final lngInt = (lng * 1000).round();
  final tileId = '${latInt}_$lngInt';
  
  debugPrint('🔢 타일 ID 생성: ($lat, $lng) → $tileId');
  
  return tileId;
}
```

### 타일 ID → 좌표 변환 검증

```dart
// 양방향 변환 테스트
final originalLat = 37.5665;
final originalLng = 126.9780;

final tileId = TileUtils.getKm1TileId(originalLat, originalLng);
final center = TileUtils.getKm1TileCenter(tileId);

debugPrint('원본: $originalLat, $originalLng');
debugPrint('타일: $tileId');
debugPrint('복원: ${center.latitude}, ${center.longitude}');
debugPrint('오차: ${(originalLat - center.latitude).abs()}, ${(originalLng - center.longitude).abs()}');
```

---

## 📝 다음 조치사항

1. ✅ **거리 필터 비활성화** 또는 **500km로 확대**
2. 🔍 **로그 확인**: Level 2 좌표가 한국 내인지 확인
3. 🧹 **데이터 정리**: 잘못된 타일 삭제
4. 🛡️ **타일 검증**: 생성/변환 시 유효성 체크

**지금 바로 테스트**: 거리 필터를 제거하고 실행해보세요!

