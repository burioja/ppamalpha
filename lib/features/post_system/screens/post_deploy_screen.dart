import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/points_service.dart';
import '../../../core/services/data/marker_service.dart';
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
  int _userPoints = 0;
  
  // 실시간 리스너 관리
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  // 기간 관련 필드
  int _selectedDuration = 7;
  final List<int> _durationOptions = [1, 3, 7, 14, 30];

  // 주소 모드 관련 필드
  String? _buildingName;
  String? _selectedUnit;

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
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _userPosts = snapshot.docs
              .map((doc) => PostModel.fromFirestore(doc))
              .toList();
        });
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.purple[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '이 위치에 뿌리기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
              tooltip: '새로고침',
            ),
          ),
        ],
      ),
      body: _selectedLocation == null
          ? const Center(child: Text('위치 정보가 없습니다.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLocationInfo(),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
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
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedLocation!.latitude.toStringAsFixed(4)}°N, ${_selectedLocation!.longitude.toStringAsFixed(4)}°E',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_buildingName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _buildingName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsToDeploy() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                height: 200,
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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: Colors.blue[300]!, width: 2)
              : Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스트 이미지
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.image,
                  size: 40,
                  color: Colors.orange,
                ),
              ),
            ),
            // 포스트 정보
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.verified, size: 12, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        '인증',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${post.reward}P',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                const Text(
                  '배포 설정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSettingField(
                    icon: Icons.description,
                    label: '수량',
                    controller: _quantityController,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSettingField(
                    icon: Icons.access_time,
                    label: '기간',
                    controller: _durationController,
                    color: Colors.orange,
                    suffix: '일',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '총 비용',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_calculateTotalCost()}원',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
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
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final duration = int.tryParse(_durationController.text) ?? 7;
    return quantity * duration * 10; // 기본 비용 계산
  }

  void _createNewPost() {
    Navigator.pushNamed(context, '/post-create');
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
      // TODO: 실제 배포 로직 구현
      await Future.delayed(const Duration(seconds: 2)); // 임시 딜레이
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('포스트가 성공적으로 배포되었습니다!'),
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
}