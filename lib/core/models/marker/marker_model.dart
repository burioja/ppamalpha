import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../constants/app_constants.dart';

/// 마커 모델 - 포스트에 접근하는 연결고리
class MarkerModel {
  final String markerId;
  final String postId; // 연결된 포스트 ID
  final String title; // 마커 제목 (간단한 정보)
  final LatLng position; // 마커 위치
  final int quantity; // 수량 (호환성 유지, remainingQuantity와 동일)
  final int? reward; // 리워드 금액 (배포 시점 고정, 기존 마커 호환성을 위해 옵셔널)
  final bool? isSuperMarker; // 슈퍼마커 여부 (파생 저장, nullable 허용)
  final String creatorId; // 마커 생성자

  // 🚀 Firebase 실제 데이터와 일치하는 새로운 필드들
  final int totalQuantity; // 총 배포 수량
  final int remainingQuantity; // 남은 수량
  final int collectedQuantity; // 수집된 수량
  final double collectionRate; // 수집률 (0.0 ~ 1.0)
  final String tileId; // 타일 ID
  final String? s2_10; // S2 level 10 cell id
  final String? s2_12; // S2 level 12 cell id
  final int? fogLevel; // 포그 레벨 (1: Clear, 2: Partial, 3: Dark)

  // 계산된 슈퍼마커 여부 (reward 기준)
  bool get computedIsSuper => (reward ?? 0) >= AppConsts.superRewardThreshold;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String? status; // 마커 상태: ACTIVE, COLLECTED, RECALLED
  final List<String> collectedBy; // 수령한 사용자 ID 목록

  MarkerModel({
    required this.markerId,
    required this.postId,
    required this.title,
    required this.position,
    required this.quantity,
    this.reward, // ✅ 옵셔널로 변경
    this.isSuperMarker,
    required this.creatorId,
    // 🚀 새로운 필드들
    required this.totalQuantity,
    required this.remainingQuantity,
    this.collectedQuantity = 0,
    this.collectionRate = 0.0,
    required this.tileId,
    this.s2_10,
    this.s2_12,
    this.fogLevel,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    this.status,
    this.collectedBy = const [],
  }) {
    // quantity는 remainingQuantity와 동일해야 함 (호환성)
    if (quantity != remainingQuantity) {
      print('⚠️ WARNING: MarkerModel 생성 시 quantity($quantity) != remainingQuantity($remainingQuantity)');
      print('   markerId: $markerId, postId: $postId');
      print('   remainingQuantity 값으로 통일합니다.');
    }
  }

  /// Firestore에서 마커 생성
  factory MarkerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // 🔍 디버깅: 특정 마커만 상세 로그 출력
    final isTargetMarker = doc.id == 'TQTIS4RPfirWBK6qHoqu';

    if (isTargetMarker) {
      print('');
      print('🔴🔴🔴 [MARKER_MODEL] 타겟 마커 파싱 시작 🔴🔴🔴');
      print('🔴 markerId (doc.id): ${doc.id}');
      print('🔴 Firebase data[\'postId\']: "${data['postId']}"');
      print('🔴 data[\'postId\'] 타입: ${data['postId'].runtimeType}');
      print('🔴 title 필드: "${data['title']}"');
    }

    final location = data['location'] as GeoPoint;

    // ✅ 안전 파싱 함수들
    int? parseNullableInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    int parseRequiredInt(dynamic v, int defaultValue) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? defaultValue;
      return defaultValue;
    }

    double parseDouble(dynamic v, double defaultValue) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? defaultValue;
      return defaultValue;
    }

    // 🚀 새로운 필드들을 안전하게 파싱
    final totalQuantity = parseRequiredInt(data['totalQuantity'], parseRequiredInt(data['quantity'], 1));
    final remainingQuantity = parseRequiredInt(data['remainingQuantity'], parseRequiredInt(data['quantity'], 1));
    final collectedQuantity = parseRequiredInt(data['collectedQuantity'], 0);
    final collectionRate = parseDouble(data['collectionRate'], 0.0);

    final postIdValue = (data['postId'] as String?) ?? '';

    if (isTargetMarker) {
      print('🔴 캐스팅 후 postIdValue: "$postIdValue"');
      print('🔴 postIdValue 타입: ${postIdValue.runtimeType}');
      print('🔴 postIdValue가 비어있는가: ${postIdValue.isEmpty}');
      print('🔴 markerId와 동일한가: ${postIdValue == doc.id}');
    }

    final result = MarkerModel(
      markerId: doc.id,
      postId: postIdValue,
      title: data['title'] ?? '',
      position: LatLng(location.latitude, location.longitude),
      quantity: remainingQuantity, // quantity는 remainingQuantity와 동일
      reward: parseNullableInt(data['reward']), // ✅ 옵셔널 파싱
      isSuperMarker: data['isSuperMarker'] as bool?,
      creatorId: data['creatorId'] ?? '',
      // 🚀 새로운 필드들
      totalQuantity: totalQuantity,
      remainingQuantity: remainingQuantity,
      collectedQuantity: collectedQuantity,
      collectionRate: collectionRate,
      tileId: data['tileId'] ?? 'unknown',
      s2_10: data['s2_10'],
      s2_12: data['s2_12'],
      fogLevel: parseNullableInt(data['fogLevel']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      status: data['status'] as String?,
      collectedBy: List<String>.from(data['collectedBy'] ?? []),
    );

    if (isTargetMarker) {
      print('🔴 생성된 MarkerModel.markerId: "${result.markerId}"');
      print('🔴 생성된 MarkerModel.postId: "${result.postId}"');
      print('🔴 두 값이 같은가: ${result.markerId == result.postId}');
      print('🔴🔴🔴 [MARKER_MODEL] 타겟 마커 파싱 완료 🔴🔴🔴');
      print('');
    }
    return result;
  }

  /// Firestore에 저장할 데이터
  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'postId': postId,
      'title': title,
      'location': GeoPoint(position.latitude, position.longitude),
      'quantity': quantity, // 호환성 유지
      'creatorId': creatorId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'collectedBy': collectedBy,
      // 🚀 새로운 필드들
      'totalQuantity': totalQuantity,
      'remainingQuantity': remainingQuantity,
      'collectedQuantity': collectedQuantity,
      'collectionRate': collectionRate,
      'tileId': tileId,
    };

    // ✅ nullable promotion 이슈 피하려고 로컬 변수로 받아서 체크
    final r = reward;
    if (r != null) {
      data['reward'] = r;
    }

    final s = isSuperMarker;
    if (s != null) {
      data['isSuperMarker'] = s;
    }

    final s2Level10 = s2_10;
    if (s2Level10 != null) {
      data['s2_10'] = s2Level10;
    }

    final s2Level12 = s2_12;
    if (s2Level12 != null) {
      data['s2_12'] = s2Level12;
    }

    final fog = fogLevel;
    if (fog != null) {
      data['fogLevel'] = fog;
    }

    final st = status;
    if (st != null) {
      data['status'] = st;
    }

    return data;
  }

  /// 마커 복사 (수량 변경)
  MarkerModel copyWith({
    String? markerId,
    String? postId,
    String? title,
    LatLng? position,
    int? quantity,
    int? reward,
    bool? isSuperMarker,
    String? creatorId,
    // 🚀 새로운 필드들
    int? totalQuantity,
    int? remainingQuantity,
    int? collectedQuantity,
    double? collectionRate,
    String? tileId,
    String? s2_10,
    String? s2_12,
    int? fogLevel,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    String? status,
    List<String>? collectedBy,
  }) {
    // quantity와 remainingQuantity는 항상 동일하게 유지 (호환성)
    // 우선순위: remainingQuantity > quantity > 기존값
    final int newValue;
    if (remainingQuantity != null) {
      newValue = remainingQuantity;
    } else if (quantity != null) {
      newValue = quantity;
    } else {
      newValue = this.remainingQuantity;
    }

    return MarkerModel(
      markerId: markerId ?? this.markerId,
      postId: postId ?? this.postId,
      title: title ?? this.title,
      position: position ?? this.position,
      quantity: newValue, // quantity와 remainingQuantity 동일
      reward: reward ?? this.reward, // ✅ null 허용
      isSuperMarker: isSuperMarker ?? this.isSuperMarker,
      creatorId: creatorId ?? this.creatorId,
      // 🚀 새로운 필드들
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: newValue, // quantity와 remainingQuantity 동일
      collectedQuantity: collectedQuantity ?? this.collectedQuantity,
      collectionRate: collectionRate ?? this.collectionRate,
      tileId: tileId ?? this.tileId,
      s2_10: s2_10 ?? this.s2_10,
      s2_12: s2_12 ?? this.s2_12,
      fogLevel: fogLevel ?? this.fogLevel,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      collectedBy: collectedBy ?? this.collectedBy,
    );
  }
}
