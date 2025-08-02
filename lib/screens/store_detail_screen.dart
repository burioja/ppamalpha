import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreDetailScreen extends StatefulWidget {
  final String placeId;
  final String placeName;

  const StoreDetailScreen({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, dynamic>? _placeData;
  Map<String, dynamic>? _userPlaceData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaceData();
  }

  // 플레이스 데이터와 사용자 권한 로드
  Future<void> _loadPlaceData() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // 플레이스 기본 정보 로드
      final placeDoc = await _firestore
          .collection('places')
          .doc(widget.placeId)
          .get();

      if (placeDoc.exists) {
        _placeData = placeDoc.data();
      }

      // 사용자의 플레이스 권한 정보 로드
      final userPlaceDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('places')
          .doc(widget.placeId)
          .get();

      if (userPlaceDoc.exists) {
        _userPlaceData = userPlaceDoc.data();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('플레이스 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 사용자 권한에 따른 UI 결정
  Widget _buildContent() {
    if (_userPlaceData == null) {
      // 플레이스에 등록되지 않은 사용자
      return _buildGuestView();
    }

    final roleId = _userPlaceData!['roleId'] ?? 'customer';
    final roleName = _userPlaceData!['roleName'] ?? '고객';

    switch (roleId) {
      case 'owner':
        return _buildOwnerView(roleName);
      case 'manager':
        return _buildManagerView(roleName);
      case 'employee':
        return _buildEmployeeView(roleName);
      case 'customer':
      default:
        return _buildCustomerView(roleName);
    }
  }

  // 게스트 뷰 (등록되지 않은 사용자)
  Widget _buildGuestView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.placeName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _placeData?['description'] ?? '설명 없음',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이 플레이스에 등록하려면',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 플레이스 관리자에게 연락하여 초대를 받으세요\n'
                    '• 또는 스토어 검색에서 팔로우하여 업데이트를 받아보세요',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 소유자 뷰
  Widget _buildOwnerView(String roleName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaceInfoCard(),
          const SizedBox(height: 16),
          _buildRoleCard(roleName, Colors.red),
          const SizedBox(height: 16),
          _buildOwnerFeatures(),
        ],
      ),
    );
  }

  // 관리자 뷰
  Widget _buildManagerView(String roleName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaceInfoCard(),
          const SizedBox(height: 16),
          _buildRoleCard(roleName, Colors.orange),
          const SizedBox(height: 16),
          _buildManagerFeatures(),
        ],
      ),
    );
  }

  // 직원 뷰
  Widget _buildEmployeeView(String roleName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaceInfoCard(),
          const SizedBox(height: 16),
          _buildRoleCard(roleName, Colors.blue),
          const SizedBox(height: 16),
          _buildEmployeeFeatures(),
        ],
      ),
    );
  }

  // 고객 뷰
  Widget _buildCustomerView(String roleName) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaceInfoCard(),
          const SizedBox(height: 16),
          _buildRoleCard(roleName, Colors.green),
          const SizedBox(height: 16),
          _buildCustomerFeatures(),
        ],
      ),
    );
  }

  // 플레이스 정보 카드
  Widget _buildPlaceInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 30,
                  child: Text(
                    widget.placeName[0],
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.placeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _placeData?['description'] ?? '설명 없음',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 역할 카드
  Widget _buildRoleCard(String roleName, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.person, color: color),
            const SizedBox(width: 12),
            Text(
              '역할: $roleName',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 소유자 기능
  Widget _buildOwnerFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소유자 기능',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          '직원 관리',
          '직원 목록 조회 및 관리',
          Icons.people,
          Colors.red,
        ),
        const SizedBox(height: 8),
        _buildFeatureCard(
          '급여 정산',
          '직원 급여 및 정산 관리',
          Icons.account_balance_wallet,
          Colors.red,
        ),
        const SizedBox(height: 8),
        _buildFeatureCard(
          '플레이스 설정',
          '플레이스 정보 및 권한 관리',
          Icons.settings,
          Colors.red,
        ),
      ],
    );
  }

  // 관리자 기능
  Widget _buildManagerFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '관리자 기능',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          '스케줄 관리',
          '팀 스케줄 생성 및 관리',
          Icons.schedule,
          Colors.orange,
        ),
        const SizedBox(height: 8),
        _buildFeatureCard(
          '직원 관리',
          '직원 목록 조회',
          Icons.people,
          Colors.orange,
        ),
      ],
    );
  }

  // 직원 기능
  Widget _buildEmployeeFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '직원 기능',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          '내 스케줄',
          '개인 스케줄 확인',
          Icons.schedule,
          Colors.blue,
        ),
        const SizedBox(height: 8),
        _buildFeatureCard(
          '팀 스케줄',
          '팀 스케줄 확인',
          Icons.group,
          Colors.blue,
        ),
      ],
    );
  }

  // 고객 기능
  Widget _buildCustomerFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '고객 기능',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildFeatureCard(
          '공개 스케줄',
          '공개된 스케줄 확인',
          Icons.visibility,
          Colors.green,
        ),
        const SizedBox(height: 8),
        _buildFeatureCard(
          '활동 기록',
          '개인 활동 기록 관리',
          Icons.history,
          Colors.green,
        ),
      ],
    );
  }

  // 기능 카드
  Widget _buildFeatureCard(String title, String description, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
        onTap: () {
          // TODO: 각 기능별 화면으로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 기능은 개발 중입니다.')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.placeName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: _buildContent(),
            ),
    );
  }
} 