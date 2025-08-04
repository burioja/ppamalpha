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
  String _status = '?€ê¸?ì¤?;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('?°ì´?°ë² ?´ìŠ¤ ë§ˆì´ê·¸ë ˆ?´ì…˜'),
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
              'PRD êµ¬ì¡°??ë§ê²Œ ?°ì´?°ë² ?´ìŠ¤ë¥??…ë°?´íŠ¸?©ë‹ˆ??',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '?…ë°?´íŠ¸???´ìš©:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('??Users ì»¬ë ‰??êµ¬ì¡° ?…ë°?´íŠ¸'),
            const Text('??Places ì»¬ë ‰???ì„±'),
            const Text('???¬ìš©???Œë ˆ?´ìŠ¤ ê´€ê³??ì„±'),
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
                    child: const Text('?°ì´??êµ¬ì¡° ?•ì¸'),
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
                    child: const Text('ë§ˆì´ê·¸ë ˆ?´ì…˜ ?¤í–‰'),
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
                  Text('?íƒœ: $_status'),
                ],
              )
            else
              const SizedBox.shrink(),
            
            const SizedBox(height: 24),
            const Text(
              'ì£¼ì˜?¬í•­:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('??ê¸°ì¡´ ?°ì´?°ê? ?…ë°?´íŠ¸?©ë‹ˆ??),
            const Text('???¤í–‰ ì¤‘ì—???±ì„ ì¢…ë£Œ?˜ì? ë§ˆì„¸??),
            const Text('???„ë£Œ ???±ì„ ?¬ì‹œ?‘í•˜?¸ìš”'),
          ],
        ),
      ),
    );
  }

  Future<void> _inspectDataStructure() async {
    setState(() {
      _isLoading = true;
      _status = '?°ì´??êµ¬ì¡° ?•ì¸ ì¤?..';
    });

    try {
      await _migrationService.inspectDataStructure();
      
      setState(() {
        _status = '?°ì´??êµ¬ì¡° ?•ì¸ ?„ë£Œ!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?°ì´??êµ¬ì¡° ?•ì¸???„ë£Œ?˜ì—ˆ?µë‹ˆ?? ì½˜ì†”???•ì¸?˜ì„¸??'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '?¤ë¥˜ ë°œìƒ: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('?°ì´??êµ¬ì¡° ?•ì¸ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤: $e'),
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
      _status = 'ë§ˆì´ê·¸ë ˆ?´ì…˜ ?œì‘...';
    });

    try {
      await _migrationService.runMigration();
      
      setState(() {
        _status = 'ë§ˆì´ê·¸ë ˆ?´ì…˜ ?„ë£Œ!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('?°ì´?°ë² ?´ìŠ¤ ë§ˆì´ê·¸ë ˆ?´ì…˜???„ë£Œ?˜ì—ˆ?µë‹ˆ??'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '?¤ë¥˜ ë°œìƒ: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ë§ˆì´ê·¸ë ˆ?´ì…˜ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤: $e'),
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
