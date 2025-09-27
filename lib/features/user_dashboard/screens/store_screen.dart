import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/data/post_service.dart';
import '../../../features/shared_services/image_upload_service.dart';
import '../../../core/models/post/post_model.dart';
import '../../post_system/widgets/post_tile_card.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final PostService _postService = PostService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  List<PostModel> _collectedPosts = [];
  List<String> _storeImages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  String _error = '';
  final String _storeName = '내 스토어';
  final String _storeDescription = '나만의 특별한 스토어입니다.';
  final double _averageRating = 4.2;
  final int _reviewCount = 127;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    await Future.wait([
      _loadCollectedPosts(),
      _loadStoreImages(),
    ]);
  }

  Future<void> _loadCollectedPosts() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final posts = await _postService.getCollectedPosts(_currentUserId!);
      setState(() {
        _collectedPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStoreImages() async {
    if (_currentUserId == null) return;

    try {
      final images = await _imageUploadService.getStoreImages(_currentUserId!);
      setState(() {
        _storeImages = images;
      });
    } catch (e) {
      // 이미지 로드 실패는 조용히 처리
    }
  }

  Future<void> _uploadImages() async {
    if (_isUploadingImage) return; // 중복 요청 방지
    
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final urls = await _imageUploadService.uploadStoreImages();
      
      if (urls.isNotEmpty) {
        setState(() {
          _storeImages.addAll(urls);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${urls.length}개 이미지가 업로드되었습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('업로드된 이미지가 없습니다.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = '이미지 업로드 실패';
      if (e.toString().contains('선택된 이미지가 없습니다')) {
        errorMessage = '이미지를 선택해주세요';
      } else if (e.toString().contains('사용자 인증이 필요')) {
        errorMessage = '로그인이 필요합니다';
      } else if (e.toString().contains('이미지 선택에 실패')) {
        errorMessage = '이미지 선택이 취소되었습니다';
      } else {
        errorMessage = '이미지 업로드 중 오류가 발생했습니다';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '다시 시도',
            textColor: Colors.white,
            onPressed: () => _uploadImages(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_isUploadingImage) return; // 중복 요청 방지
    
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final urls = await _imageUploadService.uploadStoreImages(fromCamera: true);
      
      if (urls.isNotEmpty) {
        setState(() {
          _storeImages.addAll(urls);
        });
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사진이 업로드되었습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('촬영된 사진이 없습니다.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = '사진 촬영 실패';
      if (e.toString().contains('선택된 이미지가 없습니다')) {
        errorMessage = '사진 촬영이 취소되었습니다';
      } else if (e.toString().contains('사용자 인증이 필요')) {
        errorMessage = '로그인이 필요합니다';
      } else if (e.toString().contains('이미지 선택에 실패')) {
        errorMessage = '카메라 접근에 실패했습니다';
      } else {
        errorMessage = '사진 업로드 중 오류가 발생했습니다';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: '다시 시도',
            textColor: Colors.white,
            onPressed: () => _takePhoto(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '이미지 추가',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(context);
                _uploadImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  int get _totalReward {
    return _collectedPosts
        .where((post) => post.canUse && post.status != PostStatus.DELETED)
        .fold<int>(0, (sum, post) => sum + post.reward);
  }

  int get _usablePostsCount {
    return _collectedPosts
        .where((post) => post.canBeUsed)
        .length;
  }

  Future<void> _performPostUsage(PostModel post) async {
    if (_currentUserId == null) return;

    try {
      // 로딩 다이얼로그 표시
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 포스트 사용 처리
      await _postService.usePost(post.postId, _currentUserId!);

      // 로딩 다이얼로그 닫기
      if (!mounted) return;
      Navigator.of(context).pop();

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${post.title} 포스트를 사용했습니다! (+${post.reward}포인트)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // 목록 새로고침
      await _loadCollectedPosts();
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (!mounted) return;
      Navigator.of(context).pop();

      // 에러 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('포스트 사용 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _usePost(PostModel post) {
    // 사용 가능 여부 확인
    if (!post.canBeUsed) {
      String message = '';
      if (post.isUsed || post.isUsedByCurrentUser) {
        message = '이미 사용된 포스트입니다.';
      } else if (post.status == PostStatus.DELETED) {
        message = '삭제된 포스트입니다.';
      } else if (!post.canUse) {
        message = '사용할 수 없는 포스트입니다.';
      } else if (!post.isActive) {
        message = '비활성화된 포스트입니다.';
      } else {
        message = '포스트를 사용할 수 없습니다.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('포스트 사용'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${post.title} 포스트를 사용하시겠습니까?'),
              const SizedBox(height: 8),
              Text('리워드: ${post.reward}포인트'),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('내용: ${post.description}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performPostUsage(post);
              },
              child: const Text('사용'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text('로드 오류', style: TextStyle(fontSize: 18, color: Colors.red.shade700)),
                      const SizedBox(height: 8),
                      Text(_error, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadStoreData,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : _buildGooglePlaceStyleUI(),
      floatingActionButton: _isUploadingImage
          ? const CircularProgressIndicator()
          : FloatingActionButton(
              onPressed: _showImageOptions,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add_a_photo, color: Colors.white),
            ),
    );
  }

  Widget _buildGooglePlaceStyleUI() {
    return CustomScrollView(
      slivers: [
        // 상단 이미지 슬라이더 앱바
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: Colors.white,
          title: Text(_storeName),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStoreData,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                // 공유 기능
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildImageSlider(),
          ),
        ),
        
        // 스토어 정보 섹션
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreHeader(),
                const SizedBox(height: 16),
                _buildRatingSection(),
                const SizedBox(height: 16),
                _buildQuickStats(),
                const SizedBox(height: 24),
                _buildImageGallerySection(),
                const SizedBox(height: 24),
                _buildOperatingHours(),
                const SizedBox(height: 24),
                _buildContactInfo(),
                const SizedBox(height: 24),
                _buildCollectedPostsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _getCrossAxisCount(double width) {
    // 반응형 그리드 컬럼 수 계산
    if (width < 600) {
      return 2; // 모바일: 2열
    } else if (width < 900) {
      return 3; // 태블릿: 3열  
    } else {
      return 4; // 데스크톱: 4열
    }
  }

  // 이미지 슬라이더 위젯
  Widget _buildImageSlider() {
    if (_storeImages.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '첫 번째 사진을 추가해보세요!',
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
          itemCount: _storeImages.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: _storeImages[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, size: 48, color: Colors.grey),
              ),
            );
          },
        ),
        if (_storeImages.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_storeImages.length}장',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // 스토어 헤더 (이름, 설명)
  Widget _buildStoreHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _storeName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text('인증됨', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _storeDescription,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 평점 섹션
  Widget _buildRatingSection() {
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < _averageRating.floor()
                  ? Icons.star
                  : index < _averageRating
                      ? Icons.star_half
                      : Icons.star_border,
              color: Colors.amber,
              size: 20,
            );
          }),
        ),
        const SizedBox(width: 8),
        Text(
          _averageRating.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(width: 4),
        Text(
          '($_reviewCount개 리뷰)',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ],
    );
  }

  // 빠른 통계
  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            '총 포스트',
            '${_collectedPosts.length}',
            Icons.collections_bookmark,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '사용 가능',
            '$_usablePostsCount',
            Icons.card_giftcard,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            '총 리워드',
            '$_totalReward',
            Icons.monetization_on,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 갤러리 섹션
  Widget _buildImageGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '사진',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_storeImages.isNotEmpty)
              TextButton(
                onPressed: () {
                  // 전체 이미지 보기
                },
                child: Text('모두 보기 (${_storeImages.length})'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_storeImages.isEmpty)
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                '아직 업로드된 사진이 없습니다',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _storeImages.length + 1,
              itemBuilder: (context, index) {
                if (index == _storeImages.length) {
                  return GestureDetector(
                    onTap: _showImageOptions,
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.grey),
                          Text('추가', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                }
                
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(right: index < _storeImages.length - 1 ? 8 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _storeImages[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // 운영 시간
  Widget _buildOperatingHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운영 시간',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildOperatingHourRow('월요일', '09:00 - 18:00'),
              _buildOperatingHourRow('화요일', '09:00 - 18:00'),
              _buildOperatingHourRow('수요일', '09:00 - 18:00'),
              _buildOperatingHourRow('목요일', '09:00 - 18:00'),
              _buildOperatingHourRow('금요일', '09:00 - 18:00'),
              _buildOperatingHourRow('토요일', '10:00 - 16:00'),
              _buildOperatingHourRow('일요일', '휴무', isToday: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatingHourRow(String day, String hours, {bool isToday = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              day,
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Colors.blue : Colors.black,
              ),
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isToday ? Colors.blue : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 연락처 정보
  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '연락처',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildContactRow(Icons.phone, '전화', '010-1234-5678'),
        _buildContactRow(Icons.email, '이메일', 'mystore@example.com'),
        _buildContactRow(Icons.web, '웹사이트', 'www.mystore.com'),
        _buildContactRow(Icons.location_on, '주소', '서울시 강남구 테헤란로 123'),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // 수집한 포스트 섹션
  Widget _buildCollectedPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '수집한 포스트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${_collectedPosts.length}개',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_collectedPosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            child: const Column(
              children: [
                Icon(Icons.collections_bookmark_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  '아직 수집한 포스트가 없습니다',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  '지도에서 포스트를 찾아 수집해보세요!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
              
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: _collectedPosts.length,
                itemBuilder: (context, index) {
                  final post = _collectedPosts[index];
                  return Stack(
                    children: [
                      PostTileCard(
                        post: post,
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/post-detail',
                            arguments: {
                              'post': post,
                              'isEditable': false,
                            },
                          );
                          
                          if (result == true || result == 'used') {
                            _loadCollectedPosts();
                          }
                        },
                      ),
                      if (post.canBeUsed)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _usePost(post),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.redeem, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('사용', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
      ],
    );
  }
}