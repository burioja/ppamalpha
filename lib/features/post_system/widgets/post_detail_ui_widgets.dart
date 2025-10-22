import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../routes/app_routes.dart';

/// 포스트 상세 화면의 UI 위젯들
class PostDetailUIWidgets {
  final PostModel post;
  final bool isEditable;

  PostDetailUIWidgets({
    required this.post,
    required this.isEditable,
  });

  // 이미지 슬라이더 앱바 (Place 스타일)
  Widget buildImageSliderAppBar(
    BuildContext context,
    String Function(String, int) findOriginalImageUrl,
    void Function() onEdit,
    Future<void> Function() onDelete,
    void Function() onShare,
  ) {
    // 이미지가 있는지 확인
    final imageIndices = <int>[];
    for (int i = 0; i < post.mediaType.length; i++) {
      if (post.mediaType[i] == 'image') {
        imageIndices.add(i);
      }
    }

    // 화면 높이의 60%를 최대 높이로 설정 (더 큰 이미지 영역)
    final screenHeight = MediaQuery.of(context).size.height;
    final maxExpandedHeight = screenHeight * 0.6;

    return SliverAppBar(
      expandedHeight: maxExpandedHeight,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          post.title, 
          maxLines: 1, 
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      actions: [
        // 수정 버튼: 원본 작성자만 표시
        if (post.canEdit && isEditable) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: onEdit,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: Icon(
                post.status == PostStatus.DEPLOYED
                    ? Icons.undo
                    : Icons.delete,
                color: Colors.white,
              ),
              onPressed: onDelete,
            ),
          ),
        ],
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: onShare,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // 이미지 슬라이더
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight,
              ),
              child: PostImageSlider(
                post: post,
                imageIndices: imageIndices,
                findOriginalImageUrl: findOriginalImageUrl,
              ),
            ),
            // 그라데이션 오버레이
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.1),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 포스트 헤더 (제목, 설명, 리워드)
  Widget buildPostHeader(String primaryMediaType) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.purple[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$primaryMediaType 포스트',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 리워드 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[400]!, Colors.orange[600]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${post.reward}P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (post.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                post.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 연결된 플레이스 섹션
  Widget buildLinkedPlaceSection(BuildContext context) {
    final placeService = PlaceService();
    return FutureBuilder<PlaceModel?>(
      future: placeService.getPlaceById(post.placeId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 12),
                Text('플레이스 정보 로딩 중...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final place = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                const Text(
                  '연결된 플레이스',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place.id);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.blue[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue[100]!,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[800]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (place.address != null && place.address!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    place.address!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: Colors.blue[600],
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

  // 상태 카드
  Widget buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (post.status) {
      case PostStatus.DRAFT:
        // DRAFT 상태는 표시하지 않음
        return const SizedBox.shrink();
      case PostStatus.DEPLOYED:
        statusColor = Colors.green;
        statusIcon = Icons.public;
        statusText = '배포 완료';
        statusDescription = '지도에 배포되어 사용자들이 볼 수 있습니다.';
        break;
      case PostStatus.RECALLED:
        statusColor = Colors.orange;
        statusIcon = Icons.undo;
        statusText = '회수됨';
        statusDescription = '포스트가 회수되었습니다. 재배포할 수 없습니다.';
        break;
      case PostStatus.DELETED:
        statusColor = Colors.red;
        statusIcon = Icons.delete;
        statusText = '삭제됨';
        statusDescription = '이 포스트는 삭제되었습니다.';
        break;
      case PostStatus.EXPIRED:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = '만료됨';
        statusDescription = '이 포스트는 만료되었습니다.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 타겟 정보 섹션
  Widget buildTargetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '타겟 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildPlaceStyleInfoRow(
                Icons.people,
                '성별',
                post.targetGender == 'all' ? '전체' : post.targetGender == 'male' ? '남성' : '여성',
              ),
              const SizedBox(height: 12),
              _buildPlaceStyleInfoRow(
                Icons.calendar_today,
                '연령',
                '${post.targetAge[0]}~${post.targetAge[1]}세',
              ),
              if (post.targetInterest.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPlaceStyleInfoRow(
                  Icons.interests,
                  '관심사',
                  post.targetInterest.join(', '),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 쿠폰 정보/액션 섹션
  Widget buildCouponActionSection(BuildContext context, void Function() onUseCoupon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '쿠폰',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 내 포스트: 단순 정보 표시
        if (isEditable) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.card_giftcard,
                  size: 32,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '쿠폰 포스트',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이 포스트는 쿠폰으로 사용할 수 있습니다',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '쿠폰',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]
        // 받은 포스트: 사용 가능 UI
        else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
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
                            '쿠폰 포스트',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.canUse
                              ? '이 쿠폰을 사용할 수 있습니다'
                              : '사용 불가능한 쿠폰입니다',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (post.canUse) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: onUseCoupon,
                      icon: const Icon(Icons.check_circle, size: 24),
                      label: const Text(
                        '쿠폰 사용하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: Colors.orange.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 액션 버튼 섹션
  Widget buildActionButtonsSection(
    BuildContext context,
    void Function() onForward,
    void Function() onShowStatistics,
  ) {
    // 받은 포스트
    if (!isEditable) {
      return Column(
        children: [
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onForward,
              icon: const Icon(Icons.share),
              label: const Text('포스트 공유하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      );
    }

    // 내 포스트
    return Column(
      children: [
        if (post.status == PostStatus.DEPLOYED) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onShowStatistics,
              icon: const Icon(Icons.analytics),
              label: const Text('배포 통계 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green),
              ),
            ),
          ),
        ] else if (post.status == PostStatus.RECALLED) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: onShowStatistics,
              icon: const Icon(Icons.analytics),
              label: const Text('배포 통계 보기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange,
                side: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Place 스타일 정보 행 위젯
  Widget _buildPlaceStyleInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 이미지 슬라이더 위젯
class PostImageSlider extends StatefulWidget {
  final PostModel post;
  final List<int> imageIndices;
  final String Function(String, int) findOriginalImageUrl;

  const PostImageSlider({
    super.key,
    required this.post,
    required this.imageIndices,
    required this.findOriginalImageUrl,
  });

  @override
  State<PostImageSlider> createState() => _PostImageSliderState();
}

class _PostImageSliderState extends State<PostImageSlider> {
  late PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageIndices.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '등록된 이미지가 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageIndices.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final mediaIndex = widget.imageIndices[index];
            final imageUrl = widget.findOriginalImageUrl(
              widget.post.mediaUrl[mediaIndex].toString(),
              mediaIndex,
            );

            return Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        '이미지 로드 실패',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        // 좌측 화살표
        if (widget.imageIndices.length > 1 && _currentImageIndex > 0)
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_left, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),

        // 우측 화살표
        if (widget.imageIndices.length > 1 && _currentImageIndex < widget.imageIndices.length - 1)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),

        // 이미지 카운터
        if (widget.imageIndices.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${widget.imageIndices.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }
}


