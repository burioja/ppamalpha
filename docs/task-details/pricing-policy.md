# 포스트 작성 가격 정책 개선

## 📋 과제 개요
**과제 ID**: TASK-002
**제목**: 포스트 작성 가격 정책 개선
**우선순위**: ⭐⭐⭐ 높음
**담당자**: TBD
**상태**: 🔄 계획 중

## 🎯 요구사항 분석

### 사용자 요구사항
1. **최소 가격 보장**: 용량 고려 가격이 200원이면 최소 200원 보장
2. **100원 단위 올림**: 149원 → 200원, 201원 → 300원으로 자동 올림
3. **가격 입력 제한**: 계산된 최소가격보다 낮은 가격 입력 불가

### 비즈니스 요구사항
- 미디어 용량에 비례한 공정한 가격 책정
- 사용자 편의성을 위한 직관적인 가격 단위
- 컨텐츠 품질 대비 적절한 보상 체계

## 🔍 현재 상태 분석

### 기존 구현사항
```dart
// lib/features/post_system/widgets/price_calculator.dart 분석 결과

✅ 구현 완료:
- 미디어 용량 기반 가격 계산 (100KB당 100원)
- 실시간 가격 업데이트
- 가격 유효성 검증
- 최소 가격 표시 및 안내

🔄 수정 필요:
- 100원 단위 올림 로직 추가
- 최소 가격 보장 로직 강화
```

### 현재 가격 계산 로직
```dart
// 현재 로직 (line 163-164)
_minimumPrice = (_totalSizeKB / 100.0) * _basePricePer100KB;

// 예시:
// 149KB → 149/100 * 100 = 149원
// 201KB → 201/100 * 100 = 201원
```

## ✅ 구현 계획

### Phase 1: 100원 단위 올림 로직 구현
- [ ] `_calculateMinimumPrice()` 메서드에 올림 로직 추가
- [ ] 올림된 가격을 UI에 표시
- [ ] 올림 전후 가격 비교 표시 (선택사항)

### Phase 2: 최소 가격 보장 강화
- [ ] 미디어가 있을 때 1원이라도 높아야 작성 가능하도록 검증
- [ ] 가격 입력 시 즉시 검증 및 피드백
- [ ] 자동 가격 설정 로직 개선

### Phase 3: 사용자 경험 개선
- [ ] 가격 계산 과정 표시
- [ ] 올림된 가격에 대한 안내 메시지
- [ ] 가격 변경 시 즉시 반영

## 🛠 구현 상세

### 1. 100원 단위 올림 로직

```dart
void _calculateMinimumPrice() {
  print('=== [_calculateMinimumPrice] 시작 ===');
  _totalSizeKB = 0.0;

  // ... 기존 미디어 크기 계산 로직 ...

  // 기본 최소 단가 계산 (100KB당 100원)
  double rawMinimumPrice = (_totalSizeKB / 100.0) * _basePricePer100KB;

  // 100원 단위 올림 적용
  _minimumPrice = _roundUpToHundred(rawMinimumPrice);

  print('원본 계산 가격: ${rawMinimumPrice.toStringAsFixed(0)}원');
  print('100원 단위 올림 후: ${_minimumPrice.toStringAsFixed(0)}원');

  setState(() {});

  // 계산 완료 콜백 호출
  if (widget.onPriceCalculated != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPriceCalculated!();
    });
  }
}

/// 100원 단위로 올림 처리
double _roundUpToHundred(double price) {
  if (price <= 0) return 0;

  // 100원 단위로 올림
  // 예: 149.0 → 200.0, 201.0 → 300.0, 200.0 → 200.0
  return (price / 100).ceil() * 100.0;
}
```

### 2. 최소 가격 보장 로직 강화

```dart
String? _validatePrice(String? value) {
  if (value == null || value.isEmpty) {
    return '단가를 입력해주세요';
  }

  final double? price = double.tryParse(value);
  if (price == null) {
    return '올바른 숫자를 입력해주세요';
  }

  if (price < 0) {
    return '단가는 0 이상이어야 합니다';
  }

  // 미디어가 있는 경우 최소 단가 검증 강화
  if (_totalSizeKB > 0) {
    // 조건 1: 계산된 최소가격보다 낮으면 안됨
    if (price < _minimumPrice) {
      return '최소 단가는 ${_minimumPrice.toInt()}원 이상이어야 합니다';
    }

    // 조건 2: 미디어가 있으면 1원이라도 높아야 함 (추가 보장)
    if (price == 0) {
      return '미디어가 포함된 포스트는 무료로 작성할 수 없습니다';
    }
  }

  // 사용자 정의 validator가 있는 경우 호출
  if (widget.validator != null) {
    return widget.validator!(value);
  }

  return null;
}
```

### 3. UI 개선

```dart
@override
Widget build(BuildContext context) {
  final bool hasMedia = _totalSizeKB > 0;
  final double rawPrice = hasMedia ? (_totalSizeKB / 100.0) * _basePricePer100KB : 0;
  final bool isPriceRoundedUp = hasMedia && _minimumPrice > rawPrice;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '단가',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: widget.priceController,
        decoration: InputDecoration(
          labelText: '단가 (원)',
          border: const OutlineInputBorder(),
          suffixText: '원',
          helperText: hasMedia
              ? '미디어 포함 시 최소 단가: ${_minimumPrice.toInt()}원 (${_totalSizeKB.toStringAsFixed(1)}KB)'
              : '미디어 추가 시 자동으로 최소 단가가 계산됩니다',
        ),
        keyboardType: TextInputType.number,
        validator: _validatePrice,
      ),

      // 가격 계산 정보 표시
      if (hasMedia) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '총 미디어 크기: ${_totalSizeKB.toStringAsFixed(1)}KB',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '기본 계산: ${rawPrice.toStringAsFixed(0)}원 (100KB당 ${_basePricePer100KB.toInt()}원)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[600],
                ),
              ),
              if (isPriceRoundedUp) ...[
                const SizedBox(height: 2),
                Text(
                  '100원 단위 올림: ${_minimumPrice.toInt()}원',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}
```

## 📊 테스트 시나리오

### 시나리오 1: 100원 단위 올림 검증
| 용량 | 기본 계산 | 올림 후 | 예상 결과 |
|------|-----------|---------|-----------|
| 49KB | 49원 | 100원 | ✅ |
| 149KB | 149원 | 200원 | ✅ |
| 200KB | 200원 | 200원 | ✅ |
| 201KB | 201원 | 300원 | ✅ |

### 시나리오 2: 최소 가격 보장 검증
1. 149KB 이미지 업로드 → 최소가격 200원 표시
2. 가격 필드에 150원 입력 → 오류 메시지 표시
3. 가격 필드에 200원 입력 → 검증 통과
4. 가격 필드에 250원 입력 → 검증 통과

### 시나리오 3: 자동 가격 설정 검증
1. 빈 가격 필드에서 이미지 업로드
2. 자동으로 최소가격(올림된) 설정 확인
3. 현재 가격이 최소가격보다 낮으면 자동 업데이트 확인

## 📝 체크리스트

### 개발 단계
- [ ] `_roundUpToHundred()` 메서드 구현
- [ ] `_calculateMinimumPrice()` 메서드 수정
- [ ] `_validatePrice()` 메서드 강화
- [ ] UI 개선 (가격 계산 과정 표시)
- [ ] 자동 가격 설정 로직 개선

### 테스트 단계
- [ ] 100원 단위 올림 로직 테스트
- [ ] 최소 가격 보장 테스트
- [ ] 가격 유효성 검증 테스트
- [ ] UI 업데이트 테스트

### 배포 단계
- [ ] 코드 리뷰 완료
- [ ] QA 검증 완료
- [ ] 프로덕션 배포

## 🚨 위험 요소 및 대응 방안

### 위험 요소
1. **가격 정책 변경으로 인한 사용자 혼란**: 기존 사용자가 가격 변경을 이해하지 못할 수 있음
2. **계산 오류**: 올림 로직에서 수학적 오류 발생 가능성
3. **성능 영향**: 실시간 가격 계산으로 인한 UI 지연

### 대응 방안
1. **사용자 안내**: 가격 계산 과정을 명확히 표시
2. **철저한 테스트**: 다양한 용량에 대한 테스트 케이스 작성
3. **최적화**: 불필요한 재계산 방지

## 📅 일정 계획

| 단계 | 작업 내용 | 예상 소요 시간 | 마감일 |
|------|-----------|---------------|--------|
| 분석 | 현재 상태 분석 완료 | 0.5일 | ✅ 완료 |
| 개발 | 올림 로직 및 검증 강화 | 1일 | TBD |
| 테스트 | 다양한 시나리오 테스트 | 0.5일 | TBD |
| 배포 | 프로덕션 적용 | 0.5일 | TBD |

**총 예상 기간**: 2.5일

---

*작성일: 2025-09-30*
*최종 수정일: 2025-09-30*