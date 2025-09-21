# 서버 사이드 필터링 시스템 가이드

## 🚀 주요 변경사항

### 1. 완전 서버 사이드 필터링
- **기존**: 클라이언트에서 Firestore 쿼리 → 클라이언트에서 필터링
- **변경**: Cloud Functions 서버 API → 서버에서 모든 필터링 처리

### 2. 성능 최적화
- **whereIn 제한 해결**: 10개씩 배치 쿼리로 분할
- **캐시 시스템**: 1km 그리드 스냅으로 캐시 히트율 향상
- **디바운스 개선**: 200ms → 500ms로 조정
- **동일 타일 스킵**: 캐시 키 기반으로 불필요한 업데이트 방지

### 3. 구조 개선
- **역색인 컬렉션**: `posts_by_tile/{tileId}/posts/{postId}` 구조
- **슈퍼포스트 분리**: 별도 API로 전역 노출
- **타일 교차 정확 판정**: 원-사각형 교차 알고리즘

## 📁 파일 구조

```
functions/
├── src/
│   ├── index.ts              # 함수 진입점
│   ├── queryPosts.ts         # 메인 쿼리 API
│   └── postIndexing.ts       # 역색인 생성 트리거
├── package.json
└── tsconfig.json

lib/features/map_system/services/markers/
└── marker_service.dart       # 서버 API 호출로 변경

lib/features/map_system/screens/
└── map_screen.dart           # 서버 API 사용으로 수정
```

## 🔧 설정 방법

### 1. Cloud Functions 배포
```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

### 2. Firestore 인덱스 생성
Firebase 콘솔에서 다음 복합 인덱스 생성:
- `posts_by_tile/{tileId}/posts`: `isActive` + `isCollected` + `updatedAt`
- `posts`: `isActive` + `isCollected` + `isSuperPost` + `updatedAt`

### 3. 환경 변수 설정
`.env` 파일에 Firebase 프로젝트 설정:
```
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
```

## 🚀 API 사용법

### 1. 일반 포스트 조회
```dart
final markers = await MarkerService.getMarkers(
  location: currentPosition,
  radiusInKm: 1.0,
  additionalCenters: [homeLocation, workLocation],
  filters: {
    'showCouponsOnly': false,
    'myPostsOnly': false,
    'minReward': 0,
  },
  pageSize: 500,
);
```

### 2. 슈퍼포스트 조회
```dart
final superMarkers = await MarkerService.getSuperPosts(
  location: currentPosition,
  radiusInKm: 1.0,
  additionalCenters: [homeLocation, workLocation],
  pageSize: 200,
);
```

### 3. 캐시 관리
```dart
// 전체 캐시 클리어
MarkerService.clearCache();

// 특정 위치 캐시만 클리어
MarkerService.clearCacheForLocation(currentPosition);
```

## 📊 성능 개선 효과

### 1. API 호출 감소
- **기존**: 타일마다 개별 쿼리 (N번 호출)
- **개선**: 서버에서 배치 처리 (1번 호출)

### 2. 네트워크 트래픽 감소
- **기존**: 모든 포스트 다운로드 후 클라이언트 필터링
- **개선**: 서버에서 필터링된 결과만 전송

### 3. 캐시 효율성
- **기존**: 좌표 기반 캐시 (파편화)
- **개선**: 1km 그리드 스냅 (안정적 캐시)

## 🔍 주요 기능

### 1. 포그레벨 1단계 타일 계산
- 30일 이내 방문 기록 + 1km 원 교차 타일
- 정확한 원-사각형 교차 판정 알고리즘

### 2. 슈퍼포스트 전용 처리
- 포그레벨 무시, 거리만 확인
- 별도 API로 성능 최적화

### 3. 실시간 인덱싱
- 포스트 생성/수정 시 자동으로 `posts_by_tile` 업데이트
- Cloud Functions 트리거로 동기화

## ⚠️ 주의사항

### 1. Firestore 보안 규칙
```javascript
// posts_by_tile 읽기 허용
match /posts_by_tile/{tileId}/posts/{postId} {
  allow read: if true;
}
```

### 2. Cloud Functions 권한
- Firestore Admin SDK 사용으로 모든 데이터 접근 가능
- 적절한 인증/인가 로직 구현 필요

### 3. 비용 최적화
- 페이지네이션으로 읽기 비용 제어
- 캐시 활용으로 중복 요청 방지

## 🚀 다음 단계

1. **타일 서버(MVT) 도입**: 대규모 마커 처리
2. **Redis 캐시**: 서버 사이드 캐싱 강화
3. **CDN 활용**: 정적 리소스 최적화
4. **모니터링**: 성능 메트릭 수집

이제 **완전 서버 사이드 필터링**으로 전환되어 클라이언트 부하가 크게 줄어들고, 확장성도 크게 향상되었습니다! 🎉
