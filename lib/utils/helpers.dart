import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppHelpers {
  // 날짜 포맷팅
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
  
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
  
  // 금액 포맷팅
  static String formatCurrency(int amount) {
    return NumberFormat('#,###').format(amount);
  }
  
  // 전화번호 포맷팅
  static String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.length == 11) {
      return '${phoneNumber.substring(0, 3)}-${phoneNumber.substring(3, 7)}-${phoneNumber.substring(7)}';
    }
    return phoneNumber;
  }
  
  // 이메일 유효성 검사
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
  
  // 전화번호 유효성 검사
  static bool isValidPhoneNumber(String phoneNumber) {
    return RegExp(r'^01[0-9]-?[0-9]{4}-?[0-9]{4}$').hasMatch(phoneNumber);
  }
  
  // 비밀번호 유효성 검사 (최소 8자, 영문+숫자)
  static bool isValidPassword(String password) {
    return RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$').hasMatch(password);
  }
  
  // 스낵바 표시
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  // 로딩 다이얼로그 표시
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  // 로딩 다이얼로그 닫기
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context).pop();
  }
  
  // 확인 다이얼로그 표시
  static Future<bool> showConfirmDialog(
    BuildContext context, 
    String title, 
    String content,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
} 