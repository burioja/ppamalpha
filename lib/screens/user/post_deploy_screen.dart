import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';

class PostDeployScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const PostDeployScreen({
    Key? key,
    required this.arguments,
  }) : super(key: key);

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
        // 사용자의 최근 50개 포스트 로드 (새로 생성된 포스트 포함)
        final posts = await _postService.getUserPosts(uid, limit: 50);
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

  double get _totalPrice {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    return quantity * price.toDouble();
  }

  Future<void> _deployPost() async {
    if (_selectedPost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트를 선택해주세요.'),
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

    setState(() {
      _isDeploying = true;
    });

    try {
      // 1. 지갑 잔액 확인 (구현 필요)
      // 2. 예치(escrow) 홀드 (구현 필요)
      
      // 3. 마커 생성 및 Firestore에 저장
      await _createMarkerInFirestore(
        post: _selectedPost!,
        location: _selectedLocation!,
        quantity: quantity,
        price: price,
      );

      // 4. 포스트 상태 업데이트 (배포됨으로 표시)
      await _postService.updatePost(_selectedPost!.flyerId, {
        'isDistributed': true,
        'distributedAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        Navigator.pop(context, {
          'location': _selectedLocation,
          'postId': _selectedPost!.flyerId,
          'address': null,
          'quantity': quantity,
          'price': price,
          'totalPrice': _totalPrice,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배포에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isDeploying = false;
      });
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
        final isSelected = _selectedPost?.flyerId == post.flyerId;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPost = post;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4D4DFF).withOpacity(0.1) : Colors.white,
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
                        '만료: ${_formatDate(post.expiresAt)}',
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
                    decoration: const InputDecoration(
                      hintText: '가격 입력',
                      border: OutlineInputBorder(),
                      suffixText: '원',
                    ),
                    onChanged: (_) => _calculateTotal(),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4D4DFF).withOpacity(0.1),
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
        onPressed: _selectedPost != null && !_isDeploying ? _deployPost : null,
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

  // 마커를 Firestore에 생성하는 메서드
  Future<void> _createMarkerInFirestore({
    required PostModel post,
    required LatLng location,
    required int quantity,
    required int price,
  }) async {
    try {
      // 기존 마커가 있는지 확인 (중복 방지)
      final existingMarkers = await FirebaseFirestore.instance
          .collection('markers')
          .where('flyerId', isEqualTo: post.flyerId)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (existingMarkers.docs.isNotEmpty) {
        debugPrint('이미 배포된 포스트의 마커가 존재합니다: ${post.flyerId}');
        return; // 이미 마커가 있으면 생성하지 않음
      }

      final markerData = {
        'title': post.title,
        'price': price,
        'amount': quantity,
        'userId': post.creatorId,
        'position': GeoPoint(location.latitude, location.longitude),
        'remainingAmount': quantity,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': post.expiresAt,
        'isActive': true,
        'isCollected': false,
        'type': 'post_place', // MapScreen과 일치하는 타입
        'flyerId': post.flyerId,
        'creatorName': post.creatorName,
        'description': post.description,
        'targetGender': post.targetGender,
        'targetAge': post.targetAge,
        'canRespond': post.canRespond,
        'canForward': post.canForward,
        'canRequestReward': post.canRequestReward,
        'canUse': post.canUse,
        'markerId': post.markerId,
        'radius': post.radius, // 포스트 반경 정보 추가
      };

      // markers 컬렉션에 저장
      final docRef = await FirebaseFirestore.instance.collection('markers').add(markerData);
      
      debugPrint('마커 생성 완료: ${post.title} at ${location.latitude}, ${location.longitude}');
      debugPrint('마커 ID: ${docRef.id}, 포스트 ID: ${post.flyerId}');
    } catch (e) {
      debugPrint('마커 생성 실패: $e');
      throw Exception('마커 생성에 실패했습니다: $e');
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}
