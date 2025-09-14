import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Map Screen과 Post System 간의 인터페이스를 담당하는 컨트롤러
///
/// Map Screen에서 Post 배포 플로우를 시작할 때 사용하는 중앙 집중식 컨트롤러입니다.
/// 이를 통해 Map과 Post 시스템 간의 결합도를 낮추고 명확한 인터페이스를 제공합니다.
class PostDeploymentController {

  /// 위치 기반 포스트 배포 화면으로 네비게이션
  ///
  /// [context] - 네비게이션 컨텍스트
  /// [location] - 배포할 위치 (LatLng)
  ///
  /// Returns: 배포 성공 여부 (true: 성공, false: 취소)
  static Future<bool> deployFromLocation(BuildContext context, LatLng location) async {
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
      'location': location,
      'type': 'location',
    });

    return result == true;
  }

  /// 주소 기반 포스트 배포 화면으로 네비게이션
  ///
  /// [context] - 네비게이션 컨텍스트
  /// [location] - 배포할 위치 (LatLng)
  ///
  /// Returns: 배포 성공 여부 (true: 성공, false: 취소)
  static Future<bool> deployFromAddress(BuildContext context, LatLng location) async {
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
      'location': location,
      'type': 'address',
    });

    return result == true;
  }

  /// 업종/카테고리 기반 포스트 배포 화면으로 네비게이션
  ///
  /// [context] - 네비게이션 컨텍스트
  /// [location] - 배포할 위치 (LatLng)
  ///
  /// Returns: 배포 성공 여부 (true: 성공, false: 취소)
  static Future<bool> deployFromCategory(BuildContext context, LatLng location) async {
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
      'location': location,
      'type': 'category',
    });

    return result == true;
  }

  /// 배포 타입에 따른 통합 배포 메서드
  ///
  /// [context] - 네비게이션 컨텍스트
  /// [location] - 배포할 위치 (LatLng)
  /// [deployType] - 배포 타입 ('location', 'address', 'category')
  ///
  /// Returns: 배포 성공 여부 (true: 성공, false: 취소)
  static Future<bool> deployPost(BuildContext context, LatLng location, String deployType) async {
    switch (deployType) {
      case 'location':
        return await deployFromLocation(context, location);
      case 'address':
        return await deployFromAddress(context, location);
      case 'category':
        return await deployFromCategory(context, location);
      default:
        return await deployFromLocation(context, location);
    }
  }

  /// Post 배포 후 Map 화면으로의 결과 처리
  ///
  /// Map Screen에서 Post 배포 완료 후 호출하여
  /// 필요한 후처리 작업을 수행합니다.
  ///
  /// [context] - 현재 컨텍스트
  /// [deployResult] - 배포 결과 데이터
  static void handleDeploymentResult(BuildContext context, Map<String, dynamic>? deployResult) {
    if (deployResult != null && deployResult['success'] == true) {
      // 배포 성공 시 처리 로직
      debugPrint('🎉 Post 배포 성공: ${deployResult['postId']}');

      // 필요시 Map 상태 업데이트나 마커 갱신 등의 로직 추가 가능
      // 예: Map Screen의 refreshMarkers() 호출 등
    } else {
      // 배포 취소 또는 실패 시 처리
      debugPrint('❌ Post 배포 취소 또는 실패');
    }
  }
}