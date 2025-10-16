import 'package:flutter/material.dart';

/// UI 헬퍼 함수들
/// 
/// 간단한 UI 유틸리티 (토스트, 다이얼로그 등)
class MapUIHelper {
  /// 토스트 메시지 표시
  static void showToast(BuildContext context, String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 위치 권한 요청 다이얼로그
  static void showLocationPermissionDialog(
    BuildContext context, {
    required VoidCallback onRetry,
    VoidCallback? onLater,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('위치 서비스 필요'),
            ],
          ),
          content: const Text(
            '지도에서 마커를 보려면 GPS를 활성화해주세요.\n\n'
            '설정 > 개인정보 보호 및 보안 > 위치 서비스에서\n'
            '앱의 위치 권한을 허용해주세요.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onRetry();
              },
              child: const Text('다시 시도'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onLater?.call();
              },
              child: const Text('나중에'),
            ),
          ],
        );
      },
    );
  }

  /// 제한된 배포 알림 다이얼로그
  static void showRestrictedDeployDialog(
    BuildContext context, {
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('제한된 배포 영역'),
            ],
          ),
          content: const Text(
            '이 영역은 회색 영역(Fog Level 2)입니다.\n\n'
            '이 위치에 포스트를 배포하시겠습니까?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onCancel?.call();
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('배포'),
            ),
          ],
        );
      },
    );
  }

  /// 배포 차단 메시지 표시
  static void showBlockedDeployMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red),
              SizedBox(width: 8),
              Text('배포 불가'),
            ],
          ),
          content: const Text(
            '이 영역은 검은색 영역(Fog Level 3)입니다.\n\n'
            '포스트를 배포할 수 없습니다.\n'
            '해당 위치를 직접 방문하여 Fog Level을 낮춰주세요.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 수령 가능 포스트 FAB 빌더
  static Widget buildReceiveFab({
    required int count,
    required bool isReceiving,
    required VoidCallback onPressed,
  }) {
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton.extended(
      onPressed: isReceiving ? null : onPressed,
      backgroundColor: isReceiving ? Colors.grey : Colors.green,
      icon: isReceiving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.card_giftcard),
      label: Text(
        isReceiving ? '수령 중...' : '포스트 $count개 수령',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// 에러 다이얼로그 표시
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 성공 다이얼로그 표시
  static void showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm?.call();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 확인 다이얼로그 표시
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: confirmColor != null
                  ? ElevatedButton.styleFrom(backgroundColor: confirmColor)
                  : null,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// 로딩 다이얼로그 표시
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(message ?? '처리 중...'),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 로딩 다이얼로그 닫기
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
}

