import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../utils/web_dom_stub.dart'
    if (dart.library.html) '../../utils/web_dom.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/network_image_fallback_stub.dart'
    if (dart.library.html) '../../widgets/network_image_fallback_web.dart';
import '../../routes/app_routes.dart';
import '../../services/place_service.dart';
import '../../services/post_service.dart';
import '../../models/place_model.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final bool isEditable;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.isEditable,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostModel currentPost;

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포스트 상세'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editPost(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentPost.placeId != null) _buildPlacePreview(context),
            // 포스트 헤더
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                           _getPostTypeIcon(_primaryMediaType()),
                           color: Colors.white,
                           size: 32,
                         ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentPost.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                               '${_primaryMediaType()} • ${currentPost.reward}포인트',
                               style: TextStyle(
                                 fontSize: 14,
                                 color: Colors.blue.shade700,
                                 fontWeight: FontWeight.w500,
                               ),
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                                     Text(
                     currentPost.description,
                     style: const TextStyle(
                       fontSize: 16,
                       color: Colors.black87,
                     ),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 기본 정보
            _buildInfoSection('기본 정보', [
              _buildInfoRow(Icons.person, '발행자', currentPost.creatorName),
              _buildInfoRow(Icons.calendar_today, '생성일', _formatDate(currentPost.createdAt)),
              _buildInfoRow(Icons.timer, '만료일', _formatDate(currentPost.expiresAt)),
              _buildInfoRow(Icons.location_on, '위치', '${currentPost.location.latitude.toStringAsFixed(4)}, ${currentPost.location.longitude.toStringAsFixed(4)}'),
              _buildInfoRow(Icons.price_change, '리워드', '${currentPost.reward}'),
              _buildInfoRow(Icons.settings, '기능', _buildCapabilitiesText()),
              _buildInfoRow(Icons.group, '타겟', _buildTargetText()),
            ]),

            const SizedBox(height: 24),

            // 액션 버튼들
            if (!widget.isEditable) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _useCoupon(context),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('쿠폰 사용하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _forwardPost(context),
                  icon: const Icon(Icons.share),
                  label: const Text('포스트 전달하기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 미디어(그림/텍스트/사운드) - 화면 하단에 배치
            if (currentPost.mediaType.isNotEmpty && currentPost.mediaUrl.isNotEmpty)
              _buildMediaSection(context),

            const SizedBox(height: 16),

            // 포스트 수정 버튼 - 최하단 배치 (편집 가능한 경우)
            if (widget.isEditable)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _editPost(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('포스트 수정'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _primaryMediaType() {
    if (currentPost.mediaType.isEmpty) return 'text';
    return currentPost.mediaType.first;
  }

  // 미디어 섹션
  Widget _buildMediaSection(BuildContext context) {
    final items = <Widget>[];
    final firebaseService = FirebaseService();
    for (int i = 0; i < currentPost.mediaType.length && i < currentPost.mediaUrl.length; i++) {
      final type = currentPost.mediaType[i];
      final dynamic raw = currentPost.mediaUrl[i];
      final String url = raw is String ? raw : raw.toString();
      // 디버그 로그
      // 무조건 로그에 남겨서 콘솔에서 확인 가능
      // ignore: avoid_print
      print('[PostDetail] media[$i] type=$type rawUrl=$url');
      if (type == 'image') {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 200,
                child: FutureBuilder<String?>(
                  future: firebaseService.resolveImageUrl(url),
                  builder: (context, snapshot) {
                    final effective = snapshot.data ?? url;
                    // ignore: avoid_print
                    print('[PostDetail] media[$i] resolvedUrl=$effective');
                    return _buildImageFromUrl(effective);
                  },
                ),
              ),
            ),
          ),
        );
      } else if (type == 'text') {
        items.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(url),
          ),
        );
      } else if (type == 'audio') {
        items.add(
          Row(
            children: [
              const Icon(Icons.audiotrack),
              const SizedBox(width: 8),
              Expanded(child: Text(url, overflow: TextOverflow.ellipsis)),
              TextButton.icon(
                onPressed: () async { await openExternalUrl(url); },
                icon: const Icon(Icons.open_in_new),
                label: const Text('열기'),
              ),
            ],
          ),
        );
      }
    }
    // 디버그 섹션 추가: 원본/해석 URL을 확인할 수 있도록 출력
    items.add(const SizedBox(height: 8));
    items.add(_buildMediaDebugList());
    return _buildInfoSection('미디어', items);
  }

  bool _isDataImage(String url) {
    return url.startsWith('data:image/');
  }

  Widget _buildImageFromUrl(String url) {
    if (_isDataImage(url)) {
      try {
        final base64Data = url.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
        );
      } catch (_) {
        return const Icon(Icons.broken_image);
      }
    }
    if (_isHttpUrl(url)) {
      return buildNetworkImage(url);
    }
    // 지원되지 않는 경로이면 플레이스홀더
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported, color: Colors.grey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '이미지 URL이 유효하지 않습니다',
              style: TextStyle(color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _isHttpUrl(String url) => url.startsWith('http://') || url.startsWith('https://');

  Widget _buildMediaDebugList() {
    final firebaseService = FirebaseService();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('디버그: 미디어 URL 목록', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        for (int i = 0; i < currentPost.mediaType.length && i < currentPost.mediaUrl.length; i++)
          FutureBuilder<String?>(
            future: firebaseService.resolveImageUrl(currentPost.mediaUrl[i].toString()),
            builder: (context, snapshot) {
              final type = currentPost.mediaType[i];
              final raw = currentPost.mediaUrl[i].toString();
              final resolved = snapshot.data ?? '(해석 실패)';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[$i] type=$type'),
                    const SizedBox(height: 4),
                    const Text('원본 URL:'),
                    SelectableText(raw, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('해석 URL:'),
                    SelectableText(resolved, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => openExternalUrl(resolved),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('브라우저로 열기'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _buildCapabilitiesText() {
    final caps = <String>[];
    if (currentPost.canRespond) caps.add('응답');
    if (currentPost.canForward) caps.add('전달');
    if (currentPost.canRequestReward) caps.add('리워드 수령');
    if (currentPost.canUse) caps.add('사용');
    return caps.isEmpty ? '없음' : caps.join(', ');
  }

  String _buildTargetText() {
    final gender = currentPost.targetGender == 'all' ? '전체' : currentPost.targetGender == 'male' ? '남성' : '여성';
    final age = '${currentPost.targetAge[0]}~${currentPost.targetAge[1]}세';
    final interests = currentPost.targetInterest.isNotEmpty ? currentPost.targetInterest.join(', ') : '관심사 없음';
    return '$gender / $age / $interests';
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPostTypeIcon(String mediaType) {
    switch (mediaType) {
      case 'text':
        return Icons.text_fields;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.post_add;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '없음';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _useCoupon(BuildContext context) {
    // TODO: 쿠폰 사용 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('쿠폰 사용 기능은 준비 중입니다.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _forwardPost(BuildContext context) {
    // TODO: 포스트 전달 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('포스트 전달 기능은 준비 중입니다.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _editPost(BuildContext context) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.postEdit,
      arguments: {'post': currentPost},
    );
    if (result == true) {
      // 포스트 데이터 새로고침
      await _refreshPost();
      // 성공 메시지는 _refreshPost에서 처리하거나 생략
    }
  }

  Future<void> _refreshPost() async {
    try {
      final postService = PostService();
      final updatedPost = await postService.getPostById(currentPost.postId);
      if (updatedPost != null && mounted) {
        setState(() {
          currentPost = updatedPost;
        });
        debugPrint('🔄 포스트 데이터 새로고침 완료: targetAge=${currentPost.targetAge}');
      }
    } catch (e) {
      debugPrint('❌ 포스트 새로고침 실패: $e');
    }
  }

  Widget _buildPlacePreview(BuildContext context) {
    final String? placeId = currentPost.placeId;
    if (placeId == null || placeId.isEmpty) {
      return const SizedBox.shrink();
    }

    final placeService = PlaceService();
    return FutureBuilder<PlaceModel?>(
      future: placeService.getPlaceById(placeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 8);
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final place = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    '해당 플레이스 구글지도',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place.id);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
