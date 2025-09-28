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
        backgroundColor: const Color(0xFF4D4DFF),
        foregroundColor: Colors.white,
      ),
      body: _selectedLocation == null
          ? const Center(child: Text('위치 정보가 없습니다.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 위치 정보 표시
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  
                  // 포스트 선택 섹션
                  _buildPostSelectionSection(),
                  const SizedBox(height: 24),
                  
                  // 배포 설정 섹션
                  _buildDeploySettingsSection(),
                  const SizedBox(height: 32),
                  
                  // 배포 버튼
                  _buildDeployButton(),
                ],
              ),
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

  Widget _buildDeployButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _selectedPost != null && !_isDeploying ? _deployPostToLocation : null,
        icon: _isDeploying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.rocket_launch, color: Colors.white),
        label: Text(
          _isDeploying ? '배포 중...' : '배포하기',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4D4DFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
