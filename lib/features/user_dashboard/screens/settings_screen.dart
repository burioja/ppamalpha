import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/data/user_service.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/info_section_card.dart';

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

  // 섹션 확장/축소 상태
  bool _personalInfoExpanded = true;
  bool _addressInfoExpanded = true;
  bool _accountInfoExpanded = true;
  bool _workplaceInfoExpanded = true;
  bool _contentFilterExpanded = true;
  
  // 워크플레이스 관련
  final List<Map<String, String>> _workplaces = [];
  final TextEditingController _workplaceNameController = TextEditingController();
  final TextEditingController _workplaceAddressController = TextEditingController();
  
  bool _isLoading = false;

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
    _workplaceNameController.dispose();
    _workplaceAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 기본 정보 로드
      setState(() {
        _userEmail = user.email ?? '';
      });

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        setState(() {
          _nicknameController.text = userData['nickname'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          _addressController.text = userData['address'] ?? '';
          _secondAddressController.text = userData['secondAddress'] ?? '';
          _accountController.text = userData['account'] ?? '';
          _birthController.text = userData['birthDate'] ?? '';
          final genderValue = userData['gender'] as String?;
          _selectedGender = (genderValue == 'male' || genderValue == 'female') ? genderValue : null;
          _profileImageUrl = userData['profileImageUrl'];
          _allowSexualContent = userData['allowSexualContent'] ?? false;
          _allowViolentContent = userData['allowViolentContent'] ?? false;
          _allowHateContent = userData['allowHateContent'] ?? false;

          // 워크플레이스 로드
          final workplaces = userData['workplaces'] as List<dynamic>?;
          _workplaces.clear();
          if (workplaces != null && workplaces.isNotEmpty) {
            for (final workplace in workplaces) {
              final workplaceMap = workplace as Map<String, dynamic>;
              _workplaces.add({
                'name': workplaceMap['name'] ?? '',
                'address': workplaceMap['address'] ?? '',
              });
            }
            print('로드된 근무지 개수: ${_workplaces.length}');
          } else {
            print('저장된 근무지가 없음');
          }
        });
      }
    } catch (e) {
      _showToast('사용자 정보를 불러오는 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _saveUserData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _userService.updateUserProfile(
        nickname: _nicknameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        secondAddress: _secondAddressController.text.trim(),
        account: _accountController.text.trim(),
        birth: _birthController.text.trim(),
        gender: _selectedGender,
        profileImageUrl: _profileImageUrl,
      );

      // 워크플레이스 및 콘텐츠 필터는 별도 저장
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'allowSexualContent': _allowSexualContent,
          'allowViolentContent': _allowViolentContent,
          'allowHateContent': _allowHateContent,
          'workplaces': _workplaces,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _showToast('개인정보가 성공적으로 저장되었습니다');
    } catch (e) {
      print('사용자 데이터 저장 실패: $e');
      _showToast('저장 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWorkplacesOnly() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('근무지만 저장 시작');
      print('저장할 근무지 개수: ${_workplaces.length}');
      for (int i = 0; i < _workplaces.length; i++) {
        print('근무지 $i: ${_workplaces[i]}');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'workplaces': _workplaces,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('근무지 저장 완료');
    } catch (e) {
      print('근무지 저장 실패: $e');
      _showToast('근무지 저장 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null) {
      setState(() {
        _addressController.text = result.toString();
      });
    }
  }

  Future<void> _pickWorkplaceAddress() async {
    final result = await Navigator.pushNamed(context, '/address-search');
    if (result != null) {
      setState(() {
        _workplaceAddressController.text = result.toString();
      });
    }
  }

  void _addWorkplace() async {
    if (_workplaceNameController.text.trim().isEmpty || 
        _workplaceAddressController.text.trim().isEmpty) {
      _showToast('근무지명과 주소를 모두 입력해주세요');
      return;
    }

    final workplaceName = _workplaceNameController.text.trim();
    final workplaceAddress = _workplaceAddressController.text.trim();
    
    print('근무지 추가 시도: $workplaceName, $workplaceAddress');

    // 근무지 추가
    _workplaces.add({
      'name': workplaceName,
      'address': workplaceAddress,
    });
    
    print('근무지 목록에 추가됨. 총 개수: ${_workplaces.length}');

    // UI 업데이트
    setState(() {
      _workplaceNameController.clear();
      _workplaceAddressController.clear();
    });

    // 근무지 추가 후 즉시 저장 (폼 검증 없이)
    await _saveWorkplacesOnly();
    _showToast('근무지가 추가되었습니다');
  }

  void _removeWorkplace(int index) async {
    _workplaces.removeAt(index);
    
    // UI 업데이트
    setState(() {});
    
    // 근무지 삭제 후 즉시 저장 (폼 검증 없이)
    await _saveWorkplacesOnly();
    _showToast('근무지가 삭제되었습니다');
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _onProfileUpdated() {
    setState(() {
      _loadUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("개인정보 설정"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 프로필 헤더
                    ProfileHeaderCard(
                      profileImageUrl: _profileImageUrl,
                      nickname: _nicknameController.text,
                      email: _userEmail,
                      onProfileUpdated: _onProfileUpdated,
                    ),

                    // 기본 정보 섹션
                    InfoSectionCard(
                      title: '기본 정보',
                      icon: Icons.person,
                      isCollapsible: true,
                      isExpanded: _personalInfoExpanded,
                      onToggle: () => setState(() => _personalInfoExpanded = !_personalInfoExpanded),
                      children: [
                        InfoField(
                          label: '닉네임',
                          isRequired: true,
                          child: TextFormField(
                            controller: _nicknameController,
                            decoration: InputDecoration(
                              hintText: '닉네임을 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '닉네임을 입력해주세요';
                              }
                              return null;
                            },
                            onChanged: (value) => setState(() {}),
                          ),
                        ),
                        InfoField(
                          label: '전화번호',
                          isRequired: true,
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: '010-0000-0000',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '전화번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        InfoField(
                          label: '생년월일',
                          isRequired: true,
                          child: TextFormField(
                            controller: _birthController,
                            decoration: InputDecoration(
                              hintText: 'YYYY-MM-DD',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            keyboardType: TextInputType.datetime,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '생년월일을 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        InfoField(
                          label: '성별',
                          isRequired: true,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            value: (_selectedGender == 'male' || _selectedGender == 'female')
                                ? _selectedGender
                                : null,
                            items: const [
                              DropdownMenuItem(value: "male", child: Text("남성")),
                              DropdownMenuItem(value: "female", child: Text("여성")),
                            ],
                            onChanged: (value) => setState(() => _selectedGender = value),
                            hint: const Text('성별을 선택하세요'),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '성별을 선택해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // 주소 정보 섹션
                    InfoSectionCard(
                      title: '주소 정보',
                      icon: Icons.location_on,
                      accentColor: Colors.orange,
                      isCollapsible: true,
                      isExpanded: _addressInfoExpanded,
                      onToggle: () => setState(() => _addressInfoExpanded = !_addressInfoExpanded),
                      children: [
                        InfoField(
                          label: '주소',
                          isRequired: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    hintText: '주소 검색을 눌러주세요',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  readOnly: true,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '주소를 입력해주세요';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _pickAddress,
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('검색'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InfoField(
                          label: '상세주소',
                          child: TextFormField(
                            controller: _secondAddressController,
                            decoration: InputDecoration(
                              hintText: '동, 호수 등 상세주소를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 계정 정보 섹션
                    InfoSectionCard(
                      title: '계정 정보',
                      icon: Icons.account_balance,
                      accentColor: Colors.green,
                      isCollapsible: true,
                      isExpanded: _accountInfoExpanded,
                      onToggle: () => setState(() => _accountInfoExpanded = !_accountInfoExpanded),
                      children: [
                        InfoField(
                          label: '계좌번호 (리워드 지급용)',
                          isRequired: true,
                          child: TextFormField(
                            controller: _accountController,
                            decoration: InputDecoration(
                              hintText: '은행명과 계좌번호를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '계좌번호를 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // 근무지 섹션
                    InfoSectionCard(
                      title: '근무지',
                      icon: Icons.work,
                      accentColor: Colors.purple,
                      isCollapsible: true,
                      isExpanded: _workplaceInfoExpanded,
                      onToggle: () => setState(() => _workplaceInfoExpanded = !_workplaceInfoExpanded),
                      children: [
                        // 근무지 추가 폼
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.purple.withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _workplaceNameController,
                                      decoration: InputDecoration(
                                        labelText: '근무지명',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _workplaceAddressController,
                                      decoration: InputDecoration(
                                        labelText: '주소',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                      ),
                                      readOnly: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _pickWorkplaceAddress,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Icon(Icons.search),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _addWorkplace,
                                  icon: const Icon(Icons.add),
                                  label: const Text('근무지 추가'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_workplaces.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // 근무지 목록
                          ..._workplaces.asMap().entries.map((entry) {
                            final index = entry.key;
                            final workplace = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    color: Colors.purple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          workplace['name']!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          workplace['address']!,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeWorkplace(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),

                    // 콘텐츠 필터 섹션
                    InfoSectionCard(
                      title: '콘텐츠 필터 설정',
                      icon: Icons.filter_alt,
                      accentColor: Colors.red,
                      isCollapsible: true,
                      isExpanded: _contentFilterExpanded,
                      onToggle: () => setState(() => _contentFilterExpanded = !_contentFilterExpanded),
                      children: [
                        InfoToggle(
                          label: '선정적인 자료',
                          value: _allowSexualContent,
                          onChanged: (value) => setState(() => _allowSexualContent = value),
                          description: '성인 콘텐츠 표시 여부를 설정합니다',
                        ),
                        InfoToggle(
                          label: '폭력적인 자료',
                          value: _allowViolentContent,
                          onChanged: (value) => setState(() => _allowViolentContent = value),
                          description: '폭력적인 콘텐츠 표시 여부를 설정합니다',
                        ),
                        InfoToggle(
                          label: '혐오 자료',
                          value: _allowHateContent,
                          onChanged: (value) => setState(() => _allowHateContent = value),
                          description: '혐오 표현이 포함된 콘텐츠 표시 여부를 설정합니다',
                        ),
                      ],
                    ),

                    // 저장/로그아웃 버튼
                    Container(
                      margin: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveUserData,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '변경사항 저장',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _logout,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '로그아웃',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 관리자 도구 버튼 (개발/디버그용)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/admin-cleanup');
                              },
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('관리자 도구'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }
}
