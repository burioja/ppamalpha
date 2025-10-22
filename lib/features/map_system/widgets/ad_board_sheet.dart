import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../post_system/services/ad_board_service.dart';

class AdBoardSheet extends StatefulWidget {
  final VoidCallback onCollectComplete;

  const AdBoardSheet({
    super.key,
    required this.onCollectComplete,
  });

  @override
  State<AdBoardSheet> createState() => _AdBoardSheetState();
}

class _AdBoardSheetState extends State<AdBoardSheet> {
  List<Map<String, dynamic>> _adBoardPosts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAdBoardPosts();
  }

  Future<void> _loadAdBoardPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      _adBoardPosts = await AdBoardService().fetchAdBoardPosts(
        countryCode: 'KR', // 기본값: 한국
        regionCode: null, // 전체 지역
      );
    } catch (e) {
      _errorMessage = '광고보드 포스트 로드 실패: $e';
      debugPrint(_errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _collectPost(String postId) async {
    try {
      await AdBoardService().collectAdBoardPost(postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('광고보드 포스트를 수령했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAdBoardPosts(); // 목록 새로고침
        widget.onCollectComplete(); // 맵 화면에 알림
      }
    } catch (e) {
      debugPrint('❌ 광고보드 포스트 수령 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수령 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '광고보드 포스트 (${_adBoardPosts.length}개)',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_errorMessage != null)
                Expanded(child: Center(child: Text(_errorMessage!)))
              else if (_adBoardPosts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('수령 가능한 광고보드 포스트가 없습니다.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _adBoardPosts.length,
                    itemBuilder: (context, index) {
                      final postData = _adBoardPosts[index];
                      final postId = postData['postId'] as String;
                      final title = postData['title'] as String? ?? '제목 없음';
                      final description = postData['description'] as String? ?? '';
                      final reward = postData['reward'] as int? ?? 0;
                      final remainingQuantity = postData['remainingQuantity'] as int? ?? 0;
                      final expiresAt = (postData['expiresAt'] as Timestamp?)?.toDate();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const Icon(Icons.campaign, color: Colors.orange),
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (description.isNotEmpty) Text(description),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.monetization_on, size: 16, color: Colors.green[600]),
                                  const SizedBox(width: 4),
                                  Text('$reward P', style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.inventory, size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 4),
                                  Text('남은 수량: $remainingQuantity', style: TextStyle(color: Colors.blue[600])),
                                ],
                              ),
                              if (expiresAt != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '만료: ${expiresAt.toLocal().toString().split(' ')[0]}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _collectPost(postId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('수령하기'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.25,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}
