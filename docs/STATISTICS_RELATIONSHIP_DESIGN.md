# 포스트 통계를 위한 연결 관계 설계

## 📊 개요

사용자가 "내 포스트"에서 각 템플릿의 배포 현황과 수집 통계를 확인할 수 있도록 `posts-markers-post_instances` 간의 연결 관계를 설계합니다.

## 🔗 연결 관계 구조

```
posts (템플릿)
├── postId: "post_12345"
├── totalDeployments: 3      // 이 템플릿으로 생성한 마커 수
├── totalInstances: 25       // 이 템플릿으로 수집된 인스턴스 수
└── lastDeployedAt: timestamp

    ↓ (1:N) postId로 연결

markers (배포)
├── markerId: "marker_67890"
├── postId: "post_12345"     // 상위 템플릿 참조
├── totalQuantity: 10
├── collectedQuantity: 8
└── remainingQuantity: 2

    ↓ (1:N) markerId로 연결

post_instances (수집)
├── instanceId: "instance_xyz789"
├── postId: "post_12345"     // 원본 템플릿 참조
├── markerId: "marker_67890" // 수집한 마커 참조
├── userId: "user_def456"    // 수집한 사용자
└── collectedAt: timestamp
```

## 📈 통계 쿼리 패턴

### 1. 내 포스트별 전체 통계
```javascript
// 특정 템플릿의 모든 배포 현황
async function getPostStatistics(postId) {
  // 1. 템플릿 기본 정보
  const post = await db.collection('posts').doc(postId).get();

  // 2. 이 템플릿으로 생성한 모든 마커
  const markers = await db.collection('markers')
    .where('postId', '==', postId)
    .get();

  // 3. 이 템플릿으로 수집된 모든 인스턴스
  const instances = await db.collection('post_instances')
    .where('postId', '==', postId)
    .get();

  return {
    template: post.data(),
    deployments: markers.docs.map(doc => doc.data()),
    collections: instances.docs.map(doc => doc.data()),

    // 통계 계산
    totalDeployments: markers.size,
    totalQuantityDeployed: markers.docs.reduce((sum, doc) => sum + doc.data().totalQuantity, 0),
    totalCollected: instances.size,
    totalUsed: instances.docs.filter(doc => doc.data().isUsed).length,
    collectionRate: instances.size / totalQuantityDeployed
  };
}
```

### 2. 마커별 상세 통계
```javascript
// 특정 마커의 수집 현황
async function getMarkerStatistics(markerId) {
  // 1. 마커 정보
  const marker = await db.collection('markers').doc(markerId).get();

  // 2. 이 마커로 수집된 인스턴스들
  const instances = await db.collection('post_instances')
    .where('markerId', '==', markerId)
    .get();

  return {
    marker: marker.data(),
    instances: instances.docs.map(doc => doc.data()),

    // 상세 통계
    collectedCount: instances.size,
    usedCount: instances.docs.filter(doc => doc.data().isUsed).length,
    collectionsByDate: groupByDate(instances.docs),
    collectionsByUser: groupByUser(instances.docs)
  };
}
```

### 3. 사용자별 수집 패턴 분석
```javascript
// 내가 만든 포스트를 수집한 사용자 분석
async function getCollectorAnalytics(creatorId) {
  // 1. 내 모든 템플릿
  const myPosts = await db.collection('posts')
    .where('creatorId', '==', creatorId)
    .get();

  const postIds = myPosts.docs.map(doc => doc.id);

  // 2. 내 템플릿들로 수집된 모든 인스턴스
  const allInstances = await Promise.all(
    postIds.map(postId =>
      db.collection('post_instances')
        .where('postId', '==', postId)
        .get()
    )
  );

  return {
    // 수집자 분석
    uniqueCollectors: getUniqueUsers(allInstances),
    topCollectors: getTopCollectors(allInstances),
    collectionsByRegion: groupByRegion(allInstances),
    collectionTrends: getTimeTrends(allInstances)
  };
}
```

## 🎯 필수 인덱스 설계

### 통계 조회용 인덱스

```javascript
// posts 컬렉션 (기존 유지)
{ "creatorId": 1, "createdAt": -1 }
{ "creatorId": 1, "isActive": 1 }

// markers 컬렉션 (새로 추가)
{ "postId": 1, "createdAt": -1 }          // 템플릿별 마커 조회
{ "postId": 1, "isActive": 1 }            // 활성 마커만 조회
{ "creatorId": 1, "createdAt": -1 }       // 내 마커 조회

// post_instances 컬렉션 (새로 생성)
{ "postId": 1, "collectedAt": -1 }        // 템플릿별 인스턴스 조회
{ "markerId": 1, "collectedAt": -1 }      // 마커별 인스턴스 조회
{ "userId": 1, "collectedAt": -1 }        // 사용자별 인스턴스 조회
{ "postId": 1, "userId": 1 }              // 템플릿-사용자 교집합
{ "postId": 1, "status": 1, "collectedAt": -1 } // 상태별 필터링
```

## 🔄 실시간 통계 업데이트

### 1. 마커 생성 시 (markers 컬렉션에 추가)
```javascript
// MarkerService.createMarker() 수정
async function createMarker(markerData) {
  const batch = db.batch();

  // 1. 마커 생성
  const markerRef = db.collection('markers').doc();
  batch.set(markerRef, markerData);

  // 2. 템플릿 통계 업데이트
  const postRef = db.collection('posts').doc(markerData.postId);
  batch.update(postRef, {
    totalDeployments: FieldValue.increment(1),
    lastDeployedAt: FieldValue.serverTimestamp()
  });

  await batch.commit();
  return markerRef.id;
}
```

### 2. 포스트 수집 시 (post_instances 컬렉션에 추가)
```javascript
// PostInstanceService.collectPost() 새로 생성
async function collectPost(markerId, userId) {
  const batch = db.batch();

  // 1. 마커 정보 조회
  const marker = await db.collection('markers').doc(markerId).get();
  const markerData = marker.data();

  // 2. 템플릿 정보 조회
  const post = await db.collection('posts').doc(markerData.postId).get();
  const postData = post.data();

  // 3. 인스턴스 생성 (템플릿 데이터 스냅샷)
  const instanceRef = db.collection('post_instances').doc();
  const instanceData = {
    instanceId: instanceRef.id,
    postId: markerData.postId,
    markerId: markerId,
    userId: userId,
    collectedAt: FieldValue.serverTimestamp(),

    // 템플릿 데이터 스냅샷
    ...postData,

    // 마커에서 가져온 만료일
    expiresAt: markerData.endDate
  };
  batch.set(instanceRef, instanceData);

  // 4. 마커 수량 감소
  batch.update(marker.ref, {
    remainingQuantity: FieldValue.increment(-1),
    collectedQuantity: FieldValue.increment(1)
  });

  // 5. 템플릿 통계 업데이트
  batch.update(post.ref, {
    totalInstances: FieldValue.increment(1)
  });

  await batch.commit();
  return instanceRef.id;
}
```

## 📊 UI에서 표시할 통계 정보

### 내 포스트 목록에서 (Inbox)
```javascript
// 각 포스트별로 표시할 통계
{
  postId: "post_12345",
  title: "치킨집 할인쿠폰",
  reward: 500,

  // 배포 통계
  totalDeployments: 3,        // 배포한 마커 수
  totalQuantityDeployed: 30,  // 총 배포한 수량

  // 수집 통계
  totalCollected: 25,         // 수집된 인스턴스 수
  totalUsed: 18,              // 실제 사용된 수

  // 계산된 비율
  collectionRate: 0.83,       // 수집률 (25/30)
  usageRate: 0.72,           // 사용률 (18/25)

  // 최근 활동
  lastDeployedAt: "2025-01-20",
  lastCollectedAt: "2025-01-22"
}
```

### 포스트 상세 통계 화면
```javascript
// 특정 포스트의 상세 통계
{
  // 기본 정보
  template: { ... },

  // 배포별 상세 현황
  deployments: [
    {
      markerId: "marker_1",
      location: "강남역",
      deployedAt: "2025-01-15",
      totalQuantity: 10,
      collectedQuantity: 8,
      remainingQuantity: 2,
      status: "active"
    },
    {
      markerId: "marker_2",
      location: "홍대입구역",
      deployedAt: "2025-01-18",
      totalQuantity: 15,
      collectedQuantity: 12,
      remainingQuantity: 3,
      status: "active"
    }
  ],

  // 수집자 분석
  collectors: {
    uniqueCount: 18,        // 고유 수집자 수
    totalCollections: 25,   // 총 수집 횟수
    averagePerUser: 1.39,   // 사용자당 평균 수집 수

    topCollectors: [        // 많이 수집한 사용자 (익명)
      { userId: "***456", count: 3 },
      { userId: "***789", count: 2 }
    ]
  },

  // 시간대별 수집 패턴
  timePattern: {
    hourly: { "09": 3, "12": 8, "18": 7, "20": 5 },
    daily: { "월": 4, "화": 6, "수": 8, "목": 5, "금": 2 }
  },

  // 지역별 수집 현황
  locationPattern: {
    "강남구": 15,
    "마포구": 8,
    "종로구": 2
  }
}
```

## 🎯 성능 최적화 전략

### 1. 집계 데이터 사전 계산
- `posts` 컬렉션에 `totalDeployments`, `totalInstances` 필드 유지
- Firebase Functions로 실시간 업데이트
- 복잡한 통계는 주기적으로 배치 처리

### 2. 캐싱 전략
- 자주 조회되는 통계는 클라이언트 캐싱
- 실시간성이 중요하지 않은 데이터는 시간 기반 캐시
- 메모리 기반 통계 요약 저장

### 3. 페이지네이션
- 수집 인스턴스 목록은 페이지네이션 적용
- 시간순 정렬로 최신 활동 우선 표시

---

**문서 버전**: v1.0
**마지막 업데이트**: 2025-09-26
**작성자**: Claude Code Assistant