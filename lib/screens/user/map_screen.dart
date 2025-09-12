import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/marker_service.dart';
// OSM 기반 Fog of War 시스템
import '../../services/osm_fog_service.dart';
import '../../services/visit_tile_service.dart';
import '../../services/nominatim_service.dart';
import '../../services/location_service.dart';
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
  final Function(String)? onAddressChanged;
  
  const MapScreen({super.key, this.onAddressChanged});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OSM 기반 Fog of War 상태
  List<Polygon> _fogPolygons = [];
  List<Polygon> _grayPolygons = []; // 회색 영역들 (과거 방문 위치)
  List<CircleMarker> _ringCircles = [];
  List<Marker> _currentMarkers = [];
  List<Marker> _userMarkerWidgets = [];
  List<Marker> _userMarkersUI = []; // Flutter Map용 마커
  
  // 사용자 위치 정보
  LatLng? _homeLocation;
  List<LatLng> _workLocations = [];
  
  // 기본 상태
  MapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 15.0;
  String _currentAddress = '위치 불러오는 중...';
  LatLng? _longPressedLatLng;
  Widget? _customMarkerIcon;
  
  
  // 포스트 관련
  List<PostModel> _posts = [];
  List<MarkerData> _markers = [];
  List<MarkerData> _userMarkers = []; // 사용자가 배치한 마커들
  bool _isLoading = false;
  String? _errorMessage;
  
  // 필터 관련
  bool _showFilter = false;
  String _selectedCategory = 'all';
  double _maxDistance = 10000.0; // 10km로 확장
  int _minReward = 0;
  bool _showCouponsOnly = false;
  bool _showMyPostsOnly = false;
  
  // 실시간 업데이트 관련
  Timer? _mapMoveTimer;
  LatLng? _lastMapCenter;
  Set<String> _lastFogLevel1Tiles = {};
  bool _isUpdatingPosts = false;
  
  // 포그레벨 변경 감지 관련
  Map<String, int> _tileFogLevels = {}; // 타일별 포그레벨 캐시
  Set<String> _visiblePostIds = {}; // 현재 표시 중인 포스트 ID들
  
  
  // 클러스터링 관련
  List<Marker> _clusteredMarkers = [];
  bool _isClustered = false;
  static const double _clusterRadius = 50.0; // 픽셀 단위

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    
    _initializeLocation();
    _loadCustomMarker();
    _loadPosts();
    _loadMarkers();
    _loadUserLocations();
    _setupUserDataListener();
    _setupMarkerListener();
    _setupPostStreamListener(); // 🚀 실시간 포스트 스트림 리스너 설정
  }

  void _setupUserDataListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('사용자 데이터 리스너 설정 실패: 사용자가 로그인하지 않음');
      return;
    }

    print('사용자 데이터 리스너 설정 시작: ${user.uid}');

    // 사용자 데이터 변경을 실시간으로 감지
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        print('사용자 데이터 변경 감지됨 - 타임스탬프: ${DateTime.now()}');
        final data = snapshot.data();
        if (data != null) {
          final workplaces = data['workplaces'] as List<dynamic>?;
          print('변경된 근무지 개수: ${workplaces?.length ?? 0}');
        }
        _loadUserLocations();
      } else {
        print('사용자 데이터가 존재하지 않음');
      }
    }, onError: (error) {
      print('사용자 데이터 리스너 오류: $error');
    });
  }

  void _setupMarkerListener() {
    if (_currentPosition == null) return;

    print('마커 리스너 설정 시작');

    // 실시간 마커 리스너
    MarkerService.getMarkersStream(
      center: _currentPosition!,
      radiusInKm: _maxDistance / 1000.0,
    ).listen((markers) {
      print('마커 업데이트 감지됨: ${markers.length}개');
      
      setState(() {
        _markers = markers.where((marker) => !marker.isCollected).toList();
        _userMarkers = markers.where((marker) => 
          marker.userId == FirebaseAuth.instance.currentUser?.uid
        ).toList();
      });
      
      _updateMarkers();
    }, onError: (error) {
      print('마커 리스너 오류: $error');
    });
  }

  // 🚀 실시간 포스트 스트림 리스너 설정
  void _setupPostStreamListener() {
    if (_currentPosition == null) return;

    print('포스트 스트림 리스너 설정 시작');

    // 포그레벨 1단계 포스트 실시간 스트림
    PostService().getFlyersInFogLevel1Stream(
      location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
      radiusInKm: _maxDistance / 1000.0,
    ).listen((posts) {
      print('📡 포그레벨 1단계 포스트 업데이트: ${posts.length}개');
      
      // 포스트를 마커 데이터로 변환
      final markers = <MarkerData>[];
      
      for (final post in posts) {
        markers.add(MarkerData(
          id: post.flyerId,
          title: post.title,
          description: post.description,
          userId: post.creatorId,
          position: LatLng(post.location.latitude, post.location.longitude),
          createdAt: post.createdAt,
          expiryDate: post.expiresAt,
          data: post.toFirestore(),
          isCollected: post.isCollected,
          collectedBy: post.collectedBy,
          collectedAt: post.collectedAt,
          type: MarkerType.post,
        ));
      }
      
      setState(() {
        _markers = markers;
      });
      
      _updateMarkers();
    }, onError: (error) {
      print('포스트 스트림 리스너 오류: $error');
    });
  }

  void _loadCustomMarker() {
    _customMarkerIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/ppam_work.png',
          width: 36,
          height: 36,
          fit: BoxFit.cover,
        ),
          ),
        );
      }

  Future<void> _initializeLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
        setState(() {
            _errorMessage = '위치 권한이 거부되었습니다.';
        });
          return;
    }
  }

      if (permission == LocationPermission.deniedForever) {
      setState(() {
          _errorMessage = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      });
        return;
  }

      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = '위치를 가져오는 중 오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final newPosition = LatLng(position.latitude, position.longitude);
      
        setState(() {
        _currentPosition = newPosition;
        _errorMessage = null;
      });

      // OSM Fog of War 재구성
      _rebuildFogWithUserLocations(newPosition);
      
      // 주소 업데이트
      _updateCurrentAddress();
      
      // 타일 방문 기록 업데이트 (새로운 기능)
      await VisitTileService.updateCurrentTileVisit(
        newPosition.latitude, 
        newPosition.longitude
      );
      
      
      // 포스트 및 마커 로드
      _loadPosts();
      _loadMarkers();
      
      // 현재 위치 마커 생성
      _createCurrentLocationMarker(newPosition);
      
      // 지도 중심 이동
      _mapController?.move(newPosition, _currentZoom);
      
    } catch (e) {
        setState(() {
        _errorMessage = '현재 위치를 가져올 수 없습니다: $e';
      });
    }
  }

  void _createCurrentLocationMarker(LatLng position) {
    final marker = Marker(
      point: position,
      width: 30,
      height: 30,
      child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
          Icons.my_location,
            color: Colors.white,
          size: 16,
        ),
      ),
        );
        
        setState(() {
      _currentMarkers = [marker];
    });
  }

  void _rebuildFog(LatLng currentPosition) {
    final fogPolygon = OSMFogService.createFogPolygon(currentPosition);
    final ringCircle = OSMFogService.createRingCircle(currentPosition);
        
        setState(() {
      _fogPolygons = [fogPolygon];
      _ringCircles = [ringCircle];
      // 회색 영역은 _loadVisitedLocations에서 로드되므로 여기서는 유지
    });
  }

  void _rebuildFogWithUserLocations(LatLng currentPosition) {
    final allPositions = <LatLng>[currentPosition];
    final ringCircles = <CircleMarker>[];

    print('포그 오브 워 재구성 시작');
    print('현재 위치: ${currentPosition.latitude}, ${currentPosition.longitude}');
    print('집 위치: ${_homeLocation?.latitude}, ${_homeLocation?.longitude}');
    print('근무지 개수: ${_workLocations.length}');

    // 현재 위치
    ringCircles.add(OSMFogService.createRingCircle(currentPosition));

    // 집 위치
    if (_homeLocation != null) {
      allPositions.add(_homeLocation!);
      ringCircles.add(OSMFogService.createRingCircle(_homeLocation!));
      print('집 위치 추가됨');
    }

    // 일터 위치들
    for (int i = 0; i < _workLocations.length; i++) {
      final workLocation = _workLocations[i];
      allPositions.add(workLocation);
      ringCircles.add(OSMFogService.createRingCircle(workLocation));
      print('근무지 $i 추가됨: ${workLocation.latitude}, ${workLocation.longitude}');
    }

    print('총 밝은 영역 개수: ${allPositions.length}');

    // 모든 위치에 대해 하나의 통합된 폴리곤 생성
    final fogPolygon = OSMFogService.createFogPolygonWithMultipleHoles(allPositions);

    setState(() {
      _fogPolygons = [fogPolygon];
      _ringCircles = ringCircles;
    });

    print('포그 오브 워 재구성 완료');
  }

  Future<void> _loadUserLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 프로필에서 집주소 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final address = userData?['address'] as String?;
        
        if (address != null && address.isNotEmpty) {
          print('집주소 로드 시도: $address');
          // 주소를 좌표로 변환
          final homeCoords = await NominatimService.geocode(address);
          if (homeCoords != null) {
            print('집주소 좌표 변환 성공: ${homeCoords.latitude}, ${homeCoords.longitude}');
        setState(() {
              _homeLocation = homeCoords;
            });
          } else {
            print('집주소 좌표 변환 실패');
          }
        } else {
          print('집주소가 없거나 비어있음');
        }

        // 워크플레이스 정보 가져오기 (회원가입에서 저장한 구조)
        final workplaces = userData?['workplaces'] as List<dynamic>?;
        final workLocations = <LatLng>[];
        
        if (workplaces != null) {
          print('워크플레이스 개수: ${workplaces.length}');
          for (final workplace in workplaces) {
            final workplaceMap = workplace as Map<String, dynamic>?;
            final workplaceAddress = workplaceMap?['address'] as String?;
            
            if (workplaceAddress != null && workplaceAddress.isNotEmpty) {
              print('워크플레이스 주소 로드 시도: $workplaceAddress');
              // 워크플레이스 주소를 좌표로 변환
              final workCoords = await NominatimService.geocode(workplaceAddress);
              if (workCoords != null) {
                print('워크플레이스 좌표 변환 성공: ${workCoords.latitude}, ${workCoords.longitude}');
                workLocations.add(workCoords);
              } else {
                print('워크플레이스 좌표 변환 실패');
              }
            }
          }
        } else {
          print('워크플레이스 정보가 없음');
        }
        
        setState(() {
          _workLocations = workLocations;
        });

        print('최종 워크플레이스 좌표 개수: ${workLocations.length}');
        for (int i = 0; i < workLocations.length; i++) {
          print('워크플레이스 $i: ${workLocations[i].latitude}, ${workLocations[i].longitude}');
        }
      }

      // 과거 방문 위치 로드
      await _loadVisitedLocations();

      // 포그 오브 워 업데이트
      if (_currentPosition != null) {
        print('포그 오브 워 업데이트 시작');
        _rebuildFogWithUserLocations(_currentPosition!);
        print('포그 오브 워 업데이트 완료');
      }
    } catch (e) {
      debugPrint('사용자 위치 로드 실패: $e');
    }
  }

  Future<void> _loadVisitedLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 30일 이내 방문 기록 가져오기
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final visitedTiles = await FirebaseFirestore.instance
          .collection('visited_tiles')
          .where('userId', isEqualTo: user.uid)
          .where('visitedAt', isGreaterThan: thirtyDaysAgo)
          .get();

      final visitedPositions = <LatLng>[];
      
      for (final doc in visitedTiles.docs) {
        final data = doc.data();
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        
        if (lat != null && lng != null) {
          visitedPositions.add(LatLng(lat, lng));
        }
      }

      print('과거 방문 위치 개수: ${visitedPositions.length}');
      
      // 회색 영역 생성
      final grayPolygons = OSMFogService.createGrayAreas(visitedPositions);
      
      setState(() {
        _grayPolygons = grayPolygons;
      });
      
    } catch (e) {
      debugPrint('방문 위치 로드 실패: $e');
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentPosition == null) return;
    
    try {
      final address = await NominatimService.reverseGeocode(_currentPosition!);
        setState(() {
        _currentAddress = address;
      });

      // 상위 위젯에 주소 전달
      widget.onAddressChanged?.call(address);
    } catch (e) {
    setState(() {
        _currentAddress = '주소 변환 실패';
      });
    }
  }

  Future<void> _loadPosts() async {
    if (_currentPosition == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = await PostService().getFlyersNearLocation(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
        );
    
    setState(() {
        _posts = posts;
        _isLoading = false;
      });
      
      _updateMarkers();
    } catch (e) {
    setState(() {
        _errorMessage = '포스트를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMarkers() async {
    if (_currentPosition == null) return;

    try {
      // 🚀 성능 최적화: 포그레벨 1단계 포스트만 조회
      final posts = await PostService().getFlyersInFogLevel1(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
      );
    
      // 슈퍼포스트도 추가로 조회 (검은 영역에서도 표시)
      final superPosts = await PostService().getSuperPostsInRadius(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
      );
      
      // 포스트를 마커 데이터로 변환
      final markers = <MarkerData>[];
      
      // 일반 포스트 (포그레벨 1단계)
      for (final post in posts) {
        markers.add(MarkerData(
          id: post.flyerId,
          title: post.title,
          description: post.description,
          userId: post.creatorId,
          position: LatLng(post.location.latitude, post.location.longitude),
          createdAt: post.createdAt,
          expiryDate: post.expiresAt,
          data: post.toFirestore(),
          isCollected: post.isCollected,
          collectedBy: post.collectedBy,
          collectedAt: post.collectedAt,
          type: MarkerType.post,
        ));
      }
      
      // 슈퍼포스트 (모든 영역)
      for (final post in superPosts) {
        markers.add(MarkerData(
          id: post.flyerId,
          title: post.title,
          description: post.description,
          userId: post.creatorId,
          position: LatLng(post.location.latitude, post.location.longitude),
          createdAt: post.createdAt,
          expiryDate: post.expiresAt,
          data: post.toFirestore(),
          isCollected: post.isCollected,
          collectedBy: post.collectedBy,
          collectedAt: post.collectedAt,
          type: MarkerType.superPost,
        ));
      }
    
      setState(() {
        _markers = markers;
      });
      
      _updateMarkers();
    } catch (e) {
      print('마커 로드 중 오류: $e');
    }
  }

  // 🚀 실시간 업데이트: 지도 이동 감지 및 포스트 새로고침
  void _onMapMoved(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveStart) {
      // 지도 이동 중이면 타이머 리셋
      _mapMoveTimer?.cancel();
      _mapMoveTimer = Timer(const Duration(milliseconds: 500), () {
        _handleMapMoveComplete();
      });
    }
  }

  // 지도 이동 완료 후 처리
  Future<void> _handleMapMoveComplete() async {
    if (_isUpdatingPosts) return; // 이미 업데이트 중이면 스킵
    
    final currentCenter = _mapController?.camera.center;
    if (currentCenter == null) return;
    
    // 이전 위치와 거리 계산 (100m 이상 이동했을 때만 업데이트)
    if (_lastMapCenter != null) {
      final distance = _calculateDistance(_lastMapCenter!, currentCenter);
      if (distance < 100) return; // 100m 미만 이동은 무시
    }
    
    _isUpdatingPosts = true;
    
    try {
      // 현재 포그레벨 1단계 타일들 계산
      final currentFogLevel1Tiles = await _getCurrentFogLevel1Tiles(currentCenter);
      
      // 포그레벨 1단계 타일이 변경되었을 때만 포스트 업데이트
      if (!_areTileSetsEqual(_lastFogLevel1Tiles, currentFogLevel1Tiles)) {
        print('🔄 포그레벨 1단계 타일 변경 감지 - 포스트 업데이트');
        
        // 현재 위치 업데이트
        setState(() {
          _currentPosition = currentCenter;
        });
        
        // 포스트 새로고침
        await _loadMarkers();
        
        // 포그레벨 업데이트
        await _updateFogOfWar();
        
        // 🚀 포그레벨 변경 감지 및 포스트 필터링
        await _updatePostsBasedOnFogLevel();
        
        // 마지막 상태 저장
        _lastMapCenter = currentCenter;
        _lastFogLevel1Tiles = currentFogLevel1Tiles;
      }
    } catch (e) {
      print('지도 이동 후 포스트 업데이트 실패: $e');
    } finally {
      _isUpdatingPosts = false;
    }
  }

  // 현재 위치의 포그레벨 1단계 타일들 계산
  Future<Set<String>> _getCurrentFogLevel1Tiles(LatLng center) async {
    try {
      final surroundingTiles = TileUtils.getSurroundingTiles(center.latitude, center.longitude);
      final fogLevel1Tiles = <String>{};
      
      for (final tileId in surroundingTiles) {
        final fogLevel = await VisitTileService.getFogLevelForTile(
          tileId, 
          currentPosition: center
        );
        
        if (fogLevel == 1) {
          fogLevel1Tiles.add(tileId);
        }
      }
      
      return fogLevel1Tiles;
    } catch (e) {
      print('포그레벨 1단계 타일 계산 실패: $e');
      return {};
    }
  }

  // 두 타일 세트가 같은지 비교
  bool _areTileSetsEqual(Set<String> set1, Set<String> set2) {
    if (set1.length != set2.length) return false;
    return set1.every((tile) => set2.contains(tile));
  }

  // 🚀 포그레벨 변경 감지 및 포스트 필터링
  Future<void> _updatePostsBasedOnFogLevel() async {
    if (_currentPosition == null) return;

    try {
      // 주변 타일들의 포그레벨 계산
      final surroundingTiles = TileUtils.getSurroundingTiles(
        _currentPosition!.latitude, 
        _currentPosition!.longitude
      );
      
      final newTileFogLevels = <String, int>{};
      final fogLevel1Tiles = <String>{};
      
      for (final tileId in surroundingTiles) {
        final fogLevel = await VisitTileService.getFogLevelForTile(
          tileId, 
          currentPosition: _currentPosition!
        );
        
        newTileFogLevels[tileId] = fogLevel;
        if (fogLevel == 1) {
          fogLevel1Tiles.add(tileId);
        }
      }
      
      // 포그레벨 변경 감지
      bool fogLevelChanged = false;
      for (final tileId in surroundingTiles) {
        final oldLevel = _tileFogLevels[tileId] ?? 0;
        final newLevel = newTileFogLevels[tileId] ?? 0;
        
        if (oldLevel != newLevel) {
          fogLevelChanged = true;
          print('🔄 타일 $tileId 포그레벨 변경: $oldLevel → $newLevel');
        }
      }
      
      if (fogLevelChanged) {
        print('🔄 포그레벨 변경 감지 - 포스트 필터링 업데이트');
        
        // 포그레벨 캐시 업데이트
        _tileFogLevels = newTileFogLevels;
        
        // 포스트 필터링 업데이트
        await _filterPostsByFogLevel(fogLevel1Tiles);
      }
      
    } catch (e) {
      print('포그레벨 변경 감지 실패: $e');
    }
  }

  // 포그레벨에 따른 포스트 필터링
  Future<void> _filterPostsByFogLevel(Set<String> fogLevel1Tiles) async {
    try {
      // 모든 활성 포스트 조회 (캐시된 데이터 사용)
      final allPosts = await PostService().getAllActivePosts(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
      );
      
      // 슈퍼포스트도 조회
      final superPosts = await PostService().getSuperPostsInRadius(
        location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
        radiusInKm: _maxDistance / 1000.0,
      );
      
      // 포스트 필터링
      final filteredMarkers = <MarkerData>[];
      final newVisiblePostIds = <String>{};
      
      // 일반 포스트 필터링 (포그레벨 1단계만)
      for (final post in allPosts) {
        if (post.tileId != null && fogLevel1Tiles.contains(post.tileId)) {
          filteredMarkers.add(MarkerData(
            id: post.flyerId,
            title: post.title,
            description: post.description,
            userId: post.creatorId,
            position: LatLng(post.location.latitude, post.location.longitude),
            createdAt: post.createdAt,
            expiryDate: post.expiresAt,
            data: post.toFirestore(),
            isCollected: post.isCollected,
            collectedBy: post.collectedBy,
            collectedAt: post.collectedAt,
            type: MarkerType.post,
          ));
          newVisiblePostIds.add(post.flyerId);
        }
      }
      
      // 슈퍼포스트는 항상 표시
      for (final post in superPosts) {
        filteredMarkers.add(MarkerData(
          id: post.flyerId,
          title: post.title,
          description: post.description,
          userId: post.creatorId,
          position: LatLng(post.location.latitude, post.location.longitude),
          createdAt: post.createdAt,
          expiryDate: post.expiresAt,
          data: post.toFirestore(),
          isCollected: post.isCollected,
          collectedBy: post.collectedBy,
          collectedAt: post.collectedAt,
          type: MarkerType.superPost,
        ));
        newVisiblePostIds.add(post.flyerId);
      }
      
      // 표시 상태 변경 감지
      final addedPosts = newVisiblePostIds.difference(_visiblePostIds);
      final removedPosts = _visiblePostIds.difference(newVisiblePostIds);
      
      if (addedPosts.isNotEmpty) {
        print('📌 새로 표시된 포스트: ${addedPosts.length}개');
      }
      if (removedPosts.isNotEmpty) {
        print('🙈 숨겨진 포스트: ${removedPosts.length}개');
      }
      
      setState(() {
        _markers = filteredMarkers;
        _visiblePostIds = newVisiblePostIds;
      });
      
      _updateMarkers();
      
    } catch (e) {
      print('포스트 필터링 실패: $e');
    }
  }

  // 🚀 포그레벨 확인 후 롱프레스 메뉴 표시
  Future<void> _checkFogLevelAndShowMenu(LatLng point) async {
    try {
      // 해당 위치의 포그레벨 확인
      final tileId = TileUtils.getTileId(point.latitude, point.longitude);
      
      print('🔍 포그레벨 확인 시작:');
      print('  - 롱프레스 위치: ${point.latitude}, ${point.longitude}');
      print('  - 현재 위치: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      print('  - 타일 ID: $tileId');
      
      final fogLevel = await VisitTileService.getFogLevelForTile(
        tileId, 
        currentPosition: _currentPosition ?? point
      );
      
      print('🔍 롱프레스 위치 포그레벨: $fogLevel (타일: $tileId)');
      
      if (fogLevel == 1) {
        // 포그레벨 1단계: 배포 가능
        print('✅ 포그레벨 1단계 - 정상 배포 메뉴 표시');
        _showLongPressMenu();
      } else if (fogLevel == 2) {
        // 포그레벨 2단계: 회색 영역 - 제한된 배포
        print('⚠️ 포그레벨 2단계 - 제한된 배포 메뉴 표시');
        _showRestrictedLongPressMenu();
      } else {
        // 포그레벨 3단계: 검은 영역 - 배포 불가
        print('🚫 포그레벨 3단계 - 배포 불가 메뉴 표시');
        _showBlockedLongPressMessage();
      }
      
    } catch (e) {
      print('❌ 포그레벨 확인 실패: $e');
      // 오류 시 기본 메뉴 표시
      print('🔄 오류로 인해 기본 배포 메뉴 표시');
      _showLongPressMenu();
    }
  }

  // 제한된 배포 메뉴 표시
  void _showRestrictedLongPressMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ 제한된 영역'),
          content: const Text(
            '이 영역은 회색 영역입니다.\n'
            '포스트 배포가 제한됩니다.\n\n'
            '집, 가게, 현재 위치 주변의 밝은 영역에서만 배포가 가능합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 배포 불가 메시지 표시
  void _showBlockedLongPressMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🚫 배포 불가'),
          content: const Text(
            '이 영역은 검은 영역입니다.\n'
            '포스트 배포가 불가능합니다.\n\n'
            '집, 가게, 현재 위치 주변의 밝은 영역에서만 배포가 가능합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  // 포그레벨 업데이트 메서드
  Future<void> _updateFogOfWar() async {
    if (_currentPosition == null) return;
    
    try {
      // OSM 기반 포그레벨 업데이트
      await _updateOSMFogOfWar();
    } catch (e) {
      print('포그레벨 업데이트 실패: $e');
    }
  }

  // OSM 기반 포그레벨 업데이트
  Future<void> _updateOSMFogOfWar() async {
    if (_currentPosition == null) return;

    try {
      // OSM 포그 서비스 사용
      final osmFogService = OSMFogService();
      await osmFogService.updateFogOfWar(
        currentPosition: _currentPosition!,
        homeLocation: _homeLocation,
        workLocations: _workLocations,
      );

      // 포그레벨 업데이트 후 UI 갱신
      setState(() {
        // 포그레벨 상태 업데이트 (실제 구현에 따라 조정)
      });
    } catch (e) {
      print('OSM 포그레벨 업데이트 실패: $e');
    }
  }

  // 마커 상세 정보 표시
  void _showMarkerDetails(MarkerData marker) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(marker.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설명: ${marker.description}'),
              const SizedBox(height: 8),
              Text('생성자: ${marker.userId}'),
              const SizedBox(height: 8),
              Text('생성일: ${marker.createdAt}'),
              if (marker.expiryDate != null) ...[
                const SizedBox(height: 8),
                Text('만료일: ${marker.expiryDate}'),
              ],
              const SizedBox(height: 8),
              Text('타입: ${marker.type == MarkerType.superPost ? "슈퍼포스트" : "일반포스트"}'),
            ],
          ),
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

  void _updateMarkers() {
    final markers = <Marker>[];
    
    // 포스트 마커들 - 포스트 타입에 따라 다른 색상
    for (final marker in _markers) {
      Color markerColor;
      IconData markerIcon;
      
      if (marker.type == MarkerType.superPost) {
        // 🚀 슈퍼포스트: 금색
        markerColor = Colors.amber;
        markerIcon = Icons.star;
      } else {
        // 일반 포스트: 파란색
        markerColor = Colors.blue;
        markerIcon = Icons.location_on;
      }
      
      markers.add(
        Marker(
          point: marker.position,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showMarkerDetails(marker),
            child: Container(
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                markerIcon,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    // 일반 마커들 (파란색) - 모든 사용자에게 보임
    for (final marker in _markers) {
      final position = marker.position;
      
      // 거리 확인
      if (_currentPosition != null) {
        final distance = _calculateDistance(_currentPosition!, position);
        if (distance > _maxDistance) continue;
      }
      
      final markerWidget = Marker(
      point: position,
        width: 35,
        height: 35,
      child: GestureDetector(
          onTap: () => _showMarkerDetail(marker),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/ppam_work.png',
                width: 31,
                height: 31,
                fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
      
      markers.add(markerWidget);
    }

    // 사용자 마커들을 별도 리스트로 업데이트
    _updateUserMarkers();

    setState(() {
      _clusteredMarkers = markers;
    });
  }

  void _updateUserMarkers() {
    final userMarkers = <Marker>[];
    
    // 사용자 마커들 (초록색) - 배포자만 회수 가능
    for (final markerData in _userMarkers) {
      final position = markerData.position;
      
      // 거리 확인
      if (_currentPosition != null) {
        final distance = _calculateDistance(_currentPosition!, position);
        if (distance > _maxDistance) continue;
      }
      
      final markerWidget = Marker(
        point: position,
        width: 35,
        height: 35,
        child: GestureDetector(
          onTap: () => _showUserMarkerDetail(markerData),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.place,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      );
      
      userMarkers.add(markerWidget);
    }

    setState(() {
      _userMarkerWidgets = userMarkers;
      _userMarkersUI = userMarkers;
    });
  }

  void _showUserMarkerDetail(MarkerData marker) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = marker.userId == currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들 바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 마커 정보
                    Text(
                marker.title,
                style: const TextStyle(
                  fontSize: 20,
                        fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              if (marker.description.isNotEmpty) ...[
                Text(
                  marker.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
              ],
              
              // 배치자 정보
              Text(
                '배치자: ${marker.userId}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                '배치일: ${marker.createdAt.toString().split(' ')[0]}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // 액션 버튼들
              if (isOwner) ...[
                // 배포자만 회수 가능
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _collectMarker(marker),
                    icon: const Icon(Icons.delete),
                    label: const Text('마커 회수'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ] else ...[
                // 타겟 사용자는 수집 가능
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _collectMarker(marker),
                    icon: const Icon(Icons.check),
                    label: const Text('마커 수집'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // 닫기 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              child: const Text('닫기'),
                ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Future<void> _collectMarker(MarkerData marker) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final isOwner = marker.userId == currentUserId;

      if (isOwner) {
        // 배포자: 마커 삭제
        await MarkerService.deleteMarker(marker.id);
          ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마커가 회수되었습니다')),
        );
      } else {
        // 타겟 사용자: 마커 수집
        await MarkerService.collectMarker(marker.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마커를 수집했습니다')),
        );
      }

      Navigator.pop(context); // 상세 화면 닫기
    } catch (e) {
      print('마커 처리 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 처리 실패: $e')),
        );
    }
  }

  void _showMarkerDetail(MarkerData marker) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = marker.userId == currentUserId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(marker.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('설명: ${marker.description}'),
            Text('생성일: ${marker.createdAt.toString().split(' ')[0]}'),
            if (marker.expiryDate != null)
              Text('만료일: ${marker.expiryDate!.toString().split(' ')[0]}'),
            if (isOwner) 
              Text('배포자: 본인', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
              if (isOwner)
                TextButton(
                  onPressed: () {
                Navigator.pop(context);
                _deleteMarker(marker);
              },
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteMarker(MarkerData marker) async {
    try {
      await MarkerService.deleteMarker(marker.id);
      _loadMarkers(); // 마커 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커가 삭제되었습니다.')),
          );
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 삭제 중 오류가 발생했습니다: $e')),
      );
    }
  }

  bool _matchesFilter(PostModel post) {
    // 쿠폰만 보기 필터
    if (_showCouponsOnly && !post.canUse) return false;
    
    // 내 포스트만 보기 필터
    if (_showMyPostsOnly) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || post.creatorId != currentUser.uid) return false;
    }
    
    // 카테고리 필터 (현재는 모든 포스트 허용)
    if (_selectedCategory != 'all') {
      // 카테고리 필터링 로직 구현
    }
    
    // 리워드 필터
    if (post.reward < _minReward) return false;
    
    return true;
  }


  void _showPostDetail(PostModel post) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = post.creatorId == currentUserId;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('리워드: ${post.reward}원'),
            Text('설명: ${post.description}'),
            Text('만료일: ${post.expiresAt.toString().split(' ')[0]}'),
            if (isOwner)
              Text('배포자: 본인', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          if (isOwner)
              TextButton(
                onPressed: () {
                Navigator.pop(context);
                _removePost(post); // Only owner can remove
              },
              child: const Text('회수', style: TextStyle(color: Colors.red)),
            )
          else
              TextButton(
                onPressed: () {
                Navigator.pop(context);
                _collectPost(post); // Others can collect
              },
              child: const Text('수집'),
            ),
        ],
      ),
    );
  }

  Future<void> _collectPost(PostModel post) async {
    try {
      await PostService().collectPost(
        postId: post.flyerId, 
        userId: FirebaseAuth.instance.currentUser!.uid
      );
      _loadPosts(); // 포스트 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 수집했습니다!')),
          );
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 수집 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _removePost(PostModel post) async {
    try {
      await PostService().deletePost(post.flyerId);
      _loadPosts(); // 포스트 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 회수했습니다!')),
          );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
      );
    }
  }

    void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
            children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '필터 설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 필터 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
            children: [
                    const SizedBox(height: 20),
                    // 일반/쿠폰 토글
                    Row(
                      children: [
                        const Text('포스트 타입:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
          child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'all'),
            child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                                      color: _selectedCategory == 'all' ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '전체',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'coupon'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                                      color: _selectedCategory == 'coupon' ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                                    child: const Text(
                                      '쿠폰만',
                  textAlign: TextAlign.center,
                                      style: TextStyle(
                color: Colors.white,
                                        fontWeight: FontWeight.w500,
              ),
            ),
          ),
                ),
              ),
            ],
          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 거리 슬라이더
                    Row(
                      children: [
                        const Text('거리:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text('${_maxDistance.toInt()}m', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Slider(
                                value: _maxDistance,
                                min: 100,
                                max: 5000,
                                divisions: 49,
                                onChanged: (value) {
                setState(() {
                                    _maxDistance = value;
                });
              },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 리워드 슬라이더
                    Row(
                      children: [
                        const Text('최소 리워드:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text('${_minReward}원', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Slider(
                                value: _minReward.toDouble(),
                                min: 0,
                                max: 10000,
                                divisions: 100,
                                onChanged: (value) {
    setState(() {
                                    _minReward = value.toInt();
                                  });
                                },
            ),
          ],
        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 정렬 옵션
                    Row(
          children: [
                        const Text('정렬:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '가까운순',
                                      textAlign: TextAlign.center,
              style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                                      color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                                    child: const Text(
                                      '최신순',
                  textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                ),
              ),
            ),
                ),
              ),
            ],
          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 하단 버튼들
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                onPressed: () {
                        Navigator.pop(context);
                        _resetFilters();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                onPressed: () {
                        Navigator.pop(context);
                        _updateMarkers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('적용'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _resetFilters() {
    setState(() {
      _selectedCategory = 'all';
      _maxDistance = 10000.0; // 10km로 확장
      _minReward = 0;
      _showCouponsOnly = false;
      _showMyPostsOnly = false;
    });
    _updateMarkers();
  }

  Future<void> _navigateToPostPlace() async {
    // 위치 기반 포스트 배포 화면으로 이동
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
        'location': _longPressedLatLng,
        'type': 'location',
    });
    
    // 포스트 배포 완료 후 마커 새로고침
    if (result != null) {
      print('포스트 배포 완료: $result');
      await _loadMarkers(); // 마커 목록 새로고침
    setState(() {
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
    }
  }

  Future<void> _navigateToPostAddress() async {
    // 주소 기반 포스트 배포 화면으로 이동
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
        'location': _longPressedLatLng,
        'type': 'address',
    });
    
    // 포스트 배포 완료 후 롱프레스 위치 유지
    if (result != null) {
      print('포스트 배포 완료: $result');
    setState(() {
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
    }
  }

  Future<void> _navigateToPostBusiness() async {
    // 업종 기반 포스트 배포 화면으로 이동
    final result = await Navigator.pushNamed(context, '/post-deploy', arguments: {
        'location': _longPressedLatLng,
        'type': 'category',
    });
    
    // 포스트 배포 완료 후 롱프레스 위치 유지
    if (result != null) {
      print('포스트 배포 완료: $result');
    setState(() {
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
    }
  }

  void _showLongPressMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들 바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 제목
              const Text(
                '포스트 배포',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // 설명
              const Text(
                '이 위치에 포스트를 배포하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // 메뉴 옵션들
              Expanded(
                child: Column(
                  children: [
                    // 이 위치에 뿌리기
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPostPlace();
                        },
                        icon: const Icon(Icons.location_on, color: Colors.white),
                        label: const Text(
                          '이 위치에 뿌리기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4D4DFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 이 주소에 뿌리기
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPostAddress();
                        },
                        icon: const Icon(Icons.home, color: Colors.white),
                        label: const Text(
                          '이 주소에 뿌리기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 근처 업종에 뿌리기
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPostBusiness();
                        },
                        icon: const Icon(Icons.business, color: Colors.white),
                        label: const Text(
                          '근처 업종에 뿌리기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // 취소 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _onMapReady() {
    // 현재 위치로 지도 이동
    if (_currentPosition != null) {
      _mapController?.move(_currentPosition!, _currentZoom);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(_degreesToRadians(point1.latitude)) * sin(_degreesToRadians(point2.latitude)) * 
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  @override
  void dispose() {
    _mapMoveTimer?.cancel(); // 타이머 정리
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GestureDetector(
            onSecondaryTapDown: (TapDownDetails details) {
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final localPosition = renderBox.globalToLocal(details.globalPosition);
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
            child: FlutterMap(
              mapController: _mapController,
        options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(37.5665, 126.9780), // 서울 기본값
                initialZoom: _currentZoom,
          onMapReady: _onMapReady,
                onMapEvent: _onMapMoved, // 🚀 지도 이동 감지
                onTap: (tapPosition, point) {
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                onLongPress: (tapPosition, point) async {
                  setState(() {
                    _longPressedLatLng = point;
                  });
                  
                  // 🚀 임시로 포그레벨 확인 비활성화 - 기본 배포 메뉴 표시
                  print('🔍 롱프레스 위치: ${point.latitude}, ${point.longitude}');
                  _showLongPressMenu();
                  
                  // TODO: 포그레벨 확인 로직 수정 후 활성화
                  // await _checkFogLevelAndShowMenu(point);
                },
              ),
        children: [
                // 기본 OSM 타일
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.ppamalpha.app',
                ),
                // 회색 영역들 (과거 방문 위치)
                PolygonLayer(polygons: _grayPolygons),
                // Fog of War 마스크 (전세계 검정 + 1km 원형 홀)
                PolygonLayer(polygons: _fogPolygons),
                // 1km 경계선
                CircleLayer(circles: _ringCircles),
                // 사용자 위치 마커들
                MarkerLayer(
                  markers: [
                    // 집 위치 마커
                    if (_homeLocation != null)
                      Marker(
                        point: _homeLocation!,
             child: Container(
               decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.home,
                 color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    // 일터 위치 마커들
                    ..._workLocations.map((workLocation) => Marker(
                      point: workLocation,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.work,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )),
                  ],
                ),
                // 현재 위치 마커
                MarkerLayer(markers: _currentMarkers),
                // Firebase 마커들 (포스트 + 사용자 생성 마커)
                MarkerLayer(markers: _clusteredMarkers),
                // 사용자 마커
                MarkerLayer(markers: _userMarkersUI),
                // 롱프레스 마커
              if (_longPressedLatLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _longPressedLatLng!,
                  width: 40,
                  height: 40,
                        child: _customMarkerIcon ??
                            const Icon(
                              Icons.add_location,
                      color: Colors.blue,
                              size: 40,
                  ),
                        ),
                      ],
                    ),
                      ],
                    ),
          ),
          // 에러 메시지
          if (_errorMessage != null)
           Positioned(
              top: 50,
              left: 16,
              right: 16,
             child: Container(
                padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          // 로딩 인디케이터
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          // 필터 버튼들 (상단)
          Positioned(
            top: 60,
            left: 16,
            right: 16,
               child: Row(
                 children: [
                // 내 포스트 필터
                Expanded(
                  child: FilterChip(
                    label: const Text('내 포스트'),
                    selected: _showMyPostsOnly,
                    onSelected: (selected) {
                      setState(() {
                        _showMyPostsOnly = selected;
                        if (selected) _showCouponsOnly = false;
                      });
                      _updateMarkers();
                    },
                    selectedColor: Colors.blue.withOpacity(0.2),
                    checkmarkColor: Colors.blue,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _showMyPostsOnly ? Colors.blue : Colors.grey.shade300,
                    ),
                  ),
                   ),
                   const SizedBox(width: 8),
                // 쿠폰 필터
                Expanded(
                  child: FilterChip(
                    label: const Text('쿠폰'),
                    selected: _showCouponsOnly,
                    onSelected: (selected) {
                      setState(() {
                        _showCouponsOnly = selected;
                        if (selected) _showMyPostsOnly = false;
                      });
                      _updateMarkers();
                    },
                    selectedColor: Colors.green.withOpacity(0.2),
                    checkmarkColor: Colors.green,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _showCouponsOnly ? Colors.green : Colors.grey.shade300,
                    ),
                  ),
                   ),
                   const SizedBox(width: 8),
                // 필터 초기화 버튼
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                     ),
                 ],
               ),
                  child: IconButton(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ),
          // 현위치 버튼 (우하단)
           Positioned(
            bottom: 80,
            right: 16,
             child: Container(
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                     ),
                 ],
               ),
              child: IconButton(
              onPressed: () {
                  if (_currentPosition != null) {
                    _mapController?.move(_currentPosition!, _currentZoom);
                  }
                },
                icon: const Icon(Icons.my_location, color: Colors.blue),
                iconSize: 24,
              ),
            ),
          ),
        ],
      ),
            ),
        ],
      ),
    );
  }
}
 