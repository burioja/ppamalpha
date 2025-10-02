# 쿠폰 사용 기능 개선

## 📋 과제 개요
**과제 ID**: TASK-007
**제목**: 쿠폰 사용 기능 개선
**우선순위**: ⭐⭐ 중간
**담당자**: TBD
**상태**: 🔄 계획 중

## 🎯 요구사항 분석

### 사용자 요구사항
1. **사용 확인 다이얼로그**: 쿠폰 사용 시 "사용하겠습니까?" 확인 절차
2. **사장 승인 시스템**: 사장이 승인을 눌러야 할인 적용
3. **간단한 할인 적용**: 실물 계산 시 할인, 앱과 크게 상관없는 단순 구조
4. **사용자 경험 개선**: 직관적이고 명확한 쿠폰 사용 프로세스

### 비즈니스 요구사항
- 쿠폰 오남용 방지를 위한 이중 확인 시스템
- 매장 운영진의 할인 승인 권한 보장
- 사용자와 매장 간의 신뢰할 수 있는 쿠폰 시스템

## 🔍 현재 상태 분석

### 기존 구현사항
```dart
// lib/features/post_system/widgets/coupon_usage_dialog.dart 분석 결과

✅ 구현 완료:
- CouponUsageDialog: 기본 쿠폰 사용 다이얼로그
- CouponSuccessDialog: 사용 완료 다이얼로그
- 암호 검증 시스템
- 햅틱 피드백
- 사용자 친화적 UI

🔄 개선 필요:
- 사용 확인 다이얼로그 추가
- 사장 승인 프로세스 구현
- 할인 적용 프로세스 간소화
```

### 현재 쿠폰 사용 플로우
```
1. 사용자가 쿠폰 사용 버튼 클릭
2. CouponUsageDialog 표시
3. 암호 입력 및 검증
4. CouponSuccessDialog 표시
5. 포인트 적립 완료
```

## ✅ 구현 계획

### Phase 1: 사용 확인 다이얼로그 추가
- [ ] 쿠폰 사용 전 확인 다이얼로그 구현
- [ ] 쿠폰 정보 및 할인 내용 표시
- [ ] 사용자 의사 재확인 절차

### Phase 2: 사장 승인 시스템 구현
- [ ] 사장/매장 관리자 승인 다이얼로그
- [ ] 승인 권한 검증 시스템
- [ ] 승인 거부 시 처리 로직

### Phase 3: 할인 적용 프로세스 간소화
- [ ] 실물 계산 연동 최소화
- [ ] 할인 확인 메시지 개선
- [ ] 사용 완료 피드백 최적화

## 🛠 구현 상세

### 1. 사용 확인 다이얼로그

```dart
class CouponConfirmDialog extends StatelessWidget {
  final String postTitle;
  final String placeName;
  final int discountAmount;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CouponConfirmDialog({
    super.key,
    required this.postTitle,
    required this.placeName,
    required this.discountAmount,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.local_offer,
              color: Colors.orange[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '쿠폰 사용 확인',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 쿠폰 정보 카드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[50]!, Colors.orange[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.discount,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '쿠폰 정보',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('포스트', postTitle),
                const SizedBox(height: 8),
                _buildInfoRow('장소', placeName),
                const SizedBox(height: 8),
                _buildInfoRow('할인 혜택', '${discountAmount}원 할인'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 사용 안내
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue[600],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '쿠폰을 사용하시겠습니까?\n사장님의 승인 후 할인이 적용됩니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[700],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(
            '취소',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange[600],
          ),
          child: const Text('사용하기'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
```

### 2. 사장 승인 시스템

```dart
class ManagerApprovalDialog extends StatefulWidget {
  final String postTitle;
  final String placeName;
  final int discountAmount;
  final String customerInfo;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ManagerApprovalDialog({
    super.key,
    required this.postTitle,
    required this.placeName,
    required this.discountAmount,
    required this.customerInfo,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends State<ManagerApprovalDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.admin_panel_settings,
              color: Colors.purple[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '쿠폰 사용 승인',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 승인 요청 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '쿠폰 사용 승인 요청',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildApprovalInfoRow('포스트', widget.postTitle),
                _buildApprovalInfoRow('고객 정보', widget.customerInfo),
                _buildApprovalInfoRow('할인 금액', '${widget.discountAmount}원'),
                _buildApprovalInfoRow('장소', widget.placeName),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 승인 안내
          Text(
            '고객이 쿠폰 사용을 요청했습니다.\n할인을 승인하시겠습니까?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),

          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : _handleReject,
          child: Text(
            '거부',
            style: TextStyle(color: Colors.red[600]),
          ),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _handleApprove,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green[600],
          ),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('승인'),
        ),
      ],
    );
  }

  Widget _buildApprovalInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.purple[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleApprove() {
    setState(() {
      _isProcessing = true;
    });

    // 승인 처리 (약간의 지연 후 실행)
    Future.delayed(const Duration(milliseconds: 800), () {
      HapticFeedback.lightImpact();
      widget.onApprove();
    });
  }

  void _handleReject() {
    HapticFeedback.vibrate();
    widget.onReject();
  }
}
```

### 3. 개선된 쿠폰 사용 플로우

```dart
class CouponUsageController {
  static Future<void> showCouponUsageFlow({
    required BuildContext context,
    required String postTitle,
    required String placeName,
    required int discountAmount,
    required String expectedPassword,
    required VoidCallback onSuccess,
  }) async {
    try {
      // Step 1: 사용 확인
      final confirmResult = await _showConfirmDialog(
        context: context,
        postTitle: postTitle,
        placeName: placeName,
        discountAmount: discountAmount,
      );

      if (!confirmResult) return;

      // Step 2: 암호 입력
      final passwordResult = await _showPasswordDialog(
        context: context,
        postTitle: postTitle,
        placeName: placeName,
        expectedPassword: expectedPassword,
      );

      if (!passwordResult) return;

      // Step 3: 사장 승인
      final approvalResult = await _showManagerApproval(
        context: context,
        postTitle: postTitle,
        placeName: placeName,
        discountAmount: discountAmount,
      );

      if (!approvalResult) {
        _showRejectionMessage(context);
        return;
      }

      // Step 4: 성공 처리
      onSuccess();
      _showSuccessDialog(
        context: context,
        postTitle: postTitle,
        discountAmount: discountAmount,
      );

    } catch (e) {
      _showErrorDialog(context, e.toString());
    }
  }

  static Future<bool> _showConfirmDialog({
    required BuildContext context,
    required String postTitle,
    required String placeName,
    required int discountAmount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CouponConfirmDialog(
        postTitle: postTitle,
        placeName: placeName,
        discountAmount: discountAmount,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  static Future<bool> _showPasswordDialog({
    required BuildContext context,
    required String postTitle,
    required String placeName,
    required String expectedPassword,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CouponUsageDialog(
        postTitle: postTitle,
        placeName: placeName,
        expectedPassword: expectedPassword,
        onSuccess: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  static Future<bool> _showManagerApproval({
    required BuildContext context,
    required String postTitle,
    required String placeName,
    required int discountAmount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManagerApprovalDialog(
        postTitle: postTitle,
        placeName: placeName,
        discountAmount: discountAmount,
        customerInfo: '익명 고객', // 또는 실제 고객 정보
        onApprove: () => Navigator.of(context).pop(true),
        onReject: () => Navigator.of(context).pop(false),
      ),
    );
    return result ?? false;
  }

  static void _showSuccessDialog({
    required BuildContext context,
    required String postTitle,
    required int discountAmount,
  }) {
    showDialog(
      context: context,
      builder: (context) => CouponSuccessDialog(
        postTitle: postTitle,
        rewardPoints: discountAmount,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  static void _showRejectionMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('사장님이 쿠폰 사용을 거부했습니다.'),
        backgroundColor: Colors.orange[600],
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text('쿠폰 사용 중 오류가 발생했습니다:\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
```

## 📊 테스트 시나리오

### 시나리오 1: 정상적인 쿠폰 사용
1. 쿠폰 사용 버튼 클릭
2. 사용 확인 다이얼로그에서 "사용하기" 선택
3. 올바른 암호 입력
4. 사장 승인 다이얼로그에서 "승인" 선택
5. 성공 다이얼로그 표시 및 할인 적용

### 시나리오 2: 사용자 취소
1. 사용 확인 다이얼로그에서 "취소" 선택
2. 쿠폰 사용 프로세스 중단

### 시나리오 3: 잘못된 암호
1. 사용 확인 후 잘못된 암호 입력
2. 오류 메시지 표시 및 재입력 요청

### 시나리오 4: 사장 승인 거부
1. 정상적인 암호 입력 후 사장 승인 단계
2. 사장이 "거부" 선택
3. 거부 메시지 표시 및 프로세스 중단

## 📝 체크리스트

### 개발 단계
- [ ] CouponConfirmDialog 구현
- [ ] ManagerApprovalDialog 구현
- [ ] CouponUsageController 통합 플로우 구현
- [ ] 기존 CouponUsageDialog와 연동
- [ ] 오류 처리 및 사용자 피드백 개선

### 테스트 단계
- [ ] 전체 쿠폰 사용 플로우 테스트
- [ ] 각 단계별 취소/거부 시나리오 테스트
- [ ] 오류 상황 처리 테스트
- [ ] 다양한 디바이스에서 UI 테스트

### 배포 단계
- [ ] 코드 리뷰 완료
- [ ] QA 검증 완료
- [ ] 매장 운영진 교육 자료 준비
- [ ] 프로덕션 배포

## 🚨 위험 요소 및 대응 방안

### 위험 요소
1. **복잡한 승인 프로세스**: 다단계 확인으로 인한 사용자 불편
2. **매장 운영진 교육**: 새로운 승인 시스템에 대한 이해 부족
3. **네트워크 오류**: 승인 과정 중 연결 문제 발생

### 대응 방안
1. **직관적인 UI**: 각 단계를 명확히 안내하는 사용자 인터페이스
2. **교육 자료 제공**: 매장 운영진을 위한 가이드 문서
3. **오프라인 모드**: 네트워크 오류 시 임시 승인 메커니즘

## 📅 일정 계획

| 단계 | 작업 내용 | 예상 소요 시간 | 마감일 |
|------|-----------|---------------|--------|
| 분석 | 현재 상태 분석 완료 | 0.5일 | ✅ 완료 |
| 개발 | 확인 다이얼로그 및 승인 시스템 구현 | 1일 | TBD |
| 통합 | 전체 플로우 통합 및 테스트 | 0.5일 | TBD |
| 문서화 | 사용자 및 매장 가이드 작성 | 0.5일 | TBD |

**총 예상 기간**: 2.5일

---

*작성일: 2025-09-30*
*최종 수정일: 2025-09-30*