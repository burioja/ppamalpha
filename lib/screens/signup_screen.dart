import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/address_search_widget.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 0;
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedCountryCode = "+82"; // 기본 국가 코드
  List<Map<String, String>> _countryCodes = [];

  // 생년월일 및 성별 변수
  String? _selectedYear;
  String? _selectedMonth;
  String? _selectedDay;
  String? _selectedGender;
  List<bool> _isChecked = List.generate(5, (_) => false);

  bool get _buttonActive => _isChecked[1] && _isChecked[2] && _isChecked[3];

  @override
  void initState() {
    super.initState();
    _loadCountryCodes();
  }

  // JSON에서 국가 코드 데이터 로드
  Future<void> _loadCountryCodes() async {
    String jsonString = await rootBundle.loadString(
        'assets/country_codes.json');
    List<dynamic> jsonResponse = json.decode(jsonString);
    setState(() {
      _countryCodes = jsonResponse.map((item) =>
      {
        "code": item["code"].toString(),
        "name": item["name"].toString()
      }).toList();
    });
  }

  Future<void> _signup() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: userProvider.email.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': userProvider.email.trim(),
          'phoneNumber': userProvider.phoneNumber.trim(),
          'address': userProvider.address.trim(),
          'birthDate': '$_selectedYear-$_selectedMonth-$_selectedDay',
          // 생년월일 저장
          'gender': _selectedGender,
          // 성별 저장
          'workPlaces': userProvider.workPlaces,
          'createdAt': Timestamp.now(),

        });

        userProvider.setEmail(userProvider.email.trim());
        userProvider.setPhoneNumber(userProvider.phoneNumber.trim());
        userProvider.setAddress(userProvider.address.trim());
        userProvider.setBirthDate(userProvider.birthDate.trim());
        userProvider.setGender(userProvider.gender.trim());


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공!')),
        );

        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      print('회원가입 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입 실패. 다시 시도해주세요.')),
      );
    }
  }


  void _updateCheckState(int index) {
    setState(() {
      // 모두 동의 체크박스일 경우
      if (index == 0) {
        bool isAllChecked = !_isChecked.every((element) => element);
        _isChecked = List.generate(5, (index) => isAllChecked);
      } else {
        _isChecked[index] = !_isChecked[index];
        _isChecked[0] = _isChecked.getRange(1, 5).every((element) => element);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme
              .of(context)
              .colorScheme
              .copyWith(
            primary: const Color(0xFF4D4DFF),
            onPrimary: Colors.white,
            secondary: const Color(0xFF4D4DFF),
          ),
        ),
        child: Stepper(
          type: StepperType.horizontal,
          elevation: 10,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep++;
              });
            } else {
              _signup();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            }
          },
          steps: [
            Step(
              title: const Text("기본 정보"),
              content: SizedBox(
                height: 450,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(labelText: '이메일'),
                        onChanged: userProvider.setEmail,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '비밀번호'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '비밀번호 확인'),
                      ),
                      const SizedBox(height: 10),

                      // 생년월일 선택
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                  labelText: "출생 연도"),
                              value: _selectedYear,
                              items: List.generate(100, (index) {
                                int year = DateTime
                                    .now()
                                    .year - index;
                                return DropdownMenuItem(value: year.toString(),
                                    child: Text(year.toString()));
                              }),
                              onChanged: (value) =>
                                  setState(() => _selectedYear = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: "월"),
                              value: _selectedMonth,
                              items: List.generate(12, (index) {
                                String month = (index + 1).toString().padLeft(
                                    2, '0');
                                return DropdownMenuItem(
                                    value: month, child: Text(month));
                              }),
                              onChanged: (value) =>
                                  setState(() => _selectedMonth = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: "일"),
                              value: _selectedDay,
                              items: List.generate(31, (index) {
                                String day = (index + 1).toString().padLeft(
                                    2, '0');
                                return DropdownMenuItem(
                                    value: day, child: Text(day));
                              }),
                              onChanged: (value) =>
                                  setState(() => _selectedDay = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 성별 선택
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: "성별"),
                        value: _selectedGender,
                        items: const [
                          DropdownMenuItem(value: "남성", child: Text("남성")),
                          DropdownMenuItem(value: "여성", child: Text("여성")),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                      const SizedBox(height: 10),

                      // 기존 핸드폰 입력 (국가 코드 포함)
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: _selectedCountryCode,
                            onChanged: (newValue) => setState(() =>
                            _selectedCountryCode = newValue!),
                            items: _countryCodes.map<DropdownMenuItem<String>>((
                                country) {
                              return DropdownMenuItem(value: country["code"],
                                  child: Text(country["name"]!));
                            }).toList(),
                          ),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(labelText: '전화번호',
                                  prefixText: '$_selectedCountryCode '),
                              onChanged: (value) => userProvider.setPhoneNumber(
                                  "$_selectedCountryCode$value"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 60,
                        child: AddressSearchWidget(
                          onAddressSelected: (selectedAddress) {
                            userProvider.setAddress(selectedAddress);
                            _addressController.text = selectedAddress;
                          },
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: '주소',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text("추가 정보"),
              content: SizedBox(
                height: 250,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Column(
                        children: List.generate(
                          userProvider.workPlaces.length,
                              (index) =>
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                          labelText: '일터 입력'),
                                      onChanged: (value) {
                                        userProvider.updateWorkPlace(
                                            index, 'workplaceinput', value);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                          labelText: '일터 추가'),
                                      onChanged: (value) {
                                        userProvider.updateWorkPlace(
                                            index, 'workplaceadd', value);
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      userProvider.removeWorkPlace(index);
                                    },
                                  ),
                                ],
                              ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: userProvider.addWorkPlace,
                      ),
                    ],
                  ),
                ),
              ),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text("약관 동의"),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._renderCheckList(),
                  const SizedBox(height: 20),

                ],
              ),
              isActive: _currentStep >= 2,
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ 약관 리스트 생성
  List<Widget> _renderCheckList() {
    List<String> labels = [
      '모두 동의',
      '만 14세 이상입니다.(필수)',
      '개인정보처리방침(필수)',
      '서비스 이용 약관(필수)',
      '이벤트 및 할인 혜택 안내 동의(선택)',
    ];

    return List.generate(5, (index) => renderContainer(
        _isChecked[index], labels[index], () => _updateCheckState(index)));
  }

  /// ✅ 약관 개별 항목 UI 생성
  Widget renderContainer(bool checked, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
        color: Colors.white,
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: checked ? Colors.blue : Colors.grey, width: 2.0),
                color: checked ? Colors.blue : Colors.white,
              ),
              child: Icon(Icons.check, color: checked ? Colors.white : Colors.grey, size: 18),
            ),
            const SizedBox(width: 15),
            Text(text, style: const TextStyle(color: Colors.grey, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}