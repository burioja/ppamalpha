import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/points_service.dart';
import '../../../core/services/data/marker_domain_service.dart';
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
  DeploymentType _deploymentType = DeploymentType.STREET; // 배포 방식
  List<PostModel> _userPosts = [];
  PostModel? _selectedPost;
  bool _isLoading = false;
  bool _isDeploying = false;
  int _userPoints = 0;
  
  // 실시간 리스너 관리
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  // 기간 관련 필드
  int _selectedDuration = 7;
  final List<int> _durationOptions = [1, 3, 7, 14, 30];

  // 주소 모드 관련 필드
  String? _buildingName;
  String? _selectedUnit;
  
  // 정렬 관련
  String _sortBy = 'time'; // 'time' or 'price'
  
  // 광고보드 관련 필드
  List<String> _selectedCountries = ['KR']; // 기본값: 한국
  List<String> _selectedRegions = []; // 선택적

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _quantityController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _initializeData() {
    final args = widget.arguments;
    _selectedLocation = args['location'] as LatLng?;
    _deployType = args['type'] as String? ?? 'location';
    _buildingName = args['buildingName'] as String?;
    
    // 배포 방식 파싱
    final deploymentTypeStr = args['deploymentType'] as String?;
    if (deploymentTypeStr != null) {
      _deploymentType = DeploymentTypeExtension.fromString(deploymentTypeStr);
    }
    
    if (_selectedLocation != null) {
      _setupPostsListener();
      _loadUserPoints();
    }
  }

  void _setupPostsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _postsSubscription?.cancel();
    _postsSubscription = FirebaseFirestore.instance
        .collection('posts')
        .where('creatorId', isEqualTo: user.uid)  // ✅ creatorId로 수정
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _userPosts = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
        });
        
        debugPrint('✅ 배포 화면 포스트 목록 업데이트: ${_userPosts.length}개');
      }
    });
  }

  Future<void> _loadUserPoints() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final pointsModel = await _pointsService.getUserPoints(user.uid);
      if (mounted) {
      setState(() {
          _userPoints = pointsModel?.totalPoints ?? 0;
      });
      }
    } catch (e) {
      debugPrint('포인트 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('포스트 배포'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _selectedLocation == null
          ? const Center(child: Text('위치 정보가 없습니다.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDeploymentTypeInfo(),
                  const SizedBox(height: 16),
                  _buildPostsToDeploy(),
                  const SizedBox(height: 16),
                  _buildDeploySettings(),
                  const SizedBox(height: 24),
                  _buildDeployButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택된 위치',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '위도: ${_selectedLocation!.latitude.toStringAsFixed(6)}, 경도: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_buildingName != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text(
                    '건물: $_buildingName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeploymentTypeInfo() {
    Color typeColor;
    IconData typeIcon;
    
    switch (_deploymentType) {
      case DeploymentType.STREET:
        typeColor = Colors.blue;
        typeIcon = Icons.location_on;
        break;
      case DeploymentType.MAILBOX:
        typeColor = Colors.green;
        typeIcon = Icons.mail;
        break;
      case DeploymentType.BILLBOARD:
        typeColor = Colors.orange;
        typeIcon = Icons.campaign;
        break;
    }
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _deploymentType.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 16,
                color: Colors.grey.shade300,
              ),
              const SizedBox(width: 16),
              const Text(
                '위치',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _deploymentType == DeploymentType.MAILBOX && _buildingName != null
                      ? _buildingName!
                      : _deploymentType == DeploymentType.BILLBOARD
                          ? '위치 무관'
                          : '${_selectedLocation!.latitude.toStringAsFixed(4)}°N, ${_selectedLocation!.longitude.toStringAsFixed(4)}°E',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        // 광고보드일 때만 국가/지역 선택 UI 표시
        if (_deploymentType == DeploymentType.BILLBOARD) ...[
          const SizedBox(height: 12),
          _buildBillboardTargetSelector(),
        ],
      ],
    );
  }
  
  /// 광고보드 타겟 선택 UI
  Widget _buildBillboardTargetSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, color: Colors.orange[700], size: 18),
              const SizedBox(width: 8),
              Text(
                '수신 대상 지역',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 국가 선택
          _buildCountrySelector(),
          const SizedBox(height: 12),
          
          // 지역 선택 (선택적)
          _buildRegionSelector(),
        ],
      ),
    );
  }
  
  /// 국가 선택기
  Widget _buildCountrySelector() {
    final availableCountries = {
      'KR': '🇰🇷 한국',
      'JP': '🇯🇵 일본',
      'US': '🇺🇸 미국',
      'CN': '🇨🇳 중국',
    };
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableCountries.entries.map((entry) {
        final isSelected = _selectedCountries.contains(entry.key);
        return FilterChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedCountries.add(entry.key);
              } else {
                _selectedCountries.remove(entry.key);
              }
            });
          },
          selectedColor: Colors.orange.shade100,
          checkmarkColor: Colors.orange.shade700,
        );
      }).toList(),
    );
  }
  
  /// 지역 선택기 (한국 행정구역)
  Widget _buildRegionSelector() {
    final koreaRegions = {
      'KR-11': '서울',
      'KR-26': '부산',
      'KR-27': '대구',
      'KR-28': '인천',
      'KR-29': '광주',
      'KR-30': '대전',
      'KR-31': '울산',
      'KR-41': '경기',
      'KR-42': '강원',
      'KR-43': '충북',
      'KR-44': '충남',
      'KR-45': '전북',
      'KR-46': '전남',
      'KR-47': '경북',
      'KR-48': '경남',
      'KR-50': '제주',
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '행정구역 (선택적)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '미선택 시 전체 지역',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: koreaRegions.entries.map((entry) {
            final isSelected = _selectedRegions.contains(entry.key);
            return FilterChip(
              label: Text(
                entry.value,
                style: const TextStyle(fontSize: 12),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedRegions.add(entry.key);
                  } else {
                    _selectedRegions.remove(entry.key);
                  }
                });
              },
              selectedColor: Colors.orange.shade100,
              checkmarkColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPostsToDeploy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                '뿌릴 포스트',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 정렬 버튼
              PopupMenuButton<String>(
                icon: Icon(Icons.sort, color: Colors.grey[600], size: 20),
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                    _sortPosts();
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'time',
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 18, color: _sortBy == 'time' ? Colors.blue : Colors.grey),
                        const SizedBox(width: 8),
                        Text('시간순', style: TextStyle(color: _sortBy == 'time' ? Colors.blue : Colors.black)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'price',
                    child: Row(
                      children: [
                        Icon(Icons.attach_money, size: 18, color: _sortBy == 'price' ? Colors.blue : Colors.grey),
                        const SizedBox(width: 8),
                        Text('가격순', style: TextStyle(color: _sortBy == 'price' ? Colors.blue : Colors.black)),
                      ],
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _createNewPost,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('새로 만들기'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_userPosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '배포할 포스트가 없습니다.\n새로 만들어보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
                ),
            )
          else
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _userPosts.length,
                itemBuilder: (context, index) {
                  final post = _userPosts[index];
                  return _buildPostCard(post);
                },
              ),
            ),
      ],
    );
  }

  /// 포스트 썸네일 위젯 생성
  Widget _buildPostThumbnail(PostModel post) {
    // 1. 썸네일 URL이 있으면 사용
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        post.thumbnailUrl!.first,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultThumbnail(post);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          );
        },
      );
    }
    
    // 2. mediaUrl이 있으면 첫 번째 이미지 사용
    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
      final firstMediaUrl = post.mediaUrl!.first;
      if (firstMediaUrl.isNotEmpty) {
        return Image.network(
          firstMediaUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail(post);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
        );
      }
    }
    
    // 3. 이미지가 없으면 기본 아이콘
    return _buildDefaultThumbnail(post);
  }

  /// 기본 썸네일 (이미지 없을 때)
  Widget _buildDefaultThumbnail(PostModel post) {
    IconData icon;
    Color color;
    
    // 미디어 타입에 따라 아이콘 변경
    if (post.mediaType != null && post.mediaType!.isNotEmpty) {
      final type = post.mediaType!.first.toLowerCase();
      if (type.contains('audio') || type.contains('sound')) {
        icon = Icons.audiotrack;
        color = Colors.purple;
      } else if (type.contains('video')) {
        icon = Icons.videocam;
        color = Colors.red;
      } else if (type.contains('text')) {
        icon = Icons.article;
        color = Colors.blue;
      } else {
        icon = Icons.image;
        color = Colors.orange;
      }
    } else {
      icon = Icons.post_add;
      color = Colors.grey;
    }
    
    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Icon(
          icon,
          size: 40,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final isSelected = _selectedPost?.postId == post.postId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPost = post;
        });
      },
      child: Container(
        width: 180,
        height: 240,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: Colors.blue[400]!, width: 2.5)
              : Border.all(color: Colors.grey[200]!),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Stack(
          children: [
            // 포스트 이미지 (전체 꽉 채우기)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: _buildPostThumbnail(post),
              ),
            ),
            // 그라데이션 오버레이 (하단)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
            // 배포자명 + 가격 오버레이 (하단)
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 배포자명
                  Expanded(
                    child: Text(
                      post.creatorName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 가격
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${post.reward}P',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeploySettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings,
                  color: Colors.orange[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '배포 설정',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // 수량과 기간을 한 줄에
          Row(
            children: [
              Expanded(
                child: _buildSettingField(
                  icon: Icons.numbers,
                  label: '수량',
                  controller: _quantityController,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSettingField(
                  icon: Icons.schedule,
                  label: '기간',
                  controller: _durationController,
                  color: Colors.orange,
                  suffix: '일',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 가격 설정
          _buildSettingField(
            icon: Icons.attach_money,
            label: '가격',
            controller: _priceController,
            color: Colors.green,
            suffix: 'P',
          ),
          const SizedBox(height: 20),
          
          // 포인트 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
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
                        '보유 포인트',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$_userPoints P',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '충분',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSettingField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required Color color,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            // 수량이나 기간 변경 시 UI 업데이트
            setState(() {});
          },
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: color),
            ),
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDeployButton() {
    final canDeploy = _selectedPost != null && _userPoints >= _calculateTotalCost();
    
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: canDeploy ? _deployPost : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canDeploy ? Colors.blue[600] : Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canDeploy ? 4 : 0,
        ),
        child: _isDeploying
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rocket_launch, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    '배포하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  int _calculateTotalCost() {
    if (_selectedPost == null) return 0;
    
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final postPrice = _selectedPost!.reward; // 포스트 작성 시 설정된 가격
    
    return quantity * postPrice; // 수량 × 포스트 가격
  }
  
  void _sortPosts() {
    setState(() {
      if (_sortBy == 'time') {
        // 시간순 (최신순)
        _userPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else if (_sortBy == 'price') {
        // 가격순 (높은 순)
        _userPosts.sort((a, b) => b.reward.compareTo(a.reward));
      }
    });
  }

  Future<void> _createNewPost() async {
    final result = await Navigator.pushNamed(context, '/post-place');
    
    // 포스트 생성 성공 시 데이터 새로고침
    if (result == true && mounted) {
      debugPrint('✅ 포스트 생성 완료 - 데이터 새로고침');
      _refreshData();
      
      // 스낵바로 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트가 생성되었습니다. 목록에서 선택하세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _refreshData() {
    _loadUserPoints();
    if (_selectedLocation != null) {
      _setupPostsListener();
    }
  }

  Future<void> _deployPost() async {
    if (_selectedPost == null || _selectedLocation == null) return;

    setState(() {
      _isDeploying = true;
    });

    try {
      // 배포 타입에 따라 다른 로직 수행
      switch (_deploymentType) {
        case DeploymentType.STREET:
          await _deployStreetPost();
          break;
        case DeploymentType.MAILBOX:
          await _deployMailboxPost();
          break;
        case DeploymentType.BILLBOARD:
          await _deployBillboardPost();
          break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_deploymentType.name} 성공!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배포 실패: $e'),
            backgroundColor: Colors.red,
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

  /// 거리배포 - 마커 생성
  Future<void> _deployStreetPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    // 마커 생성 로직
    final markerId = await MarkerDomainService.createMarker(
      position: _selectedLocation!,
      postId: _selectedPost!.postId,
      creatorId: user.uid,
      title: _selectedPost!.title,
      reward: _selectedPost!.reward,
      quantity: int.tryParse(_quantityController.text) ?? 1,
      expiresAt: DateTime.now().add(Duration(days: _selectedDuration)),
    );
    
    debugPrint('✅ 거리배포: 마커 생성 완료 (markerId: $markerId)');
  }

  /// 우편함배포 - 집/일터 사용자에게 자동 전송
  Future<void> _deployMailboxPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    // 선택 위치 주변의 집/일터를 가진 사용자 찾기
    // TODO: 집/일터 사용자 쿼리 및 미확인 포스트로 자동 전송
    debugPrint('🏠 우편함배포: 집/일터 사용자 검색 중...');
    
    await Future.delayed(const Duration(seconds: 1)); // 임시
    
    debugPrint('✅ 우편함배포: 완료');
  }

  /// 광고보드배포 - 광고보드에 등록
  Future<void> _deployBillboardPost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다');

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final expiresAt = DateTime.now().add(Duration(days: _selectedDuration));

    // ad_board_posts 컬렉션에 저장
    final adBoardRef = FirebaseFirestore.instance.collection('ad_board_posts').doc();
    
    await adBoardRef.set({
      'postId': _selectedPost!.postId,
      'type': 'AD_BOARD',
      'title': _selectedPost!.title,
      'description': _selectedPost!.description,
      'mediaUrl': _selectedPost!.mediaUrl,
      'thumbnailUrl': _selectedPost!.thumbnailUrl,
      'creatorId': user.uid,
      'creatorName': _selectedPost!.creatorName,
      'reward': _selectedPost!.reward,
      'isVerified': _selectedPost!.isVerified,
      'countryCodes': _selectedCountries, // 선택한 국가 코드
      'regionCodes': _selectedRegions, // 선택한 지역 코드 (빈 리스트면 전체)
      'totalQuantity': quantity,
      'remainingQuantity': quantity,
      'isActive': true,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'DEPLOYED',
    });
    
    debugPrint('✅ 광고보드배포: 완료 (id: ${adBoardRef.id}, 수량: $quantity, 국가: $_selectedCountries, 지역: $_selectedRegions)');
  }
}