import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/points_service.dart';

class UserPointGrantDialog extends StatefulWidget {
  const UserPointGrantDialog({super.key});

  @override
  State<UserPointGrantDialog> createState() => _UserPointGrantDialogState();
}

class _UserPointGrantDialogState extends State<UserPointGrantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pointsController = TextEditingController();
  final _reasonController = TextEditingController();
  final _pointsService = PointsService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _grantPoints() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final points = int.parse(_pointsController.text);
      final reason = _reasonController.text.trim().isEmpty
          ? '관리자 포인트 지급'
          : _reasonController.text.trim();

      // 이메일로 사용자 찾기
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('해당 이메일의 사용자를 찾을 수 없습니다');
      }

      final userId = userQuery.docs.first.id;
      final userName = userQuery.docs.first.data()['nickname'] ?? email;

      // 포인트 지급
      await _pointsService.addPoints(userId, points, reason);

      if (mounted) {
        Navigator.pop(context, {
          'success': true,
          'email': email,
          'userName': userName,
          'points': points,
          'reason': reason,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포인트 지급 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사용자 포인트 지급'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '사용자 이메일',
                  hintText: 'user@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력하세요';
                  }
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pointsController,
                decoration: const InputDecoration(
                  labelText: '지급할 포인트',
                  hintText: '1000',
                  prefixIcon: Icon(Icons.stars),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '포인트를 입력하세요';
                  }
                  final points = int.tryParse(value);
                  if (points == null) {
                    return '유효한 숫자를 입력하세요';
                  }
                  if (points <= 0) {
                    return '포인트는 0보다 커야 합니다';
                  }
                  if (points > 1000000) {
                    return '한 번에 1,000,000 포인트를 초과할 수 없습니다';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: '지급 사유 (선택사항)',
                  hintText: '관리자 포인트 지급',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _grantPoints,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check),
          label: Text(_isLoading ? '처리중...' : '지급'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}