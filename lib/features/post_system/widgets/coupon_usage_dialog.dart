import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 쿠폰 사용 확인 다이얼로그 (첫 번째 단계)
class CouponConfirmDialog extends StatelessWidget {
  final String postTitle;
  final String placeName;
  final int rewardPoints;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CouponConfirmDialog({
    super.key,
    required this.postTitle,
    required this.placeName,
    required this.rewardPoints,
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
              Icons.confirmation_number,
              color: Colors.orange[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '쿠폰 사용 확인',
              style: TextStyle(
                fontSize: 20,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_offer, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        postTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        placeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      '예상 포인트: $rewardPoints P',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '이 쿠폰을 사용하시겠습니까?\n\n다음 단계에서 사장님의 승인이 필요합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                      height: 1.4,
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
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text('사용하기'),
        ),
      ],
    );
  }
}

class CouponUsageDialog extends StatefulWidget {
  final String postTitle;
  final String placeName;
  final String expectedPassword;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const CouponUsageDialog({
    super.key,
    required this.postTitle,
    required this.placeName,
    required this.expectedPassword,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<CouponUsageDialog> createState() => _CouponUsageDialogState();
}

class _CouponUsageDialogState extends State<CouponUsageDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _validateAndUseCoupon() {
    final inputPassword = _passwordController.text.trim();

    if (inputPassword.isEmpty) {
      setState(() {
        _errorMessage = '암호를 입력해주세요';
      });
      return;
    }

    if (inputPassword != widget.expectedPassword) {
      setState(() {
        _errorMessage = '잘못된 암호입니다. 다시 시도해주세요';
      });

      // 잘못된 암호 입력 시 햅틱 피드백
      HapticFeedback.vibrate();

      // 텍스트 필드를 흔들기 애니메이션 (선택사항)
      _passwordController.clear();
      return;
    }

    // 암호가 맞으면 성공 처리
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 성공 햅틱 피드백
    HapticFeedback.lightImpact();

    // 약간의 지연 후 성공 콜백 호출 (사용자 경험 개선)
    Future.delayed(const Duration(milliseconds: 500), () {
      widget.onSuccess();
    });
  }

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
              '쿠폰 사용',
              style: TextStyle(
                fontSize: 20,
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
          // 포스트 및 플레이스 정보
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '포스트: ${widget.postTitle}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '장소: ${widget.placeName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 안내 메시지
          Text(
            '해당 장소에서 설정한 쿠폰 사용 암호를 입력해주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),

          const SizedBox(height: 12),

          // 암호 입력 필드
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '쿠폰 사용 암호',
              hintText: '암호를 입력하세요',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              errorText: _errorMessage,
            ),
            obscureText: !_isPasswordVisible,
            enabled: !_isLoading,
            autofocus: true,
            onSubmitted: (_) => _validateAndUseCoupon(),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : widget.onCancel,
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _validateAndUseCoupon,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('사용하기'),
        ),
      ],
    );
  }
}

// 쿠폰 사용 성공 다이얼로그
class CouponSuccessDialog extends StatelessWidget {
  final String postTitle;
  final int rewardPoints;
  final VoidCallback onClose;

  const CouponSuccessDialog({
    super.key,
    required this.postTitle,
    required this.rewardPoints,
    required this.onClose,
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
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green[700],
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '쿠폰 사용 완료',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.celebration,
                  size: 48,
                  color: Colors.green[600],
                ),
                const SizedBox(height: 12),
                Text(
                  '$rewardPoints 포인트 적립!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '쿠폰이 성공적으로 사용되었습니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: onClose,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('확인'),
        ),
      ],
    );
  }
}

/// 사장 승인 다이얼로그
class ManagerApprovalDialog extends StatefulWidget {
  final String postTitle;
  final String placeName;
  final int rewardPoints;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ManagerApprovalDialog({
    super.key,
    required this.postTitle,
    required this.placeName,
    required this.rewardPoints,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends State<ManagerApprovalDialog> {
  bool _isProcessing = false;

  void _handleApproval(bool approved) {
    setState(() {
      _isProcessing = true;
    });

    // 햅틱 피드백
    HapticFeedback.lightImpact();

    // 약간의 지연 후 콜백 호출 (사용자 경험 개선)
    Future.delayed(const Duration(milliseconds: 300), () {
      if (approved) {
        widget.onApprove();
      } else {
        widget.onReject();
      }
    });
  }

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
              '사장님 승인 요청',
              style: TextStyle(
                fontSize: 20,
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
          // 쿠폰 정보
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_offer, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.postTitle,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.placeName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      '할인 적용: ${widget.rewardPoints} P',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 안내 메시지
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.amber[900]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '고객이 쿠폰 사용을 요청했습니다.\n할인을 적용하시겠습니까?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => _handleApproval(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('거부'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : () => _handleApproval(true),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
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
}