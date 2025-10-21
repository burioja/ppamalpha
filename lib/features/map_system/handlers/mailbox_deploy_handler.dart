import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/models/user/user_model.dart';
import '../../post_system/screens/post_deploy_screen.dart';
import '../../../core/models/post/post_model.dart';

/// 우편함 배포 핸들러
/// 
/// **책임**:
/// - 주소 확인 다이얼로그 표시
/// - 거리 검증 (1km/3km)
/// - 주소 검색
class MailboxDeployHandler {
  /// 우편함 배포 시작
  /// 
  /// [context]: BuildContext
  /// [location]: 롱프레스 위치
  /// [currentPosition]: 현재 위치
  /// [homeLocation]: 집 위치
  /// [workLocations]: 일터 위치들
  /// [userType]: 사용자 타입
  static Future<void> handleMailboxDeploy({
    required BuildContext context,
    required LatLng location,
    required LatLng? currentPosition,
    required LatLng? homeLocation,
    required List<LatLng> workLocations,
    required UserType userType,
  }) async {
    debugPrint('🏠 우편함 배포 시작: $location');
    
    // 1. 건물명 조회
    debugPrint('📍 건물명 조회 중...');
    final buildingName = await _getBuildingName(location);
    debugPrint('✅ 건물명: $buildingName');
    
    // 2. 컨텍스트 유효성 재확인 (역지오코딩 대기 중 화면이 바뀌었을 수 있음)
    if (!context.mounted) {
      debugPrint('❌ Context disposed. 다이얼로그 생략');
      return;
    }
    
    // 3. 주소 확인 다이얼로그
    debugPrint('💬 주소 확인 다이얼로그 표시 중...');
    final confirmed = await _showAddressConfirmDialog(
      context: context,
      buildingName: buildingName,
    );
    debugPrint('✅ 다이얼로그 결과: $confirmed');
    
    if (confirmed == null) return; // 취소
    
    String? finalBuildingName;
    LatLng? finalLocation;
    
    if (confirmed) {
      // 예 선택 - 현재 위치 사용
      finalBuildingName = buildingName;
      finalLocation = location;
    } else {
      // 아니오 선택 - 주소 검색
      final searchResult = await _showAddressSearchDialog(context);
      if (searchResult == null) return; // 취소
      
      finalBuildingName = searchResult.$1;
      finalLocation = searchResult.$2;
    }
    
    // 3. 거리 검증
    final isValid = _validateDistance(
      targetLocation: finalLocation,
      currentPosition: currentPosition,
      homeLocation: homeLocation,
      workLocations: workLocations,
      userType: userType,
    );
    
    if (!isValid) {
      final maxDistance = userType == UserType.superSite ? 3 : 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이 위치에는 포스트를 배포할 수 없습니다.\n${maxDistance}km 이내의 주소에서 선택해주세요.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // 4. 포스트 배포 화면으로 이동
    Navigator.pushNamed(
      context,
      '/post-deploy',
      arguments: {
        'location': finalLocation,
        'deploymentType': DeploymentType.MAILBOX.value,
        'buildingName': finalBuildingName,
      },
    );
  }
  
  /// 건물명 조회
  static Future<String> _getBuildingName(LatLng location) async {
    try {
      debugPrint('🌍 Nominatim 호출 중: ${location.latitude}, ${location.longitude}');
      final address = await NominatimService.reverseGeocode(location);
      debugPrint('✅ Nominatim 결과: $address');
      return address ?? '건물명 없음';
    } catch (e) {
      debugPrint('❌ Nominatim 에러: $e');
      return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
    }
  }
  
  /// 주소 확인 다이얼로그
  static Future<bool?> _showAddressConfirmDialog({
    required BuildContext context,
    required String buildingName,
  }) async {
    debugPrint('🔍 다이얼로그 함수 진입');
    debugPrint('🔍 context.mounted: ${context.mounted}');
    
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        debugPrint('🔍 다이얼로그 builder 실행됨');
        return AlertDialog(
          title: const Text('이 위치가 맞습니까?'),
          content: Text(buildingName),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('🔍 아니오 버튼 클릭');
                Navigator.pop(dialogContext, false);
              },
              child: const Text('아니오'),
            ),
            ElevatedButton(
              onPressed: () {
                debugPrint('🔍 예 버튼 클릭');
                Navigator.pop(dialogContext, true);
              },
              child: const Text('예'),
            ),
          ],
        );
      },
    );
  }
  
  /// 주소 검색 다이얼로그
  static Future<(String, LatLng)?> _showAddressSearchDialog(
    BuildContext context,
  ) async {
    // TODO: 주소 검색 다이얼로그 구현
    // 현재는 임시로 기본값 반환
    return null;
  }
  
  /// 거리 검증
  /// 
  /// 현재 위치, 집, 일터 중 하나라도 1km(일반)/3km(슈퍼) 이내인지 확인
  static bool _validateDistance({
    required LatLng targetLocation,
    required LatLng? currentPosition,
    required LatLng? homeLocation,
    required List<LatLng> workLocations,
    required UserType userType,
  }) {
    final maxDistance = userType == UserType.superSite ? 3000.0 : 1000.0; // 미터
    
    // 현재 위치 확인
    if (currentPosition != null) {
      final distance = _calculateDistance(currentPosition, targetLocation);
      if (distance <= maxDistance) return true;
    }
    
    // 집 위치 확인
    if (homeLocation != null) {
      final distance = _calculateDistance(homeLocation, targetLocation);
      if (distance <= maxDistance) return true;
    }
    
    // 일터 위치들 확인
    for (final work in workLocations) {
      final distance = _calculateDistance(work, targetLocation);
      if (distance <= maxDistance) return true;
    }
    
    return false;
  }
  
  /// 거리 계산 (미터)
  static double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
}

