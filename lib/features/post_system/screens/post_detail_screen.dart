import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/data/post_service.dart';
import '../../../routes/app_routes.dart';
import '../../../utils/web/web_dom_stub.dart'
    if (dart.library.html) '../../../utils/web/web_dom.dart';
import '../../../../widgets/network_image_fallback_with_data.dart';
import '../widgets/post_detail_image_widgets.dart';
import '../widgets/post_detail_ui_widgets.dart';
import '../widgets/post_detail_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  late PostDetailImageWidgets _imageWidgets;
  late PostDetailUIWidgets _uiWidgets;
  bool _isDeveloperInfoExpanded = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    currentPost = widget.post;
    _imageWidgets = PostDetailImageWidgets(
      post: currentPost,
      firebaseService: _firebaseService,
    );
    _uiWidgets = PostDetailUIWidgets(
      post: currentPost,
      isEditable: widget.isEditable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlaceStyleUI(context);
  }

  // Place 스타일 UI
  Widget _buildPlaceStyleUI(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 상단 이미지 슬라이더 앱바
          _uiWidgets.buildImageSliderAppBar(
            context,
            _findOriginalImageUrl,
            () => PostDetailHelpers.editPost(context, currentPost, _refreshPost),
            () => PostDetailHelpers.deletePost(context, currentPost),
            () => PostDetailHelpers.forwardPost(context),
          ),

          // 포스트 정보 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _uiWidgets.buildPostHeader(_primaryMediaType()),
                  const SizedBox(height: 24),

                  // 플레이스 정보
                  if (currentPost.placeId != null && currentPost.placeId!.isNotEmpty) ...[
                    _uiWidgets.buildLinkedPlaceSection(context),
                    const SizedBox(height: 24),
                  ],

                  // 상태 카드
                  if (widget.isEditable && currentPost.status != PostStatus.DRAFT) ...[
                    _uiWidgets.buildStatusCard(),
                    const SizedBox(height: 24),
                  ],

                  // 타겟 정보
                  if (widget.isEditable) ...[
                    _uiWidgets.buildTargetSection(),
                    const SizedBox(height: 24),
                  ],

                  // 쿠폰 정보
                  if (currentPost.isCoupon) ...[
                    _uiWidgets.buildCouponActionSection(
                      context,
                      () => PostDetailHelpers.useCoupon(context, currentPost, _updatePost),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // 개발자 정보
                  if (widget.isEditable) ...[
                    _buildDeveloperInfoSection(),
                  ],

                  // 액션 버튼들
                  _uiWidgets.buildActionButtonsSection(
                    context,
                    () => PostDetailHelpers.forwardPost(context),
                    () => PostDetailHelpers.showPostStatistics(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 주요 미디어 타입
  String _primaryMediaType() {
    if (currentPost.mediaType.isEmpty) return 'text';
    return currentPost.mediaType.first;
  }

  // 포스트 업데이트 콜백
  void _updatePost(PostModel updatedPost) {
    setState(() {
      currentPost = updatedPost;
      _imageWidgets = PostDetailImageWidgets(
        post: currentPost,
        firebaseService: _firebaseService,
      );
      _uiWidgets = PostDetailUIWidgets(
        post: currentPost,
        isEditable: widget.isEditable,
      );
    });
  }

  // 포스트 새로고침
  Future<void> _refreshPost() async {
    try {
      final postService = PostService();
      final updatedPost = await postService.getPostById(currentPost.postId);
      if (updatedPost != null && mounted) {
        _updatePost(updatedPost);
        debugPrint('🔄 포스트 데이터 새로고침 완료: targetAge=${currentPost.targetAge}');
      }
    } catch (e) {
      debugPrint('❌ 포스트 새로고침 실패: $e');
    }
  }

  // 원본 이미지 URL 찾기
  String _findOriginalImageUrl(String baseUrl, int imageIndex) {
    return findOriginalImageUrl(currentPost, baseUrl, imageIndex);
  }

  // 조건부 URL 해석
  Future<String?> _resolveImageUrlConditionally(String url, FirebaseService service) {
    return resolveImageUrlConditionally(url, service);
  }

  // 개발자 정보 섹션
  Widget _buildDeveloperInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isDeveloperInfoExpanded = !_isDeveloperInfoExpanded;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  color: Colors.grey.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '개발자 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
                Icon(
                  _isDeveloperInfoExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ),
        ),
        if (_isDeveloperInfoExpanded) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.tag, '포스트 ID', currentPost.postId),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.person, '발행자', currentPost.creatorName),
                const SizedBox(height: 8),
                _buildStatusRow(),
                const SizedBox(height: 8),
                if (currentPost.placeId != null && currentPost.placeId!.isNotEmpty) ...[
                  _buildStoreLink(),
                  const SizedBox(height: 8),
                ],
                _buildInfoRow(Icons.calendar_today, '생성일', PostDetailHelpers.formatDate(currentPost.createdAt)),
                if (currentPost.isDeployed) ...[
                  const SizedBox(height: 8),
                  if (currentPost.deployedAt != null)
                    _buildInfoRow(Icons.rocket_launch, '배포일', PostDetailHelpers.formatDate(currentPost.deployedAt!)),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.timer, '배포 기간', '${PostDetailHelpers.calculateDeploymentDuration(currentPost)}일'),
                ],
                const SizedBox(height: 8),
                _buildInfoRow(Icons.price_change, '리워드', '${currentPost.reward}'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.settings, '기능', PostDetailHelpers.buildCapabilitiesText(currentPost)),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.group, '타겟', PostDetailHelpers.buildTargetText(currentPost)),
                if (currentPost.isCoupon) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.card_giftcard,
                    '쿠폰 상태',
                    currentPost.canUse ? '사용 가능 ✅' : '사용 불가 ❌',
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 정보 행 위젯
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

  // 상태 행 위젯
  Widget _buildStatusRow() {
    Color statusColor;
    String statusText;

    switch (currentPost.status) {
      case PostStatus.DRAFT:
        statusColor = Colors.blue;
        statusText = '배포 대기';
        break;
      case PostStatus.DEPLOYED:
        statusColor = Colors.green;
        statusText = '배포됨';
        break;
      case PostStatus.RECALLED:
        statusColor = Colors.orange;
        statusText = '회수됨';
        break;
      case PostStatus.DELETED:
        statusColor = Colors.red;
        statusText = '삭제됨';
        break;
      case PostStatus.EXPIRED:
        statusColor = Colors.grey;
        statusText = '만료됨';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상태',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 스토어 링크 위젯
  Widget _buildStoreLink() {
    final placeService = PlaceService();
    return FutureBuilder<PlaceModel?>(
      future: placeService.getPlaceById(currentPost.placeId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.store, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                const CircularProgressIndicator(strokeWidth: 2),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final place = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place.id);
            },
            child: Row(
              children: [
                Icon(Icons.store, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '연결된 스토어',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              place.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

