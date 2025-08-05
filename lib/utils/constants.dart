class AppConstants {
  // 앱 정보
  static const String appName = 'PPAM Alpha';
  static const String appVersion = '1.0.0';
  
  // Firebase 컬렉션명
  static const String usersCollection = 'users';
  static const String workplacesCollection = 'workplaces';
  static const String profilesCollection = 'profile';
  static const String infoDocument = 'info';
  
  // 사용자 권한
  static const String userRole = 'User';
  static const String adminRole = 'Admin';
  static const String advertiserRole = 'Advertiser';
  
  // 상태 관련
  static const String workMode = 'work';
  static const String lifeMode = 'life';
  
  // 라우트명
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String mainRoute = '/main';
  static const String mapRoute = '/map';
  static const String walletRoute = '/wallet';
  static const String budgetRoute = '/budget';
  static const String searchRoute = '/search';
  static const String settingsRoute = '/settings';
  
  // 에러 메시지
  static const String networkError = '네트워크 연결을 확인해주세요.';
  static const String authError = '인증에 실패했습니다.';
  static const String unknownError = '알 수 없는 오류가 발생했습니다.';
  
  // 성공 메시지
  static const String profileUpdateSuccess = '프로필이 업데이트되었습니다.';
  static const String loginSuccess = '로그인되었습니다.';
  static const String signupSuccess = '회원가입이 완료되었습니다.';
} 