import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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