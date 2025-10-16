import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// PostDeployScreen 관련 로직을 관리하는 컨트롤러
class PostDeployController {
  /// 배포 가능 위치 검증
  static bool validateDeployLocation({
    required LatLng deployLocation,
    LatLng? homeLocation,
    List<LatLng>? workLocations,
    double maxDistance = 200.0,
  }) {
    // 집 주변 체크
    if (homeLocation != null) {
      final distance = _calculateDistance(deployLocation, homeLocation);
      if (distance <= maxDistance) return true;
    }

    // 일터 주변 체크
    if (workLocations != null) {
      for (final workLocation in workLocations) {
        final distance = _calculateDistance(deployLocation, workLocation);
        if (distance <= maxDistance) return true;
      }
    }

    return false;
  }

  /// 거리 계산 (미터)
  static double _calculateDistance(LatLng from, LatLng to) {
    const earthRadius = 6371000.0; // 지구 반지름 (미터)
    final dLat = _toRadians(to.latitude - from.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);

    final a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        (from.latitude).toRadians().cos() *
        (to.latitude).toRadians().cos() *
        (dLng / 2).sin() *
        (dLng / 2).sin();

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180;

  /// 마커 생성 데이터
  static Map<String, dynamic> createMarkerData({
    required String postId,
    required String creatorId,
    required LatLng location,
    required int quantity,
    required int reward,
    required DateTime expiresAt,
    String? address,
  }) {
    return {
      'postId': postId,
      'creatorId': creatorId,
      'location': GeoPoint(location.latitude, location.longitude),
      'quantity': quantity,
      'initialQuantity': quantity,
      'reward': reward,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'createdAt': FieldValue.serverTimestamp(),
      'address': address,
      'collectedCount': 0,
    };
  }
}

extension on double {
  double toRadians() => this * pi / 180;
  double sin() => math.sin(this);
  double cos() => math.cos(this);
}

double atan2(double y, double x) => math.atan2(y, x);
double sqrt(double x) => math.sqrt(x);
const pi = math.pi;

import 'dart:math' as math;

