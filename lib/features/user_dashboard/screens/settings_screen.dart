import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/data/user_service.dart';
import '../../../utils/admin_point_grant.dart';
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
  
  // 프로필 이미지 강제 업데이트를 위한 카운터
  int _profileUpdateCounter = 0;

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

        debugPrint('📄 사용자 데이터 로드: ${userData.keys.toList()}');
        debugPrint('🖼️ profileImageUrl in Firestore: ${userData['profileImageUrl']}');

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
          debugPrint('💾 _profileImageUrl 설정됨: $_profileImageUrl');
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
        birth: _birthController.text.trim(), // 읽기 전용이지만 기존 값 유지
        gender: _selectedGender, // 읽기 전용이지만 기존 값 유지
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

  void _onProfileUpdated() async {
    debugPrint('📥 _onProfileUpdated 호출됨');
    
    // 이전 URL 저장
    final previousUrl = _profileImageUrl;
    debugPrint('📥 이전 profileImageUrl: $previousUrl');
    
    await _loadUserData();  // 데이터 다시 로드 (await 추가)
    debugPrint('📊 _loadUserData 완료 - 새 profileImageUrl: $_profileImageUrl');
    
    // URL 변경 확인
    if (previousUrl != _profileImageUrl) {
      debugPrint('✅ profileImageUrl이 변경됨: $previousUrl → $_profileImageUrl');
    } else {
      debugPrint('⚠️ profileImageUrl이 변경되지 않음');
    }
    
    if (mounted) {
      setState(() {
        _profileUpdateCounter++;  // 카운터 증가로 ProfileHeaderCard 강제 재빌드
      });
      debugPrint('🔄 setState 호출 완료 - _profileUpdateCounter: $_profileUpdateCounter');
    } else {
      debugPrint('⚠️ mounted가 false - setState 건너뜀');
    }
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
                      key: ValueKey('profile_header_$_profileUpdateCounter'),
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
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '닉네임을 입력해주세요';
                              }
                              return null;
                            },
                          ),
                        ),
                        InfoField(
                          label: '전화번호',
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              hintText: '전화번호를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        // 생년월일과 성별을 같은 행에 표시
                        Row(
                          children: [
                            Expanded(
                              child: InfoField(
                                label: '생년월일',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _birthController.text.isEmpty ? '회원가입 시 입력한 생년월일' : _birthController.text,
                                          style: TextStyle(
                                            color: _birthController.text.isEmpty ? Colors.grey[600] : Colors.black87,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InfoField(
                                label: '성별',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock, color: Colors.grey[600], size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedGender == null 
                                            ? '회원가입 시 입력한 성별'
                                            : (_selectedGender == 'male' ? '남성' : '여성'),
                                          style: TextStyle(
                                            color: _selectedGender == null ? Colors.grey[600] : Colors.black87,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // 주소 정보 섹션
                    InfoSectionCard(
                      title: '주소 정보',
                      icon: Icons.location_on,
                      isCollapsible: true,
                      isExpanded: _addressInfoExpanded,
                      onToggle: () => setState(() => _addressInfoExpanded = !_addressInfoExpanded),
                      children: [
                        InfoField(
                          label: '주소',
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    hintText: '주소를 입력해주세요',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _pickAddress,
                                child: const Icon(Icons.search),
                              ),
                            ],
                          ),
                        ),
                        InfoField(
                          label: '상세주소',
                          child: TextFormField(
                            controller: _secondAddressController,
                            decoration: InputDecoration(
                              hintText: '상세주소를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 계좌 정보 섹션
                    InfoSectionCard(
                      title: '계좌 정보',
                      icon: Icons.account_balance,
                      isCollapsible: true,
                      isExpanded: _accountInfoExpanded,
                      onToggle: () => setState(() => _accountInfoExpanded = !_accountInfoExpanded),
                      children: [
                        InfoField(
                          label: '계좌번호',
                          child: TextFormField(
                            controller: _accountController,
                            decoration: InputDecoration(
                              hintText: '계좌번호를 입력해주세요',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 근무지 정보 섹션
                    InfoSectionCard(
                      title: '근무지 정보',
                      icon: Icons.work,
                      isCollapsible: true,
                      isExpanded: _workplaceInfoExpanded,
                      onToggle: () => setState(() => _workplaceInfoExpanded = !_workplaceInfoExpanded),
                      children: [
                        // 근무지 추가 폼
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '새 근무지 추가',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _workplaceNameController,
                                  decoration: InputDecoration(
                                    labelText: '근무지명',
                                    hintText: '근무지명을 입력해주세요',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _workplaceAddressController,
                                        decoration: InputDecoration(
                                          labelText: '주소',
                                          hintText: '주소를 입력해주세요',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _pickWorkplaceAddress,
                                      child: const Icon(Icons.search),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _addWorkplace,
                                    child: const Text('근무지 추가'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // 기존 근무지 목록
                        if (_workplaces.isNotEmpty) ...[
                          const Text(
                            '등록된 근무지',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_workplaces.length, (index) {
                            final workplace = _workplaces[index];
                            return Card(
                              child: ListTile(
                                title: Text(workplace['name'] ?? ''),
                                subtitle: Text(workplace['address'] ?? ''),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeWorkplace(index),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),

                    // 콘텐츠 필터 섹션
                    InfoSectionCard(
                      title: '콘텐츠 필터',
                      icon: Icons.filter_list,
                      isCollapsible: true,
                      isExpanded: _contentFilterExpanded,
                      onToggle: () => setState(() => _contentFilterExpanded = !_contentFilterExpanded),
                      children: [
                        SwitchListTile(
                          title: const Text('성인 콘텐츠 허용'),
                          value: _allowSexualContent,
                          onChanged: (value) {
                            setState(() {
                              _allowSexualContent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('폭력 콘텐츠 허용'),
                          value: _allowViolentContent,
                          onChanged: (value) {
                            setState(() {
                              _allowViolentContent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          title: const Text('혐오 콘텐츠 허용'),
                          value: _allowHateContent,
                          onChanged: (value) {
                            setState(() {
                              _allowHateContent = value;
                            });
                          },
                        ),
                      ],
                    ),

                    // 저장 버튼
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveUserData,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text('저장'),
                        ),
                      ),
                    ),

                    // 로그아웃 버튼
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('로그아웃'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// InfoField 위젯 정의
class InfoField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;

  const InfoField({
    super.key,
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label + (isRequired ? ' *' : ''),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}