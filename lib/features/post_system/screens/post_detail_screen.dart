import 'package:flutter/material.dart';
import '../../../core/models/post/post_model.dart';
import '../../../utils/web/web_dom_stub.dart'
    if (dart.library.html) '../../../utils/web/web_dom.dart';
import 'dart:convert';
import '../../../core/services/auth/firebase_service.dart';
import '../../../../widgets/network_image_fallback_with_data.dart';
import '../../../routes/app_routes.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/models/place/place_model.dart';
import '../widgets/coupon_usage_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/points_service.dart';

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
        title: Text(widget.isEditable ? '포스트 관리' : '포스트'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.isEditable && currentPost.canEdit)
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
            // 사용자 뷰: 미디어 우선 표시
            if (!widget.isEditable) ...[
              // 미디어(그림/텍스트/사운드) 최상단 배치
              if (currentPost.mediaType.isNotEmpty && currentPost.mediaUrl.isNotEmpty)
                _buildMediaSection(context),

              const SizedBox(height: 16),

              // 포스트 헤더 (간소화)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPost.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          currentPost.creatorName,
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Icon(Icons.wallet_giftcard, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '${currentPost.reward}P',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (currentPost.isCoupon) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentPost.canUse ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              size: 16,
                              color: currentPost.canUse ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentPost.canUse ? '쿠폰 사용 가능' : '쿠폰 사용 불가',
                              style: TextStyle(
                                fontSize: 12,
                                color: currentPost.canUse ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 스토어 링크 (사용자에게 중요) - 강조된 카드 형태
              if (currentPost.placeId != null && currentPost.placeId!.isNotEmpty)
                _buildStoreLinkCard(),

              const SizedBox(height: 24),

              // 액션 버튼들 (쿠폰 사용, 공유 등)
              ..._buildStatusBasedActions(),

            ] else ...[
              // 배포자 뷰: 기존 상세 정보 유지
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

              // 포스트 상태 표시
              _buildStatusCard(),

              const SizedBox(height: 24),

              // 기본 정보
              _buildInfoSection('기본 정보', [
                _buildInfoRow(Icons.tag, '포스트 ID', currentPost.postId),
                _buildInfoRow(Icons.person, '발행자', currentPost.creatorName),
                _buildStatusRow(), // 상태 표시
                // 스토어 링크 (placeId가 있는 경우)
                Builder(
                  builder: (context) {
                    debugPrint('📍 포스트 placeId 체크: ${currentPost.placeId}');
                    if (currentPost.placeId != null && currentPost.placeId!.isNotEmpty) {
                      debugPrint('✅ 스토어 링크 표시');
                      return _buildStoreLink();
                    } else {
                      debugPrint('❌ placeId가 없어서 스토어 링크 미표시');
                      return const SizedBox.shrink();
                    }
                  },
                ),
                _buildInfoRow(Icons.calendar_today, '생성일', _formatDate(currentPost.createdAt)),
                // 배포된 포스트만 배포 정보 표시
                if (currentPost.isDeployed) ...[
                  if (currentPost.deployedAt != null)
                    _buildInfoRow(Icons.rocket_launch, '배포일', _formatDate(currentPost.deployedAt!)),
                  _buildInfoRow(Icons.timer, '배포 기간', '${_calculateDeploymentDuration()}일'),
                ],
                _buildInfoRow(Icons.price_change, '리워드', '${currentPost.reward}'),
                _buildInfoRow(Icons.settings, '기능', _buildCapabilitiesText()),
                _buildInfoRow(Icons.group, '타겟', _buildTargetText()),
                // 쿠폰 상태 표시
                if (currentPost.isCoupon)
                  _buildInfoRow(
                    Icons.card_giftcard,
                    '쿠폰 상태',
                    currentPost.canUse ? '사용 가능 ✅' : '사용 불가 ❌',
                  ),
              ]),

              const SizedBox(height: 24),

              // 액션 버튼들 (상태별 분기)
              ..._buildStatusBasedActions(),

              const SizedBox(height: 24),

              // 미디어(그림/텍스트/사운드) - 화면 하단에 배치
              if (currentPost.mediaType.isNotEmpty && currentPost.mediaUrl.isNotEmpty)
                _buildMediaSection(context),

              const SizedBox(height: 16),

              // 포스트 상태 표시 섹션
              _buildPostStatusSection(),
            ],

            const SizedBox(height: 16),

            // 포스트 수정 버튼 - 최하단 배치 (편집 가능한 경우 + DRAFT 상태인 경우만)
            if (widget.isEditable && currentPost.canEdit)
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
    if (currentPost.isCoupon) caps.add('쿠폰');
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

  int _calculateDeploymentDuration() {
    if (!currentPost.isDeployed || currentPost.deployedAt == null) {
      return 0;
    }

    // deployedAt과 defaultExpiresAt 사이의 기간을 일수로 계산
    final duration = currentPost.defaultExpiresAt.difference(currentPost.deployedAt!);
    return duration.inDays;
  }

  // 사용자 뷰용 강조된 스토어 링크 카드
  Widget _buildStoreLinkCard() {
    final placeService = PlaceService();
    return FutureBuilder<PlaceModel?>(
      future: placeService.getPlaceById(currentPost.placeId!),
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
                Text('스토어 정보 로딩 중...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final place = snapshot.data!;
        return InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place.id);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.orange.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '연결된 스토어',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (place.address != null && place.address!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          place.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: Colors.orange.shade700,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 배포자 뷰용 간단한 스토어 링크
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

  void _useCoupon(BuildContext context) async {
    // 쿠폰 사용 가능 여부 체크
    if (!currentPost.canUse || !currentPost.isCoupon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 포스트는 쿠폰으로 사용할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 이미 사용된 쿠폰인지 체크
    // TODO: 쿼리 기반으로 사용 여부 확인
    final isUsedByCurrentUser = false; // 임시: 쿼리에서 확인 필요
    if (isUsedByCurrentUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 사용된 쿠폰입니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 연결된 플레이스 정보 가져오기
    if (currentPost.placeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('플레이스 정보를 찾을 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 플레이스 정보 가져오기
      final placeService = PlaceService();
      final place = await placeService.getPlace(currentPost.placeId!);

      // 로딩 다이얼로그 닫기
      if (mounted) Navigator.of(context).pop();

      if (place == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('플레이스 정보를 가져올 수 없습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 쿠폰이 활성화되어 있는지 체크
      if (!place.isCouponEnabled || place.couponPassword == null || place.couponPassword!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이 장소에서는 쿠폰 사용이 활성화되지 않았습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 쿠폰 사용 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CouponUsageDialog(
            postTitle: currentPost.title,
            placeName: place.name,
            expectedPassword: place.couponPassword!,
            onSuccess: () async {
              Navigator.of(context).pop(); // 다이얼로그 닫기
              await _processCouponUsage(context, place);
            },
            onCancel: () {
              Navigator.of(context).pop(); // 다이얼로그 닫기
            },
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그가 열려있다면 닫기
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processCouponUsage(BuildContext context, PlaceModel place) async {
    try {
      // 현재 사용자 정보 가져오기
      final currentUser = FirebaseService().currentUser;
      if (currentUser == null) {
        throw Exception('사용자 로그인이 필요합니다.');
      }

      // Firebase에 쿠폰 사용 기록 저장
      final batch = FirebaseFirestore.instance.batch();

      // 1. 포스트 사용 상태 업데이트
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(currentPost.postId);

      batch.update(postRef, {
        'usedAt': Timestamp.fromDate(DateTime.now()),
        'isUsedByCurrentUser': true,
        'totalUsed': FieldValue.increment(1),
      });

      // 2. 사용자의 쿠폰 사용 기록 추가
      final usageRef = FirebaseFirestore.instance
          .collection('coupon_usage')
          .doc();

      batch.set(usageRef, {
        'postId': currentPost.postId,
        'placeId': place.id,
        'userId': currentUser.uid,
        'placeName': place.name,
        'postTitle': currentPost.title,
        'rewardPoints': currentPost.reward,
        'usedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });

      // 3. 포인트 서비스를 통해 포인트 적립 처리 (배치 커밋 후)
      // batch.update는 나중에 별도로 처리

      // 배치 커밋
      await batch.commit();

      // 4. 포인트 시스템을 통해 포인트 적립
      final pointsService = PointsService();
      await pointsService.addCouponPoints(
        currentUser.uid,
        currentPost.reward,
        currentPost.title,
        place.id,
      );

      // 로컬 상태 업데이트
      setState(() {
        // TODO: 사용 통계는 별도 컬렉션에서 관리
        // usedAt, isUsedByCurrentUser, totalUsed는 PostModel에서 제거됨
        // 사용 기록은 post_collections 컬렉션에 저장될 예정
      });

      // 성공 다이얼로그 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => CouponSuccessDialog(
            postTitle: currentPost.title,
            rewardPoints: currentPost.reward,
            onClose: () {
              Navigator.of(context).pop(); // 성공 다이얼로그 닫기
            },
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('쿠폰 사용 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            // 플레이스 섹션 제목 추가
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.place, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '연결된 플레이스',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.placeDetail, arguments: place.id);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                        ),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Stack(
                        children: [
                          // 배경 패턴
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.1,
                              child: Container(
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/map_pattern.png'),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // 콘텐츠
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        place.name,
                                        style: TextStyle(
                                          color: Colors.blue.shade800,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.touch_app,
                                            size: 16,
                                            color: Colors.blue.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '플레이스 상세보기',
                                            style: TextStyle(
                                              color: Colors.blue.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          // 클릭 표시
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8), // 플레이스 박스와 다음 요소 간격 조정
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

            // 상세화면에서는 원본 이미지 우선 사용, 실패 시 썸네일 사용
            return _buildReliableImage(effectiveUrl, 0);
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
                            // 상세화면에서는 원본 이미지 우선 사용, 실패 시 썸네일 사용
            return _buildReliableImage(effectiveUrl, 0);
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

  // 안정적인 이미지 위젯 (원본 우선, 실패 시 썸네일 사용)
  Widget _buildReliableImage(String url, int imageIndex) {
    print('=== [_buildReliableImage] 시작 ===');
    print('URL: $url');
    print('이미지 인덱스: $imageIndex');

    // 1. Data URL (base64) 처리
    if (url.startsWith('data:image/')) {
      print('타입: Data URL - 직접 base64 디코딩');
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Data URL 이미지 로딩 실패: $error');
                return _buildImageErrorPlaceholder('Data 이미지를 불러올 수 없습니다');
              },
            ),
          ),
        );
      } catch (e) {
        print('Data URL 처리 실패: $e');
        return _buildImageErrorPlaceholder('이미지 데이터가 손상되었습니다');
      }
    }

    // 2. HTTP URL 처리 - 다단계 fallback 사용
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildNetworkImageWithFallback(url, imageIndex),
        ),
      );
    }

    // 3. 지원되지 않는 형식
    print('지원되지 않는 URL 형식: $url');
    return _buildImageErrorPlaceholder('지원되지 않는 이미지 형식');
  }

  // 네트워크 이미지 다단계 fallback
  Widget _buildNetworkImageWithFallback(String primaryUrl, int imageIndex) {
    print('네트워크 이미지 로딩 시도: $primaryUrl');

    return Image.network(
      primaryUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
                const SizedBox(height: 8),
                Text('고화질 이미지 로딩 중...', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('1차 이미지 로딩 실패: $primaryUrl - $error');

        // Fallback 1: 썸네일 URL 시도
        if (imageIndex < currentPost.thumbnailUrl.length) {
          final thumbnailUrl = currentPost.thumbnailUrl[imageIndex];
          print('Fallback 1: 썸네일 URL 시도 - $thumbnailUrl');

          return Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error2, stackTrace2) {
              print('2차 썸네일 로딩 실패: $thumbnailUrl - $error2');

              // Fallback 2: 웹 프록시 사용
              final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(primaryUrl)}&w=800&h=600&fit=cover&q=85';
              print('Fallback 2: 웹 프록시 시도 - $proxyUrl');

              return Image.network(
                proxyUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error3, stackTrace3) {
                  print('3차 프록시 로딩 실패: $proxyUrl - $error3');
                  return _buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
                },
              );
            },
          );
        }

        // Fallback: 프록시 직접 시도
        final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(primaryUrl)}&w=800&h=600&fit=cover&q=85';
        print('직접 프록시 시도: $proxyUrl');

        return Image.network(
          proxyUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error2, stackTrace2) {
            print('프록시도 실패: $error2');
            return _buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
          },
        );
      },
    );
  }

  // 고화질 원본 이미지 위젯 (상단 메인 플라이어용) - 기존 함수 유지
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

  // 포스트 상태 표시 섹션
  Widget _buildPostStatusSection() {
    Color statusColor;
    IconData statusIcon;
    String statusDescription;

    switch (currentPost.status) {
      case PostStatus.DRAFT:
        statusColor = Colors.blue;
        statusIcon = Icons.edit_note;
        statusDescription = '포스트가 작성되었으나 아직 배포되지 않았습니다. 언제든지 수정할 수 있습니다.';
        break;
      case PostStatus.DEPLOYED:
        statusColor = Colors.green;
        statusIcon = Icons.public;
        statusDescription = '포스트가 지도에 배포되어 다른 사용자들이 볼 수 있습니다. 더 이상 수정할 수 없습니다.';
        break;
      case PostStatus.RECALLED:
        statusColor = Colors.orange;
        statusIcon = Icons.undo;
        statusDescription = '포스트가 회수되었습니다. 재배포할 수 없습니다.';
        break;
      case PostStatus.DELETED:
        statusColor = Colors.red;
        statusIcon = Icons.delete;
        statusDescription = '포스트가 삭제되었습니다.';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Text(
                '포스트 상태: ${currentPost.status.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: statusColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusDescription,
            style: TextStyle(
              fontSize: 14,
              color: statusColor.withOpacity(0.7),
            ),
          ),
          if (currentPost.status == PostStatus.DEPLOYED) ...[
            const SizedBox(height: 12),
            _buildDeploymentInfo(),
          ],
        ],
      ),
    );
  }

  // 배포 정보 표시 (DEPLOYED 상태일 때)
  Widget _buildDeploymentInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배포 정보',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          // TODO: 배포 수량은 마커에서 조회해야 함
          Row(
            children: [
              Icon(Icons.numbers, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('배포 수량: 마커에서 확인 가능'),
            ],
          ),
          const SizedBox(height: 4),
          // TODO: 배포 시간은 마커에서 조회해야 함
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('배포 시간: 마커에서 확인 가능'),
            ],
          ),
          const SizedBox(height: 4),
          // TODO: 배포 위치는 마커에서 조회해야 함
          Row(
            children: [
              Icon(Icons.place, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('배포 위치: 마커에서 확인 가능'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 날짜/시간 포맷팅
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 포스트 상태 카드
  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (currentPost.status) {
      case PostStatus.DRAFT:
        statusColor = Colors.blue;
        statusIcon = Icons.edit_note;
        statusText = '초안 상태';
        statusDescription = '아직 배포되지 않았습니다. 수정 및 배포가 가능합니다.';
        break;
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

  // 상태별 액션 버튼들
  List<Widget> _buildStatusBasedActions() {
    final List<Widget> actions = [];

    switch (currentPost.status) {
      case PostStatus.DRAFT:
        // 초안 상태: 편집 및 배포 가능
        if (widget.isEditable) {
          actions.addAll([
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _editPost(context),
                icon: const Icon(Icons.edit),
                label: const Text('포스트 편집'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _deployPost(context),
                icon: const Icon(Icons.publish),
                label: const Text('포스트 배포하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ]);
        }
        break;

      case PostStatus.DEPLOYED:
        // 배포된 상태: 쿠폰 사용, 공유 등 가능
        if (!widget.isEditable) {
          if (currentPost.canUse && currentPost.isCoupon) {
            actions.add(
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
            );
            actions.add(const SizedBox(height: 12));
          }

          actions.add(
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _forwardPost(context),
                icon: const Icon(Icons.share),
                label: const Text('포스트 공유하기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
            ),
          );
        } else {
          // 본인의 배포된 포스트: 통계 보기
          actions.add(
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showPostStatistics(context),
                icon: const Icon(Icons.analytics),
                label: const Text('배포 통계 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
            ),
          );
        }
        break;

      case PostStatus.RECALLED:
        // 회수된 상태: 통계 보기만 가능
        if (widget.isEditable) {
          actions.add(
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showPostStatistics(context),
                icon: const Icon(Icons.analytics),
                label: const Text('배포 통계 보기'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          );
        }
        break;

      case PostStatus.DELETED:
        // 삭제된 상태: 복원 옵션 (본인의 경우)
        if (widget.isEditable) {
          actions.add(
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      '삭제된 포스트입니다',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        break;
    }

    if (actions.isNotEmpty) {
      actions.add(const SizedBox(height: 24));
    }

    return actions;
  }

  // 포스트 배포하기
  void _deployPost(BuildContext context) {
    // TODO: 포스트 배포 화면으로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('포스트 배포 기능을 구현 중입니다.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 포스트 통계 보기
  void _showPostStatistics(BuildContext context) {
    // TODO: 포스트 통계 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 통계'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 총 수령 횟수: 마커에서 확인 가능'),
            Text('• 남은 수량: 마커에서 확인 가능'),
            Text('• 배포 위치: 마커에서 확인 가능'),
            Text('• 배포 시간: 마커에서 확인 가능'),
            SizedBox(height: 16),
            Text(
              '상세한 통계는 마커 정보에서 확인할 수 있습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
