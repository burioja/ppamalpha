import 'dart:async';
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
import '../widgets/post_deploy_helpers.dart';
import '../widgets/post_deploy_widgets.dart';

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
  String? _unitNumber;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _postsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 사용자 포인트 로드
      final points = await PostDeployHelpers.getUserPoints();
      
      // 사용자 포스트 로드
      final posts = await PostDeployHelpers.getUserPosts();
      
      setState(() {
        _userPoints = points;
        _userPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      PostDeployHelpers.showErrorSnackBar(context, '데이터 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '포스트 배포',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return PostDeployWidgets.buildLoadingWidget();
    }

    if (_userPosts.isEmpty) {
      return PostDeployWidgets.buildEmptyWidget('배포할 포스트가 없습니다.\n먼저 포스트를 생성해주세요.');
    }

    return Form(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 포스트 선택 섹션
            PostDeployWidgets.buildSectionHeader('포스트 선택', Icons.post_add, Colors.blue),
            const SizedBox(height: 12),
            PostDeployWidgets.buildPostSelector(
              selectedPost: _selectedPost,
              posts: _userPosts,
              onChanged: (post) {
                setState(() {
                  _selectedPost = post;
                });
              },
            ),
            const SizedBox(height: 24),

            // 위치 선택 섹션
            PostDeployWidgets.buildSectionHeader('위치 선택', Icons.location_on, Colors.green),
            const SizedBox(height: 12),
            PostDeployWidgets.buildLocationSelector(
              selectedLocation: _selectedLocation,
              onTap: _selectLocation,
            ),
            const SizedBox(height: 24),

            // 배포 방식 섹션
            PostDeployWidgets.buildSectionHeader('배포 방식', Icons.settings, Colors.orange),
            const SizedBox(height: 12),
            PostDeployWidgets.buildDeployTypeSelector(
              selectedDeployType: _deployType,
              onChanged: (type) {
                setState(() {
                  _deployType = type;
                  // 배포 방식이 변경되면 관련 필드 초기화
                  if (type != 'building') {
                    _buildingName = null;
                  }
                  if (type != 'unit') {
                    _unitNumber = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            // 빌딩명 입력 (빌딩 배포 또는 단위 배포일 때)
            if (_deployType == 'building' || _deployType == 'unit') ...[
              PostDeployWidgets.buildBuildingNameField(
                buildingName: _buildingName,
                onChanged: (name) {
                  setState(() {
                    _buildingName = name;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // 단위번호 입력 (단위 배포일 때)
            if (_deployType == 'unit') ...[
              PostDeployWidgets.buildUnitNumberField(
                unitNumber: _unitNumber,
                onChanged: (unit) {
                  setState(() {
                    _unitNumber = unit;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // 배포 설정 섹션
            PostDeployWidgets.buildSectionHeader('배포 설정', Icons.tune, Colors.purple),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: PostDeployWidgets.buildQuantityField(
                    controller: _quantityController,
                    validator: PostDeployHelpers.validateQuantity,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PostDeployWidgets.buildPriceField(
                    controller: _priceController,
                    validator: PostDeployHelpers.validatePrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            PostDeployWidgets.buildDurationField(
              controller: _durationController,
              validator: PostDeployHelpers.validateDuration,
            ),
            const SizedBox(height: 24),

            // 비용 계산 섹션
            PostDeployWidgets.buildSectionHeader('비용 계산', Icons.calculate, Colors.red),
            const SizedBox(height: 12),
            PostDeployWidgets.buildCostCalculator(
              quantity: int.tryParse(_quantityController.text) ?? 0,
              price: int.tryParse(_priceController.text) ?? 0,
              userPoints: _userPoints,
            ),
            const SizedBox(height: 24),

            // 배포 버튼
            PostDeployWidgets.buildDeployButton(
              onPressed: _deployPost,
              isLoading: _isDeploying,
              canDeploy: _canDeploy(),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  bool _canDeploy() {
    if (_selectedPost == null) return false;
    if (_selectedLocation == null) return false;
    if (_deployType == null) return false;
    
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    final totalCost = quantity * price;
    
    if (quantity <= 0 || price <= 0) return false;
    if (_userPoints < totalCost) return false;
    
    // 빌딩 배포일 때 빌딩명 필수
    if (_deployType == 'building' && (_buildingName == null || _buildingName!.isEmpty)) {
      return false;
    }
    
    // 단위 배포일 때 빌딩명과 단위번호 필수
    if (_deployType == 'unit' && 
        (_buildingName == null || _buildingName!.isEmpty || 
         _unitNumber == null || _unitNumber!.isEmpty)) {
      return false;
    }
    
    return true;
  }

  Future<void> _selectLocation() async {
    try {
      final location = await PostDeployHelpers.showLocationPickerDialog(context);
      if (location != null) {
        setState(() {
          _selectedLocation = location;
        });
      }
    } catch (e) {
      PostDeployHelpers.showErrorSnackBar(context, '위치 선택 실패: $e');
    }
  }

  Future<void> _deployPost() async {
    if (!_canDeploy()) {
      PostDeployHelpers.showErrorSnackBar(context, '배포 조건을 확인해주세요');
      return;
    }

    final quantity = int.parse(_quantityController.text);
    final price = int.parse(_priceController.text);
    final duration = int.parse(_durationController.text);
    final totalCost = quantity * price;

    // 배포 비용 확인 다이얼로그
    final confirmed = await PostDeployHelpers.showDeployCostDialog(
      context,
      quantity,
      price,
      totalCost,
      _userPoints,
    );

    if (!confirmed) return;

    setState(() {
      _isDeploying = true;
    });

    try {
      final success = await PostDeployHelpers.deployPost(
        post: _selectedPost!,
        location: _selectedLocation!,
        quantity: quantity,
        price: price,
        duration: duration,
        deployType: _deployType!,
        buildingName: _buildingName,
        unitNumber: _unitNumber,
      );

      if (success) {
        // 포인트 업데이트
        final newPoints = await PostDeployHelpers.getUserPoints();
        setState(() {
          _userPoints = newPoints;
        });

        // 성공 다이얼로그
        await PostDeployHelpers.showDeploySuccessDialog(
          context,
          _selectedPost!.title,
          quantity,
          totalCost,
        );

        // 화면 닫기
        Navigator.pop(context, true);
      } else {
        PostDeployHelpers.showErrorSnackBar(context, '포스트 배포에 실패했습니다');
      }
    } catch (e) {
      PostDeployHelpers.showErrorSnackBar(context, '포스트 배포 실패: $e');
    } finally {
      setState(() {
        _isDeploying = false;
      });
    }
  }
}