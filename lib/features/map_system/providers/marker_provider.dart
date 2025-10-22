import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/marker/marker_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/models/user/user_model.dart';
import '../../../core/repositories/markers_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/data/marker_domain_service.dart' as marker_domain_service;
import '../services/clustering/marker_clustering_service.dart';
import '../services/clustering/marker_clustering_service.dart' show ClusterMarkerModel, ClusterOrMarker;
import '../services/markers/marker_app_service.dart';
import '../widgets/cluster_widgets.dart';

/// 마커 상태 관리 Provider
/// 
/// **책임**: 
/// - 마커 목록 상태 관리
/// - 클러스터링 상태 관리
/// - 로딩/에러 상태 관리
/// 
/// **금지**: 
/// - Firebase 직접 호출 (Repository 사용)
/// - 클러스터링 로직 (Service 사용)
class MarkerProvider with ChangeNotifier {
  final MarkersRepository _repository;
  final MarkerClusteringService _clusteringService = MarkerClusteringService();

  // ==================== 상태 ====================
  
  /// 원본 마커 리스트
  List<MarkerModel> _rawMarkers = [];
  
  /// 포스트 리스트
  List<PostModel> _posts = [];
  
  /// 클러스터링된 그룹 리스트
  List<ClusterOrMarker> _clusters = [];
  
  /// 로딩 상태
  bool _isLoading = false;
  
  /// 에러 메시지
  String? _errorMessage;
  
  /// 스트림 구독
  StreamSubscription<List<MarkerModel>>? _markersSubscription;

  // ==================== Getters ====================
  
  List<MarkerModel> get rawMarkers => List.unmodifiable(_rawMarkers);
  List<PostModel> get posts => List.unmodifiable(_posts);
  List<ClusterOrMarker> get clusters => List.unmodifiable(_clusters);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get markerCount => _rawMarkers.length;
  int get postCount => _posts.length;
  int get clusterCount => _clusters.length;

  // ==================== Constructor ====================
  
  MarkerProvider({MarkersRepository? repository})
      : _repository = repository ?? MarkersRepository();

  // ==================== 액션 ====================

  /// 가시 영역의 마커 새로고침
  /// 
  /// [bounds]: 지도 보이는 영역
  /// [userType]: 사용자 타입
  /// [mapCenter]: 지도 중심 (클러스터링용)
  /// [zoom]: 줌 레벨 (클러스터링용)
  /// [viewSize]: 화면 크기 (클러스터링용)
  Future<void> refreshVisibleMarkers({
    required LatLngBounds bounds,
    required UserType userType,
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
  }) async {
    // 기존 구독 취소
    await _markersSubscription?.cancel();
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Repository에서 마커 스트리밍
      _markersSubscription = _repository
          .streamByBounds(bounds, userType)
          .listen(
        (markers) {
          _rawMarkers = markers;
          
          // 클러스터링 수행 (Service 사용)
          _clusters = MarkerClusteringService.performClustering(
            markers: markers,
            mapCenter: mapCenter,
            zoom: zoom,
            viewSize: viewSize,
          );
          
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = '마커 로드 실패: $error';
          _isLoading = false;
          notifyListeners();
          debugPrint('❌ 마커 스트림 에러: $error');
        },
      );
    } catch (e) {
      _errorMessage = '마커 로드 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ 마커 새로고침 실패: $e');
    }
  }

  /// 클러스터링 재계산 (줌 변경 시)
  /// 
  /// [mapCenter]: 지도 중심
  /// [zoom]: 새로운 줌 레벨
  /// [viewSize]: 화면 크기
  void recluster({
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
  }) {
    if (_rawMarkers.isEmpty) return;

    _clusters = MarkerClusteringService.performClustering(
      markers: _rawMarkers,
      mapCenter: mapCenter,
      zoom: zoom,
      viewSize: viewSize,
    );
    
    notifyListeners();
  }

  /// Flutter Marker 위젯 리스트 생성
  /// 
  /// [mapCenter]: 지도 중심
  /// [zoom]: 줌 레벨
  /// [viewSize]: 화면 크기
  /// [onTapSingle]: 단일 마커 탭 콜백
  /// [onTapCluster]: 클러스터 탭 콜백
  List<Marker> buildMarkerWidgets({
    required LatLng mapCenter,
    required double zoom,
    required Size viewSize,
    required Function(MarkerModel) onTapSingle,
    required Function(List<MarkerModel>) onTapCluster,
  }) {
    final widgets = <Marker>[];

    for (final cluster in _clusters) {
      if (!cluster.isCluster) {
        // 단일 마커
        final markerId = cluster.single!.markerId;
        final marker = MarkerClusteringService.findOriginalMarker(
          markerId,
          _rawMarkers,
        );
        
        if (marker == null) continue;

        final isSuper = MarkerClusteringService.isSuperMarker(
          marker,
          AppConsts.superRewardThreshold,
        );
        
        widgets.add(
          Marker(
            key: ValueKey('single_$markerId'),
            point: marker.position,
            width: 35,
            height: 35,
            child: SingleMarkerWidget(
              imagePath: MarkerClusteringService.getMarkerIconPath(isSuper),
              size: MarkerClusteringService.getMarkerIconSize(isSuper),
              isSuper: isSuper,
              userId: marker.creatorId,
              onTap: () => onTapSingle(marker),
            ),
          ),
        );
      } else {
        // 클러스터 마커
        final rep = cluster.representative!;
        final clusterMarkers = cluster.items!
            .map((cm) => MarkerClusteringService.findOriginalMarker(
                  cm.markerId,
                  _rawMarkers,
                ))
            .whereType<MarkerModel>()
            .toList();
        
        widgets.add(
          Marker(
            key: ValueKey('cluster_${rep.markerId}_${cluster.items!.length}'),
            point: rep.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => onTapCluster(clusterMarkers),
              child: SimpleClusterDot(count: cluster.items!.length),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// 특정 마커 조회
  Future<MarkerModel?> getMarker(String markerId) async {
    return await _repository.getMarkerById(markerId);
  }

  /// 마커 수량 감소
  Future<bool> decreaseMarkerQuantity(String markerId, int amount) async {
    return await _repository.decreaseQuantity(markerId, amount);
  }

  /// 마커 삭제
  Future<bool> deleteMarker(String markerId) async {
    return await _repository.deleteMarker(markerId);
  }

  /// 캐시 무효화
  void invalidateCache() {
    _repository.invalidateCache();
    _rawMarkers = [];
    _clusters = [];
    notifyListeners();
  }

  /// Fog 레벨 기반 마커 새로고침
  /// 
  /// [currentPosition]: 현재 위치
  /// [homeLocation]: 집 위치
  /// [workLocations]: 일터 위치들
  /// [userType]: 사용자 타입
  /// [filters]: 필터 조건
  Future<void> refreshByFogLevel({
    required LatLng currentPosition,
    LatLng? homeLocation,
    List<LatLng> workLocations = const [],
    required UserType userType,
    Map<String, dynamic> filters = const {},
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 기준 위치들
      final centers = [currentPosition];
      if (homeLocation != null) centers.add(homeLocation);
      centers.addAll(workLocations);

      // 사용자 타입에 따른 반경 (미터 단위)
      final normalRadiusM = marker_domain_service.MarkerDomainService.getMarkerDisplayRadius(userType, false).toDouble();
      final superRadiusM = marker_domain_service.MarkerDomainService.getMarkerDisplayRadius(userType, true).toDouble();

      final primaryCenter = centers.first;
      final additionalCenters = centers.skip(1).toList();

      // 병렬 조회
      final futures = await Future.wait([
        MapMarkerService.getMarkers(
          location: primaryCenter,
          radiusInM: normalRadiusM,
          additionalCenters: additionalCenters,
          filters: filters,
          pageSize: 1000,
        ),
        MapMarkerService.getSuperMarkers(
          location: primaryCenter,
          radiusInM: superRadiusM,
          additionalCenters: additionalCenters,
          filters: filters,
          pageSize: 500,
        ),
      ]);

      // 중복 제거
      final allMarkers = <MapMarkerData>[];
      final seenIds = <String>{};

      for (final m in [...futures[0], ...futures[1]]) {
        if (!seenIds.contains(m.id)) {
          allMarkers.add(m);
          seenIds.add(m.id);
        }
      }

      // MarkerModel로 변환
      final uniqueMarkers = allMarkers.map((data) =>
        MapMarkerService.convertToMarkerModel(data)
      ).toList();

      // 이미 수령한 포스트 필터링
      final currentUser = FirebaseAuth.instance.currentUser;
      Set<String> collectedPostIds = {};

      if (currentUser != null) {
        try {
          final collectedSnapshot = await FirebaseFirestore.instance
              .collection('post_collections')
              .where('userId', isEqualTo: currentUser.uid)
              .get();

          collectedPostIds = collectedSnapshot.docs
              .map((doc) => doc.data()['postId'] as String)
              .toSet();

        } catch (e) {
          // 수령 기록 조회 실패
        }
      }

      // 수령한 포스트 제거
      _rawMarkers = uniqueMarkers.where((m) =>
        !collectedPostIds.contains(m.postId)
      ).toList();

      // 타겟팅 조건 필터링 적용 (나이/성별)
      _rawMarkers = await _filterByTargeting(_rawMarkers);

      // 포스트 정보 조회
      final postIds = _rawMarkers.map((m) => m.postId).toSet().toList();
      _posts = [];

      if (postIds.isNotEmpty) {
        try {
          final postSnapshots = await FirebaseFirestore.instance
              .collection('posts')
              .where('postId', whereIn: postIds)
              .get();

          for (final doc in postSnapshots.docs) {
            try {
              _posts.add(PostModel.fromFirestore(doc));
            } catch (e) {
              debugPrint('포스트 파싱 오류: $e');
            }
          }

        } catch (e) {
          // 포스트 조회 실패
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '마커 조회 실패: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Fog 기반 마커 조회 실패: $e');
    }
  }

  /// 타겟팅 조건으로 마커 필터링 (나이/성별)
  Future<List<MarkerModel>> _filterByTargeting(List<MarkerModel> markers) async {
    if (markers.isEmpty) return markers;
    
    debugPrint('🎯 타겟팅 필터링 시작: 전체 마커 ${markers.length}개');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ 로그인 안됨 - 필터링 스킵');
        return markers;
      }
      
      // 사용자 정보 조회
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('⚠️ 사용자 문서 없음 - 필터링 스킵');
        return markers;
      }
      
      final userData = userDoc.data()!;
      final userGender = userData['gender'] as String?;
      final userBirth = userData['birthDate'] as String?;
      
      // 사용자 나이 계산
      final userAge = _calculateAge(userBirth);
      
      debugPrint('👤 사용자 정보: 나이=$userAge, 성별=$userGender');
      
      final filtered = <MarkerModel>[];
      
      // 각 마커의 postId로 포스트 타겟팅 조건 확인
      final postIds = markers.map((m) => m.postId).toSet().toList();
      
      if (postIds.isEmpty) return markers;
      
      // 포스트 정보 한번에 조회 (최대 30개씩)
      for (int i = 0; i < postIds.length; i += 30) {
        final batch = postIds.skip(i).take(30).toList();
        
        debugPrint('📦 배치 조회 중: ${i ~/ 30 + 1}/${(postIds.length / 30).ceil()} (${batch.length}개)');
        
        final postDocs = await FirebaseFirestore.instance
            .collection('posts')
            .where('postId', whereIn: batch)
            .get();
        
        debugPrint('✅ 포스트 문서 조회 완료: ${postDocs.docs.length}개');
        
        final postTargeting = <String, Map<String, dynamic>>{};
        for (final doc in postDocs.docs) {
          final data = doc.data();
          final postId = data['postId'] as String? ?? doc.id; // postId 필드 사용
          postTargeting[postId] = {
            'targetAge': data['targetAge'] ?? [],
            'targetGender': data['targetGender'] ?? 'all',
          };
        }
        
        // 해당 배치의 마커 필터링
        for (final marker in markers.where((m) => batch.contains(m.postId))) {
          // ✅ 내가 배포한 포스트는 무조건 표시 (타겟팅 무시)
          if (marker.creatorId == user.uid) {
            debugPrint('  ✅ ${marker.postId}: 내 포스트 → 무조건 포함');
            filtered.add(marker);
            continue;
          }
          
          final targeting = postTargeting[marker.postId];
          if (targeting == null) {
            // 타겟팅 정보 없으면 포함 (모든 사용자 대상)
            debugPrint('  ✅ ${marker.postId}: 타겟팅 정보 없음 → 포함');
            filtered.add(marker);
            continue;
          }
          
          bool passesTargeting = true;
          String rejectReason = '';
          
          // 나이 타겟팅 확인
          final targetAge = List<int>.from(targeting['targetAge'] ?? []);
          if (targetAge.isNotEmpty && targetAge.length >= 2) {
            if (userAge == null) {
              // 사용자 나이 정보 없으면 타겟팅 포스트 제외
              passesTargeting = false;
              rejectReason = '사용자 나이 정보 없음';
            } else if (userAge < targetAge[0] || userAge > targetAge[1]) {
              // 나이 범위 벗어남
              passesTargeting = false;
              rejectReason = '나이 불일치 (타겟: ${targetAge[0]}-${targetAge[1]}, 사용자: $userAge)';
            }
          }
          
          // 성별 타겟팅 확인
          if (passesTargeting) {
            final targetGender = targeting['targetGender'] as String? ?? 'all';
            // 'all' 또는 'both'이면 모두 허용
            if (targetGender != 'all' && targetGender != 'both') {
              if (userGender == null || targetGender != userGender) {
                // 성별 조건 불일치
                passesTargeting = false;
                rejectReason = '성별 불일치 (타겟: $targetGender, 사용자: $userGender)';
              }
            }
          }
          
          // 조건 통과한 마커만 추가
          if (passesTargeting) {
            debugPrint('  ✅ ${marker.postId}: 타겟팅 통과 → 포함');
            filtered.add(marker);
          } else {
            debugPrint('  ❌ ${marker.postId}: $rejectReason → 제외');
          }
        }
      }
      
      debugPrint('🎯 타겟팅 필터링 완료: ${markers.length}개 → ${filtered.length}개');
      return filtered;
    } catch (e) {
      debugPrint('❌ 타겟팅 필터링 실패: $e');
      return markers; // 에러 시 원본 반환
    }
  }
  
  /// 생년월일에서 나이 계산
  int? _calculateAge(String? birth) {
    if (birth == null || birth.isEmpty) return null;
    
    try {
      DateTime birthDate;
      
      if (birth.contains('-')) {
        birthDate = DateTime.parse(birth);
      } else if (birth.length == 8) {
        final year = int.parse(birth.substring(0, 4));
        final month = int.parse(birth.substring(4, 6));
        final day = int.parse(birth.substring(6, 8));
        birthDate = DateTime(year, month, day);
      } else {
        return null;
      }
      
      final now = DateTime.now();
      int age = now.year - birthDate.year;
      
      if (now.month < birthDate.month || 
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      
      return age;
    } catch (e) {
      return null;
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
    _markersSubscription?.cancel();
    super.dispose();
  }

  // ==================== 디버그 ====================

  Map<String, dynamic> getDebugInfo() {
    return {
      'rawMarkersCount': _rawMarkers.length,
      'clustersCount': _clusters.length,
      'isLoading': _isLoading,
      'hasError': _errorMessage != null,
      'errorMessage': _errorMessage,
    };
  }
}

