# 포스트 데이터베이스 구조 분석 및 개선안

## 현재 구조 (As-Is)

### 1. PostModel (lib/models/post_model.dart)
```dart
class PostModel {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final int reward;
  final DateTime expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? collectedAt;  // 단일 사용자만 수집 가능
  final String? collectedBy;    // 단일 사용자 ID만 저장
  // ... 기타 필드들
}
```

### 2. 현재 Firestore 구조
```
flyers (컬렉션)
├── {flyerId}
    ├── id: String
    ├── title: String
    ├── description: String
    ├── creatorId: String
    ├── creatorName: String
    ├── reward: int
    ├── expiresAt: Timestamp
    ├── isActive: boolean
    ├── createdAt: Timestamp
    ├── collectedAt: Timestamp?  // 단일 수집
    ├── collectedBy: String?     // 단일 사용자
    └── ... 기타 필드들
```

### 3. 현재 구조의 한계점
- **단일 수집 제한**: `collectedBy`가 단일 사용자만 저장 가능
- **통계 부족**: 배포한 포스트에 대한 수집/사용 통계 없음
- **상태 추적 불가**: 주운 포스트의 사용 여부 추적 불가
- **확장성 부족**: 다수 사용자가 동일 포스트를 수집할 수 없음

---

## 제안하는 구조 (To-Be)

### 1. 개선된 PostModel
```dart
class PostModel {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final int reward;
  final int totalSupply;        // 총 배포 수량
  final DateTime expiresAt;
  final bool isActive;
  final bool recalled;          // 회수 여부
  final DateTime createdAt;
  final DateTime? recalledAt;   // 회수 시간
  
  // 통계 필드들
  final int collectedCount;     // 총 수집된 수
  final int redeemedCount;     // 총 사용된 수
  final int remainingCount;    // 남은 수량 (totalSupply - collectedCount)
  
  // ... 기타 기존 필드들
}

class PostClaim {
  final String id;
  final String flyerId;
  final String userId;
  final String userName;
  final DateTime collectedAt;
  final DateTime? redeemedAt;
  final String? storeId;        // 사용한 가게 ID
  final String? storeName;      // 사용한 가게명
  final PostClaimStatus status; // collected, redeemed, expired
}
```

### 2. 개선된 Firestore 구조
```
flyers (컬렉션)
├── {flyerId}
    ├── id: String
    ├── title: String
    ├── description: String
    ├── creatorId: String
    ├── creatorName: String
    ├── reward: int
    ├── totalSupply: int        // NEW: 총 배포 수량
    ├── expiresAt: Timestamp
    ├── isActive: boolean
    ├── recalled: boolean       // NEW: 회수 여부
    ├── createdAt: Timestamp
    ├── recalledAt: Timestamp?  // NEW: 회수 시간
    ├── collectedCount: int     // NEW: 총 수집된 수
    ├── redeemedCount: int      // NEW: 총 사용된 수
    ├── remainingCount: int     // NEW: 남은 수량
    └── ... 기타 필드들
    
    └── claims (서브컬렉션)     // NEW: 수집/사용 기록
        ├── {claimId}
            ├── id: String
            ├── flyerId: String
            ├── userId: String
            ├── userName: String
            ├── collectedAt: Timestamp
            ├── redeemedAt: Timestamp?
            ├── storeId: String?
            ├── storeName: String?
            └── status: String   // collected, redeemed, expired

user_claims (컬렉션)            // NEW: 사용자별 수집 기록 (역인덱스)
├── {userId}
    ├── {claimId}
        ├── flyerId: String
        ├── collectedAt: Timestamp
        ├── status: String
        └── ... 기타 claim 정보
```

---

## 구조 개선의 장점

### 1. 다중 수집 지원
- **기존**: 한 포스트당 한 명만 수집 가능
- **개선**: 한 포스트당 다수 사용자 수집 가능

### 2. 상세한 통계 제공
- **기존**: 수집 여부만 확인 가능
- **개선**: 
  - 총 배포 수량
  - 총 수집된 수
  - 총 사용된 수
  - 남은 수량
  - 회수 여부

### 3. 사용자 행동 추적
- **기존**: 수집만 가능
- **개선**: 수집 → 가게 방문 → 사용까지 전체 플로우 추적

### 4. 효율적인 쿼리
- **기존**: 복잡한 복합 인덱스 필요
- **개선**: `user_claims` 컬렉션으로 사용자별 조회 최적화

---

## 구현 단계별 계획

### Phase 1: 스키마 확장
1. PostModel에 통계 필드 추가
2. PostClaim 모델 생성
3. Firestore 규칙 업데이트

### Phase 2: 서비스 계층 구현
1. PostService에 claim 관련 메서드 추가
2. 통계 계산 로직 구현
3. 에러 처리 및 폴백 로직

### Phase 3: Cloud Functions
1. claim 생성 시 통계 업데이트
2. claim 상태 변경 시 통계 업데이트
3. 배치 처리 및 트랜잭션 처리

### Phase 4: UI 업데이트
1. Inbox 화면에 통계 표시
2. PostCard에 상태 정보 추가
3. 사용자 인터랙션 개선

---

## 마이그레이션 고려사항

### 1. 기존 데이터 처리
- `collectedBy`가 있는 기존 포스트는 `claims` 서브컬렉션으로 마이그레이션
- 기존 수집 기록을 claim 형태로 변환

### 2. 호환성 유지
- 기존 API는 유지하면서 새로운 필드 추가
- 점진적 마이그레이션으로 서비스 중단 최소화

### 3. 성능 최적화
- 인덱스 전략 재설계
- 캐싱 전략 수립
- 배치 처리 최적화

---

## 보안 고려사항

### 1. Firestore 규칙
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 작성자만 포스트 수정/삭제 가능
    match /flyers/{flyerId} {
      allow read: if true;
      allow write: if request.auth != null && 
                   request.auth.uid == resource.data.creatorId;
    }
    
    // 본인만 자신의 claim 읽기/수정 가능
    match /flyers/{flyerId}/claims/{claimId} {
      allow read, write: if request.auth != null && 
                         request.auth.uid == resource.data.userId;
    }
    
    // 본인만 자신의 user_claims 읽기 가능
    match /user_claims/{userId}/{claimId} {
      allow read, write: if request.auth != null && 
                         request.auth.uid == userId;
    }
  }
}
```

### 2. 데이터 무결성
- 트랜잭션을 통한 통계 필드 동기화
- claim 상태 변경 시 유효성 검증
- 만료된 포스트에 대한 자동 상태 업데이트

---

## 결론

현재 구조는 단순하지만 확장성과 기능성이 제한적입니다. 제안하는 구조로 개선하면:

1. **사용자 경험 향상**: 더 풍부한 정보와 상호작용
2. **비즈니스 인사이트**: 상세한 통계와 분석 가능
3. **확장성**: 향후 기능 추가 시 유연한 확장 가능
4. **성능**: 최적화된 쿼리와 인덱싱

단계별 구현을 통해 서비스 중단 없이 점진적으로 개선할 수 있습니다.


