import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/post/post_model.dart';

/// 광고보드 배포 핸들러
/// 
/// **책임**:
/// - 광고보드 배포 화면으로 이동
/// - 국가/지역 선택 처리
class BillboardDeployHandler {
  /// 광고보드 배포 시작
  /// 
  /// [context]: BuildContext
  /// [location]: 롱프레스 위치 (참고용)
  static Future<void> handleBillboardDeploy({
    required BuildContext context,
    required LatLng location,
  }) async {
    // 광고보드는 위치 무관, 국가/지역 기반
    // 포스트 배포 화면으로 이동
    Navigator.pushNamed(
      context,
      '/post-deploy',
      arguments: {
        'location': location, // 참고용 (실제로는 사용 안함)
        'deploymentType': DeploymentType.BILLBOARD.value,
        'buildingName': '광고보드',
      },
    );
  }
}

