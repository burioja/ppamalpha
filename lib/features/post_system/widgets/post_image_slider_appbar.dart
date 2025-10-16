import 'package:flutter/material.dart';
import '../../../core/models/post/post_model.dart';

/// 포스트 상세 화면의 이미지 슬라이더 앱바
class PostImageSliderAppBar extends StatelessWidget {
  final PostModel post;
  final bool isEditable;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;
  final String Function(String) findOriginalImageUrl;

  const PostImageSliderAppBar({
    Key? key,
    required this.post,
    required this.isEditable,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.findOriginalImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 이미지 인덱스 추출
    final imageIndices = <int>[];
    for (int i = 0; i < post.mediaType.length; i++) {
      if (post.mediaType[i] == 'image') {
        imageIndices.add(i);
      }
    }

    // 화면 높이의 50%를 최대 높이로 설정
    final screenHeight = MediaQuery.of(context).size.height;
    final maxExpandedHeight = screenHeight * 0.5;

    return SliverAppBar(
      expandedHeight: maxExpandedHeight,
      pinned: true,
      backgroundColor: Colors.white,
      title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        // 수정/삭제 버튼 (편집 가능한 경우만)
        if (post.canEdit && isEditable) ...[
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(
              post.status == PostStatus.DEPLOYED
                  ? Icons.undo
                  : Icons.delete,
            ),
            onPressed: onDelete,
          ),
        ],
        // 공유 버튼 (항상 표시)
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: onShare,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
          ),
          child: PostImageSlider(
            post: post,
            imageIndices: imageIndices,
            findOriginalImageUrl: findOriginalImageUrl,
          ),
        ),
      ),
    );
  }
}

/// 이미지 슬라이더 위젯
class PostImageSlider extends StatefulWidget {
  final PostModel post;
  final List<int> imageIndices;
  final String Function(String) findOriginalImageUrl;

  const PostImageSlider({
    Key? key,
    required this.post,
    required this.imageIndices,
    required this.findOriginalImageUrl,
  }) : super(key: key);

  @override
  State<PostImageSlider> createState() => _PostImageSliderState();
}

class _PostImageSliderState extends State<PostImageSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageIndices.isEmpty) {
      return _buildNoImagePlaceholder();
    }

    return Stack(
      children: [
        // 이미지 슬라이더
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageIndices.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, pageIndex) {
            final mediaIndex = widget.imageIndices[pageIndex];
            final imageUrl = widget.post.mediaUrl[mediaIndex];
            
            return GestureDetector(
              onTap: () => _showFullScreenImage(context, pageIndex),
              child: _buildImage(imageUrl),
            );
          },
        ),
        
        // 페이지 인디케이터
        if (widget.imageIndices.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildPageIndicator(),
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    return Container(
      color: Colors.grey[100],
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              '이미지가 없습니다',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.imageIndices.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, int initialPage) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          post: widget.post,
          imageIndices: widget.imageIndices,
          initialPage: initialPage,
          findOriginalImageUrl: widget.findOriginalImageUrl,
        ),
      ),
    );
  }
}

/// 전체화면 이미지 뷰어
class FullScreenImageViewer extends StatefulWidget {
  final PostModel post;
  final List<int> imageIndices;
  final int initialPage;
  final String Function(String) findOriginalImageUrl;

  const FullScreenImageViewer({
    Key? key,
    required this.post,
    required this.imageIndices,
    required this.initialPage,
    required this.findOriginalImageUrl,
  }) : super(key: key);

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentPage + 1} / ${widget.imageIndices.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageIndices.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, pageIndex) {
          final mediaIndex = widget.imageIndices[pageIndex];
          final imageUrl = widget.post.mediaUrl[mediaIndex];
          final originalUrl = widget.findOriginalImageUrl(imageUrl);
          
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                originalUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.white54),
                        SizedBox(height: 8),
                        Text(
                          '이미지를 불러올 수 없습니다',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

