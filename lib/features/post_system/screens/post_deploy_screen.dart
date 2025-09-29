import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../map_system/services/fog_of_war/visit_tile_service.dart';
import '../../../utils/tile_utils.dart';


class PostDeployScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const PostDeployScreen({
    super.key,
    required this.arguments,
  });

  @override
  State<PostDeployScreen> createState() => _PostDeployScreenState();
}

class _PostDeployScreenState extends State<PostDeployScreen> {
  final PostService _postService = PostService();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController(text: '100');

  LatLng? _selectedLocation;
  String? _deployType;
  List<PostModel> _userPosts = [];
  PostModel? _selectedPost;
  bool _isLoading = false;
  bool _isDeploying = false;

  // 기간 관련 필드 추가
  int _selectedDuration = 7; // 기본 7일
  final List<int> _durationOptions = [1, 3, 7, 14, 30]; // 1일, 3일, 7일, 14일, 30일

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 포커스를 받을 때 포스트 목록 새로고침
    if (_selectedLocation != null) {
      _loadUserPosts();
    }
  }

  void _initializeData() {
    debugPrint('PostDeployScreen 초기화 시작');
    debugPrint('arguments: ${widget.arguments}');
    
    final args = widget.arguments;
    _selectedLocation = args['location'] as LatLng?;
    _deployType = args['type'] as String? ?? 'location'; // 기본값 설정
    
    debugPrint('위치: $_selectedLocation');
    debugPrint('타입: $_deployType');
    
    if (_selectedLocation != null) {
      _loadUserPosts();
    } else {
      // 위치 정보가 없으면 로딩 상태 해제
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        debugPrint('사용자 ID: $uid');
        // DRAFT 상태 포스트만 로드 (배포 가능한 포스트만)
        final posts = await _postService.getDraftPosts(uid);
        debugPrint('사용자 포스트 로드 완료: ${posts.length}개');
        setState(() {
          _userPosts = posts;
        });
      } else {
        debugPrint('사용자가 로그인되어 있지 않습니다');
      }
    } catch (e) {
      debugPrint('포스트 로드 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포스트를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateTotal() {
    setState(() {});
  }

  void _onPostSelected(PostModel post) {
    setState(() {
      _selectedPost = post;
      // 선택된 포스트의 리워드(단가)를 가격 필드에 자동 설정
      _priceController.text = post.reward.toString();
    });
    _calculateTotal();
  }

  double get _totalPrice {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    return quantity * price.toDouble();
  }

  Future<void> _deployPostToLocation() async {
    if (_selectedPost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트를 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // postId 검증 추가
    if (_selectedPost!.postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트 정보가 올바르지 않습니다. 포스트를 다시 선택해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text);
    final price = int.tryParse(_priceController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유효한 수량을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('유효한 가격을 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🚀 임시로 포그레벨 체크 비활성화 - 모든 위치에서 배포 허용
    print('🔍 배포 위치: ${_selectedLocation?.latitude}, ${_selectedLocation?.longitude}');
    print('✅ 포그레벨 체크 비활성화 - 배포 진행');
    
    // TODO: 포그레벨 체크 로직 수정 후 활성화
    // if (_selectedLocation != null) {
    //   final tileId = getTileId(_selectedLocation!.latitude, _selectedLocation!.longitude);
    //   final fogLevel = await VisitTileService.getFogLevelForTile(tileId, currentPosition: _selectedLocation);
    //   if (fogLevel == 3) {
    //     // 배포 불가 처리
    //     return;
    //   }
    // }

    setState(() {
      _isDeploying = true;
    });

    try {
      // 1. 지갑 잔액 확인 (구현 필요)
      // 2. 예치(escrow) 홀드 (구현 필요)
      
      // 3. 포스트는 업데이트하지 않고 마커만 생성 (중복 배포 허용)
      // 포스트 자체는 원본 그대로 유지하고, 마커만 새로 생성

      // 4. 마커 생성 (커스텀 기간 적용)
      final customExpiresAt = DateTime.now().add(Duration(days: _selectedDuration));

      await MarkerService.createMarker(
        postId: _selectedPost!.postId,
        title: _selectedPost!.title,
        position: _selectedLocation!,
        quantity: quantity, // 전체 수량을 하나의 마커에
        reward: _selectedPost!.reward, // ✅ reward 전달
        creatorId: _selectedPost!.creatorId,
        expiresAt: customExpiresAt, // 사용자가 선택한 기간 적용
      );
      print('✅ 마커 생성 완료: ${_selectedPost!.title} (${quantity}개 수량)');

      print('✅ 포스트 배포 완료: ${_selectedPost!.postId} (${quantity}개 마커 생성)');

      if (mounted) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포스트가 성공적으로 배포되었습니다! (${quantity}개 마커 생성)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        Navigator.pop(context, {
          'location': _selectedLocation,
          'postId': _selectedPost!.postId,
          'address': null,
          'quantity': quantity,
          'price': price,
          'totalPrice': _totalPrice,
        });
      }
    } catch (e) {
      debugPrint('❌ 포스트 배포 실패: $e');
      if (mounted) {
        String errorMessage = '배포 실패: ';
        if (e.toString().contains('포스트 ID가 비어있습니다')) {
          errorMessage += '포스트 정보가 올바르지 않습니다. 포스트를 다시 선택해주세요.';
        } else if (e.toString().contains('포스트를 찾을 수 없습니다')) {
          errorMessage += '선택한 포스트를 찾을 수 없습니다. 포스트를 다시 선택해주세요.';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeploying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle()),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: _selectedLocation == null
          ? const Center(child: Text('위치 정보가 없습니다.'))
          : Column(
              children: [
                // 상단 위치 정보 영역
                _buildLocationInfo(),

                // 포스트 선택 리스트 (확장 가능)
                Expanded(
                  child: _buildPostList(),
                ),

                // 하단 고정 뿌리기 영역
                _buildBottomDeploySection(),
              ],
            ),
    );
  }

  String _getScreenTitle() {
    final type = _deployType ?? 'location';
    switch (type) {
      case 'location':
        return '이 위치에 뿌리기';
      case 'address':
        return '이 주소에 뿌리기';
      case 'category':
        return '특정 업종에 뿌리기';
      default:
        return '포스트 배포';
    }
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택된 위치',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF4D4DFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '위도: ${_selectedLocation!.latitude.toStringAsFixed(6)}\n경도: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '포스트 선택',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_userPosts.isEmpty)
          _buildNoPostsSection()
        else
          _buildPostsGrid(),
      ],
    );
  }

  Widget _buildNoPostsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.post_add,
            size: 48,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '저장된 포스트가 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '새로운 포스트를 만들어보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              // PostPlaceSelectionScreen으로 이동하고 결과 대기
              final result = await Navigator.pushNamed(
                context, 
                '/post-place-selection',
                arguments: {
                  'fromPostDeploy': true,
                  'returnToPostDeploy': true,
                },
              );
              
              // 포스트 생성 완료 후 사용자 포스트 목록 새로고침
              if (result == true && mounted) {
                _loadUserPosts();
              }
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('포스트 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4D4DFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    return LayoutBuilder(
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
          itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final isSelected = _selectedPost?.postId == post.postId;
        
        return GestureDetector(
          onTap: () {
            _onPostSelected(post);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4D4DFF).withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF4D4DFF) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 32,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${post.reward}원',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4D4DFF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '기본 만료: ${_formatDate(post.defaultExpiresAt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
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
      },
    );
  }

  Widget _buildDeploySettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '배포 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '배포 수량',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '수량 입력',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _calculateTotal(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '개당 가격',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    enabled: false, // 수정 불가능하게 변경
                    decoration: InputDecoration(
                      hintText: _selectedPost != null ? '${_selectedPost!.reward}원 (고정)' : '포스트를 선택하세요',
                      border: const OutlineInputBorder(),
                      suffixText: '원',
                      filled: true,
                      fillColor: Colors.grey.shade100, // 비활성화 상태 시각적 표시
                    ),
                    style: const TextStyle(
                      color: Colors.black54, // 읽기 전용 필드 스타일
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 기간 선택 필드 추가
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '배포 기간',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedDuration,
                  isExpanded: true,
                  items: _durationOptions.map((duration) {
                    return DropdownMenuItem<int>(
                      value: duration,
                      child: Text('${duration}일'),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    if (value != null) {
                      setState(() {
                        _selectedDuration = value;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4D4DFF).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4D4DFF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '토탈 가격',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₩${_totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4D4DFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border(
          bottom: BorderSide(color: Colors.blue[200]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: Colors.blue[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '위도: ${_selectedLocation!.latitude.toStringAsFixed(6)}, 경도: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '뿌릴 포스트 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userPosts.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.68, // 하단 오버플로우 방지를 위해 높이 증가
                        ),
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          final post = _userPosts[index];
                          return _buildPostGridCard(post);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostGridCard(PostModel post) {
    final isSelected = _selectedPost?.postId == post.postId;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onPostSelected(post),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스트 이미지
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    // 포스트 이미지 (PostTileCard와 동일한 로직)
                    _buildImageWidget(post),

                    // 선택 표시
                    if (isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.blue[400],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 포스트 정보
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      post.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // 설명
                    Text(
                      post.description,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // 리워드
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${post.reward}원',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(PostModel post) {
    if (post.mediaUrl.isNotEmpty) {
      // 이미지 타입 체크를 더 관대하게 변경
      bool hasImageMedia = post.mediaType.isNotEmpty &&
          (post.mediaType.any((type) => type.toLowerCase().contains('image')) ||
           post.mediaUrl.first.toLowerCase().contains('.jpg') ||
           post.mediaUrl.first.toLowerCase().contains('.jpeg') ||
           post.mediaUrl.first.toLowerCase().contains('.png') ||
           post.mediaUrl.first.toLowerCase().contains('.gif') ||
           post.mediaUrl.first.toLowerCase().contains('firebasestorage'));

      if (hasImageMedia) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          child: Image.network(
            post.mediaUrl.first,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Center(child: Icon(Icons.image, color: Colors.grey[400])),
          ),
        );
      }
    }

    // 이미지가 없거나 이미지 타입이 아닌 경우 기본 아이콘 표시
    return Center(
      child: Icon(
        Icons.image,
        size: 32,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.post_add,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '저장된 포스트가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 포스트를 만들어보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDeploySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 선택된 포스트 요약
              if (_selectedPost != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '선택된 포스트: ${_selectedPost!.title}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_selectedPost!.reward}원',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),

              // 배포 설정 (간소화)
              Row(
                children: [
                  // 수량 설정
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: '수량',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 기간 설정
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedDuration,
                      decoration: const InputDecoration(
                        labelText: '기간',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _durationOptions.map((duration) {
                        return DropdownMenuItem(
                          value: duration,
                          child: Text('${duration}일'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDuration = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 총 비용 및 뿌리기 버튼
              Row(
                children: [
                  // 총 비용 표시
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '총 비용',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${_totalPrice.toStringAsFixed(0)}원',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 뿌리기 버튼
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedPost != null && !_isDeploying
                          ? _deployPostToLocation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isDeploying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '뿌리기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '미정';
    return '${date.month}/${date.day}';
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


  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
