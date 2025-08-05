import 'package:flutter/material.dart';
import '../../services/database_migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final DatabaseMigrationService _migrationService = DatabaseMigrationService();
  bool _isLoading = false;
  String _status = '대기 중';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터베이스 마이그레이션'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRD 구조에 맞게 데이터베이스를 업데이트합니다',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '업데이트 내용:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• Users 컬렉션 구조 업데이트'),
            const Text('• Places 컬렉션 생성'),
            const Text('• 사용자 프로필 관리 기능 생성'),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _inspectDataStructure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('데이터 구조 확인'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _runMigration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('마이그레이션 실행'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            if (_isLoading)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('상태: $_status'),
                ],
              )
            else
              const SizedBox.shrink(),
            
            const SizedBox(height: 24),
            const Text(
              '주의사항:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('• 기존 데이터가 업데이트됩니다'),
            const Text('• 실행 중에는 앱을 종료하지 마세요'),
            const Text('• 완료 후 앱을 재시작하세요'),
          ],
        ),
      ),
    );
  }

  Future<void> _inspectDataStructure() async {
    setState(() {
      _isLoading = true;
      _status = '데이터 구조 확인 중...';
    });

    try {
      await _migrationService.inspectDataStructure();
      
      setState(() {
        _status = '데이터 구조 확인 완료';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데이터 구조 확인이 완료되었습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        _status = '오류 발생: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _runMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('마이그레이션 실행'),
        content: const Text('데이터베이스 마이그레이션을 실행하시겠습니까?\n\n기존 데이터가 업데이트됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('실행'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _status = '마이그레이션 실행 중...';
    });

    try {
      await _migrationService.runMigration();
      
      setState(() {
        _status = '마이그레이션 완료';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이그레이션이 완료되었습니다.')),
        );
      }
    } catch (e) {
      setState(() {
        _status = '오류 발생: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('마이그레이션 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }
} 
