# PlaceStatistics 타입 캐스팅 오류 수정

## 오류 내용
```
❌ getPerformanceAnalytics 오류: TypeError: Instance of 'JSArray<dynamic>':
type 'List<dynamic>' is not a subtype of type 'List<Map<String, dynamic>>'
```

## 원인
`place_statistics_service.dart`의 `getPerformanceAnalytics()` 메서드에서 Firestore 데이터를 직접 `List<Map<String, dynamic>>`으로 캐스팅하려고 시도했기 때문입니다.

Firestore에서 가져온 데이터는 `List<dynamic>` 타입이며, 이를 직접 `List<Map<String, dynamic>>`으로 캐스팅할 수 없습니다.

## 수정 내용

### 파일: `lib/core/services/data/place_statistics_service.dart`

**수정 전 (라인 287)**:
```dart
final postStats = stats['postStatistics'] as List<Map<String, dynamic>>;
```

**수정 후 (라인 287-288)**:
```dart
final postStatsRaw = stats['postStatistics'] as List<dynamic>;
final postStats = postStatsRaw.map((e) => e as Map<String, dynamic>).toList();
```

## 수정 방법

1. **1단계**: `List<dynamic>`으로 먼저 캐스팅
   ```dart
   final postStatsRaw = stats['postStatistics'] as List<dynamic>;
   ```

2. **2단계**: `.map()`을 사용하여 각 요소를 `Map<String, dynamic>`으로 변환
   ```dart
   final postStats = postStatsRaw.map((e) => e as Map<String, dynamic>).toList();
   ```

## 테스트 결과

```bash
flutter analyze lib/core/services/data/place_statistics_service.dart
```

**결과**: ✅ 에러 없음 (기존 info 메시지만 존재)

## 수정 일시
2025-10-09

## 영향 범위
- `getPerformanceAnalytics()` 메서드만 수정
- 플레이스 통계 화면에서 성과 분석 탭을 볼 때 발생하던 오류 해결

## 추가 확인 사항
다른 서비스 파일들에서 동일한 패턴 검색 결과, 유사한 타입 캐스팅 오류는 발견되지 않았습니다.
