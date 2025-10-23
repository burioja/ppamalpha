import 'package:flutter/material.dart';
import '../../../core/models/post/post_model.dart';
import '../../../../widgets/network_image_fallback_web.dart' if (dart.library.io) '../../../../widgets/network_image_fallback_stub.dart';
import 'package:intl/intl.dart';

class PostTileCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final bool isSelected;
  final bool showDeleteButton;
  final VoidCallback? onDelete;
  final bool showStatisticsButton;
  final VoidCallback? onStatistics;
  final bool hideTextOverlay; // 받은 포스트용 - 제목/가격 숨김
  final bool enableImageViewer; // 이미지 확대 뷰어 활성화

  const PostTileCard({
    super.key,
    required this.post,
    this.onTap,
    this.onDoubleTap,
    this.isSelected = false,
    this.showDeleteButton = false,
    this.onDelete,
    this.showStatisticsButton = false,
    this.onStatistics,
    this.hideTextOverlay = false,
    this.enableImageViewer = false,
  });

  @override
  State<PostTileCard> createState() => _PostTileCardState();
}

class _PostTileCardState extends State<PostTileCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // 이미지 뷰어 활성화 모드일 때
    if (widget.enableImageViewer) {
      _showImageViewer();
      return;
    }
    
    // 선택되지 않은 상태면 선택만 하고 (1번 탭)
    // 이미 선택된 상태면 onTap 호출 (2번 탭)
    if (!widget.isSelected) {
      // 1번 탭: 선택만 하기
      if (widget.onTap != null) {
        widget.onTap!();
      }
    } else {
      // 2번 탭: 포스트 상세로 이동
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
      if (widget.onDoubleTap != null) {
        widget.onDoubleTap!();
      }
    }
  }

  void _showImageViewer() {
    // 원본 이미지 URL 가져오기
    final imageUrls = <String>[];
    for (int i = 0; i < widget.post.mediaType.length; i++) {
      if (widget.post.mediaType[i].toLowerCase() == 'image' && 
          i < widget.post.mediaUrl.length) {
        imageUrls.add(widget.post.mediaUrl[i]);
      }
    }

    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지가 없습니다')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageViewerScreen(
          imageUrls: imageUrls,
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      // 디버그: 포스트 상태 로깅
      debugPrint('🔍 PostTileCard - postId: ${widget.post.postId}, title: ${widget.post.title}');
      debugPrint('   status: ${widget.post.status.name} (${widget.post.status})');

      final isDeleted = widget.post.status == PostStatus.DELETED;
      // 🚀 제거된 필드들: isCollected, isUsed, isUsedByCurrentUser
      // 이들은 이제 post_collections 컬렉션에서 쿼리해야 함
      final isCollected = false; // TODO: 쿼리 기반으로 변경 필요
      final isUsed = false; // TODO: 쿼리 기반으로 변경 필요

      debugPrint('   isDeleted: $isDeleted, isCollected: $isCollected, isUsed: $isUsed');

      return GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
        decoration: BoxDecoration(
          color: isUsed
              ? Colors.grey.shade100
              : widget.isSelected
                  ? const Color(0xFF4D4DFF).withValues(alpha: 0.1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUsed
                ? Colors.grey.shade400
                : widget.isSelected
                    ? const Color(0xFF4D4DFF)
                    : Colors.grey.shade300,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isUsed ? 0.02 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 전체 배경 이미지
              Positioned.fill(
                child: _buildImageWidget(),
              ),
              
              // 우상단 버튼 영역 (상태 배지 + 삭제 버튼)
              Positioned(
                top: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 삭제 버튼 (우상단)
                    if (widget.showDeleteButton && widget.onDelete != null)
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delete,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    // 상태 배지와 삭제 버튼 사이 간격
                    if (widget.showDeleteButton && widget.onDelete != null)
                      const SizedBox(height: 4),
                    // 상태 배지
                    _buildStatusBadge(isDeleted, isCollected, isUsed),
                  ],
                ),
              ),
              
              // 하단 그라데이션 + 텍스트 오버레이 (hideTextOverlay가 false일 때만)
              if (!widget.hideTextOverlay)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 제목
                        widget.isSelected
                            ? SizedBox(
                              height: 20,
                              child: _ScrollingText(
                                text: (widget.post.title.isNotEmpty ? widget.post.title : '(제목 없음)').replaceAll(' 관련 포스트', '').replaceAll('관련 포스트', ''),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  decoration: isUsed ? TextDecoration.lineThrough : TextDecoration.none,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Text(
                              (widget.post.title.isNotEmpty ? widget.post.title : '(제목 없음)').replaceAll(' 관련 포스트', '').replaceAll('관련 포스트', ''),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                decoration: isUsed ? TextDecoration.lineThrough : TextDecoration.none,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                  ),
                                ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        const SizedBox(height: 6),
                        
                        // 하단 정보 (리워드와 통계/날짜)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 리워드
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUsed 
                                      ? Colors.grey.withOpacity(0.8)
                                      : const Color(0xFF4D4DFF).withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.monetization_on,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isUsed ? '사용완료' : '${NumberFormat('#,###').format(widget.post.reward)}원',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // 통계 버튼과 배포일
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 통계 버튼 (배포된 포스트만)
                                if (widget.showStatisticsButton && widget.post.isDeployed && widget.onStatistics != null)
                                  GestureDetector(
                                    onTap: widget.onStatistics,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.analytics,
                                            size: 10,
                                            color: Color(0xFF4D4DFF),
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            '통계',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4D4DFF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (widget.showStatisticsButton && widget.post.isDeployed && widget.onStatistics != null)
                                  const SizedBox(height: 2),
                                // 배포일 (배포된 포스트만 표시)
                                if (widget.post.isDeployed)
                                  Text(
                                    DateFormat('MM/dd').format(widget.post.createdAt),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black45,
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 사용된 포스트 전체 오버레이
              if (isUsed)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ PostTileCard 빌드 에러: $e');
      debugPrint('스택 트레이스: $stackTrace');
      debugPrint('포스트 정보: postId=${widget.post.postId}, title=${widget.post.title}');

      // 에러 발생 시 간단한 에러 카드 표시
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '포스트 로드 오류',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${widget.post.postId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '제목: ${widget.post.title}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              '에러: $e',
              style: TextStyle(fontSize: 11, color: Colors.red.shade600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildImageWidget() {
    try {
      // 디버그: 포스트 이미지 정보 로깅
      debugPrint('🔍 PostTileCard 이미지 정보:');
      debugPrint('   postId: ${widget.post.postId}');
      debugPrint('   mediaType: ${widget.post.mediaType}');
      debugPrint('   mediaUrl: ${widget.post.mediaUrl}');
      debugPrint('   thumbnailUrl: ${widget.post.thumbnailUrl}');
      
      // 썸네일 우선 사용
      final imageUrl = widget.post.thumbnailUrl.isNotEmpty
          ? widget.post.thumbnailUrl.first
          : (widget.post.mediaUrl.isNotEmpty ? widget.post.mediaUrl.first : '');

      debugPrint('   선택된 imageUrl: $imageUrl');

      if (imageUrl.isNotEmpty) {
        // 이미지 타입 체크를 더 관대하게 변경
        bool hasImageMedia = widget.post.mediaType.isNotEmpty &&
            (widget.post.mediaType.any((type) => type.toLowerCase().contains('image')) ||
             imageUrl.toLowerCase().contains('.jpg') ||
             imageUrl.toLowerCase().contains('.jpeg') ||
             imageUrl.toLowerCase().contains('.png') ||
             imageUrl.toLowerCase().contains('.gif') ||
             imageUrl.toLowerCase().contains('firebasestorage'));

        debugPrint('   hasImageMedia: $hasImageMedia');

        if (hasImageMedia) {
          debugPrint('   ✅ 이미지 표시 시도: $imageUrl');
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: buildNetworkImage(imageUrl),
          );
        } else {
          debugPrint('   ❌ 이미지 타입이 아님, 그라데이션 표시');
        }
      }
    } catch (e) {
      debugPrint('❌ 이미지 위젯 빌드 에러: $e');
    }

    // 이미지가 없거나 이미지 타입이 아닌 경우 그라데이션 배경
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.primaries[widget.post.title.hashCode % Colors.primaries.length][300]!,
            Colors.primaries[widget.post.title.hashCode % Colors.primaries.length][600]!,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image,
          size: 40,
          color: Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDeleted, bool isCollected, bool isUsed) {
    debugPrint('📛 _buildStatusBadge 호출');
    debugPrint('   postId: ${widget.post.postId}');
    debugPrint('   status: ${widget.post.status.name}');
    debugPrint('   isDeleted: $isDeleted');
    debugPrint('   isCollected: $isCollected');
    debugPrint('   isUsed: $isUsed');

    Widget buildBadge(String text, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // 사용 상태가 최우선
    if (isUsed) {
      debugPrint('   ✅ 배지: 사용됨');
      return buildBadge('사용됨', Colors.grey.shade700);
    }

    // RECALLED 상태 - 회수된 포스트 (DELETED보다 먼저 체크!)
    if (widget.post.status == PostStatus.RECALLED) {
      debugPrint('   ✅ 배지: 회수됨');
      return buildBadge('회수됨', Colors.orange);
    }

    // 삭제된 상태
    if (isDeleted) {
      debugPrint('   ✅ 배지: 삭제');
      return buildBadge('삭제', Colors.red);
    }

    if (isCollected) {
      debugPrint('   ✅ 배지: 수집됨');
      return buildBadge('수집됨', Colors.green);
    }

    // DEPLOYED 상태면 배지 숨김 (배포된 포스트 탭에서는 모든 포스트가 DEPLOYED이므로 중복 정보)
    if (widget.post.status == PostStatus.DEPLOYED) {
      debugPrint('   ⚪ 배지 숨김: DEPLOYED');
      return const SizedBox.shrink();
    }

    // DRAFT 상태 - "작성중" 배지 숨김 처리
    if (widget.post.status == PostStatus.DRAFT) {
      debugPrint('   ⚪ 배지 숨김: DRAFT');
      return const SizedBox.shrink();
    }

    // 기타 상태는 배지 표시 안 함
    debugPrint('   ⚪ 배지 숨김: 기타 상태');
    return const SizedBox.shrink();
  }
}

/// 좌우 스크롤 애니메이션 텍스트 위젯
class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _ScrollingText({
    required this.text,
    required this.style,
  });

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // 좌우 반복 애니메이션
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        alignment: Alignment.centerLeft,
        child: SlideTransition(
          position: _animation,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.text, style: widget.style, overflow: TextOverflow.visible),
              const SizedBox(width: 20),
              Text(widget.text, style: widget.style, overflow: TextOverflow.visible),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이미지 확대 뷰어 화면
class _ImageViewerScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
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
      body: Stack(
        children: [
          // 이미지 페이지 뷰
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 50),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          
          // 상단 닫기 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 이미지 카운터
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 닫기 버튼
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}