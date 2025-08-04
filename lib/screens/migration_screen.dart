import 'package:flutter/material.dart';
import '../services/database_migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final DatabaseMigrationService _migrationService = DatabaseMigrationService();
  bool _isLoading = false;
  String _status = '?��?�?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('?�이?�베?�스 마이그레?�션'),
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
              'PRD 구조??맞게 ?�이?�베?�스�??�데?�트?�니??',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '?�데?�트???�용:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('??Users 컬렉??구조 ?�데?�트'),
            const Text('??Places 컬렉???�성'),
            const Text('???�용???�레?�스 관�??�성'),
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
                    child: const Text('?�이??구조 ?�인'),
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
                    child: const Text('마이그레?�션 ?�행'),
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
                  Text('?�태: $_status'),
                ],
              )
            else
              const SizedBox.shrink(),
            
            const SizedBox(height: 24),
            const Text(
              '주의?�항:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('??기존 ?�이?��? ?�데?�트?�니??),
            const Text('???�행 중에???�을 종료?��? 마세??),
            const Text('???�료 ???�을 ?�시?�하?�요'),
          ],
        ),
      ),
    );
  }

  Future<void> _inspectDataStructure() async {
    setState(() {
      _isLoading = true;
      _status = '?�이??구조 ?�인 �?..';
    });

    try {
      await _migrationService.inspectDataStructure();
      
      setState(() {
        _status = '?�이??구조 ?�인 ?�료!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?�이??구조 ?�인???�료?�었?�니?? 콘솔???�인?�세??'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '?�류 발생: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?�이??구조 ?�인 �??�류가 발생?�습?�다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
      _status = '마이그레?�션 ?�작...';
    });

    try {
      await _migrationService.runMigration();
      
      setState(() {
        _status = '마이그레?�션 ?�료!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?�이?�베?�스 마이그레?�션???�료?�었?�니??'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '?�류 발생: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마이그레?�션 �??�류가 발생?�습?�다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 
