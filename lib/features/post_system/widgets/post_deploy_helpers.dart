import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';
import '../../../core/services/data/points_service.dart';
import '../../map_system/services/fog_of_war/visit_tile_service.dart';
import '../../../utils/tile_utils.dart';

/// 포스트 배포 화면의 헬퍼 함수들
class PostDeployHelpers {
  // 포스트 배포
  static Future<bool> deployPost({
    required PostModel post,
    required LatLng location,
    required int quantity,
    required int price,
    required int duration,
    required String deployType,
    String? buildingName,
    String? unitNumber,
  }) async {
    try {
      final postService = PostService();
      final markerService = MarkerService();
      
      // 포스트 배포
      await postService.deployPost(
        postId: post.postId,
        quantity: quantity,
        locations: [{'lat': location.latitude, 'lng': location.longitude}],
        radiusInMeters: 100,
        expiresAt: DateTime.now().add(Duration(days: duration)),
      );
      
      final deploymentResult = true;
      
      if (deploymentResult) {
        // 포인트 차감
        final pointsService = PointsService();
        await pointsService.deductPoints(
          FirebaseAuth.instance.currentUser?.uid ?? '',
          price * quantity,
          '포스트 배포',
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('포스트 배포 실패: $e');
      return false;
    }
  }

  // 사용자 포인트 조회
  static Future<int> getUserPoints() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0;
      
      final pointsService = PointsService();
      final userPoints = await pointsService.getUserPoints(currentUser.uid);
      return userPoints?.totalPoints ?? 0;
    } catch (e) {
      debugPrint('포인트 조회 실패: $e');
      return 0;
    }
  }

  // 사용자 포스트 목록 조회
  static Future<List<PostModel>> getUserPosts() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];
      
      final postService = PostService();
      return await postService.getUserPosts(currentUser.uid);
    } catch (e) {
      debugPrint('사용자 포스트 조회 실패: $e');
      return [];
    }
  }

  // 배포 비용 계산
  static int calculateDeployCost(int quantity, int pricePerUnit) {
    return quantity * pricePerUnit;
  }

  // 배포 가능 여부 확인
  static bool canDeploy(int userPoints, int requiredPoints) {
    return userPoints >= requiredPoints;
  }

  // 폼 유효성 검사
  static String? validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '수량을 입력해주세요';
    }
    
    final quantity = int.tryParse(value);
    if (quantity == null) {
      return '숫자를 입력해주세요';
    }
    
    if (quantity < 1) {
      return '수량은 1개 이상이어야 합니다';
    }
    
    if (quantity > 100) {
      return '수량은 100개 이하여야 합니다';
    }
    
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '가격을 입력해주세요';
    }
    
    final price = int.tryParse(value);
    if (price == null) {
      return '숫자를 입력해주세요';
    }
    
    if (price < 10) {
      return '가격은 10원 이상이어야 합니다';
    }
    
    if (price > 10000) {
      return '가격은 10,000원 이하여야 합니다';
    }
    
    return null;
  }

  static String? validateDuration(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '기간을 입력해주세요';
    }
    
    final duration = int.tryParse(value);
    if (duration == null) {
      return '숫자를 입력해주세요';
    }
    
    if (duration < 1) {
      return '기간은 1일 이상이어야 합니다';
    }
    
    if (duration > 365) {
      return '기간은 365일 이하여야 합니다';
    }
    
    return null;
  }

  static String? validateLocation(LatLng? location) {
    if (location == null) {
      return '위치를 선택해주세요';
    }
    return null;
  }

  static String? validateDeployType(String? deployType) {
    if (deployType == null || deployType.isEmpty) {
      return '배포 방식을 선택해주세요';
    }
    return null;
  }

  static String? validatePost(PostModel? post) {
    if (post == null) {
      return '포스트를 선택해주세요';
    }
    return null;
  }

  // 전체 폼 유효성 검사
  static Map<String, String?> validateForm({
    required String quantity,
    required String price,
    required String duration,
    required LatLng? location,
    required String? deployType,
    required PostModel? post,
  }) {
    return {
      'quantity': validateQuantity(quantity),
      'price': validatePrice(price),
      'duration': validateDuration(duration),
      'location': validateLocation(location),
      'deployType': validateDeployType(deployType),
      'post': validatePost(post),
    };
  }

  // 에러 메시지 표시
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 성공 메시지 표시
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
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
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  // 배포 비용 다이얼로그 표시
  static Future<bool> showDeployCostDialog(
    BuildContext context,
    int quantity,
    int pricePerUnit,
    int totalCost,
    int userPoints,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배포 비용 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수량: $quantity개'),
            Text('단가: ${pricePerUnit}원'),
            Text('총 비용: ${totalCost}원'),
            const SizedBox(height: 8),
            Text(
              '보유 포인트: ${userPoints}원',
              style: TextStyle(
                color: userPoints >= totalCost ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (userPoints < totalCost) ...[
              const SizedBox(height: 8),
              Text(
                '포인트가 부족합니다. 포인트를 충전해주세요.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          if (userPoints >= totalCost)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('배포'),
            ),
        ],
      ),
    );
    
    return result ?? false;
  }

  // 위치 선택 다이얼로그 표시
  static Future<LatLng?> showLocationPickerDialog(BuildContext context) async {
    // 실제로는 지도 화면으로 이동
    // 여기서는 간단한 예시
    return await showDialog<LatLng>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 선택'),
        content: const Text('지도에서 위치를 선택해주세요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, const LatLng(37.5665, 126.9780)),
            child: const Text('서울시청 선택'),
          ),
        ],
      ),
    );
  }

  // 포스트 선택 다이얼로그 표시
  static Future<PostModel?> showPostSelectorDialog(
    BuildContext context,
    List<PostModel> posts,
  ) async {
    return await showDialog<PostModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포스트 선택'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return ListTile(
                title: Text(post.title),
                subtitle: Text(post.description),
                trailing: Text('${post.reward}원'),
                onTap: () => Navigator.pop(context, post),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 배포 방식 선택 다이얼로그 표시
  static Future<String?> showDeployTypeDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배포 방식 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('일반 배포'),
              subtitle: const Text('기본적인 배포 방식'),
              onTap: () => Navigator.pop(context, 'normal'),
            ),
            ListTile(
              title: const Text('빌딩 배포'),
              subtitle: const Text('특정 빌딩에 배포'),
              onTap: () => Navigator.pop(context, 'building'),
            ),
            ListTile(
              title: const Text('단위 배포'),
              subtitle: const Text('특정 단위에 배포'),
              onTap: () => Navigator.pop(context, 'unit'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  // 빌딩명 입력 다이얼로그 표시
  static Future<String?> showBuildingNameDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('빌딩명 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '빌딩명을 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 단위번호 입력 다이얼로그 표시
  static Future<String?> showUnitNumberDialog(BuildContext context) async {
    final controller = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('단위번호 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '단위번호를 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 포인트 부족 다이얼로그 표시
  static Future<void> showInsufficientPointsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('포인트 부족'),
        content: const Text('포인트가 부족합니다. 포인트를 충전해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 포인트 충전 화면으로 이동
            },
            child: const Text('포인트 충전'),
          ),
        ],
      ),
    );
  }

  // 배포 성공 다이얼로그 표시
  static Future<void> showDeploySuccessDialog(
    BuildContext context,
    String postTitle,
    int quantity,
    int totalCost,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('배포 성공'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('포스트: $postTitle'),
            Text('수량: $quantity개'),
            Text('총 비용: ${totalCost}원'),
            const SizedBox(height: 8),
            const Text(
              '포스트가 성공적으로 배포되었습니다.',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 포인트 포맷팅
  static String formatPoints(int points) {
    return '${points.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    )}원';
  }

  // 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 시간 포맷팅
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 배포 방식 텍스트 생성
  static String generateDeployTypeText(String deployType) {
    switch (deployType) {
      case 'normal':
        return '일반 배포';
      case 'building':
        return '빌딩 배포';
      case 'unit':
        return '단위 배포';
      default:
        return '알 수 없음';
    }
  }

  // 배포 정보 텍스트 생성
  static String generateDeployInfoText({
    required String deployType,
    String? buildingName,
    String? unitNumber,
  }) {
    switch (deployType) {
      case 'normal':
        return '일반 배포';
      case 'building':
        return '빌딩 배포: ${buildingName ?? '미지정'}';
      case 'unit':
        return '단위 배포: ${buildingName ?? '미지정'} ${unitNumber ?? '미지정'}';
      default:
        return '알 수 없음';
    }
  }

  // 배포 미리보기 데이터 생성
  static Map<String, dynamic> generateDeployPreviewData({
    required PostModel post,
    required LatLng location,
    required int quantity,
    required int price,
    required int duration,
    required String deployType,
    String? buildingName,
    String? unitNumber,
  }) {
    return {
      'postTitle': post.title,
      'postDescription': post.description,
      'postReward': post.reward,
      'location': '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
      'quantity': quantity,
      'price': price,
      'totalCost': quantity * price,
      'duration': duration,
      'deployType': generateDeployTypeText(deployType),
      'deployInfo': generateDeployInfoText(
        deployType: deployType,
        buildingName: buildingName,
        unitNumber: unitNumber,
      ),
      'expiresAt': DateTime.now().add(Duration(days: duration)),
    };
  }
}

