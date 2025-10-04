import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/admin/cleanup_service.dart';
import '../../debug_firebase_check.dart';
import 'widgets/user_point_grant_dialog.dart';

/// 관리자용 데이터 정리 화면
class AdminCleanupScreen extends StatefulWidget {
  const AdminCleanupScreen({super.key});

  @override
  State<AdminCleanupScreen> createState() => _AdminCleanupScreenState();
}

class _AdminCleanupScreenState extends State<AdminCleanupScreen> {
  final CleanupService _cleanupService = CleanupService();
  bool _isLoading = false;
  Map<String, dynamic>? _lastResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 - 데이터 정리'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경고 메시지
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        '⚠️ 관리자 전용 도구',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '이 도구는 데이터베이스를 직접 수정합니다. 신중하게 사용하세요.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 고아 마커 정리
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧹 고아 마커 정리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '존재하지 않는 포스트를 참조하는 마커들을 찾아서 정리합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _cleanupOrphanedMarkers(dryRun: true),
                            icon: const Icon(Icons.search),
                            label: const Text('고아 마커 찾기 (삭제 안함)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : () => _cleanupOrphanedMarkers(dryRun: false),
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('고아 마커 삭제'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 사용자 포인트 지급
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 사용자 포인트 지급',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '특정 사용자에게 포인트를 지급합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showPointGrantDialog,
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('포인트 지급하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Firebase 디버그 체크
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Firebase 디버그 체크',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '특정 포스트 ID와 컬렉션 상태를 자세히 확인합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _runFirebaseDebugCheck,
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Firebase 디버그 실행'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _checkMarkersCollection,
                        icon: const Icon(Icons.location_on),
                        label: const Text('Markers 컬렉션 확인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _searchPostInAllCollections,
                        icon: const Icon(Icons.search),
                        label: const Text('특정 포스트 ID 전체 검색'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 컬렉션 상태 확인
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 컬렉션 상태 확인',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Firebase 컬렉션들의 존재 여부를 확인합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _checkCollections,
                        icon: const Icon(Icons.analytics),
                        label: const Text('컬렉션 상태 확인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isLoading) ...[
              const SizedBox(height: 24),
              const Center(
                child: CircularProgressIndicator(),
              ),
            ],

            if (_lastResult != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📋 실행 결과',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatResult(_lastResult!),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cleanupOrphanedMarkers({required bool dryRun}) async {
    setState(() => _isLoading = true);

    try {
      final result = await _cleanupService.cleanupOrphanedMarkers(dryRun: dryRun);
      setState(() => _lastResult = result);

      if (!mounted) return;

      final message = result['message'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result['status'] == 'success'
            ? (dryRun ? Colors.blue : Colors.green)
            : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('작업 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runFirebaseDebugCheck() async {
    setState(() => _isLoading = true);

    try {
      // 디버그 함수 실행 (콘솔에 로그 출력)
      await debugFirebaseCheck();

      if (!mounted) return;

      setState(() => _lastResult = {
        'status': 'debug_completed',
        'message': 'Firebase 디버그 체크가 완료되었습니다. 콘솔 로그를 확인하세요.',
        'note': '자세한 결과는 브라우저 개발자 도구의 콘솔 탭에서 확인할 수 있습니다.',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase 디버그 체크 완료 - 콘솔 로그 확인'),
          backgroundColor: Colors.purple,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('디버그 체크 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkCollections() async {
    setState(() => _isLoading = true);

    try {
      final result = await _cleanupService.getCollectionsSummary();
      setState(() => _lastResult = result);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('컬렉션 상태 확인 완료'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('확인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _checkMarkersForPost() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final targetPostId = 'fsTkJPcxCS2mPyJsIeA7';

      // markers 컬렉션에서 해당 postId 검색
      final markersQuery = await firestore
          .collection('markers')
          .where('postId', isEqualTo: targetPostId)
          .get();

      if (markersQuery.docs.isNotEmpty) {
        // markers에서 발견됨
        final markerData = markersQuery.docs.first.data();
        return {
          'status': 'found_in_markers',
          'message': '포스트 ID가 markers 컬렉션에서 발견됨!',
          'details': {
            'postId': targetPostId,
            'collection': 'markers',
            'documentId': markersQuery.docs.first.id,
            'markerData': markerData,
            'found_count': markersQuery.docs.length,
          }
        };
      } else {
        // markers에서도 없음
        return {
          'status': 'not_found',
          'message': 'markers 컬렉션에서도 해당 포스트 ID를 찾을 수 없음',
          'details': {
            'postId': targetPostId,
            'checked_collection': 'markers',
            'result': 'not_found'
          }
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'markers 컬렉션 확인 중 오류: $e',
        'error': e.toString()
      };
    }
  }

  Future<Map<String, dynamic>> _searchPostIdInAllCollections() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final targetPostId = 'fsTkJPcxCS2mPyJsIeA7';
      final results = <String, dynamic>{};

      // 검색할 컬렉션들과 필드들
      final searchTargets = {
        'posts': ['postId'],
        'markers': ['postId'],
        'post_collections': ['postId'],
        'flyers': ['postId', 'id'],
        'post_instances': ['postId'],
        'post_deployments': ['postId'],
      };

      for (final collection in searchTargets.keys) {
        final fields = searchTargets[collection]!;
        final collectionResults = <String, dynamic>{};

        for (final field in fields) {
          try {
            final query = await firestore
                .collection(collection)
                .where(field, isEqualTo: targetPostId)
                .get();

            collectionResults[field] = {
              'found': query.docs.isNotEmpty,
              'count': query.docs.length,
              'documents': query.docs.map((doc) => {
                'id': doc.id,
                'data': doc.data()
              }).toList()
            };
          } catch (e) {
            collectionResults[field] = {
              'error': e.toString(),
              'found': false
            };
          }
        }

        results[collection] = collectionResults;
      }

      // 결과 요약
      final foundIn = <String>[];
      for (final collection in results.keys) {
        final collectionData = results[collection] as Map<String, dynamic>;
        for (final field in collectionData.keys) {
          final fieldData = collectionData[field] as Map<String, dynamic>;
          if (fieldData['found'] == true) {
            foundIn.add('$collection.$field');
          }
        }
      }

      return {
        'status': foundIn.isNotEmpty ? 'found' : 'not_found',
        'message': foundIn.isNotEmpty
            ? '포스트 ID가 다음 위치에서 발견됨: ${foundIn.join(", ")}'
            : '모든 컬렉션에서 포스트 ID를 찾을 수 없음',
        'targetPostId': targetPostId,
        'foundIn': foundIn,
        'searchResults': results
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': '전체 검색 중 오류: $e',
        'error': e.toString()
      };
    }
  }

  Future<void> _checkMarkersCollection() async {
    setState(() => _isLoading = true);

    try {
      final result = await _checkMarkersForPost();
      setState(() => _lastResult = result);

      if (!mounted) return;

      final isSuccess = result['status'] != 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Markers 컬렉션 확인 완료'),
          backgroundColor: isSuccess ? Colors.orange : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Markers 확인 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchPostInAllCollections() async {
    setState(() => _isLoading = true);

    try {
      final result = await _searchPostIdInAllCollections();
      setState(() => _lastResult = result);

      if (!mounted) return;

      final isSuccess = result['status'] != 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '전체 검색 완료'),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('전체 검색 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showPointGrantDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const UserPointGrantDialog(),
    );

    if (result != null && result['success'] == true) {
      if (!mounted) return;

      final email = result['email'];
      final userName = result['userName'];
      final points = result['points'];
      final reason = result['reason'];

      setState(() => _lastResult = {
        'status': 'success',
        'message': '포인트 지급 완료',
        'details': {
          '이메일': email,
          '사용자': userName,
          '지급 포인트': '$points P',
          '지급 사유': reason,
        },
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $userName($email)님에게 $points 포인트를 지급했습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatResult(Map<String, dynamic> result) {
    final buffer = StringBuffer();

    void addLine(String key, dynamic value, [int indent = 0]) {
      final spaces = '  ' * indent;
      if (value is Map) {
        buffer.writeln('$spaces$key:');
        for (final entry in value.entries) {
          addLine(entry.key, entry.value, indent + 1);
        }
      } else {
        buffer.writeln('$spaces$key: $value');
      }
    }

    for (final entry in result.entries) {
      addLine(entry.key, entry.value);
    }

    return buffer.toString();
  }
}