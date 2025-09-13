import 'package:flutter/material.dart';
import '../../core/models/post/post_model.dart';
import '../../utils/web_dom_stub.dart'
    if (dart.library.html) '../../utils/web_dom.dart';
import 'dart:convert';
import '../../services/firebase_service.dart';
import '../../widgets/network_image_fallback_with_data.dart';
import '../../routes/app_routes.dart';
import '../../core/services/data/place_service.dart';
import '../../core/services/data/post_service.dart';
import '../../core/models/place/place_model.dart';

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
            // 메인 플라이어 이미지 (첫 번째 이미지를 대형으로 표시)
            _buildMainPostImage(),
            const SizedBox(height: 16),
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
      print('[PostDetail] 하단 미디어 섹션: 썸네일 사용 예정');
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
                    return buildNetworkImage(effective);
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
    
    // 사용자 친화적인 미디어 접근 버튼들
    if (items.isNotEmpty) {
      items.add(const SizedBox(height: 16));
      items.add(_buildMediaAccessButtons());
    }
    
    return items.isEmpty ? const SizedBox.shrink() : _buildInfoSection('미디어', items);
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

  // 메인 포스트 이미지 위젯
  Widget _buildMainPostImage() {
    print('\n========== [_buildMainPostImage] 시작 ==========');
    
    // 첫 번째 이미지 찾기 (원본 이미지 사용)
    final firstImageIndex = currentPost.mediaType.indexOf('image');
    if (firstImageIndex == -1 || firstImageIndex >= currentPost.mediaUrl.length) {
      print('이미지 없음: firstImageIndex=$firstImageIndex, mediaUrl.length=${currentPost.mediaUrl.length}');
      return const SizedBox.shrink(); // 이미지가 없으면 표시하지 않음
    }

    // 원본 이미지 URL 찾기: mediaUrl에서 원본 이미지를 찾거나 원본 URL 생성
    String imageUrl = currentPost.mediaUrl[firstImageIndex].toString();
    
    // 상세 디버그 로그 추가
    print('=== [MainPostImage] 데이터 구조 분석 ===');
    print('[MainPostImage] firstImageIndex: $firstImageIndex');
    print('[MainPostImage] 기본 이미지 URL: $imageUrl');
    print('[MainPostImage] mediaType: ${currentPost.mediaType}');
    print('[MainPostImage] mediaUrl 길이: ${currentPost.mediaUrl.length}');
    for (int i = 0; i < currentPost.mediaUrl.length; i++) {
      print('[MainPostImage] mediaUrl[$i]: ${currentPost.mediaUrl[i]}');
    }
    print('[MainPostImage] thumbnailUrl 길이: ${currentPost.thumbnailUrl.length}');
    for (int i = 0; i < currentPost.thumbnailUrl.length; i++) {
      print('[MainPostImage] thumbnailUrl[$i]: ${currentPost.thumbnailUrl[i]}');
    }
    print('[MainPostImage] URL 패턴 분석:');
    print('  - HTTP/HTTPS: ${imageUrl.startsWith('http')}');
    print('  - Data URL: ${imageUrl.startsWith('data:image/')}');
    print('  - Contains /thumbnails/: ${imageUrl.contains('/thumbnails/')}');
    print('  - Contains %2Fthumbnails%2F: ${imageUrl.contains('%2Fthumbnails%2F')}');
    print('  - Contains /original/: ${imageUrl.contains('/original/')}');
    print('  - Contains %2Foriginal%2F: ${imageUrl.contains('%2Foriginal%2F')}');
    
    // 원본 이미지 URL 찾기 로직
    String originalImageUrl = _findOriginalImageUrl(imageUrl, firstImageIndex);
    print('[MainPostImage] 최종 원본 URL: $originalImageUrl');
    
    final firebaseService = FirebaseService();

    return Container(
      width: double.infinity,
      height: 300, // 대형 이미지 크기
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<String?>(
          future: _resolveImageUrlConditionally(originalImageUrl, firebaseService),
          builder: (context, snapshot) {
            final effectiveUrl = snapshot.data ?? originalImageUrl;
            print('[MainPostImage] resolveImageUrl 결과: $effectiveUrl');
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return buildHighQualityImageWithData(
              effectiveUrl,
              currentPost.thumbnailUrl,
              0, // 첫 번째 이미지
            );
          },
        ),
      ),
    );
  }



  // 사용자 친화적인 미디어 접근 버튼들
  Widget _buildMediaAccessButtons() {
    final firebaseService = FirebaseService();
    final List<Widget> buttons = [];
    
    // 이미지 보기 버튼들
    final imageIndices = <int>[];
    for (int i = 0; i < currentPost.mediaType.length; i++) {
      if (currentPost.mediaType[i] == 'image') {
        imageIndices.add(i);
      }
    }
    
    if (imageIndices.length > 1) {
      // 첫 번째 이미지는 이미 위에 대형으로 표시되므로, 추가 이미지들만 버튼으로 제공
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _showImageGallery(imageIndices),
          icon: const Icon(Icons.photo_library, color: Colors.white),
          label: Text(
            '모든 이미지 보기 (${imageIndices.length}장)',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }
    
    // 오디오 재생 버튼들
    for (int i = 0; i < currentPost.mediaType.length; i++) {
      if (currentPost.mediaType[i] == 'audio') {
        final audioUrl = currentPost.mediaUrl[i].toString();
        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              final resolvedUrl = await firebaseService.resolveImageUrl(audioUrl);
              if (resolvedUrl != null) {
                await openExternalUrl(resolvedUrl);
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            label: const Text(
              '오디오 재생',
              style: TextStyle(color: Colors.green),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      }
    }
    
    return buttons.isEmpty 
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 12,
          runSpacing: 8,
          children: buttons,
        );
  }

  // 이미지 갤러리 다이얼로그 표시
  void _showImageGallery(List<int> imageIndices) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 갤러리'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: imageIndices.length,
            itemBuilder: (context, index) {
              final mediaIndex = imageIndices[index];
              final imageUrl = currentPost.mediaUrl[mediaIndex].toString();
              final firebaseService = FirebaseService();
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이미지 ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 200,
                        child: FutureBuilder<String?>(
                          future: firebaseService.resolveImageUrl(imageUrl),
                          builder: (context, snapshot) {
                            final effectiveUrl = snapshot.data ?? imageUrl;
                            return buildHighQualityImageWithData(
              effectiveUrl,
              currentPost.thumbnailUrl,
              0, // 첫 번째 이미지
            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 고화질 원본 이미지 위젯 (상단 메인 플라이어용)
  Widget _buildHighQualityOriginalImage(String url) {
    print('=== [_buildHighQualityOriginalImage] 시작 ===');
    print('로딩할 URL: $url');
    
    // Data URL 처리
    if (url.startsWith('data:image/')) {
      print('타입: Data URL - base64 이미지 사용');
      try {
        final base64Data = url.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (e) {
        print('에러: Data URL 처리 실패 - $e');
        return _buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
      }
    }
    
    // HTTP URL 처리 - 고화질 원본 이미지 직접 로드
    if (url.startsWith('http://') || url.startsWith('https://')) {
      print('타입: HTTP URL - 네트워크 이미지 로딩');
      print('  - 원본 경로 포함: ${url.contains('/original/')}');
      print('  - 썸네일 경로 포함: ${url.contains('/thumbnails/')}');
      
      return Image.network(
        url, // 원본 URL 직접 사용 (썸네일 변환 없이)
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('이미지 로딩 완료: $url');
            return child;
          }
          final progress = loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null;
          print('이미지 로딩 중: ${(progress ?? 0 * 100).toStringAsFixed(1)}%');
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('고화질 원본 로딩 중...', 
                    style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('에러: 고화질 이미지 로드 실패');
          print('  URL: $url');
          print('  에러: $error');
          print('  스택트레이스: $stackTrace');
          return _buildImageErrorPlaceholderWithFallback(url);
        },
      );
    }
    
    // 지원되지 않는 URL 형식
    print('에러: 지원되지 않는 URL 형식 - $url');
    return _buildImageErrorPlaceholder('지원되지 않는 이미지 형식');
  }

  // 이미지 에러 플레이스홀더 (Fallback 로직 포함)
  Widget _buildImageErrorPlaceholderWithFallback(String failedUrl) {
    print('=== [_buildImageErrorPlaceholderWithFallback] Fallback 시도 ===');
    print('실패한 URL: $failedUrl');
    
    // 원본 이미지 실패 시 썸네일로 대체 시도
    if (failedUrl.contains('/original/') || failedUrl.contains('%2Foriginal%2F')) {
      final thumbnailUrl = failedUrl
        .replaceAll('/original/', '/thumbnails/')
        .replaceAll('%2Foriginal%2F', '%2Fthumbnails%2F');
      print('Fallback: 썸네일 URL로 시도 - $thumbnailUrl');
      
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('Fallback 성공: 썸네일 로딩 완료');
            return Stack(
              children: [
                child,
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '썸네일',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('썸네일 로딩 중...',
                    style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Fallback 실패: 썸네일도 로드 실패');
          return _buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
        },
      );
    }
    
    // Fallback도 실패한 경우 기본 에러 플레이스홀더
    return _buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
  }

  // 기본 이미지 에러 플레이스홀더
  Widget _buildImageErrorPlaceholder(String message) {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 60,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 원본 이미지 URL 찾기 로직
  String _findOriginalImageUrl(String baseUrl, int imageIndex) {
    print('=== [_findOriginalImageUrl] 분석 시작 ===');
    print('baseUrl: $baseUrl');
    print('imageIndex: $imageIndex');
    
    // 1. 우선: baseUrl(mediaUrl)이 이미 원본 URL인지 확인
    if (baseUrl.contains('/original/') || baseUrl.contains('%2Foriginal%2F')) {
      print('기본 mediaUrl이 이미 원본 URL임: $baseUrl');
      return baseUrl; // 이미 원본 URL이므로 그대로 사용
    }
    
    // 2. mediaUrl이 썸네일이면 원본 URL로 변경
    if (baseUrl.contains('/thumbnails/') || baseUrl.contains('%2Fthumbnails%2F')) {
      final originalUrl = baseUrl
        .replaceAll('/thumbnails/', '/original/')
        .replaceAll('%2Fthumbnails%2F', '%2Foriginal%2F');
      print('mediaUrl이 썸네일이므로 원본 URL로 변경: $originalUrl');
      return originalUrl;
    }
    
    // 3. thumbnailUrl 배열에서 원본 URL 생성 시도 (마지막 수단)
    if (currentPost.thumbnailUrl.isNotEmpty && imageIndex < currentPost.thumbnailUrl.length) {
      final thumbnailUrl = currentPost.thumbnailUrl[imageIndex];
      if (thumbnailUrl.contains('/thumbnails/') || thumbnailUrl.contains('%2Fthumbnails%2F')) {
        final originalUrl = thumbnailUrl
          .replaceAll('/thumbnails/', '/original/')
          .replaceAll('%2Fthumbnails%2F', '%2Foriginal%2F');
        print('마지막 수단: thumbnailUrl에서 원본 URL 생성: $originalUrl');
        return originalUrl;
      }
    }
    
    // 4. 모두 실패한 경우 기본 URL 사용
    print('기본 URL 그대로 사용: $baseUrl');
    return baseUrl;
  }

  // 조건부 URL 해석
  Future<String?> _resolveImageUrlConditionally(String url, FirebaseService service) async {
    print('=== [_resolveImageUrlConditionally] 분석 ===');
    print('입력 URL: $url');
    
    // HTTP/HTTPS URL이면 그대로 사용 (이중 처리 방지)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      print('HTTP URL이므로 resolveImageUrl 생략');
      return url;
    }
    
    // Data URL이면 그대로 사용
    if (url.startsWith('data:image/')) {
      print('Data URL이므로 resolveImageUrl 생략');
      return url;
    }
    
    // 그 외의 경우만 Firebase 해석 사용
    print('Firebase resolveImageUrl 사용');
    final resolved = await service.resolveImageUrl(url);
    print('해석 결과: $resolved');
    return resolved;
  }
}
