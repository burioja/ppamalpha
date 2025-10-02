# 포인트 지급 시스템 개선

## 📋 과제 개요
**과제 ID**: TASK-001
**제목**: 포인트 지급 시스템 개선
**우선순위**: ⭐⭐⭐ 높음
**담당자**: TBD
**상태**: 🔄 계획 중

## 🎯 요구사항 분석

### 사용자 요구사항
1. **기존 사용자 포인트 지급**: 현재 가입자에게 10만 포인트 지급
2. **신규 사용자 포인트 지급**: 새로 가입하는 사용자에게 10만 포인트 자동 지급
3. **포스트 수령 보상**: 포스트 수령 시 지정한 가격만큼 수집자에게 포인트 지급

### 비즈니스 요구사항
- 포인트 지급 기록 추적 가능
- 중복 지급 방지
- 사용자 활동 촉진을 위한 적절한 보상 체계

## 🔍 현재 상태 분석

### 기존 구현사항
```dart
// lib/core/services/data/points_service.dart 분석 결과

✅ 구현 완료:
- getUserPoints(): 사용자 포인트 조회
- addPoints(): 포인트 추가
- deductPoints(): 포인트 차감
- getPointsHistory(): 포인트 히스토리 조회
- rewardPostCollection(): 포스트 수집 보상 지급
- grantMillionPointsToAllUsers(): 모든 사용자에게 100만 포인트 지급

🔄 수정 필요:
- 신규 사용자 기본 지급액: 100만 포인트 → 10만 포인트
- 기존 사용자 보정: 100만 포인트 이상 보유자 → 10만 포인트로 조정
```

### 현재 포인트 정책
- **신규 가입자**: 100만 포인트 자동 지급 (line 22)
- **기존 사용자**: `grantMillionPointsToAllUsers()` 메서드로 100만 포인트 지급
- **포스트 수집**: `rewardPostCollection()` 메서드로 보상 지급

## ✅ 구현 계획

### Phase 1: 포인트 정책 조정
- [ ] 신규 사용자 기본 지급액을 10만 포인트로 변경
- [ ] 기존 사용자 포인트를 10만 포인트로 조정하는 메서드 구현
- [ ] 포인트 지급 히스토리에 정책 변경 기록

### Phase 2: 포스트 수령 보상 연동 확인
- [ ] `collectPost` 메서드에서 `rewardPostCollection` 호출 확인
- [ ] 포인트 지급 실패 시 롤백 메커니즘 확인
- [ ] 포인트 지급 로그 개선

### Phase 3: 테스트 및 검증
- [ ] 신규 가입자 10만 포인트 지급 테스트
- [ ] 기존 사용자 포인트 조정 테스트
- [ ] 포스트 수집 보상 연동 테스트

## 🛠 구현 상세

### 1. 신규 사용자 포인트 정책 변경

```dart
// 변경 전 (line 20-25)
final newUserPoints = UserPointsModel(
  userId: userId,
  totalPoints: 1000000, // 100만 포인트
  createdAt: DateTime.now(),
  lastUpdated: DateTime.now(),
);

// 변경 후
final newUserPoints = UserPointsModel(
  userId: userId,
  totalPoints: 100000, // 10만 포인트
  createdAt: DateTime.now(),
  lastUpdated: DateTime.now(),
);
```

### 2. 기존 사용자 포인트 조정 메서드

```dart
/// 모든 기존 사용자에게 10만 포인트로 조정 (관리자용)
Future<void> adjustToHundredThousandPoints() async {
  try {
    final querySnapshot = await _firestore
        .collection('user_points')
        .get();

    final batch = _firestore.batch();
    int updateCount = 0;

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final currentPoints = data['totalPoints'] ?? 0;

      // 100만 포인트 이상 보유자를 10만 포인트로 조정
      if (currentPoints >= 1000000) {
        batch.update(doc.reference, {
          'totalPoints': 100000,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // 히스토리 추가
        final historyRef = doc.reference.collection('history').doc();
        batch.set(historyRef, {
          'points': 100000 - currentPoints, // 음수값
          'type': 'system_adjustment',
          'reason': '포인트 정책 변경 (10만 포인트 조정)',
          'timestamp': FieldValue.serverTimestamp(),
        });

        updateCount++;
      }
    }

    if (updateCount > 0) {
      await batch.commit();
      print('✅ $updateCount명의 사용자 포인트를 10만으로 조정 완료');
    }

  } catch (e) {
    print('❌ 포인트 조정 실패: $e');
    rethrow;
  }
}
```

### 3. 포스트 수집 보상 연동 점검

현재 `PostService.collectPost()` 메서드에서 포인트 지급 연동 상태를 확인해야 함:

```dart
// 확인 필요 사항
1. collectPost() 메서드에서 rewardPostCollection() 호출 여부
2. 포인트 지급 실패 시 수집 작업 롤백 여부
3. 포인트 지급 로그 충분성
```

## 📊 테스트 시나리오

### 시나리오 1: 신규 가입자 포인트 지급
1. 새 사용자 계정 생성
2. `getUserPoints()` 호출
3. 10만 포인트 자동 지급 확인
4. 포인트 히스토리 기록 확인

### 시나리오 2: 기존 사용자 포인트 조정
1. 100만 포인트 이상 보유 사용자 선택
2. `adjustToHundredThousandPoints()` 실행
3. 포인트가 10만으로 조정되었는지 확인
4. 조정 히스토리 기록 확인

### 시나리오 3: 포스트 수집 보상
1. 포스트 수집 실행
2. 수집 완료 후 포인트 지급 확인
3. 지급된 포인트가 설정된 리워드와 일치하는지 확인
4. 포인트 히스토리에 기록되었는지 확인

## 📝 체크리스트

### 개발 단계
- [ ] 신규 사용자 포인트 정책 변경 (100만 → 10만)
- [ ] 기존 사용자 포인트 조정 메서드 구현
- [ ] 포인트 지급 히스토리 로직 개선
- [ ] 포스트 수집 보상 연동 확인

### 테스트 단계
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 수행
- [ ] 사용자 시나리오 테스트

### 배포 단계
- [ ] 코드 리뷰 완료
- [ ] QA 검증 완료
- [ ] 프로덕션 배포

## 🚨 위험 요소 및 대응 방안

### 위험 요소
1. **대량 포인트 조정 시 성능 이슈**: 사용자가 많을 경우 배치 처리 시간 증가
2. **포인트 중복 지급**: 시스템 오류로 인한 중복 지급 가능성
3. **데이터 일관성**: 포인트 조정 중 시스템 장애 발생 시 데이터 불일치

### 대응 방안
1. **배치 처리 최적화**: 청크 단위로 나누어 처리
2. **중복 방지 로직**: 조정 이력 확인 후 처리
3. **트랜잭션 처리**: Firestore 배치 트랜잭션 활용

## 📅 일정 계획

| 단계 | 작업 내용 | 예상 소요 시간 | 마감일 |
|------|-----------|---------------|--------|
| 분석 | 현재 상태 분석 완료 | 0.5일 | ✅ 완료 |
| 개발 | 포인트 정책 변경 구현 | 1일 | TBD |
| 테스트 | 단위/통합 테스트 | 0.5일 | TBD |
| 배포 | 프로덕션 적용 | 0.5일 | TBD |

**총 예상 기간**: 2.5일

---

*작성일: 2025-09-30*
*최종 수정일: 2025-09-30*