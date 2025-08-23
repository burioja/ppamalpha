# PPAM 앱 인박스 및 스토어 구현 필요사항

## 문서 개요
- **작성일**: 2025년 8월 18일
- **목적**: 인박스와 스토어 기능의 MVP 구현을 위한 상세 요구사항 정리
- **범위**: 가상 포인트 시스템 기반의 MVP 완성

---

## 1. 현재 구현 상태 분석

### 1.1 인박스 화면 (InboxScreen)
#### ✅ 이미 구현된 기능
- **기본 구조**: 2개 탭 (내 포스트 (배포 포스트 통계 링크 포함), 주운 포스트)
- **검색 및 필터링**: 제목, 내용, 발행자 기반 검색
- **상태 필터**: 전체, 활성, 비활성, 만료됨
- **기간 필터**: 전체, 오늘, 1주일, 1개월
- **정렬 기능**: 생성일, 제목, 리워드, 만료일 기준
- **페이지네이션**: 20개씩 로딩, 무한 스크롤
- **포스트 생성**: 플로팅 액션 버튼으로 포스트 만들기 화면 이동

#### ⚠️ 부분적으로 구현된 기능
- **포스트 상세 화면**: 기본 이동은 가능하나 실제 화면 미구현
- **포스트 수정**: 수정 가능 여부만 판단, 실제 수정 기능 미구현
- **포스트 삭제**: 삭제 후 처리 로직 미구현

#### ❌ 미구현된 핵심 기능
- **쿠폰 사용 시스템**: GPS 기반 쿠폰 사용 및 가상 포인트 지급
- **포스트 전달 기능**: 조건부 전달 가능 여부 판단 및 실행
- **응답 기능**: 대화창 입력 및 대화 표시
- **포스트 상태 관리**: 활성/비활성 토글, 만료 처리
- **가상 포인트 시스템**: 리워드 지급 및 수령

### 1.2 스토어 관련 기능
#### ✅ 이미 구현된 기능
- **플레이스 모델**: 기본적인 장소 정보 구조
- **플레이스 서비스**: CRUD 기본 기능
- **카테고리 시스템**: 3단계 카테고리 구조

#### ❌ 미구현된 기능
- **내 스토어 화면**: 사용자별 스토어 관리 화면
- **스토어 인증 시스템**: WiFi, NFC 기반 직원 인증
- **스토어 수정 기능**: 가게명, 사진, 리뷰 관리
- **스토어 연동**: 포스트와 스토어 연결

---

## 2. MVP 구현 우선순위

### 2.1 **최우선 구현 (Phase 1)**
#### A. 가상 포인트 시스템
- **포인트 모델 생성**
  ```dart
  class PointModel {
    final String userId;
    final int balance;
    final List<PointTransaction> transactions;
    final DateTime lastUpdated;
  }
  
  class PointTransaction {
    final String id;
    final int amount;
    final String type; // 'earn', 'spend', 'transfer'
    final String description;
    final DateTime timestamp;
  }
  ```

- **현금 서비스 구현**
  - 현금 잔액 조회
  - 현금 획득 (쿠폰 사용 시)
  - 현금 사용 (포스트 생성 시)
  - 현금 이력 조회

#### B. 쿠폰 사용 시스템
- **GPS 기반 위치 검증**
  - 사용자 현재 위치와 포스트 위치 비교
  - 설정된 반경 내에서만 사용 가능
  - 위치 검증 실패 시 적절한 에러 메시지

- **쿠폰 사용 처리**
  - 포스트 상태를 'used'로 변경
  - 발행자에게 가상 포인트 지급
  - 사용 이력 기록

#### C. 포스트 상세 화면
- **기본 정보 표시**
  - 제목, 설명, 이미지/사운드
  - 발행자 정보, 생성일, 만료일
  - 리워드 금액, 타겟팅 조건
  - 가상 현금 충전 페이지 링크

- **액션 버튼**
  - 쿠폰 사용 (canUse = true인 경우)
  - 포스트 전달 (canForward = true인 경우)
  - 응답하기 (canRespond = true인 경우)
  - 스토어로 이동 (placeId가 있는 경우)

### 2.2 **중간 우선순위 (Phase 2)**
#### A. 포스트 전달 및 응답 시스템
- **전달 기능**
  - 전달 가능 여부 확인
  - 전달 시 새로운 포스트 생성
  - 전달 이력 추적

- **응답 기능**
  - 응답 가능 여부 확인
  - 대화창 UI 구현
  - 응답 메시지 저장 및 표시

#### B. 포스트 상태 관리
- **활성/비활성 토글**
  - 사용자가 직접 상태 변경
  - 상태 변경 시 지도에 반영

- **만료 처리**
  - 자동 만료 감지
  - 만료된 포스트 필터링

#### C. 내 스토어 기본 기능
- **스토어 정보 표시**
  - 가게명, 설명, 이미지
  - 주소, 연락처 정보
  - 운영 시간

- **스토어 수정**
  - 기본 정보 수정
  - 이미지 추가/제거
  - 운영 정보 업데이트

### 2.3 **낮은 우선순위 (Phase 3)**
#### A. 고급 타겟팅 기능
- **사용자 프로필 기반 필터링**
  - 나이, 성별, 관심사 매칭
  - 구매 이력 기반 추천

#### B. 스토어 인증 시스템
- **WiFi 기반 인증**
  - 스토어 WiFi 연결 시 자동 인증
  - 인증 상태 표시

- **NFC 기반 인증**
  - NFC 태그 스캔 시 인증
  - 직원 권한 관리

---

## 3. 데이터베이스 스키마 확장

### 3.1 새로운 컬렉션 추가
#### A. points (가상 포인트)
```json
{
  "userId": "string",
  "balance": "number",
  "lastUpdated": "timestamp",
  "createdAt": "timestamp"
}
```

#### B. point_transactions (포인트 거래 내역)
```json
{
  "id": "string",
  "userId": "string",
  "amount": "number",
  "type": "string", // 'earn', 'spend', 'transfer'
  "description": "string",
  "relatedPostId": "string?",
  "timestamp": "timestamp"
}
```

#### C. post_claims (포스트 사용 내역)
```json
{
  "id": "string",
  "postId": "string",
  "userId": "string",
  "claimedAt": "timestamp",
  "location": "geopoint",
  "reward": "number",
  "status": "string" // 'pending', 'completed', 'failed'
}
```

#### D. post_responses (포스트 응답)
```json
{
  "id": "string",
  "postId": "string",
  "userId": "string",
  "message": "string",
  "timestamp": "timestamp"
}
```

### 3.2 기존 컬렉션 수정
#### A. flyers 컬렉션
```json
{
  // 기존 필드들...
  "isUsed": "boolean", // 사용됨 여부
  "usedBy": "string?", // 사용한 사용자 ID
  "usedAt": "timestamp?", // 사용 시간
  "forwardCount": "number", // 전달 횟수
  "responseCount": "number" // 응답 횟수
}
```

#### B. users 컬렉션
```json
{
  // 기존 필드들...
  "pointBalance": "number", // 포인트 잔액
  "totalEarnedPoints": "number", // 총 획득 포인트
  "totalSpentPoints": "number" // 총 사용 포인트
}
```

---

## 4. 구현 세부사항

### 4.1 가상 포인트 시스템 구현
#### A. 포인트 획득 로직
```dart
// 쿠폰 사용 시
Future<void> useCoupon(String postId, String userId, GeoPoint location) async {
  // 1. 포스트 유효성 검증
  final post = await getPostById(postId);
  if (!post.canUse || post.isExpired()) {
    throw Exception('사용할 수 없는 쿠폰입니다.');
  }
  
  // 2. 위치 검증
  if (!post.isInRadius(location)) {
    throw Exception('설정된 반경 내에서만 사용 가능합니다.');
  }
  
  // 3. 포인트 지급
  await addPoints(userId, post.reward, 'earn', '쿠폰 사용: ${post.title}');
  
  // 4. 포스트 상태 업데이트
  await updatePost(postId, {
    'isUsed': true,
    'usedBy': userId,
    'usedAt': DateTime.now(),
  });
}
```

#### B. 포인트 사용 로직
```dart
// 포스트 생성 시
Future<void> createPost(PostModel post) async {
  // 1. 포인트 차감
  final user = await getUserById(post.creatorId);
  if (user.pointBalance < post.reward) {
    throw Exception('포인트가 부족합니다.');
  }
  
  await deductPoints(post.creatorId, post.reward, 'spend', '포스트 생성: ${post.title}');
  
  // 2. 포스트 생성
  await _postService.createPost(post);
}
```

### 4.2 쿠폰 사용 UI 구현
#### A. 포스트 상세 화면
```dart
class PostDetailScreen extends StatelessWidget {
  final PostModel post;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post.title)),
      body: Column(
        children: [
          // 포스트 정보 표시
          PostInfoCard(post: post),
          
          // 액션 버튼들
          if (post.canUse && !post.isUsed)
            ElevatedButton(
              onPressed: () => _useCoupon(context),
              child: Text('쿠폰 사용하기 (${post.reward}포인트)'),
            ),
          
          if (post.canForward)
            ElevatedButton(
              onPressed: () => _forwardPost(context),
              child: Text('전달하기'),
            ),
          
          if (post.canRespond)
            ElevatedButton(
              onPressed: () => _showResponseDialog(context),
              child: Text('응답하기'),
            ),
        ],
      ),
    );
  }
}
```

### 4.3 내 스토어 화면 구현
#### A. 스토어 정보 표시
```dart
class MyStoreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('내 스토어'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editStore(context),
          ),
        ],
      ),
      body: FutureBuilder<PlaceModel?>(
        future: _getUserStore(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            final store = snapshot.data!;
            return StoreInfoCard(store: store);
          } else {
            return Center(
              child: Column(
                children: [
                  Text('등록된 스토어가 없습니다.'),
                  ElevatedButton(
                    onPressed: () => _createStore(context),
                    child: Text('스토어 등록하기'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
```

---

## 5. 테스트 계획

### 5.1 단위 테스트
- **포인트 시스템**: 포인트 획득/사용 로직 검증
- **쿠폰 사용**: 위치 검증 및 포인트 지급 검증
- **포스트 상태**: 활성/비활성, 만료 처리 검증

### 5.2 통합 테스트
- **전체 플로우**: 포스트 생성 → 배포 → 수집 → 사용 → 포인트 지급
- **에러 처리**: 부족한 포인트, 잘못된 위치, 만료된 쿠폰 등

### 5.3 UI 테스트
- **사용자 경험**: 직관적인 버튼 배치, 명확한 피드백
- **반응성**: 로딩 상태, 에러 메시지, 성공 알림

---

## 6. 배포 및 모니터링

### 6.1 MVP 배포 체크리스트
- [ ] 가상 포인트 시스템 구현 완료
- [ ] 쿠폰 사용 기능 구현 완료
- [ ] 포스트 상세 화면 구현 완료
- [ ] 내 스토어 기본 기능 구현 완료
- [ ] 기본 테스트 완료
- [ ] 사용자 가이드 작성

### 6.2 모니터링 지표
- **사용자 참여도**: 쿠폰 사용률, 포스트 생성률
- **시스템 안정성**: 에러 발생률, 응답 시간
- **비즈니스 지표**: 포인트 거래량, 활성 사용자 수

---

## 7. 향후 확장 계획

### 7.1 Phase 4 (실제 결제 연동)
- **Tajapay 연동**: 가상 포인트를 실제 화폐로 전환
- **수수료 시스템**: 플랫폼 수수료 적용
- **정산 시스템**: 발행자별 수익 정산

### 7.2 Phase 5 (고급 기능)
- **AI 추천**: 사용자 행동 기반 포스트 추천
- **소셜 기능**: 사용자 간 팔로우, 리뷰 시스템
- **분석 대시보드**: 상세한 사용자 행동 분석

---

## 8. 결론

현재 PPAM 앱의 인박스와 스토어 기능은 기본적인 UI 구조와 데이터 관리 기능은 갖추고 있으나, **핵심 가치를 제공하는 기능들이 대부분 미구현**되어 있습니다.

**MVP 완성을 위해서는 가상 포인트 시스템과 쿠폰 사용 기능을 최우선으로 구현**해야 하며, 이를 통해 사용자들이 실제로 앱을 사용할 수 있는 기본적인 경험을 제공할 수 있습니다.

구현 우선순위를 명확히 하고 단계별로 진행하면, 2-3주 내에 기본적인 MVP를 완성할 수 있을 것으로 예상됩니다.
