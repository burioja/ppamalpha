import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/services/location/nominatim_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  
  // 개인정보 컨트롤러들
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _secondAddressController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _birthController = TextEditingController();
  
  // 상태 변수들
  String? _selectedGender;
  bool _allowSexualContent = false;
  bool _allowViolentContent = false;
  bool _allowHateContent = false;
  
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
          _selectedGender = userData['gender'] ?? 'male';
          _allowSexualContent = userData['allowSexualContent'] ?? false;
          _allowViolentContent = userData['allowViolentContent'] ?? false;
          _allowHateContent = userData['allowHateContent'] ?? false;
          
          // 워크플레이스 로드
          final workplaces = userData['workplaces'] as List<dynamic>?;
          _workplaces.clear(); // 항상 초기화
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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      print('사용자 데이터 저장 시작');
      print('저장할 근무지 개수: ${_workplaces.length}');
      for (int i = 0; i < _workplaces.length; i++) {
        print('근무지 $i: ${_workplaces[i]}');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'nickname': _nicknameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'secondAddress': _secondAddressController.text.trim(),
        'account': _accountController.text.trim(),
        'birthDate': _birthController.text.trim(),
        'gender': _selectedGender,
        'allowSexualContent': _allowSexualContent,
        'allowViolentContent': _allowViolentContent,
        'allowHateContent': _allowHateContent,
        'workplaces': _workplaces,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('사용자 데이터 저장 완료');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("개인정보 설정"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 기본 정보 섹션
                    _buildSectionTitle("기본 정보"),
                    const SizedBox(height: 16),
                    
                    // 닉네임
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        labelText: '닉네임 *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '닉네임을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 전화번호
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: '전화번호 *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '전화번호를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 생년월일
                    TextFormField(
                      controller: _birthController,
                      decoration: const InputDecoration(
                        labelText: '생년월일 * (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '생년월일을 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // 성별
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "성별 *",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedGender,
                      items: const [
                        DropdownMenuItem(value: "male", child: Text("남성")),
                        DropdownMenuItem(value: "female", child: Text("여성")),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '성별을 선택해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // 주소 정보 섹션
                    _buildSectionTitle("주소 정보"),
                    const SizedBox(height: 16),
                    
                    // 주소
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: '주소 *',
                              border: OutlineInputBorder(),
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
                        ElevatedButton(
                          onPressed: _pickAddress,
                          child: const Text('주소 검색'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 상세주소
                    TextFormField(
                      controller: _secondAddressController,
                      decoration: const InputDecoration(
                        labelText: '상세주소',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 계정 정보 섹션
                    _buildSectionTitle("계정 정보"),
                    const SizedBox(height: 16),
                    
                    // 계좌번호
                    TextFormField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        labelText: '계좌번호 * (리워드 지급용)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '계좌번호를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // 근무지 섹션
                    _buildSectionTitle("근무지"),
                    const SizedBox(height: 16),
                    
                    // 근무지 추가
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _workplaceNameController,
                            decoration: const InputDecoration(
                              hintText: '근무지명',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _workplaceAddressController,
                            decoration: const InputDecoration(
                              hintText: '주소',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _pickWorkplaceAddress,
                          child: const Text('주소 검색'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addWorkplace,
                        child: const Text('근무지 추가'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 근무지 목록
                    ..._workplaces.asMap().entries.map((entry) {
                      final index = entry.key;
                      final workplace = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(workplace['name']!),
                          subtitle: Text(workplace['address']!),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeWorkplace(index),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    const SizedBox(height: 24),
                    
                    // 콘텐츠 필터 섹션
                    _buildSectionTitle("콘텐츠 필터 설정"),
                    const SizedBox(height: 16),
                    
                    // 선정적인 자료
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('선정적인 자료'),
                        Switch(
                          value: _allowSexualContent,
                          onChanged: (value) => setState(() => _allowSexualContent = value),
                        ),
                      ],
                    ),
                    
                    // 폭력적인 자료
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('폭력적인 자료'),
                        Switch(
                          value: _allowViolentContent,
                          onChanged: (value) => setState(() => _allowViolentContent = value),
                        ),
                      ],
                    ),
                    
                    // 혐오 자료
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('혐오 자료'),
                        Switch(
                          value: _allowHateContent,
                          onChanged: (value) => setState(() => _allowHateContent = value),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // 저장/로그아웃 버튼
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveUserData,
                            child: _isLoading 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('저장'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _logout,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('로그아웃'),
                          ),
                        ),
                      ],
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
