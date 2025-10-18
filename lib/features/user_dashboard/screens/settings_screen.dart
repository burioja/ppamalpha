import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/models/place/place_model.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/data/user_service.dart';
import '../../../utils/admin_point_grant.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/info_section_card.dart';
import '../widgets/settings_helpers.dart';
import '../widgets/settings_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  
  // 개인정보 컨트롤러들
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _secondAddressController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  
  // 상태 변수들
  String? _selectedGender;
  String? _profileImageUrl;
  String _userEmail = '';
  bool _allowSexualContent = false;
  bool _allowViolentContent = false;
  bool _allowHateContent = false;
  
  // 프로필 이미지 강제 업데이트를 위한 카운터
  int _profileUpdateCounter = 0;

  // 섹션 확장/축소 상태
  bool _personalInfoExpanded = true;
  bool _addressInfoExpanded = true;
  bool _accountInfoExpanded = true;
  bool _workplaceInfoExpanded = true;
  bool _contentFilterExpanded = true;

  // 로딩 상태
  bool _isLoading = false;
  bool _isSaving = false;

  // 사용자 플레이스 목록
  List<PlaceModel> _userPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _secondAddressController.dispose();
    _accountController.dispose();
    _birthController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userInfo = await SettingsHelpers.loadUserInfo();
      if (userInfo != null) {
        _nicknameController.text = userInfo['nickname'] ?? '';
        _phoneController.text = userInfo['phone'] ?? '';
        _addressController.text = userInfo['address'] ?? '';
        _secondAddressController.text = userInfo['secondAddress'] ?? '';
        _accountController.text = userInfo['account'] ?? '';
        _birthController.text = userInfo['birth'] ?? '';
        _selectedGender = userInfo['gender'];
        _profileImageUrl = userInfo['profileImageUrl'];
        _allowSexualContent = userInfo['allowSexualContent'] ?? false;
        _allowViolentContent = userInfo['allowViolentContent'] ?? false;
        _allowHateContent = userInfo['allowHateContent'] ?? false;
      }

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _userEmail = currentUser.email ?? '';
      }

      // 사용자 플레이스 목록 로드
      final places = await SettingsHelpers.getUserPlaces();
      setState(() {
        _userPlaces = places;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      SettingsHelpers.showErrorSnackBar(context, '데이터 로드 실패: $e');
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
            '설정',
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
              icon: Icon(
                Icons.save,
                color: _isSaving ? Colors.grey : Colors.white,
              ),
              onPressed: _isSaving ? null : _saveUserData,
              tooltip: '저장',
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return SettingsWidgets.buildLoadingWidget();
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 프로필 헤더
            SettingsWidgets.buildProfileHeaderCard(
              profileImageUrl: _profileImageUrl,
              userEmail: _userEmail,
              onImageTap: _changeProfileImage,
            ),
            const SizedBox(height: 24),

            // 개인정보 섹션
            SettingsWidgets.buildInfoSectionCard(
              title: '개인정보',
              icon: Icons.person,
              color: Colors.blue,
              isExpanded: _personalInfoExpanded,
              onToggle: () {
                setState(() {
                  _personalInfoExpanded = !_personalInfoExpanded;
                });
              },
              children: [
                SettingsWidgets.buildFormField(
                  label: '닉네임',
                  hintText: '닉네임을 입력하세요',
                  controller: _nicknameController,
                  validator: SettingsHelpers.validateNickname,
                ),
                const SizedBox(height: 16),
                SettingsWidgets.buildFormField(
                  label: '전화번호',
                  hintText: '전화번호를 입력하세요',
                  controller: _phoneController,
                  validator: SettingsHelpers.validatePhone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                SettingsWidgets.buildFormField(
                  label: '생년월일',
                  hintText: 'YYYY-MM-DD 형식으로 입력하세요',
                  controller: _birthController,
                  validator: SettingsHelpers.validateBirth,
                ),
                const SizedBox(height: 16),
                SettingsWidgets.buildGenderSelector(
                  selectedGender: _selectedGender,
                  onChanged: (gender) {
                    setState(() {
                      _selectedGender = gender;
                    });
                  },
                ),
              ],
            ),

            // 주소 정보 섹션
            SettingsWidgets.buildInfoSectionCard(
              title: '주소 정보',
              icon: Icons.location_on,
              color: Colors.green,
              isExpanded: _addressInfoExpanded,
              onToggle: () {
                setState(() {
                  _addressInfoExpanded = !_addressInfoExpanded;
                });
              },
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SettingsWidgets.buildFormField(
                        label: '주소',
                        hintText: '주소를 입력하세요',
                        controller: _addressController,
                        validator: SettingsHelpers.validateAddress,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _searchAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: const Icon(Icons.search, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingsWidgets.buildFormField(
                  label: '상세주소',
                  hintText: '상세주소를 입력하세요',
                  controller: _secondAddressController,
                ),
              ],
            ),

            // 계좌 정보 섹션
            SettingsWidgets.buildInfoSectionCard(
              title: '계좌 정보',
              icon: Icons.account_balance,
              color: Colors.orange,
              isExpanded: _accountInfoExpanded,
              onToggle: () {
                setState(() {
                  _accountInfoExpanded = !_accountInfoExpanded;
                });
              },
              children: [
                SettingsWidgets.buildFormField(
                  label: '계좌번호',
                  hintText: '계좌번호를 입력하세요',
                  controller: _accountController,
                  validator: SettingsHelpers.validateAccount,
                ),
              ],
            ),

            // 플레이스 정보 섹션
            SettingsWidgets.buildInfoSectionCard(
              title: '내 플레이스',
              icon: Icons.store,
              color: Colors.purple,
              isExpanded: _workplaceInfoExpanded,
              onToggle: () {
                setState(() {
                  _workplaceInfoExpanded = !_workplaceInfoExpanded;
                });
              },
              children: [
                SettingsWidgets.buildPlaceList(
                  places: _userPlaces,
                  onDelete: _deletePlace,
                ),
                const SizedBox(height: 16),
                SettingsWidgets.buildActionButton(
                  text: '새 플레이스 추가',
                  onPressed: () {
                    Navigator.pushNamed(context, '/create-place');
                  },
                  color: Colors.purple,
                  icon: Icons.add,
                ),
              ],
            ),

            // 콘텐츠 필터 섹션
            SettingsWidgets.buildInfoSectionCard(
              title: '콘텐츠 필터',
              icon: Icons.filter_list,
              color: Colors.red,
              isExpanded: _contentFilterExpanded,
              onToggle: () {
                setState(() {
                  _contentFilterExpanded = !_contentFilterExpanded;
                });
              },
              children: [
                SettingsWidgets.buildContentFilter(
                  allowSexualContent: _allowSexualContent,
                  allowViolentContent: _allowViolentContent,
                  allowHateContent: _allowHateContent,
                  onSexualContentChanged: (value) {
                    setState(() {
                      _allowSexualContent = value;
                    });
                  },
                  onViolentContentChanged: (value) {
                    setState(() {
                      _allowViolentContent = value;
                    });
                  },
                  onHateContentChanged: (value) {
                    setState(() {
                      _allowHateContent = value;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 관리자 기능 (개발용)
            if (_userEmail.contains('admin')) ...[
              SettingsWidgets.buildSectionHeader('관리자 기능', Icons.admin_panel_settings, Colors.red),
              const SizedBox(height: 12),
              SettingsWidgets.buildActionButton(
                text: '포인트 부여',
                onPressed: _showAdminPointDialog,
                color: Colors.red,
                icon: Icons.monetization_on,
              ),
              const SizedBox(height: 16),
            ],

            // 계정 관리
            SettingsWidgets.buildSectionHeader('계정 관리', Icons.account_circle, Colors.grey),
            const SizedBox(height: 12),
            SettingsWidgets.buildDangerButton(
              text: '로그아웃',
              onPressed: _logout,
              icon: Icons.logout,
            ),
            const SizedBox(height: 8),
            SettingsWidgets.buildDangerButton(
              text: '계정 삭제',
              onPressed: _deleteAccount,
              icon: Icons.delete_forever,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfileImage() async {
    try {
      final source = await SettingsHelpers.showImageSourceDialog(context);
      if (source == null) return;

      // 실제로는 이미지 선택 및 업로드 로직 구현
      // 여기서는 간단한 예시
      final imageUrl = await SettingsHelpers.uploadProfileImage('dummy_path');
      if (imageUrl != null) {
        setState(() {
          _profileImageUrl = imageUrl;
          _profileUpdateCounter++;
        });
        SettingsHelpers.showSuccessSnackBar(context, '프로필 이미지가 변경되었습니다');
      }
    } catch (e) {
      SettingsHelpers.showErrorSnackBar(context, '프로필 이미지 변경 실패: $e');
    }
  }

  Future<void> _searchAddress() async {
    try {
      final result = await SettingsHelpers.showAddressSearchDialog(context);
      if (result != null) {
        setState(() {
          _addressController.text = result['display_name'] ?? '';
        });
      }
    } catch (e) {
      SettingsHelpers.showErrorSnackBar(context, '주소 검색 실패: $e');
    }
  }

  Future<void> _deletePlace(PlaceModel place) async {
    try {
      final confirmed = await SettingsHelpers.showDeletePlaceDialog(context, place.name);
      if (!confirmed) return;

      SettingsHelpers.showLoadingDialog(context);

      final success = await SettingsHelpers.deletePlace(place.id);
      SettingsHelpers.hideLoadingDialog(context);

      if (success) {
        setState(() {
          _userPlaces.removeWhere((p) => p.id == place.id);
        });
        SettingsHelpers.showSuccessSnackBar(context, '플레이스가 삭제되었습니다');
      } else {
        SettingsHelpers.showErrorSnackBar(context, '플레이스 삭제에 실패했습니다');
      }
    } catch (e) {
      SettingsHelpers.hideLoadingDialog(context);
      SettingsHelpers.showErrorSnackBar(context, '플레이스 삭제 실패: $e');
    }
  }

  Future<void> _showAdminPointDialog() async {
    await SettingsHelpers.showAdminPointDialog(context);
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 추가 유효성 검사
    final validationErrors = SettingsHelpers.validateForm(
      nickname: _nicknameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      account: _accountController.text,
      birth: _birthController.text,
      gender: _selectedGender,
    );

    final hasErrors = validationErrors.values.any((error) => error != null);
    if (hasErrors) {
      final firstError = validationErrors.values.firstWhere((error) => error != null);
      SettingsHelpers.showErrorSnackBar(context, firstError!);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userData = {
        'nickname': _nicknameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'secondAddress': _secondAddressController.text.trim(),
        'account': _accountController.text.trim(),
        'birth': _birthController.text.trim(),
        'gender': _selectedGender,
        'profileImageUrl': _profileImageUrl,
        'allowSexualContent': _allowSexualContent,
        'allowViolentContent': _allowViolentContent,
        'allowHateContent': _allowHateContent,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final success = await SettingsHelpers.updateUserInfo(userData);
      
      if (success) {
        SettingsHelpers.showSuccessSnackBar(context, '정보가 저장되었습니다');
      } else {
        SettingsHelpers.showErrorSnackBar(context, '정보 저장에 실패했습니다');
      }
    } catch (e) {
      SettingsHelpers.showErrorSnackBar(context, '정보 저장 실패: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final confirmed = await SettingsHelpers.showLogoutDialog(context);
      if (!confirmed) return;

      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      SettingsHelpers.showErrorSnackBar(context, '로그아웃 실패: $e');
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final confirmed = await SettingsHelpers.showDeleteAccountDialog(context);
      if (!confirmed) return;

      SettingsHelpers.showLoadingDialog(context);

      // 실제 계정 삭제 로직 구현
      await Future.delayed(const Duration(seconds: 2)); // 시뮬레이션

      SettingsHelpers.hideLoadingDialog(context);
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      SettingsHelpers.hideLoadingDialog(context);
      SettingsHelpers.showErrorSnackBar(context, '계정 삭제 실패: $e');
    }
  }
}