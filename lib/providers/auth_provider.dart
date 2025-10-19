import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/user/user_model.dart';

/// 인증 상태 관리 Provider
/// 
/// **책임**: 
/// - 사용자 로그인/로그아웃 상태 관리
/// - 사용자 정보 관리
/// - 사용자 타입 및 구독 상태 관리
/// 
/// **금지**: 
/// - 복잡한 비즈니스 로직 (Service로 분리)
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // ==================== 상태 ====================
  
  /// 현재 사용자
  User? _currentUser;
  
  /// 사용자 상세 정보
  UserModel? _userModel;
  
  /// 로딩 상태
  bool _isLoading = false;
  
  /// 에러 메시지
  String? _errorMessage;
  
  /// 인증 상태 스트림 구독
  StreamSubscription<User?>? _authSubscription;
  
  /// 사용자 정보 스트림 구독
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // ==================== Getters ====================
  
  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// 로그인 여부
  bool get isAuthenticated => _currentUser != null;
  
  /// 사용자 ID
  String? get userId => _currentUser?.uid;
  
  /// 사용자 이메일
  String? get userEmail => _currentUser?.email;
  
  /// 사용자 타입
  UserType get userType => _userModel?.userType ?? UserType.normal;
  
  /// 프리미엄 사용자 여부
  bool get isPremiumUser => userType == UserType.superSite;
  
  /// 인증된 사용자 여부
  bool get isVerified => _userModel != null;

  // ==================== Constructor ====================
  
  AuthProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _initializeAuth();
  }

  // ==================== 초기화 ====================

  /// 인증 상태 초기화
  void _initializeAuth() {
    _authSubscription = _auth.authStateChanges().listen(
      (user) {
        _currentUser = user;
        
        if (user != null) {
          _loadUserData(user.uid);
          debugPrint('✅ 사용자 로그인: ${user.email}');
        } else {
          _userModel = null;
          _userSubscription?.cancel();
          debugPrint('👋 사용자 로그아웃');
        }
        
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = '인증 에러: $error';
        notifyListeners();
        debugPrint('❌ 인증 에러: $error');
      },
    );
  }

  /// 사용자 데이터 로드
  void _loadUserData(String uid) {
    _userSubscription?.cancel();
    
    _userSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists) {
          try {
            _userModel = UserModel.fromFirestore(snapshot);
            _errorMessage = null;
            notifyListeners();
            debugPrint('✅ 사용자 데이터 로드 완료: ${_userModel?.email}');
          } catch (e) {
            _errorMessage = '사용자 데이터 파싱 실패: $e';
            notifyListeners();
            debugPrint('❌ 사용자 데이터 파싱 실패: $e');
          }
        } else {
          _userModel = null;
          debugPrint('⚠️ 사용자 문서가 존재하지 않음');
        }
      },
      onError: (error) {
        _errorMessage = '사용자 데이터 로드 실패: $error';
        notifyListeners();
        debugPrint('❌ 사용자 데이터 로드 실패: $error');
      },
    );
  }

  // ==================== 액션 ====================

  /// 로그인
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('✅ 로그인 성공: $email');
      return true;
    } catch (e) {
      _errorMessage = '로그인 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 로그인 실패: $e');
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('✅ 로그아웃 성공');
    } catch (e) {
      _errorMessage = '로그아웃 실패: $e';
      notifyListeners();
      debugPrint('❌ 로그아웃 실패: $e');
    }
  }

  /// 회원가입
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Firebase Auth 회원가입
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = userCredential.user;
      if (user == null) {
        throw Exception('사용자 생성 실패');
      }
      
      // 사용자 프로필 업데이트
      await user.updateDisplayName(displayName);
      
      // Firestore에 사용자 문서 생성
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'displayName': displayName,
        'userType': 'normal',
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('✅ 회원가입 성공: $email');
      return true;
    } catch (e) {
      _errorMessage = '회원가입 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 회원가입 실패: $e');
      return false;
    }
  }

  /// 비밀번호 재설정 이메일 전송
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('✅ 비밀번호 재설정 이메일 전송: $email');
      return true;
    } catch (e) {
      _errorMessage = '비밀번호 재설정 실패: $e';
      notifyListeners();
      debugPrint('❌ 비밀번호 재설정 실패: $e');
      return false;
    }
  }

  /// 사용자 정보 업데이트
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    if (_currentUser == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(data);
      
      debugPrint('✅ 사용자 정보 업데이트 성공');
      return true;
    } catch (e) {
      _errorMessage = '사용자 정보 업데이트 실패: $e';
      notifyListeners();
      debugPrint('❌ 사용자 정보 업데이트 실패: $e');
      return false;
    }
  }

  /// 에러 초기화
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== Dispose ====================

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }

  // ==================== 디버그 ====================

  Map<String, dynamic> getDebugInfo() {
    return {
      'isAuthenticated': isAuthenticated,
      'userId': userId,
      'userEmail': userEmail,
      'userType': userType.toString(),
      'isPremium': isPremiumUser,
      'isVerified': isVerified,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
    };
  }
}

