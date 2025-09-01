import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post_model.dart';
import '../../services/fog_of_war_tile_provider.dart';
import '../../services/fog_of_war_manager.dart';
import '../../utils/tile_utils.dart';

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

class MapScreen extends StatefulWidget {
  MapScreen({super.key});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;
  double _currentZoom = 13.0;
  String? _mapStyle;
  List<MarkerItem> _markerItems = [];
  List<PostModel> _posts = [];
  BitmapDescriptor? _customMarkerIcon;
  String? userId;
  final PostService _postService = PostService();
  
  // 🔥 TileOverlay 기반 Fog of War 시스템
  FogOfWarTileProvider? _fogTileProvider;
  FogOfWarManager? _fogManager;
  final Set<TileOverlay> _tileOverlays = {};

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid;
    _loadMapStyle();
    _loadCustomMarkerIcon();
    _initializeLocationAndFogOfWar(); // 위치 서비스와 Fog of War 초기화
  }

  /// TileOverlay 새로고침 (캐시 무효화 후 재생성)
  void _refreshTileOverlay() {
    if (_fogTileProvider == null) return;
    
    debugPrint('🔄 TileOverlay 새로고침');
    
    // 새로운 TileOverlay 생성 (강제 새로고침)
    final newTileOverlay = TileOverlay(
      tileOverlayId: TileOverlayId('fog_of_war_${DateTime.now().millisecondsSinceEpoch}'),
      tileProvider: _fogTileProvider!,
      transparency: 0.0,
      visible: true,
      zIndex: 10,
    );
    
    setState(() {
      _tileOverlays.clear();
      _tileOverlays.add(newTileOverlay);
    });
  }

  @override
  void dispose() {
    // HTTP 기반 TileOverlay Fog of War 정리
    _fogManager?.dispose();
    _fogTileProvider?.dispose();
    super.dispose();
  }

  // 위치 서비스와 Fog of War 초기화
  Future<void> _initializeLocationAndFogOfWar() async {
    debugPrint('🚀 위치 서비스와 Fog of War 시스템 초기화');
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('❌ 사용자 인증 없음 - 초기화 건너뜀');
        return;
      }
      
      // 1. 위치 권한 확인 및 현재 위치 가져오기
      await _getCurrentLocation();
      
      // 2. Firestore 기반 TileProvider 생성
      _fogTileProvider = FogOfWarTileProvider(
        userId: uid,
      );
      
      // 3. FogOfWarManager 생성 및 현재 위치 설정
      _fogManager = FogOfWarManager();
      _fogManager?.setRevealRadius(0.3); // 300m 원형 반경 설정
      
      // 현재 위치가 있으면 FogOfWarManager와 TileProvider에 설정
      if (_currentPosition != null) {
        _fogManager?.setCurrentLocation(_currentPosition!);
        _fogTileProvider?.setCurrentLocation(_currentPosition!);
        _fogTileProvider?.setRevealRadius(0.3); // 300m 반경
        debugPrint('📍 현재 위치 설정: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      }
      
      // 4. 타일 업데이트 시 캐시 무효화 연동
      _fogManager?.setTileUpdateCallback(() {
        _fogTileProvider?.clearCache();
        _refreshTileOverlay();
      });
      
      // 5. 위치 추적 시작
      _fogManager?.startTracking();
      
      // 6. TileOverlay 생성
      final tileOverlay = TileOverlay(
        tileOverlayId: const TileOverlayId('fog_of_war'),
        tileProvider: _fogTileProvider!,
        transparency: 0.0,
        visible: true,
        zIndex: 10,
      );
      
      setState(() {
        _tileOverlays.clear();
        _tileOverlays.add(tileOverlay);
      });

      debugPrint('✅ 위치 서비스와 Fog of War 초기화 완료');
      
    } catch (e) {
      debugPrint('❌ 초기화 오류: $e');
    }
  }

  // 현재 위치 가져오기
  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('📍 현재 위치 가져오기 시작');
      
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ 위치 권한 거부됨');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ 위치 권한 영구 거부됨');
        return;
      }
      
      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      
      debugPrint('✅ 현재 위치 가져오기 완료: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      
    } catch (e) {
      debugPrint('❌ 현재 위치 가져오기 실패: $e');
    }
  }

  Future<void> _loadMapStyle() async {
    try {
      _mapStyle = await rootBundle.loadString('assets/map_style.json');
    } catch (e) {
      debugPrint('맵 스타일 로드 실패: $e');
    }
  }

  Future<void> _loadCustomMarkerIcon() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/images/icon_search.png');
      final Uint8List list = bytes.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(list);
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
    
    // 현재 위치가 있으면 해당 위치로 이동
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
      );
      debugPrint('🗺️ 맵 생성 완료 - 현재 위치로 이동: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } else {
      debugPrint('🗺️ 맵 생성 완료 (현재 위치 없음)');
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

  void _clusterMarkers() {
    debugPrint('클러스터링 시작: 마커 아이템 ${_markerItems.length}개, 포스트 ${_posts.length}개');
    
    const double clusterRadius = 0.001; // 클러스터링 반경 (도 단위)
    final Map<String, List<dynamic>> clusters = {};
    
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // 마커 아이템들 클러스터링
    for (final item in _markerItems) {
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final distance = TileUtils.calculateDistance(clusterCenter, item.position);
        
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
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final postLatLng = LatLng(post.location.latitude, post.location.longitude);
        final distance = TileUtils.calculateDistance(clusterCenter, postLatLng);
        
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
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // 기존 마커들 추가
    for (final item in _markerItems) {
      newMarkers.add(_createMarker(item));
      debugPrint('마커 추가됨: ${item.title} at ${item.position}');
    }
    
    // 포스트 마커들 추가
    for (final post in _posts) {
      newMarkers.add(_createPostMarker(post));
      debugPrint('포스트 마커 추가됨: ${post.title} at ${post.location.latitude}, ${post.location.longitude}');
    }
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = false;
    });
    
    debugPrint('개별 마커 표시 완료: 총 ${newMarkers.length}개 마커');
  }

  LatLng _parseLatLng(String key) {
    final parts = key.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }



  Marker _createMarker(MarkerItem item) {
    // 전단지 타입인지 확인
    final isPostPlace = item.data['type'] == 'post_place';
    
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? 
            (isPostPlace 
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarker),
      infoWindow: InfoWindow(
        title: item.title,
        snippet: isPostPlace ? '${item.price}원' : item.amount,
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
                Text('남은 수량: ${item.remainingAmount}개'),
                if (item.expiryDate != null) ...[
                const SizedBox(height: 8),
                  Text('만료일: ${_formatDate(item.expiryDate!)}'),
                ],
              ] else ...[
                Text('위치: ${item.title}'),
                const SizedBox(height: 8),
                Text('정보: ${item.amount}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (isPostPlace && !isOwner)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  // 수령 로직 추가
                  },
                  child: const Text('수령'),
                ),
          ],
        );
      },
    );
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
            const SnackBar(content: Text('포스트를 수령했습니다!')),
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

  void _showClusterInfo(LatLng position, int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('클러스터'),
          content: Text('이 지역에 $count개의 아이템이 있습니다.'),
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

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
            onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(37.4969433, 127.0311633),
          zoom: 13.0,
        ),
        markers: _isClustered ? _clusteredMarkers : _markers.union(_clusteredMarkers),
        circles: _circles,
        tileOverlays: _tileOverlays, // TileOverlay 기반 Fog of War
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              _updateClustering();
            },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
      ),
    );
  }
}
 