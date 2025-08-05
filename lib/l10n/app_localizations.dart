import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'ko': {
      // 인증 관련
      'login': '로그인',
      'signup': '회원가입',
      'logout': '로그아웃',
      'email': '이메일',
      'password': '비밀번호',
      'confirmPassword': '비밀번호 확인',
      'forgotPassword': '비밀번호 찾기',
      'loginSuccess': '로그인되었습니다.',
      'signupSuccess': '회원가입이 완료되었습니다.',
      'loginFailed': '로그인에 실패했습니다.',
      'signupFailed': '회원가입에 실패했습니다.',
      
      // 사용자 관련
      'profile': '프로필',
      'settings': '설정',
      'nickname': '닉네임',
      'phoneNumber': '전화번호',
      'address': '주소',
      'gender': '성별',
      'birth': '생년월일',
      'save': '저장',
      'cancel': '취소',
      'edit': '수정',
      'delete': '삭제',
      
      // 메인 화면
      'home': '홈',
      'map': '지도',
      'wallet': '지갑',
      'budget': '예산',
      'search': '검색',
      
      // 지도 관련
      'currentLocation': '현재 위치',
      'searchLocation': '위치 검색',
      'workMode': '업무 모드',
      'lifeMode': '생활 모드',
      
      // 지갑 관련
      'balance': '잔액',
      'income': '수입',
      'expense': '지출',
      'transfer': '이체',
      'history': '거래 내역',
      
      // 예산 관련
      'budgetManagement': '예산 관리',
      'monthlyBudget': '월 예산',
      'category': '카테고리',
      'amount': '금액',
      'date': '날짜',
      
      // 공통
      'loading': '로딩 중...',
      'error': '오류',
      'success': '성공',
      'confirm': '확인',
      'back': '뒤로',
      'next': '다음',
      'done': '완료',
      'retry': '다시 시도',
      'networkError': '네트워크 연결을 확인해주세요.',
      'unknownError': '알 수 없는 오류가 발생했습니다.',
    },
    'en': {
      // Authentication
      'login': 'Login',
      'signup': 'Sign Up',
      'logout': 'Logout',
      'email': 'Email',
      'password': 'Password',
      'confirmPassword': 'Confirm Password',
      'forgotPassword': 'Forgot Password',
      'loginSuccess': 'Login successful.',
      'signupSuccess': 'Sign up completed.',
      'loginFailed': 'Login failed.',
      'signupFailed': 'Sign up failed.',
      
      // User related
      'profile': 'Profile',
      'settings': 'Settings',
      'nickname': 'Nickname',
      'phoneNumber': 'Phone Number',
      'address': 'Address',
      'gender': 'Gender',
      'birth': 'Birth Date',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'delete': 'Delete',
      
      // Main screen
      'home': 'Home',
      'map': 'Map',
      'wallet': 'Wallet',
      'budget': 'Budget',
      'search': 'Search',
      
      // Map related
      'currentLocation': 'Current Location',
      'searchLocation': 'Search Location',
      'workMode': 'Work Mode',
      'lifeMode': 'Life Mode',
      
      // Wallet related
      'balance': 'Balance',
      'income': 'Income',
      'expense': 'Expense',
      'transfer': 'Transfer',
      'history': 'Transaction History',
      
      // Budget related
      'budgetManagement': 'Budget Management',
      'monthlyBudget': 'Monthly Budget',
      'category': 'Category',
      'amount': 'Amount',
      'date': 'Date',
      
      // Common
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirm': 'Confirm',
      'back': 'Back',
      'next': 'Next',
      'done': 'Done',
      'retry': 'Retry',
      'networkError': 'Please check your network connection.',
      'unknownError': 'An unknown error occurred.',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ko', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
} 