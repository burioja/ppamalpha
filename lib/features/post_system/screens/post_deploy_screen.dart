import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../../core/services/data/points_service.dart';
import '../../map_system/services/fog_of_war/visit_tile_service.dart';
import '../../../utils/tile_utils.dart';
import '../widgets/building_unit_selector.dart';


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
  final PointsService _pointsService = PointsService();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController(text: '100');
  final TextEditingController _durationController = TextEditingController(text: '7');

  LatLng? _selectedLocation;
  String? _deployType;
  List<PostModel> _userPosts = [];
  PostModel? _selectedPost;
  bool _isLoading = false;
  bool _isDeploying = false;
  int _userPoints = 0; // 사용자 포인트

  // 기간 관련 필드 추가
  int _selectedDuration = 7; // 기본 7일
  final List<int> _durationOptions = [1, 3, 7, 14, 30]; // 1일, 3일, 7일, 14일, 30일

  // 주소 모드 관련 필드
  String? _buildingName;
  String? _selectedUnit;

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
    _buildingName = args['buildingName'] as String?;
    
    debugPrint('위치: $_selectedLocation');
    debugPrint('타입: $_deployType');
    debugPrint('건물명: $_buildingName');
    
    if (_selectedLocation != null) {
      _loadUserPosts();
      _loadUserPoints(); // 포인트 로드
    } else {
      // 위치 정보가 없으면 로딩 상태 해제
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserPoints() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userPoints = await _pointsService.getUserPoints(uid);
        setState(() {
          _userPoints = userPoints?.totalPoints ?? 0;
        });
        debugPrint('사용자 포인트: $_userPoints');
      }
    } catch (e) {
      debugPrint('포인트 로드 오류: $e');
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
        // DRAFT와 DEPLOYED 포스트 모두 로드 (다회 배포 지원)
        final allPosts = await _postService.getUserPosts(uid);
        debugPrint('전체 포스트 로드 완료: ${allPosts.length}개');

        // DELETED 상태만 제외 (DRAFT, DEPLOYED, RECALLED 모두 표시)
        final deployablePosts = allPosts.where((post) {
          return post.status != PostStatus.DELETED;
        }).toList();
        
        debugPrint('배포 가능한 포스트: ${deployablePosts.length}개 (DRAFT + DEPLOYED + RECALLED)');
        debugPrint('  - DRAFT: ${deployablePosts.where((p) => p.status == PostStatus.DRAFT).length}개');
        debugPrint('  - DEPLOYED: ${deployablePosts.where((p) => p.status == PostStatus.DEPLOYED).length}개');
        debugPrint('  - RECALLED: ${deployablePosts.where((p) => p.status == PostStatus.RECALLED).length}개');

        setState(() {
          _userPosts = deployablePosts;
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
    // 1. 포스트 선택 검증
    if (_selectedPost == null) {
      _showErrorDialog(
        title: '포스트 선택 필요',
        message: '배포할 포스트를 먼저 선택해주세요.',
        action: '확인',
      );
      return;
    }

    // 2. 포스트 ID 검증
    if (_selectedPost!.postId.isEmpty) {
      _showErrorDialog(
        title: '포스트 오류',
        message: '포스트 정보가 올바르지 않습니다.\n포스트를 다시 선택하거나 새로 생성해주세요.',
        action: '확인',
      );
      return;
    }

    // 3. 배포 가능 상태 검증 (DRAFT, DEPLOYED 배포 가능)
    if (!_selectedPost!.canDeploy) {
      _showErrorDialog(
        title: '배포 불가',
        message: '회수되었거나 삭제된 포스트는 배포할 수 없습니다.\n\n현재 상태: ${_selectedPost!.status.name}\n배포 가능 상태: 배포 대기 또는 배포됨',
        action: '확인',
      );
      return;
    }

    // 3-1. 기간 검증 및 자동 조정
    int duration = int.tryParse(_durationController.text) ?? 7;
    if (duration > 30) {
      setState(() {
        _selectedDuration = 30;
        _durationController.text = '30';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포스트 배포 기간은 최대 30일입니다. 30일로 설정되었습니다.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      duration = 30;
    } else {
      _selectedDuration = duration;
    }

    // 3-2. 수량 검증
    int quantity = int.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      _showErrorDialog(
        title: '수량 입력 오류',
        message: '배포 수량은 1개 이상이어야 합니다.\n현재 입력: "${_quantityController.text}"',
        action: '확인',
      );
      return;
    }

    if (quantity > 1000) {
      _showErrorDialog(
        title: '수량 제한 초과',
        message: '한 번에 최대 1,000개까지만 배포할 수 있습니다.\n현재 입력: $quantity개',
        action: '확인',
      );
      return;
    }

    // 4. 가격 검증
    final price = int.tryParse(_priceController.text);
    if (price == null || price <= 0) {
      _showErrorDialog(
        title: '가격 입력 오류',
        message: '단가는 0원보다 커야 합니다.\n현재 입력: "${_priceController.text}"',
        action: '확인',
      );
      return;
    }

    // 5. 총 비용 계산 및 포인트 검증
    final totalCost = quantity * price;
    if (totalCost > _userPoints) {
      // 소지금 내에서 최대 수량 계산 (단가는 그대로)
      final maxQuantity = (_userPoints / price).floor();
      
      if (maxQuantity <= 0) {
        _showErrorDialog(
          title: '포인트 부족',
          message: '포인트가 부족합니다.\n현재 포인트: ${_userPoints}원\n필요 포인트: ${totalCost}원\n\n포인트를 충전해주세요.',
          action: '확인',
        );
        return;
      }

      // 자동으로 수량 조정
      setState(() {
        _quantityController.text = maxQuantity.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('포인트가 부족하여 수량을 ${maxQuantity}개로 조정했습니다.\n(현재 포인트: ${_userPoints}원)'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 조정된 수량으로 재설정
      quantity = maxQuantity;
    }


    // 6. 위치 정보 검증
    if (_selectedLocation == null) {
      _showErrorDialog(
        title: '위치 정보 없음',
        message: '배포 위치 정보를 찾을 수 없습니다.\n지도에서 위치를 다시 선택해주세요.',
        action: '확인',
      );
      return;
    }

    // 7. 고액 배포 확인
    final finalTotalCost = quantity * price;
    if (finalTotalCost > 10000000) {
      final confirmed = await _showConfirmDialog(
        title: '고액 배포 확인',
        message: '총 ${finalTotalCost.toStringAsFixed(0)}원을 배포하시겠습니까?\n수량: $quantity개 × 단가: $price원',
        confirmText: '배포',
        cancelText: '취소',
      );
      if (confirmed != true) return;
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

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
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

        // Navigator.pop에서 사용하기 위해 postId 저장
        final deployedPostId = _selectedPost!.postId;

        // 배포 성공 후 즉시 포스트 목록 새로고침 (배포된 포스트 제거)
        await _loadUserPosts();

        // 선택된 포스트 초기화 (배포 완료되었으므로)
        setState(() {
          _selectedPost = null;
        });

        if (mounted) {
          Navigator.pop(context, {
            'location': _selectedLocation,
            'postId': deployedPostId,
            'address': null,
            'quantity': quantity,
            'price': price,
            'totalPrice': _totalPrice,
          });
        }
        break; // 성공하면 루프 종료

      } catch (e, stackTrace) {
        retryCount++;
        debugPrint('❌ 포스트 배포 실패 (시도 $retryCount/$maxRetries): $e');
        debugPrint('스택 트레이스: $stackTrace');

        if (!mounted) break;

        // 마지막 시도가 실패한 경우
        if (retryCount >= maxRetries) {
          await _showDetailedErrorDialog(e, quantity, price);
          break;
        }

        // 재시도 전 사용자에게 확인
        final shouldRetry = await _showRetryDialog(
          attempt: retryCount,
          maxAttempts: maxRetries,
          error: e.toString(),
        );

        if (shouldRetry != true) break;

        // 재시도 전 잠시 대기 (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }

    if (mounted) {
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
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: '디자인 프리뷰',
            onPressed: () {
              Navigator.pushNamed(context, '/post-deploy-design-demo');
            },
          ),
        ],
      ),
      body: _selectedLocation == null
          ? const Center(child: Text('위치 정보가 없습니다.'))
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue[50]!, Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 상단 위치 정보 영역
                    _buildLocationInfo(),

                    const SizedBox(height: 20),
                    // 포스트 선택 리스트
                    _buildPostList(),

                    const SizedBox(height: 20),
                    // 하단 뿌리기 영역
                    _buildBottomDeploySection(),
                    
                    const SizedBox(height: 16),
                    // 배포 버튼
                    _buildModernDeployButton(),
                    
                    const SizedBox(height: 20),
                  ],
                ),
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
          InkWell(
            onTap: () async {
              // 아이콘 클릭 시 포스트 만들기 화면으로 이동
              final result = await Navigator.pushNamed(
                context, 
                '/post-place-selection',
                arguments: {
                  'fromPostDeploy': true,
                  'returnToPostDeploy': true,
                },
              );
              
              if (result == true && mounted) {
                _loadUserPosts();
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.post_add,
                size: 48,
                color: Colors.grey[600],
              ),
            ),
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
                      Row(
                        children: [
                          Text(
                            '${post.reward}원',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4D4DFF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // 이미 배포된 포스트 표시
                          if (post.status == PostStatus.DEPLOYED) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '배포됨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  // 이 함수는 이제 _buildBottomDeploySection으로 통합됨

  Widget _buildLocationInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _deployType == 'address' ? Icons.business : Icons.location_on,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _deployType == 'address' && _buildingName != null
                          ? _buildingName!
                          : '선택된 위치',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_selectedLocation!.latitude.toStringAsFixed(4)}°N, ${_selectedLocation!.longitude.toStringAsFixed(4)}°E',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 주소 모드일 때 건물 단위 선택
          if (_deployType == 'address' && _buildingName != null) ...[
            const SizedBox(height: 12),
            BuildingUnitSelector(
              buildingName: _buildingName!,
              onUnitSelected: (unit) {
                // setState를 다음 프레임에서 실행
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedUnit = unit;
                    });
                  }
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '💫 뿌릴 포스트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    '/post-place-selection',
                    arguments: {
                      'fromPostDeploy': true,
                      'returnToPostDeploy': true,
                    },
                  );
                  if (result == true && mounted) {
                    _loadUserPosts();
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('새로 만들기'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _userPosts.isEmpty
                  ? _buildEmptyState()
                  : SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          final post = _userPosts[index];
                          return _buildModernPostCard(post);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  // 가로 스크롤용 모던 포스트 카드 (이미지 위에 텍스트 오버레이)
  Widget _buildModernPostCard(PostModel post) {
    final isSelected = _selectedPost?.postId == post.postId;
    
    return GestureDetector(
      onTap: () => _onPostSelected(post),
      child: Container(
        width: 160,
        height: 220,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 포스트 이미지 (전체 배경)
              _buildImageWidget(post),
              
              // 하단 그라데이션 (텍스트 가독성)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 배포자
                      const Text(
                        '배포자',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      
                      // 제목 (한 줄)
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      
                      // 리워드와 상태
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 상태 뱃지
                          if (post.status == PostStatus.RECALLED)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange[400],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '회수',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            '${post.reward}원',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // 인증 라벨 (왼쪽 상단)
              if (post.isVerified)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[400]!],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text(
                          '인증',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 선택 표시
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[600],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
          InkWell(
            onTap: () async {
              // 아이콘 클릭 시 포스트 만들기 화면으로 이동
              final result = await Navigator.pushNamed(
                context, 
                '/post-place-selection',
                arguments: {
                  'fromPostDeploy': true,
                  'returnToPostDeploy': true,
                },
              );
              
              if (result == true && mounted) {
                _loadUserPosts();
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.post_add,
                size: 64,
                color: Colors.grey[600],
              ),
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚙️ 배포 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 수량 & 기간을 한 줄에 (더욱 컴팩트)
          Row(
            children: [
              // 수량
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2, color: Colors.blue[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '수량',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '1',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => _calculateTotal(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 기간
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '기간',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '7',
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            final duration = int.tryParse(value);
                            if (duration != null && duration > 0) {
                              setState(() {
                                _selectedDuration = duration;
                              });
                            }
                          },
                        ),
                      ),
                      Text(
                        '일',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // 총 비용 요약 (수량/기간과 같은 높이)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, size: 20, color: Colors.green[600]),
                const SizedBox(width: 8),
                const Text(
                  '총 비용',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_totalPrice.toStringAsFixed(0)}원',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDeployButton() {
    final canDeploy = _selectedPost != null && !_isDeploying;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: canDeploy
            ? LinearGradient(
                colors: [Colors.blue[400]!, Colors.purple[400]!],
              )
            : null,
        color: canDeploy ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
        boxShadow: canDeploy
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canDeploy ? _deployPostToLocation : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isDeploying
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        '배포하기',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: canDeploy ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
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


  // 오류 처리 헬퍼 메서드들
  void _showErrorDialog({
    required String title,
    required String message,
    String action = '확인',
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required String cancelText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }


  Future<void> _showDetailedErrorDialog(Object error, int quantity, int price) {
    String title = '배포 실패';
    String message = '';
    String suggestion = '';

    final errorString = error.toString();

    // 에러 타입별 상세 메시지
    if (errorString.contains('permission-denied') || errorString.contains('권한')) {
      title = '권한 오류';
      message = '마커를 생성할 권한이 없습니다.';
      suggestion = '로그인 상태를 확인하거나, 앱을 재시작해주세요.';
    } else if (errorString.contains('network') || errorString.contains('네트워크')) {
      title = '네트워크 오류';
      message = '인터넷 연결을 확인할 수 없습니다.';
      suggestion = 'Wi-Fi 또는 모바일 데이터 연결을 확인해주세요.';
    } else if (errorString.contains('timeout') || errorString.contains('시간 초과')) {
      title = '시간 초과';
      message = '서버 응답 시간이 초과되었습니다.';
      suggestion = '잠시 후 다시 시도해주세요.';
    } else if (errorString.contains('포스트 ID가 비어있습니다')) {
      title = '포스트 ID 오류';
      message = '포스트 정보가 올바르지 않습니다.';
      suggestion = '포스트를 다시 선택하거나 새로 생성해주세요.';
    } else if (errorString.contains('포스트를 찾을 수 없습니다')) {
      title = '포스트 없음';
      message = '선택한 포스트를 찾을 수 없습니다.';
      suggestion = '포스트가 삭제되었거나 접근 권한이 없을 수 있습니다.';
    } else if (errorString.contains('insufficient') || errorString.contains('잔액')) {
      title = '잔액 부족';
      message = '포인트 잔액이 부족합니다.';
      suggestion = '필요 금액: ${(quantity * price).toStringAsFixed(0)}원\n포인트를 충전하거나 배포 수량을 줄여주세요.';
    } else {
      title = '알 수 없는 오류';
      message = '배포 중 오류가 발생했습니다.';
      suggestion = '오류 내용: ${errorString.length > 100 ? errorString.substring(0, 100) + "..." : errorString}';
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  suggestion,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '문제가 계속되면 고객센터에 문의해주세요.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRetryDialog({
    required int attempt,
    required int maxAttempts,
    required String error,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.refresh, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('재시도 확인')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('배포에 실패했습니다. ($attempt/$maxAttempts 시도)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                error.length > 100 ? error.substring(0, 100) + '...' : error,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '다시 시도하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('재시도'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
