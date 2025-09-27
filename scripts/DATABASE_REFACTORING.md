# 데이터베이스 구조 최적화 계획

## 📊 현재 데이터 구조 분석 결과

### 🔍 주요 발견사항

#### 1. **Post 데이터 구조 문제점**
- **Posts 컬렉션이 과부하 상태**: 창작용 + 배포용 필드가 혼재
- **실제 Firebase 데이터와 코드 모델 불일치**: PostModel이 실제 데이터 필드의 일부만 반영
- **불필요한 통계 필드**: Post에 저장되지만 실제로는 쿼리로 계산됨

#### 2. **Marker 데이터 구조 불일치** ⚠️
현재 MarkerModel vs 실제 Firebase Marker 데이터:

| 필드 | MarkerModel | 실제 Firebase | 상태 |
|------|-------------|---------------|------|
| `collectedBy` | `List<String>` | `array` | ✅ 일치 |
| `collectedQuantity` | ❌ 없음 | 0 (number) | ❌ 누락 |
| `collectionRate` | ❌ 없음 | 0 (number) | ❌ 누락 |
| `remainingQuantity` | ❌ 없음 | 1 (number) | ❌ 누락 |
| `totalQuantity` | ❌ 없음 | 1 (number) | ❌ 누락 |
| `tileId` | ❌ 없음 | "tile_4166_14100" | ❌ 누락 |

#### 3. **Post_Collections 구조 (완벽함!)**
현재 `PostInstanceModel`과 `post_collections` 컬렉션이 이미 완벽하게 설계되어 있음:
- ✅ postID, markerID 연결
- ✅ 수집자 정보 (userId)
- ✅ 쿠폰 사용 여부 (isCoupon, couponData)
- ✅ 상태 관리 (COLLECTED, USED, EXPIRED, DELETED)
- ✅ 스냅샷 방식 데이터 보존

## 🎯 최적화된 데이터베이스 구조 제안

### 📝 **Posts 컬렉션 (포스트 창작용)**
```dart
// 포스트 템플릿 - 창작할 때만 필요한 필드들
class PostTemplateModel {
  // 기본 정보
  final String postId;
  final String creatorId;
  final String creatorName;
  final DateTime createdAt;

  // 콘텐츠
  final String title;
  final String description;
  final List<String> mediaType;
  final List<String> mediaUrl;
  final List<String> thumbnailUrl;

  // 리워드 & 조건
  final int reward;
  final bool canRespond;
  final bool canForward;
  final bool canRequestReward;
  final bool canUse;

  // 타겟팅
  final List<int> targetAge;
  final String targetGender;
  final List<String> targetInterest;
  final List<String> targetPurchaseHistory;

  // 상태 관리
  final PostStatus status; // DRAFT, PUBLISHED, DELETED
}
```

### 📍 **Markers 컬렉션 (배포된 마커들)**
```dart
// 실제 배포된 마커 - 위치, 기간, 포그 정보 포함
class MarkerModel {
  // 연결 정보
  final String markerId;
  final String postId; // posts 컬렉션 참조

  // 위치 & 배포 정보
  final GeoPoint location;
  final int radius;
  final DateTime deployedAt;
  final DateTime expiresAt;

  // 수량 관리 (Firebase 데이터와 일치)
  final int totalQuantity;
  final int remainingQuantity;
  final int collectedQuantity;
  final double collectionRate;

  // 위치 최적화
  final String tileId;
  final String s2_10;
  final String s2_12;
  final int fogLevel;

  // 상태
  final bool isActive;
  final String creatorId;
}
```

### 📊 **Post_Collections 컬렉션 (수집 기록) - 현재 완벽함**
```dart
// 이미 존재하는 컬렉션 - 수집/사용 기록용
class PostCollectionModel {
  final String collectionId;
  final String postId;        // ✅ postID
  final String markerId;      // ✅ markerID
  final String userId;        // ✅ 수집자 정보
  final DateTime collectedAt;
  final String status;        // COLLECTED, USED
  final DateTime? usedAt;
  final bool isCoupon;        // ✅ 쿠폰 사용 여부
  final Map<String, dynamic>? couponData;
  // ... 템플릿 스냅샷 데이터
}
```

## 🚀 **쿼리 기반 통계 시스템**

### 📊 **실시간 통계 조회 (이미 구현됨)**
현재 `PostStatisticsService`에서 이미 쿼리 기반으로 통계를 계산하고 있음:

```dart
// 배포 통계 (markers 컬렉션 쿼리)
final markers = await FirebaseFirestore.instance
    .collection('markers')
    .where('postId', isEqualTo: postId)
    .get();

// 수집 통계 (post_collections 컬렉션 쿼리)
final collections = await FirebaseFirestore.instance
    .collection('post_collections')
    .where('postId', isEqualTo: postId)
    .get();

return {
  'totalDeployments': markers.size,
  'totalCollected': collections.size,
  'totalUsed': collections.docs.where((d) => d.data()['status'] == 'USED').length,
};
```

## 🚨 **예상 컨플릭트 영역 (역할 분담 기준)**

### 역할 분담
- **당신**: Inbox 관련 (InboxScreen, PostService 통계 부분)
- **친구**: Map/Markers 관련 (MapScreen, MarkerService)

### 🔥 **High Risk - 높은 컨플릭트 가능성**

**1. PostModel 수정**
- **당신**: InboxScreen에서 PostModel 필드들 사용 (title, reward, expiresAt, status 등)
- **친구**: MapScreen에서 PostModel의 위치 관련 필드들 사용 (location, radius, s2_10, tileId 등)
- **컨플릭트**: PostModel에서 위치 관련 필드 제거 시 MapScreen 코드 깨짐

**2. PostService 클래스**
```dart
// 당신이 수정할 가능성:
- getUserPosts(), getCollectedPosts()
- 통계 관련 메서드들

// 친구가 수정할 가능성:
- 위치 기반 포스트 조회
- 마커 배포 관련 메서드들
```

**3. 통계 필드 사용**
- **당신**: InboxScreen에서 `post.totalDeployed`, `post.totalCollected` 등 사용
- **친구**: 마커 수량 계산에서 동일 필드들 사용 가능성

### ⚡ **Medium Risk - 중간 컨플릭트 가능성**

**4. MarkerModel 확장**
- **당신**: PostInstanceModel과의 연동 부분
- **친구**: 실제 마커 표시 및 수량 관리

**5. 서비스 클래스 Import**
```dart
// 양쪽에서 사용할 가능성
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
```

### 🟡 **Low Risk - 낮은 컨플릭트 가능성**

**6. PostInstanceModel (Post_Collections)**
- **당신**: InboxScreen의 "받은 포스트" 탭에서 주로 사용
- **친구**: 마커에서 수집 시에만 생성

**7. UI 위젯들**
- **당신**: PostCard, PostTileCard
- **친구**: MarkerLayerWidget, 지도 관련 위젯들

## 🛡️ **컨플릭트 방지 전략**

### 📋 **작업 전 조율 필요사항**

**1. PostModel 필드 제거 순서**
```dart
// Step 1: 친구가 MapScreen에서 위치 필드들을 MarkerModel로 이전
// Step 2: 당신이 PostModel에서 위치 관련 필드 제거
```

**2. 통계 필드 처리**
```dart
// 당신: InboxScreen에서 쿼리 기반 통계로 변경
// 친구: 마커 수량 관리를 MarkerModel 기반으로 변경
```

**3. PostService 메서드 분리**
```dart
// 당신이 수정:
- getUserPosts(), getCollectedPosts()
- 통계 관련 메서드들

// 친구가 수정:
- 위치 기반 조회 메서드들
- 마커 배포 관련 메서드들
```

## 🎯 **단계별 마이그레이션 로드맵**

### Phase 1: 문서화 및 브랜치 관리 ✅
- [x] 현재 구조 분석
- [x] 최적화 계획 문서화
- [x] 백업 브랜치 생성

### Phase 2: MarkerModel 확장 (친구 담당)
- [ ] MarkerModel에 누락된 필드들 추가
  - `collectedQuantity`, `remainingQuantity`, `totalQuantity`
  - `collectionRate`, `tileId`
  - `s2_10`, `s2_12`, `fogLevel`
- [ ] MarkerService에서 새 필드들 활용
- [ ] MapScreen에서 MarkerModel 기반으로 로직 변경

### Phase 3: PostModel 간소화 (당신 담당)
- [ ] PostModel에서 제거할 필드들:
  - 위치 관련: `location`, `radius`, `deployLocation`
  - 시간 관련: `expiresAt`, `deployStartDate`, `deployEndDate`
  - 위치 최적화: `s2_10`, `s2_12`, `tileId`, `tileId_fog1`, `fogLevel`
  - 배포 상태: `isDistributed`, `distributedAt`
  - 통계 필드: `totalDeployed`, `totalCollected`, `totalUsed`, `totalDeployments`, `totalInstances`, `lastDeployedAt`, `lastCollectedAt`

### Phase 4: 서비스 클래스 정리 (공동 작업)
- [ ] PostService에서 위치/배포 관련 로직을 MarkerService로 이전
- [ ] 통계 관련 메서드들을 PostStatisticsService로 통합
- [ ] InboxScreen, MapScreen에서 사용하는 필드 참조 수정

### Phase 5: 테스트 및 검증
- [ ] 기존 기능 동작 확인
- [ ] 성능 개선 측정
- [ ] 데이터 일관성 검증

## ✨ **기대 효과**

### 🎯 **1. 명확한 역할 분리**
- **Posts**: 포스트 템플릿 (창작 정보만)
- **Markers**: 배포된 인스턴스 (위치, 기간, 포그 정보)
- **Post_Collections**: 수집/사용 기록

### 🎯 **2. 데이터 일관성 향상**
- Post와 Marker 간 데이터 중복 제거
- 실제 Firebase 데이터와 모델 일치

### 🎯 **3. 성능 최적화**
- 불필요한 통계 필드 제거
- 실시간 쿼리 기반 통계 활용

### 🎯 **4. 유지보수성 향상**
- 각 컬렉션의 명확한 책임
- 모듈별 독립적인 수정 가능

## 📅 **작성일**: 2025-09-28
## 👥 **작성자**: ytshaha (Inbox 담당), 친구 (Map/Markers 담당)