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

      // 사용자 타입에 따른 반경
      final normalRadiusKm = marker_domain_service.MarkerDomainService.getMarkerDisplayRadius(userType, false) / 1000.0;
      final superRadiusKm = marker_domain_service.MarkerDomainService.getMarkerDisplayRadius(userType, true) / 1000.0;

      final primaryCenter = centers.first;
      final additionalCenters = centers.skip(1).toList();

      debugPrint('🔍 Fog 기반 마커 조회: 일반(${normalRadiusKm}km), 슈퍼(${superRadiusKm}km)');

      // 병렬 조회
      final futures = await Future.wait([
        MapMarkerService.getMarkers(
          location: primaryCenter,
          radiusInKm: normalRadiusKm,
          additionalCenters: additionalCenters,
          filters: filters,
          pageSize: 1000,
        ),
        MapMarkerService.getSuperMarkers(
          location: primaryCenter,
          radiusInKm: superRadiusKm,
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

          debugPrint('📦 이미 수령: ${collectedPostIds.length}개');
        } catch (e) {
          debugPrint('❌ 수령 기록 조회 실패: $e');
        }
      }

      // 수령한 포스트 제거
      _rawMarkers = uniqueMarkers.where((m) =>
        !collectedPostIds.contains(m.postId)
      ).toList();

      debugPrint('✅ 최종 마커: ${_rawMarkers.length}개');

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

          debugPrint('📄 포스트: ${_posts.length}개');
        } catch (e) {
          debugPrint('❌ 포스트 조회 실패: $e');
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

