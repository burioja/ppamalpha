import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
// import 'package:provider/provider.dart';
// import '../../providers/map_filter_provider.dart';

/// 마커 아이템 클래스
class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl;
  final int remainingAmount;
  final DateTime? expiryDate;

  MarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
    this.imageUrl,
    required this.remainingAmount,
    this.expiryDate,
  });
}

// 포그오브워 페인터 클래스
class FogOfWarPainter extends CustomPainter {
  final GoogleMapController? mapController;
  final LatLng? currentPosition;
  final Set<LatLng> visitedPositions;
  final double currentRadius;
  final double visitedRadius;

  FogOfWarPainter({
    this.mapController,
    this.currentPosition,
    required this.visitedPositions,
    this.currentRadius = 1000,
    this.visitedRadius = 1000,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // mapController가 null이어도 렌더링 가능하도록 수정
    
    // 웹 플랫폼 체크 및 디버그 출력
    if (kIsWeb) {
      debugPrint('웹 환경에서 포그오브워 렌더링 중...');
    }

    // 현재 위치가 있는 경우에만 Fog of War 적용
    if (currentPosition != null) {
      // 현재 위치 중심으로부터의 거리 계산을 위한 화면 좌표 변환
      final centerX = (currentPosition!.longitude + 180) / 360 * size.width;
      final centerY = (1 - (currentPosition!.latitude + 90) / 180) * size.height;
      final pixelRatio = kIsWeb ? 1.0 : ui.window.devicePixelRatio;
      final brightRadius = (1000.0 / 111000 * size.width / 360) * pixelRatio; // 1km를 픽셀로 변환
      
      // 방사형 그라데이션으로 Fog of War 적용
      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          Colors.transparent,           // 중심: 완전 투명 (밝음)
          Colors.transparent,           // 1km까지: 투명 유지
          Colors.black.withOpacity(0.3), // 1.5km: 약간 어두워짐
          Colors.black.withOpacity(0.7), // 2km: 더 어두워짐
          Colors.black.withOpacity(0.9), // 가장자리: 거의 검은색
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      );
      
      // 현재 위치를 중심으로 하는 원형 그라데이션 적용
      final gradientPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(
            center: Offset(centerX, centerY),
            radius: brightRadius * 3, // 3km 반경까지 그라데이션
          ),
        );
      
      // 전체 화면에 그라데이션 적용하되, 중심부는 투명하게
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);

      // 방문한 지역들 - 회색 반투명으로 표시
      final visitedPaint = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      for (final position in visitedPositions) {
        _drawCircleHole(canvas, size, position, visitedRadius, visitedPaint);
      }

      // 현재 위치 테두리 (파란색)
      final borderPaint = Paint()
        ..color = Colors.blue.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      
      _drawCircleHole(canvas, size, currentPosition!, 1000.0, borderPaint);
    }
    // currentPosition이 null이면 아무것도 그리지 않음 (지도가 그대로 보임)
  }

  void _drawCircleHole(Canvas canvas, Size size, LatLng position, double radius, Paint paint) {
    // LatLng을 화면 좌표로 변환하는 로직
    // 웹 환경에서는 브라우저의 렌더링 성능을 고려하여 최적화
    
    // 간단한 메르카토르 투영 사용
    final screenX = (position.longitude + 180) / 360 * size.width;
    final screenY = (1 - (position.latitude + 90) / 180) * size.height;
    
    // 웹에서는 DPI 스케일링 고려
    final pixelRatio = kIsWeb ? 1.0 : ui.window.devicePixelRatio;
    final screenRadius = (radius / 111000 * size.width / 360) * pixelRatio;
    
    canvas.drawCircle(Offset(screenX, screenY), screenRadius, paint);
  }

  @override
  bool shouldRepaint(FogOfWarPainter oldDelegate) {
    return currentPosition != oldDelegate.currentPosition ||
           visitedPositions != oldDelegate.visitedPositions;
  }
}

class MapScreen extends StatefulWidget {
  MapScreen({super.key});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;

  final userId = FirebaseAuth.instance.currentUser?.uid;
  final PostService _postService = PostService();
  
  final List<MarkerItem> _markerItems = [];
  final List<PostModel> _posts = [];
  double _currentZoom = 15.0;
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;
  StreamSubscription<QuerySnapshot>? _markersListener;
  final Set<Circle> _fogOfWarCircles = {};
  final Set<LatLng> _visitedPositions = {}; // 방문한 위치들

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _loadCustomMarker();
    _setInitialLocation(); // 위치 설정 시 자동으로 Fog of War 업데이트됨
    _loadMarkersFromFirestore();
    _loadPostsFromFirestore();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    // 실시간 리스너 정리
    _markersListener?.cancel();
    super.dispose();
  }

  Future<void> _loadVisitsAndBuildFog() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final Set<Circle> circles = {};

      // 1. 전체 Fog는 이제 오버레이 위젯으로 처리

      // 2. 최근 30일 방문 지역 (회색 불투명 - 검은 Fog 위에)
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snapshot = await FirebaseFirestore.instance
          .collection('visits')
          .doc(uid)
          .collection('points')
          .where('ts', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      // 방문지역 중복 제거 및 오버레이용 데이터 수집
      final visitedLocations = <String, bool>{};
      _visitedPositions.clear();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final gp = data['geo'] as GeoPoint? ?? data['position'] as GeoPoint?;
        if (gp == null) continue;

        // 중복 좌표 체크
        final key = '${gp.latitude.toStringAsFixed(4)},${gp.longitude.toStringAsFixed(4)}';
        if (visitedLocations.containsKey(key)) continue;
        visitedLocations[key] = true;

        final position = LatLng(gp.latitude, gp.longitude);
        _visitedPositions.add(position);

        // 기존 Circle 방식도 유지 (백업용)
        circles.add(
          Circle(
            circleId: CircleId('visited_${doc.id}'),
            center: position,
            radius: 1000, // 1km 반경
            strokeWidth: 0,
            strokeColor: Colors.transparent,
            fillColor: Colors.grey.withOpacity(0.5), // 회색 반투명 (지도 흐리게 보임)
          ),
        );
      }

      // 3. 현재 위치 완전히 밝은 영역 (투명하게 - 지도 완전히 보임)
      if (_currentPosition != null) {
        circles.add(
          Circle(
            circleId: const CircleId('current_location'),
            center: _currentPosition!,
            radius: 1000, // 1km 반경
            strokeWidth: 2,
            strokeColor: Colors.blue.withOpacity(0.8),
            fillColor: Colors.transparent, // 완전 투명 (지도 완전히 보임)
          ),
        );
      }

      if (mounted) {
        setState(() {
          _fogOfWarCircles
            ..clear()
            ..addAll(circles);
        });
      }

      debugPrint('Fog of War 로드 완료: ${circles.length}개 영역');
    } catch (e) {
      debugPrint('Fog of War 로드 오류: $e');
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // 스타일 로드 실패 시 무시
    }
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(37.495872, 127.025046);
      });
      
      // 현재 위치가 설정되면 즉시 Fog of War 업데이트
      if (_currentPosition != null) {
        await _loadVisitsAndBuildFog();
      }
    } catch (_) {
      setState(() {
        _currentPosition = const LatLng(37.492894, 127.012469);
      });
      
      // 기본 위치라도 Fog of War 업데이트
      if (_currentPosition != null) {
        await _loadVisitsAndBuildFog();
      }
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      const double targetSize = 48.0;
      
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        drawWidth = targetSize;
        drawHeight = targetSize / imageRatio;
        offsetY = (targetSize - drawHeight) / 2;
      }
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
      
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final ByteData? resizedBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedBytes != null) {
        final Uint8List resizedUint8List = resizedBytes.buffer.asUint8List();
        setState(() {
          _customMarkerIcon = BitmapDescriptor.fromBytes(resizedUint8List);
        });
      }
    } catch (e) {
      // 커스텀 마커 로드 실패 시 기본 마커 사용
    }
  }



  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  void _updateClustering() {
    // 줌 레벨에 따라 클러스터링 결정
    if (_currentZoom < 12.0) {
      _clusterMarkers();
    } else {
      _showIndividualMarkers();
    }
    
    // 디버그 정보 출력
    debugPrint('클러스터링 업데이트: 줌=${_currentZoom}, 클러스터링=${_isClustered}, 마커 수=${_clusteredMarkers.length}');
    debugPrint('마커 아이템 수: ${_markerItems.length}, 포스트 수: ${_posts.length}');
  }

  void _showPostInfo(PostModel flyer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(flyer.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('발행자: ${flyer.creatorName}'),
              const SizedBox(height: 8),
              Text('리워드: ${flyer.reward}원'),
              const SizedBox(height: 8),
              Text('타겟: ${flyer.targetGender == 'all' ? '전체' : flyer.targetGender == 'male' ? '남성' : '여성'} ${flyer.targetAge[0]}~${flyer.targetAge[1]}세'),
              const SizedBox(height: 8),
              if (flyer.targetInterest.isNotEmpty)
                Text('관심사: ${flyer.targetInterest.join(', ')}'),
              const SizedBox(height: 8),
              Text('만료일: ${_formatDate(flyer.expiresAt)}'),
              const SizedBox(height: 8),
              if (flyer.canRespond) const Text('✓ 응답 가능'),
              if (flyer.canForward) const Text('✓ 전달 가능'),
              if (flyer.canRequestReward) const Text('✓ 리워드 수령 가능'),
              if (flyer.canUse) const Text('✓ 사용 가능'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            // 발행자만 회수 가능
            if (userId != null && userId == flyer.creatorId)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectPostAsCreator(flyer);
                },
                child: const Text('회수'),
              ),
            // 조건에 맞는 사용자는 수령 가능
            if (userId != null && userId != flyer.creatorId && flyer.canRequestReward)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectUserPost(flyer);
                },
                child: const Text('수령'),
              ),
          ],
        );
      },
    );
  }

  // 발행자가 포스트 회수
  Future<void> _collectPostAsCreator(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectPostAsCreator(
          postId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('포스트를 회수했습니다!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 회수에 실패했습니다: $e')),
        );
      }
    }
  }

  // 일반 사용자가 포스트 수령
  Future<void> _collectUserPost(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectPost(
          postId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('포스트를 수령했습니다! ${flyer.reward}원 리워드가 지급되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 수령에 실패했습니다: $e')),
        );
      }
    }
  }


  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _clusterMarkers() {
    if (_isClustered) return;
    
    debugPrint('클러스터링 시작: 마커 아이템 ${_markerItems.length}개, 포스트 ${_posts.length}개');
    
    final clusters = <String, List<dynamic>>{};
    // final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = false; // filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = false; // filter?.showMyPostsOnly ?? false;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    const double clusterRadius = 0.01; // 약 1km
    
    // 기존 마커 아이템들 클러스터링
    for (final item in _markerItems) {
      // 쿠폰만 필터
      if (couponsOnly && item.data['type'] != 'post_place') continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && item.userId != currentUserId) continue;
      
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final distance = _calculateDistance(clusterCenter, item.position);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(item);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${item.position.latitude},${item.position.longitude}';
        clusters[key] = [item];
      }
    }
    
    // 포스트들 클러스터링
    for (final post in _posts) {
      // 쿠폰만 필터
      if (couponsOnly && !(post.canUse || post.canRequestReward)) continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && post.creatorId != currentUserId) continue;
      
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final postLatLng = LatLng(post.location.latitude, post.location.longitude);
        final distance = _calculateDistance(clusterCenter, postLatLng);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(post);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${post.location.latitude},${post.location.longitude}';
        clusters[key] = [post];
      }
    }
    
    final Set<Marker> newMarkers = {};
    
    clusters.forEach((key, items) {
      if (items.length == 1) {
        final item = items.first;
        if (item is MarkerItem) {
          newMarkers.add(_createMarker(item));
        } else if (item is PostModel) {
          newMarkers.add(_createPostMarker(item));
        }
      } else {
        final center = _parseLatLng(key);
        newMarkers.add(_createClusterMarker(center, items.length));
      }
    });
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = true;
    });
  }

  void _showIndividualMarkers() {
    debugPrint('개별 마커 표시 시작: 마커 아이템 ${_markerItems.length}개, 포스트 ${_posts.length}개');
    
    final Set<Marker> newMarkers = {};
    // final filter = mounted ? context.read<MapFilterProvider>() : null;
    final bool couponsOnly = false; // filter?.showCouponsOnly ?? false;
    final bool myPostsOnly = false; // filter?.showMyPostsOnly ?? false;
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // 기존 마커들 추가
    for (final item in _markerItems) {
      // 쿠폰만 필터
      if (couponsOnly && item.data['type'] != 'post_place') continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && item.userId != currentUserId) continue;
      
      newMarkers.add(_createMarker(item));
      debugPrint('마커 추가됨: ${item.title} at ${item.position}');
    }
    
    // 포스트 마커들 추가
    for (final post in _posts) {
      // 쿠폰만 필터
      if (couponsOnly && !(post.canUse || post.canRequestReward)) continue;
      
      // 내 포스트만 필터
      if (myPostsOnly && post.creatorId != currentUserId) continue;
      
      newMarkers.add(_createPostMarker(post));
      debugPrint('포스트 마커 추가됨: ${post.title} at ${post.location}');
    }
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = false;
    });
    
    debugPrint('마커 설정 완료: 총 ${newMarkers.length}개 마커');
  }

  LatLng _parseLatLng(String key) {
    final parts = key.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return sqrt(pow(point1.latitude - point2.latitude, 2) + 
                pow(point1.longitude - point2.longitude, 2));
  }

  double _haversineKm(LatLng a, LatLng b) {
    const double R = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final aa = 
        sin(dLat/2) * sin(dLat/2) +
        cos(_deg2rad(a.latitude)) * cos(_deg2rad(b.latitude)) *
        sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(aa), sqrt(1-aa));
    return R * c;
  }

  double _deg2rad(double d) => d * (pi / 180.0);

  Marker _createMarker(MarkerItem item) {
    // 전단지 타입인지 확인
    final isPostPlace = item.data['type'] == 'post_place';
    
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: item.title,
        snippet: isPostPlace 
            ? '${item.price}원 - ${item.data['creatorName'] ?? '알 수 없음'}'
            : '${item.price}원 - ${item.amount}개',
      ),
      onTap: () => _showMarkerInfo(item),
    );
  }

  Marker _createPostMarker(PostModel flyer) {
    return Marker(
      markerId: MarkerId(flyer.markerId),
      position: LatLng(flyer.location.latitude, flyer.location.longitude),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: flyer.title,
        snippet: '${flyer.reward}원 - ${flyer.creatorName}',
      ),
      onTap: () => _showPostInfo(flyer),
    );
  }

  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
      ),
      onTap: () => _showClusterInfo(position, count),
    );
  }

  void _showMarkerInfo(MarkerItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 전단지 타입인지 확인
        final isPostPlace = item.data['type'] == 'post_place';
        final isOwner = item.userId == FirebaseAuth.instance.currentUser?.uid;
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                isPostPlace ? Icons.description : Icons.location_on,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(item.title),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPostPlace) ...[
                Text('발행자: ${item.data['creatorName'] ?? '알 수 없음'}'),
                const SizedBox(height: 8),
                Text('리워드: ${item.price}원'),
                const SizedBox(height: 8),
                if (item.data['description'] != null && item.data['description'].isNotEmpty)
                  Text('설명: ${item.data['description']}'),
                const SizedBox(height: 8),
                if (item.data['targetGender'] != null)
                  Text('타겟 성별: ${item.data['targetGender'] == 'all' ? '전체' : item.data['targetGender'] == 'male' ? '남성' : '여성'}'),
                const SizedBox(height: 8),
                if (item.data['targetAge'] != null)
                  Text('타겟 나이: ${item.data['targetAge'][0]}~${item.data['targetAge'][1]}세'),
                const SizedBox(height: 8),
                if (item.data['address'] != null)
                  Text('주소: ${item.data['address']}'),
                const SizedBox(height: 8),
                if (item.expiryDate != null)
                  Text('만료일: ${_formatDate(item.expiryDate!)}'),
              ] else ...[
                Text('가격: ${item.price}원'),
                const SizedBox(height: 8),
                Text('수량: ${item.amount}개'),
                const SizedBox(height: 8),
                Text('남은 수량: ${item.remainingAmount}개'),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOwner ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isOwner ? Colors.blue : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOwner ? Icons.person : Icons.people,
                      color: isOwner ? Colors.blue : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOwner ? '내가 등록한 마커' : '다른 사용자 마커',
                      style: TextStyle(
                        color: isOwner ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (isPostPlace) ...[
              // 전단지 수령 버튼 (소유자가 아닌 경우만)
              if (item.data['canRequestReward'] == true && !isOwner)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handlePostCollection(item);
                  },
                  child: const Text('수령'),
                ),
            ] else ...[
              // 일반 마커 수령/회수 버튼
              if (isOwner)
                // 마커 소유자만 회수 가능
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleMarkerCollection(item.id, item.data);
                  },
                  child: const Text('회수'),
                )
              else
                // 다른 사용자는 수령 가능
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handlePostCollection(item); // 모든 마커에서 포스트 수령 가능
                  },
                  child: const Text('수령'),
                ),
            ],
          ],
        );
      },
    );
  }

  void _showClusterInfo(LatLng position, int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('클러스터 정보'),
          content: Text('이 지역에 $count개의 마커가 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _handleRecovery(String markerId, Map<String, dynamic> data) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'isCollected': true,
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('마커를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마커 수령에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 마커 소유자가 회수하는 함수
  void _handleMarkerCollection(String markerId, Map<String, dynamic> data) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'isActive': false, // 비활성화
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('마커를 회수했습니다!'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('마커 회수에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 포스트 수령 처리
  void _handlePostCollection(MarkerItem item) async {
    try {
      debugPrint('🔄 _handlePostCollection 호출: 마커 ID=${item.id}, 제목=${item.title}');
      debugPrint('📊 마커 데이터: ${item.data}');
      
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // 마커 데이터에서 postId 또는 flyerId 가져오기
        String? postId = item.data['postId'] ?? item.data['flyerId'];
        
        if (postId != null) {
          // 기존 포스트가 있는 경우
          debugPrint('📝 기존 포스트 수령: postId=$postId');
          
          try {
            // PostService를 통해 포스트 수령
            await _postService.collectPost(
              postId: postId,
              userId: currentUserId,
            );
            debugPrint('✅ PostService.collectPost 성공');
          } catch (e) {
            debugPrint('⚠️ 기존 포스트 수령 실패, 새 포스트 생성: $e');
            // 기존 포스트가 없으면 새로 생성
            postId = null;
          }
        }
        
        if (postId == null) {
          // 새 포스트 생성
          debugPrint('🆕 새 포스트 생성 중...');
          
          final newPost = {
            'title': item.title,
            'description': item.data['description'] ?? '마커에서 수령한 포스트',
            'reward': int.parse(item.price),
            'creatorId': item.data['userId'] ?? 'unknown',
            'creatorName': item.data['creatorName'] ?? '알 수 없음',
            'location': GeoPoint(item.position.latitude, item.position.longitude),
            'address': item.data['address'] ?? '',
            'targetGender': item.data['targetGender'] ?? 'all',
            'targetAge': item.data['targetAge'] ?? [18, 65],
            'canRespond': item.data['canRespond'] ?? false,
            'canForward': item.data['canForward'] ?? false,
            'canRequestReward': true,
            'canUse': item.data['canUse'] ?? false,
            'isDistributed': false,
            'isCollected': true,
            'collectedBy': currentUserId,
            'collectedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': item.expiryDate ?? Timestamp.fromDate(DateTime.now().add(Duration(days: 30))),
          };
          
          final postRef = await FirebaseFirestore.instance.collection('posts').add(newPost);
          postId = postRef.id;
          debugPrint('✅ 새 포스트 생성 완료: $postId');
        }
        
        // Firebase에서 마커 상태 업데이트
        await FirebaseFirestore.instance.collection('markers').doc(item.id).update({
          'isCollected': true,
          'collectedBy': currentUserId,
          'collectedAt': FieldValue.serverTimestamp(),
          'postId': postId, // 생성된 포스트 ID 저장
        });
        
        debugPrint('✅ 마커 상태 업데이트 성공');
        
        // 마커 목록에서 제거
        setState(() {
          _markerItems.removeWhere((marker) => marker.id == item.id);
        });
        
        // 클러스터링 업데이트
        _updateClustering();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('포스트를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        debugPrint('🎉 포스트 수령 완료!');
      }
    } catch (e) {
      debugPrint('❌ 포스트 수령 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('포스트 수령에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();
      
      _processMarkersSnapshot(snapshot);
    } catch (e) {
      debugPrint('마커 로드 오류: $e');
    }
  }

  void _setupRealtimeListeners() {
    // 실시간 마커 리스너 설정
    _markersListener = FirebaseFirestore.instance
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('isCollected', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _processMarkersSnapshot(snapshot);
        });
  }

  void _processMarkersSnapshot(QuerySnapshot snapshot) {
    setState(() {
      _markerItems.clear();
    });
    
    debugPrint('마커 스냅샷 처리 중: ${snapshot.docs.length}개 마커');
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final geoPoint = data['position'] as GeoPoint;
      
      // 만료된 마커는 제외
      if (data['expiryDate'] != null) {
        final expiryDate = data['expiryDate'].toDate() as DateTime;
        if (DateTime.now().isAfter(expiryDate)) {
          debugPrint('만료된 마커 제외: ${doc.id}');
          continue; // 만료된 마커는 건너뛰기
        }
      }
      
      final markerItem = MarkerItem(
        id: doc.id,
        title: data['title'] ?? '',
        price: data['price']?.toString() ?? '0',
        amount: data['amount']?.toString() ?? '0',
        userId: data['userId'] ?? '',
        data: data,
        position: LatLng(geoPoint.latitude, geoPoint.longitude),
        imageUrl: data['imageUrl'],
        remainingAmount: data['remainingAmount'] ?? 0,
        expiryDate: data['expiryDate']?.toDate(),
      );
      
      _markerItems.add(markerItem);
      debugPrint('마커 로드됨: ${markerItem.title} at ${markerItem.position}, 타입: ${data['type']}');
    }
    
    debugPrint('마커 처리 완료: 총 ${_markerItems.length}개 마커 로드됨');
    
    // 클러스터링 업데이트로 마커들을 지도에 표시
    _updateClustering();
  }

  Future<void> _loadPostsFromFirestore() async {
    try {
      if (_currentPosition != null) {
        // 사용자 정보 가져오기 (실제로는 사용자 프로필에서 가져와야 함)
        final userGender = 'male'; // 임시 값
        final userAge = 25; // 임시 값
        final userInterests = ['패션', '뷰티']; // 임시 값
        final userPurchaseHistory = ['화장품']; // 임시 값
        
        // 새로운 flyer 시스템에서 전단지 로드
        final flyers = await _postService.getFlyersNearLocation(
          location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          radiusInKm: 5.0, // 5km 반경 내 전단지 조회
          userGender: userGender,
          userAge: userAge,
          userInterests: userInterests,
          userPurchaseHistory: userPurchaseHistory,
        );
        
        setState(() {
          _posts.clear();
          _posts.addAll(flyers);
        });
        
        _updateClustering();
      }
    } catch (e) {
      debugPrint('전단지 로드 오류: $e');
    }
  }



  void _addMarkerToMap(MarkerItem markerItem) {
    setState(() {
      _markerItems.add(markerItem);
      // 마커를 직접 _clusteredMarkers에 추가하지 않고 _markerItems에만 추가
      // _updateClustering()에서 모든 마커를 다시 생성
    });
    
    // Firestore에 저장
    _saveMarkerToFirestore(markerItem);
    
    // 클러스터링 업데이트로 모든 마커를 다시 생성
    _updateClustering();
    
    debugPrint('마커 추가됨: ${markerItem.title} at ${markerItem.position}');
  }

  Future<void> _saveMarkerToFirestore(MarkerItem markerItem) async {
    try {
      final markerData = {
        'title': markerItem.title,
        'price': int.parse(markerItem.price),
        'amount': int.parse(markerItem.amount),
        'userId': markerItem.userId,
        'position': GeoPoint(markerItem.position.latitude, markerItem.position.longitude),
        'remainingAmount': markerItem.remainingAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': markerItem.expiryDate,
        'isActive': true, // 활성 상태
        'isCollected': false, // 회수되지 않음
      };
      
      // 전단지 타입인 경우 추가 정보 저장
      if (markerItem.data['type'] == 'post_place') {
        markerData.addAll({
          'type': 'post_place',
          'flyerId': markerItem.data['flyerId'],
          'creatorName': markerItem.data['creatorName'],
          'description': markerItem.data['description'],
          'targetGender': markerItem.data['targetGender'],
          'targetAge': markerItem.data['targetAge'],
          'canRespond': markerItem.data['canRespond'],
          'canForward': markerItem.data['canForward'],
          'canRequestReward': markerItem.data['canRequestReward'],
          'canUse': markerItem.data['canUse'],
          'address': markerItem.data['address'],
        });
      }
      
      final docRef = await FirebaseFirestore.instance.collection('markers').add(markerData);
      debugPrint('마커 Firebase 저장 완료: ${docRef.id}');
    } catch (e) {
      debugPrint('마커 저장 오류: $e');
    }
  }

  void _handleAddMarker() async {
    if (_longPressedLatLng != null) {
      // 선택된 위치의 주소 가져오기
      try {
        final address = await LocationService.getAddressFromCoordinates(
          _longPressedLatLng!.latitude,
          _longPressedLatLng!.longitude,
        );
        
        // 롱프레스 팝업 닫기
        setState(() {
          _longPressedLatLng = null;
        });
        
        // 주소 확인 팝업 표시
        _showAddressConfirmationDialog(address);
      } catch (e) {
        // 롱프레스 팝업 닫기
        setState(() {
          _longPressedLatLng = null;
        });
        
        // 주소 가져오기 실패 시 기본 메시지로 진행
        _showAddressConfirmationDialog('주소를 가져올 수 없습니다');
      }
    }
  }

  void _showAddressConfirmationDialog(String address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('주소 확인'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '이 주소가 맞습니까?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.shade50,
                ),
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPostPlaceWithAddress(address);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPopupWidget() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '포스트 배포',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4D4DFF),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '선택한 위치에서 포스트를 배포합니다',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeploy();
                },
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: const Text(
                  "이 위치에 뿌리기",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeployWithAddress();
                },
                icon: const Icon(Icons.home, color: Color(0xFF4D4DFF)),
                label: const Text(
                  "이 주소에 뿌리기",
                  style: TextStyle(color: Color(0xFF4D4DFF), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _navigateToPostDeployByCategory();
                },
                icon: const Icon(Icons.category, color: Color(0xFF4D4DFF)),
                label: const Text(
                  "특정 업종에 뿌리기",
                  style: TextStyle(color: Color(0xFF4D4DFF), fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF4D4DFF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '수수료/반경/타겟팅 주의',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                child: const Text(
                  "취소",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPostDeploy() async {
    // 이 위치에 뿌리기 - 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'location',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostDeployWithAddress() async {
    // 이 주소에 뿌리기 - 주소 기반 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'address',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostDeployByCategory() async {
    // 특정 업종에 뿌리기 - 업종 기반 포스트 설정화면으로 이동
    debugPrint('롱프레스 위치 전달: ${_longPressedLatLng?.latitude}, ${_longPressedLatLng?.longitude}');
    final result = await Navigator.pushNamed(
      context, 
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng,
        'type': 'category',
        'address': null,
      },
    );
    
    // 화면에서 돌아오면 롱프레스 마커 제거
    setState(() {
      _longPressedLatLng = null;
    });
    
    _handlePostDeployResult(result);
  }

  void _navigateToPostPlaceWithAddress(String address) async {
    // 주소 정보와 함께 포스트 화면으로 이동
    final result = await Navigator.pushNamed(
      context, 
      '/post-place',
      arguments: {
        'location': _longPressedLatLng,
        'address': address,
      },
    );
    _handlePostPlaceResult(result);
  }

  void _handlePostDeployResult(dynamic result) async {
    // 포스트 배포 결과 처리
    if (result != null && result is Map<String, dynamic>) {
      // 새로 생성된 포스트 정보를 MarkerItem으로 변환
      if (result['location'] != null && result['postId'] != null) {
        final location = result['location'] as LatLng;
        final postId = result['postId'] as String;
        final address = result['address'] as String?;
        
        try {
          // PostService에서 실제 포스트 정보 가져오기
          final post = await _postService.getPostById(postId);
          
          if (post != null) {
            // MarkerItem 생성 (실제 포스트 정보 사용)
            final markerItem = MarkerItem(
              id: postId,
              title: post.title,
              price: post.reward.toString(),
              amount: '1', // 포스트는 개별 단위
              userId: post.creatorId,
              data: {
                'address': address,
                'postId': postId,
                'type': 'post',
                'creatorName': post.creatorName,
                'description': post.description,
                'targetGender': post.targetGender,
                'targetAge': post.targetAge,
                'canRespond': post.canRespond,
                'canForward': post.canForward,
                'canRequestReward': post.canRequestReward,
                'canUse': post.canUse,
              },
              position: location,
              remainingAmount: 1, // 포스트는 개별 단위
              expiryDate: post.expiresAt,
            );
            
            // 마커 추가 (Firebase에 저장됨)
            _addMarkerToMap(markerItem);
            
            // 생성된 포스트 위치로 카메라 이동
            mapController.animateCamera(
              CameraUpdate.newLatLng(location),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('포스트 정보를 가져오는데 실패했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void _handlePostPlaceResult(dynamic result) async {
    // 전단지 생성 후 지도 새로고침
    if (result != null && result is Map<String, dynamic>) {
      // 새로 생성된 전단지 정보를 MarkerItem으로 변환
      if (result['location'] != null && result['flyerId'] != null) {
        final location = result['location'] as LatLng;
        final flyerId = result['flyerId'] as String;
        final address = result['address'] as String?;
        
        try {
          // PostService에서 실제 전단지 정보 가져오기
          final flyer = await _postService.getFlyerById(flyerId);
          
          if (flyer != null) {
            // MarkerItem 생성 (실제 전단지 정보 사용)
            final markerItem = MarkerItem(
              id: flyerId,
              title: flyer.title,
              price: flyer.reward.toString(),
              amount: '1', // 전단지는 개별 단위
              userId: flyer.creatorId,
              data: {
                'address': address,
                'flyerId': flyerId,
                'type': 'post_place',
                'creatorName': flyer.creatorName,
                'description': flyer.description,
                'targetGender': flyer.targetGender,
                'targetAge': flyer.targetAge,
                'canRespond': flyer.canRespond,
                'canForward': flyer.canForward,
                'canRequestReward': flyer.canRequestReward,
                'canUse': flyer.canUse,
              },
              position: location,
              remainingAmount: 1, // 전단지는 개별 단위
              expiryDate: flyer.expiresAt,
            );
            
            // 마커 추가 (Firebase에 저장됨)
            _addMarkerToMap(markerItem);
            
            // 생성된 전단지 위치로 카메라 이동
            mapController.animateCamera(
              CameraUpdate.newLatLng(location),
            );
            

          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('전단지 정보를 가져오는데 실패했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void goToCurrentLocation() async {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
      
      // 현재 위치 방문 기록 저장
      await _recordCurrentLocationVisit();
    }
  }

  /// 현재 위치 방문 기록 저장
  Future<void> _recordCurrentLocationVisit() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _currentPosition == null) return;

      await FirebaseFirestore.instance
          .collection('visits')
          .doc(uid)
          .collection('points')
          .add({
        'geo': GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        'ts': Timestamp.now(),
        'weight': 1.0,
      });

      // Fog of War 업데이트
      await _loadVisitsAndBuildFog();
      
      debugPrint('현재 위치 방문 기록 저장 완료');
    } catch (e) {
      debugPrint('방문 기록 저장 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // final filters = Provider.of<MapFilterProvider>(context);
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
          : Stack(
        children: [
          GestureDetector(
            onSecondaryTapDown: (TapDownDetails details) {
              // 크롬에서 오른쪽 클릭 시 포스트 뿌리기 메뉴 표시
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              
              // 지도 좌표로 변환 (대략적인 계산)
              final mapWidth = renderBox.size.width;
              final mapHeight = renderBox.size.height;
              final latRatio = localPosition.dy / mapHeight;
              final lngRatio = localPosition.dx / mapWidth;
              
              final lat = _currentPosition!.latitude + (0.01 * (0.5 - latRatio));
              final lng = _currentPosition!.longitude + (0.01 * (lngRatio - 0.5));
              
              setState(() {
                _longPressedLatLng = LatLng(lat, lng);
              });
            },
            child: Stack(
              children: [
                GoogleMap(
              key: mapWidgetKey,
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 15.0,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              // circles: _fogOfWarCircles, // 오버레이로 대체
              onLongPress: (LatLng latLng) {
                setState(() {
                  _longPressedLatLng = latLng;
                });
              },
              markers: {
                ..._clusteredMarkers,
                if (_longPressedLatLng != null)
                  Marker(
                    markerId: const MarkerId('long_press_marker'),
                    position: _longPressedLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    infoWindow: const InfoWindow(title: "선택한 위치"),
                  ),
              },
              onCameraMove: (CameraPosition position) {
                _currentZoom = position.zoom;
              },
              onCameraIdle: () {
                _updateClustering();
              },
            ),
                // 포그오브워 오버레이 (항상 표시, 터치 이벤트 무시)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: FogOfWarPainter(
                        mapController: null, // mapController 불필요
                        currentPosition: _currentPosition,
                        visitedPositions: _visitedPositions,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
                     // 상단 필터 바
           Positioned(
             top: 16,
             left: 12,
             right: 12,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                 boxShadow: const [
                   BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2)),
                 ],
               ),
               child: Row(
                 children: [
                   FilterChip(
                     label: const Text('쿠폰만'),
                     selected: false, // filters.showCouponsOnly,
                     onSelected: (_) {
                       // filters.toggleCouponsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   FilterChip(
                     label: const Text('내 포스트'),
                     selected: false, // filters.showMyPostsOnly,
                     onSelected: (_) {
                       // filters.toggleMyPostsOnly();
                       _updateClustering();
                     },
                   ),
                   const SizedBox(width: 8),
                   // if (filters.showCouponsOnly || filters.showMyPostsOnly)
                     // FilterChip(
                       // label: const Text('필터 초기화'),
                       // selected: false,
                       // onSelected: (_) {
                         // filters.resetFilters();
                         // _updateClustering();
                       // },
                     // ),
                 ],
               ),
             ),
           ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}

 