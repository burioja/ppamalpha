import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/models/place/place_model.dart';
import '../../../../widgets/network_image_fallback_with_data.dart';

class PostPreviewScreen extends StatefulWidget {
  final PostModel post;

  const PostPreviewScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostPreviewScreen> createState() => _PostPreviewScreenState();
}

class _PostPreviewScreenState extends State<PostPreviewScreen> {
  PlaceModel? _place;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceInfo();
  }

  Future<void> _loadPlaceInfo() async {
    if (widget.post.placeId != null && widget.post.placeId!.isNotEmpty) {
      try {
        final placeService = PlaceService();
        final place = await placeService.getPlaceById(widget.post.placeId!);
        if (mounted) {
          setState(() {
            _place = place;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('❌ 장소 정보 로드 실패: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 전체 화면 이미지
          _buildFullScreenImage(),
          
          // 상단 앱바
          _buildTopAppBar(),
          
          // 하단 오버레이 정보
          _buildBottomOverlay(),
        ],
      ),
    );
  }

  Widget _buildFullScreenImage() {
    final mediaUrl = _getPrimaryImageUrl();
    
    if (mediaUrl == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[800],
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 100,
            color: Colors.white54,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[800],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(
                Icons.error_outline,
                size: 100,
                color: Colors.white54,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 뒤로가기 버튼
            Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
            ),
            
            const Spacer(),
            
            // 내 포스트인지 확인
            if (_isMyPost())
              Container(
                decoration: BoxDecoration(
                  color: Colors.green[600]?.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: const Text(
                  '내 포스트',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 가게명
                if (_place != null) ...[
                  Text(
                    _place!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 포스트 제목
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                
                // 가격과 인증업체 정보
                Row(
                  children: [
                    // 가격
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[600],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${widget.post.reward}원',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // 인증업체 여부
                    if (_place?.isVerified == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[600],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '인증업체',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // 포스트 설명
                if (widget.post.description != null && widget.post.description!.isNotEmpty)
                  Text(
                    widget.post.description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                
                const SizedBox(height: 16),
                
                // 미디어 타입 표시
                Row(
                  children: [
                    Icon(
                      _getMediaTypeIcon(),
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getMediaTypeText(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _getPrimaryImageUrl() {
    // 썸네일이 있으면 우선 사용
    if (widget.post.thumbnailUrl != null && widget.post.thumbnailUrl!.isNotEmpty) {
      return widget.post.thumbnailUrl!.first;
    }
    
    // 미디어 URL에서 이미지 찾기
    if (widget.post.mediaUrl.isNotEmpty) {
      for (int i = 0; i < widget.post.mediaUrl.length; i++) {
        if (i < widget.post.mediaType.length && 
            widget.post.mediaType[i].toLowerCase().contains('image')) {
          return widget.post.mediaUrl[i];
        }
      }
    }
    
    return null;
  }

  bool _isMyPost() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && widget.post.creatorId == currentUser.uid;
  }

  IconData _getMediaTypeIcon() {
    if (widget.post.mediaType.isEmpty) return Icons.description;
    
    final primaryType = widget.post.mediaType.first.toLowerCase();
    if (primaryType.contains('image')) return Icons.image;
    if (primaryType.contains('video')) return Icons.videocam;
    if (primaryType.contains('audio')) return Icons.audiotrack;
    return Icons.description;
  }

  String _getMediaTypeText() {
    if (widget.post.mediaType.isEmpty) return '텍스트';
    
    final primaryType = widget.post.mediaType.first.toLowerCase();
    if (primaryType.contains('image')) return '이미지';
    if (primaryType.contains('video')) return '동영상';
    if (primaryType.contains('audio')) return '오디오';
    return '미디어';
  }
}
