# 🔄 Map Screen 리팩토링 가이드

## 📊 현재 상황

| 파일 | 라인 수 | 상태 |
|------|---------|------|
| map_screen.dart (원본) | 4,939줄 | ❌ 너무 큼 |
| map_screen_refactored.dart (신규) | 642줄 | ✅ Controller 사용 |

**감소율**: 87% (4,939줄 → 642줄)

---

## 🎯 리팩토링 방법 선택

### Option 1: Part 파일 분할 (안전 ⭐⭐⭐)

**장점:**
- ✅ 기존 코드 유지하면서 분할
- ✅ State 공유 가능
- ✅ 점진적 마이그레이션 가능

**단점:**
- ⚠️ Part 파일 관리 필요
- ⚠️ 여전히 큰 코드베이스

**구조:**
```
screens/
├── map_screen.dart (메인, 200줄)
├── map_screen_fog.dart (part, 500줄)
├── map_screen_markers.dart (part, 800줄)
├── map_screen_posts.dart (part, 1000줄)
└── map_screen_ui.dart (part, 1500줄)
```

### Option 2: 완전 교체 (위험 ⚠️⚠️⚠️)

**장점:**
- ✅ 완전히 새로운 깔끔한 코드
- ✅ Controller 100% 활용
- ✅ 최소 라인 수

**단점:**
- ❌ 기존 기능 누락 위험
- ❌ 앱이 깨질 수 있음
- ❌ 대량 테스트 필요

**방법:**
```bash
# 백업
mv map_screen.dart map_screen_backup.dart

# 교체
mv map_screen_refactored.dart map_screen.dart
```

### Option 3: 점진적 마이그레이션 (추천 ⭐⭐)

**방법:**
1. 원본 유지
2. 새 파일로 기능 하나씩 이동
3. 테스트 후 원본 삭제

---

## 💡 추천 방식: Part 파일 분할

가장 안전하고 효과적인 방법입니다!

### 단계:

1. **원본 map_screen.dart 수정**
```dart
// 파일 맨 위에 추가
part 'map_screen_fog.dart';
part 'map_screen_markers.dart';
part 'map_screen_posts.dart';
part 'map_screen_ui.dart';
```

2. **Fog 관련 메서드 이동**
- `map_screen_fog.dart`로 이동
- 원본에서 삭제

3. **Marker 관련 메서드 이동**
- `map_screen_markers.dart`로 이동
- 원본에서 삭제

4. **결과**
- map_screen.dart: 500줄 이하
- Part 파일들: 각 500-800줄
- 총합은 같지만 **파일을 찾기 쉬움**!

---

## 🚀 즉시 적용 가능한 개선

원본을 건드리지 않고 **당장 사용 가능**한 방법:

```dart
// 기존 map_screen.dart에서
import '../controllers/location_controller.dart';

// 기존 메서드를 이렇게 간단히 교체
Future<void> _getCurrentLocation() async {
  final position = await LocationController.getCurrentLocation(
    isMockMode: _isMockModeEnabled,
    mockPosition: _mockPosition,
  );
  
  if (position != null) {
    setState(() => _currentPosition = position);
    // 나머지 로직...
  }
}
```

이렇게 메서드 내부만 교체하면:
- ✅ 안전함
- ✅ 점진적 개선
- ✅ 라인 수 감소

---

## ✅ 다음 단계

어떤 방식으로 진행하시겠어요?

1. **Part 파일 분할** - 안전하지만 시간 소요
2. **완전 교체** - 빠르지만 위험
3. **점진적 개선** - 안전하고 실용적


