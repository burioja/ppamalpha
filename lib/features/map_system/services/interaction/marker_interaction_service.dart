import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/models/marker/marker_model.dart';
import '../../../../core/repositories/markers_repository.dart';
import '../../utils/client_cluster.dart';

/// 마커 상호작용 서비스
/// 
/// **책임**: 마커 클릭, 수집, 확대 등 사용자 상호작용 로직
/// **원칙**: UI와 분리, Repository 사용
class MarkerInteractionService {
  final MarkersRepository _repository;

  MarkerInteractionService({MarkersRepository? repository})
      : _repository = repository ?? MarkersRepository();

  // ==================== 마커 선택 ====================

  /// 단일 마커 선택 처리
  /// 
  /// Returns: 선택된 마커 정보
  Future<MarkerModel?> handleMarkerTap(
    ClusterMarkerModel clusterMarker,
    List<MarkerModel> allMarkers,
  ) async {
    try {
      // 원본 마커 찾기
      final marker = allMarkers.firstWhere(
        (m) => m.markerId == clusterMarker.markerId,
      );
      
      debugPrint('📍 마커 선택: ${marker.title}');
      return marker;
    } catch (e) {
      debugPrint('❌ 마커 찾기 실패: $e');
      return null;
    }
  }

  /// 클러스터 확대 타겟 줌 계산
  /// 
  /// [currentZoom]: 현재 줌 레벨
  /// [cluster]: 클러스터 정보
  /// 
  /// Returns: (타겟 위치, 타겟 줌)
  (LatLng, double) calculateClusterZoomTarget(
    double currentZoom,
    ClusterOrMarker cluster,
  ) {
    final targetZoom = (currentZoom + 1.5).clamp(14.0, 16.0);
    final representative = cluster.representative!;
    
    debugPrint('🔍 클러스터 확대: ${cluster.items!.length}개 → 줌 $targetZoom');
    return (representative.position, targetZoom);
  }

  // ==================== 마커 수집 ====================

  /// 마커 수집 가능 여부 확인
  /// 
  /// [userPosition]: 사용자 현재 위치
  /// [marker]: 수집할 마커
  /// [collectRadius]: 수집 가능 반경 (미터)
  /// 
  /// Returns: (가능 여부, 거리, 에러 메시지)
  (bool, double, String?) canCollectMarker({
    required LatLng userPosition,
    required MarkerModel marker,
    double collectRadius = 200.0,
  }) {
    // 거리 계산
    final distance = _calculateDistance(userPosition, marker.position);
    
    // 범위 확인
    if (distance > collectRadius) {
      final message = '마커가 너무 멀리 있습니다 (${distance.toInt()}m)';
      debugPrint('❌ $message');
      return (false, distance, message);
    }
    
    // 수량 확인
    if (marker.quantity <= 0) {
      const message = '수량이 모두 소진되었습니다';
      debugPrint('❌ $message');
      return (false, distance, message);
    }
    
    debugPrint('✅ 마커 수집 가능: ${marker.title} (${distance.toInt()}m)');
    return (true, distance, null);
  }

  /// 마커 수집 실행
  /// 
  /// [markerId]: 마커 ID
  /// [userId]: 사용자 ID
  /// 
  /// Returns: (성공 여부, 보상 포인트)
  Future<(bool, int)> collectMarker({
    required String markerId,
    required String userId,
  }) async {
    try {
      debugPrint('🎁 마커 수집 시작: $markerId');
      
      // 마커 정보 조회
      final marker = await _repository.getMarkerById(markerId);
      if (marker == null) {
        debugPrint('❌ 마커를 찾을 수 없음');
        return (false, 0);
      }
      
      final reward = marker.reward ?? 0;
      
      // 수량 감소
      final success = await _repository.decreaseQuantity(markerId, 1);
      
      if (success) {
        debugPrint('✅ 마커 수집 성공: ${marker.title}, 보상: ${reward}P');
        return (true, reward);
      } else {
        debugPrint('❌ 마커 수집 실패');
        return (false, 0);
      }
    } catch (e) {
      debugPrint('❌ 마커 수집 에러: $e');
      return (false, 0);
    }
  }

  // ==================== 마커 관리 ====================

  /// 마커 제거 (소유자만 가능)
  /// 
  /// [marker]: 제거할 마커
  /// [userId]: 현재 사용자 ID
  /// 
  /// Returns: 성공 여부
  Future<bool> removeMarker({
    required MarkerModel marker,
    required String userId,
  }) async {
    // 소유권 확인
    if (marker.creatorId != userId) {
      debugPrint('❌ 마커 제거 권한 없음');
      return false;
    }
    
    try {
      debugPrint('🗑️ 마커 제거 시작: ${marker.title}');
      
      final success = await _repository.deleteMarker(marker.markerId);
      
      if (success) {
        debugPrint('✅ 마커 제거 성공');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ 마커 제거 실패: $e');
      return false;
    }
  }

  /// 마커가 슈퍼 마커인지 확인
  /// 
  /// [marker]: 확인할 마커
  /// [superThreshold]: 슈퍼 마커 기준 보상
  bool isSuperMarker(MarkerModel marker, int superThreshold) {
    final reward = marker.reward ?? 0;
    return reward >= superThreshold;
  }

  // ==================== 헬퍼 메서드 ====================

  /// 두 좌표 간 거리 계산 (미터)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadius = 6371000; // 지구 반경 (미터)
    
    final lat1 = point1.latitude * (pi / 180);
    final lat2 = point2.latitude * (pi / 180);
    final dLat = (point2.latitude - point1.latitude) * (pi / 180);
    final dLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// 수집 성공 메시지 생성
  String generateCollectSuccessMessage({
    required int reward,
    required int remainingQuantity,
  }) {
    if (reward > 0) {
      return '포스트를 수령했습니다! 🎉\n${reward}포인트가 지급되었습니다! ($remainingQuantity개 남음)';
    } else {
      return '포스트를 수령했습니다! ($remainingQuantity개 남음)';
    }
  }
}

