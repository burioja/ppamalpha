# 맵 스크린 마커 표시 문제 디버깅 가이드

## 문제 증상
맵 스크린에서 다른 사용자가 배포한 포스트(마커)가 보이지 않는 경우

## 1단계: 디버깅 로그 확인

앱을 실행하고 맵 화면으로 이동하면 콘솔에 다음과 같은 로그가 출력됩니다:

```
🔵🔵🔵 ========== getMarkers() 시작 ========== 🔵🔵🔵
🔵 사용자 UID: [현재 사용자 ID]
🔵 중심 위치: [위도], [경도]
🔵 검색 반경: [반경]km
🔵 적용된 필터: {...}
🔵 myPostsOnly: [true/false]
🔵 showCouponsOnly: [true/false]
🔵 minReward: [최소 리워드]
🔵 showUrgentOnly: [true/false]

🔵 Firebase 쿼리 결과: [X]개 마커

📊 ========== 필터링 결과 요약 ========== 📊
📊 총 쿼리된 마커: [X]개
📊 제외된 마커:
   - 회수됨 (RECALLED): [X]개
   - 수량 소진: [X]개
   - 위치 정보 없음: [X]개
   - 이미 수령함: [X]개
   - 거리 범위 밖: [X]개
   - 포그 레벨 필터링: [X]개
📊 최종 반환 마커: [X]개
🔵🔵🔵 ========== getMarkers() 종료 ========== 🔵🔵🔵
```

## 2단계: 로그 분석

### A. 필터 설정 확인
- `myPostsOnly: true` → **문제!** 내 포스트만 보기가 활성화됨
  - **해결책**: 맵 화면의 필터 버튼에서 "내 포스트만" 필터를 끄세요

- `minReward: [큰 값]` → 최소 리워드 필터가 너무 높게 설정됨
  - **해결책**: 최소 리워드를 0원 또는 낮은 값으로 설정

### B. Firebase 쿼리 결과 확인
- `Firebase 쿼리 결과: 0개` → 서버에 활성 마커가 없거나 만료됨
  - **원인**:
    1. 실제로 다른 사용자가 배포한 포스트가 없음
    2. 모든 마커가 만료됨 (`expiresAt` < 현재시간)
    3. 모든 마커가 비활성화됨 (`isActive: false`)
  - **해결책**: 3단계 Firebase 데이터 확인

### C. 필터링 단계별 분석
1. **회수됨 (RECALLED)**: 포스트 생성자가 회수한 마커
   - 정상: 회수된 마커는 보이지 않아야 함

2. **수량 소진**: `remainingQuantity = 0`인 마커
   - 정상: 모든 수량이 소진된 마커는 보이지 않아야 함

3. **위치 정보 없음**: `location` 필드가 null
   - **문제!** 마커 생성 시 위치 정보가 누락됨
   - **해결책**: 마커 생성 로직 확인 필요

4. **이미 수령함**: 현재 사용자가 이미 수령한 마커
   - 정상: 한 번 수령한 마커는 다시 보이지 않음
   - **확인**: 다른 계정으로 로그인하면 보일 수 있음

5. **거리 범위 밖**: 설정된 반경 밖에 있는 마커
   - 정상: 검색 반경을 벗어난 마커는 보이지 않음
   - **해결책**: 검색 반경을 늘리거나 (유료 회원: 3km) 해당 위치로 이동

6. **포그 레벨 필터링**: 방문하지 않은 영역의 마커
   - **정상 동작**: 포그 오브 워 시스템
   - 1km 이내: 항상 표시
   - 1km 이상: 방문한 타일(FogLevel 1)만 표시
   - **해결책**: 해당 영역을 방문하여 포그를 제거

## 3단계: Firebase 데이터 확인

Firebase Console에서 `markers` 컬렉션을 확인:

### 확인 항목:
1. **마커 존재 여부**
   - 다른 사용자가 생성한 마커가 실제로 존재하는가?
   - `creatorId`가 현재 사용자와 다른 마커가 있는가?

2. **마커 활성 상태**
   ```
   isActive: true  ✅
   isActive: false ❌ (비활성화됨)
   ```

3. **마커 상태**
   ```
   status: null (또는 없음) ✅
   status: "ACTIVE"          ✅
   status: "RECALLED"        ❌ (회수됨)
   status: "COLLECTED"       ❌ (수령됨)
   ```

4. **만료 시간**
   ```
   expiresAt: [미래 시간] ✅
   expiresAt: [과거 시간] ❌ (만료됨)
   ```

5. **수량**
   ```
   remainingQuantity: 1 이상 ✅
   remainingQuantity: 0      ❌ (수량 소진)
   ```

6. **위치 정보**
   ```
   location: GeoPoint(위도, 경도) ✅
   location: null                ❌ (위치 없음)
   ```

7. **수령 목록**
   ```
   collectedBy: []                    ✅ (아무도 수령 안 함)
   collectedBy: ["다른사용자ID"]       ✅ (다른 사람만 수령)
   collectedBy: ["내ID"]              ❌ (내가 이미 수령)
   ```

## 4단계: 일반적인 해결 방법

### 해결책 1: 필터 초기화
맵 화면의 필터 버튼 → "필터 초기화" 클릭

### 해결책 2: 검색 반경 확대
- 무료 회원: 1km → 유료 회원 가입 (3km)
- 또는 마커가 있는 위치로 이동

### 해결책 3: 포그 오브 워 해제
- 해당 영역을 실제로 방문 (1km 이내로 접근)
- 또는 개발 환경에서 포그 레벨 필터링 임시 비활성화:
  ```dart
  // marker_service.dart의 getMarkers 메서드에서
  if (!shouldShow) {
    // 이 부분을 주석 처리하면 포그 필터링 비활성화
    // final fogLevel1Tiles = await _getFogLevel1Tiles(location, radiusInKm);
    // if (!fogLevel1Tiles.contains(tileId)) {
    //   fogLevelFilteredCount++;
    //   continue;
    // }
  }
  ```

### 해결책 4: 다른 사용자 계정으로 테스트
- 이미 수령한 마커는 보이지 않으므로
- 다른 계정으로 로그인하거나
- 새 마커를 생성하여 테스트

### 해결책 5: 테스트 마커 생성
다른 계정에서 테스트 마커를 생성:
1. 현재 위치에서 1km 이내에 생성
2. 만료 시간을 충분히 길게 설정 (예: 7일)
3. 수량을 충분히 많이 설정 (예: 100개)

## 5단계: 개발자 도구

### 포그 레벨 확인
```dart
// VisitTileService를 사용하여 현재 포그 레벨 확인
final tiles = await VisitTileService.getFogLevel1TileIdsCached();
print('방문한 타일 (FogLevel 1): ${tiles.length}개');
```

### 마커 직접 조회 (테스트용)
```dart
// 포그 필터링 없이 모든 마커 조회
final snapshot = await FirebaseFirestore.instance
    .collection('markers')
    .where('isActive', isEqualTo: true)
    .where('expiresAt', isGreaterThan: Timestamp.now())
    .get();

print('전체 활성 마커: ${snapshot.docs.length}개');
```

## 문의 사항
문제가 지속되면 다음 정보를 포함하여 문의:
1. 디버깅 로그 전체 내용
2. Firebase 콘솔 스크린샷 (markers 컬렉션)
3. 사용자 UID
4. 테스트 환경 (iOS/Android, 버전)
