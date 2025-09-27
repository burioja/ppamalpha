import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/marker_layer_widget.dart';
import '../../post_system/controllers/post_deployment_controller.dart';
// OSM 기반 Fog of War 시스템
import '../services/external/osm_fog_service.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../widgets/fog_overlay_widget.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/location/location_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/models/map/fog_level.dart';

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
  List<Polygon> _grayPolygons = []; // 회색 영역들 (과거 방문 위치)
  List<CircleMarker> _ringCircles = [];
  List<Marker> _currentMarkers = [];
  
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
  List<MarkerModel> _markers = []; // 새로운 마커 모델 사용
  bool _isLoading = false;
  String? _errorMessage;
  
  // 필터 관련
  bool _showFilter = false;
  String _selectedCategory = 'all';
  double _maxDistance = 1000.0; // 기본 1km, 유료회원 3km
  int _minReward = 0;
  bool _showCouponsOnly = false;
  bool _showMyPostsOnly = false;
  bool _isPremiumUser = false; // 유료 사용자 여부
  
  // 실시간 업데이트 관련
  Timer? _mapMoveTimer;
  LatLng? _lastMapCenter;
  Set<String> _lastFogLevel1Tiles = {};
  bool _isUpdatingPosts = false;
  String? _lastCacheKey; // 캐시 키 기반 스킵용
  
  // 로컬 포그레벨 1 타일 캐시 (즉시 반영용)
  Set<String> _currentFogLevel1TileIds = {};
  
  // 포그레벨 변경 감지 관련
  Map<String, int> _tileFogLevels = {}; // 타일별 포그레벨 캐시
  Set<String> _visiblePostIds = {}; // 현재 표시 중인 포스트 ID들
  
  
  // 클러스터링 관련
  List<Marker> _clusteredMarkers = [];
  bool _isClustered = false;
  static const double _clusterRadius = 50.0; // 픽셀 단위
  
  // 위치 이동 관련
  int _currentWorkplaceIndex = 0; // 현재 일터 인덱스

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _initializeLocation();
    _loadCustomMarker();
    _loadUserLocations();
    _setupUserDataListener();
    _setupMarkerListener();
    // _checkPremiumStatus()와 _setupPostStreamListener()는 _getCurrentLocation()에서 호출됨
    
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
  }


  // 유료 사용자 상태 확인
  Future<void> _checkPremiumStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final isPremium = userData?['isPremium'] ?? false;
        
        setState(() {
          _isPremiumUser = isPremium;
          _maxDistance = isPremium ? 3000.0 : 1000.0; // 유료: 3km, 무료: 1km
        });
        
        print('💰 유료 사용자 상태: $_isPremiumUser, 검색 반경: ${_maxDistance}m');
      }
    } catch (e) {
      print('유료 사용자 상태 확인 실패: $e');
    }
  }


  // 🚀 마커 서비스 리스너 설정 (포스트 조회 제거)
  void _setupPostStreamListener() {
    if (_currentPosition == null) {
      print('❌ _setupPostStreamListener: _currentPosition이 null입니다');
      return;
    }

    print('🚀 마커 서비스 리스너 설정 시작');
    print('📍 현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    print('💰 유료 사용자: $_isPremiumUser');
    print('📏 검색 반경: ${_maxDistance}m (${_maxDistance / 1000.0}km)');

    // 새로운 구조: MarkerService에서 직접 마커 조회
    _updatePostsBasedOnFogLevel();
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
      print('📍 현재 위치 요청 중...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print('✅ 현재 위치 획득 성공: ${position.latitude}, ${position.longitude}');
      print('   - 정확도: ${position.accuracy}m');
      print('   - 고도: ${position.altitude}m');
      print('   - 속도: ${position.speed}m/s');
      
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
      final tileId = TileUtils.getKm1TileId(newPosition.latitude, newPosition.longitude);
      print('   - 타일 ID: $tileId');
      await VisitTileService.updateCurrentTileVisit(tileId);
      
      // 즉시 반영 (렌더링용 메모리 캐시)
      _setLevel1TileLocally(tileId);
      
      // 유료 상태 확인 후 포스트 스트림 설정
      await _checkPremiumStatus();
      
      // 🚀 실시간 포스트 스트림 리스너 설정 (위치 확보 후)
      _setupPostStreamListener();
      
      // 추가로 마커 조회 강제 실행 (위치 기반으로 더 정확하게)
      print('🚀 위치 설정 완료 후 마커 조회 강제 실행');
      setState(() {
        _isLoading = true;
      });
      _updatePostsBasedOnFogLevel();
      
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


  /// 모든 위치를 반환하는 메서드 (현재 위치, 집, 근무지)

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

    setState(() {
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

  // 🚀 Firestore 기반 실시간 마커 로드 (제거됨 - _setupPostStreamListener로 대체)

  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (_currentPosition == null) return;
    
    // 로딩 상태는 짧게만 표시
    if (forceRefresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // 새로운 구조: MarkerService에서 직접 마커 조회
      await _updatePostsBasedOnFogLevel();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '마커를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }


  // 🚀 실시간 업데이트: 지도 이동 감지 및 포스트 새로고침
  void _onMapMoved(MapEvent event) {
    if (event is MapEventMove || event is MapEventMoveStart) {
      // 지도 이동 중이면 타이머 리셋 (디바운스 시간 증가)
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
    
    // 캐시 키 기반 스킵 로직
    final newCacheKey = _generateCacheKeyForLocation(currentCenter);
    if (newCacheKey == _lastCacheKey) {
      print('🔄 동일 타일 위치 - 마커 업데이트 스킵');
      return;
    }
    
    // 이전 위치와 거리 계산 (200m 이상 이동했을 때만 업데이트)
    if (_lastMapCenter != null) {
      final distance = _calculateDistance(_lastMapCenter!, currentCenter);
      if (distance < 200) return; // 200m 미만 이동은 무시
    }
    
    _isUpdatingPosts = true;
    
    try {
      print('🔄 지도 이동 감지 - 마커 업데이트 시작');
        
        // 현재 위치는 GPS에서만 업데이트 (맵센터로 업데이트하지 않음)
        
      // 🚀 서버 API를 통한 마커 조회
        await _updatePostsBasedOnFogLevel();
        
        // 마지막 상태 저장
        _lastMapCenter = currentCenter;
      _lastCacheKey = newCacheKey;
      
    } catch (e) {
      print('지도 이동 후 포스트 업데이트 실패: $e');
    } finally {
      _isUpdatingPosts = false;
    }
  }
  
  // 위치 기반 캐시 키 생성 (1km 그리드 스냅)
  String _generateCacheKeyForLocation(LatLng location) {
    final lat = (location.latitude * 1000).round() / 1000; // 1km 그리드 스냅
    final lng = (location.longitude * 1000).round() / 1000;
    return '${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}';
  }

  // 현재 위치의 포그레벨 1단계 타일들 계산
  Future<Set<String>> _getCurrentFogLevel1Tiles(LatLng center) async {
    try {
      final surroundingTiles = TileUtils.getKm1SurroundingTiles(center.latitude, center.longitude);
      final fogLevel1Tiles = <String>{};
      
      print('🔍 포그레벨 1단계 타일 계산 시작:');
      print('  - 중심 위치: ${center.latitude}, ${center.longitude}');
      print('  - 주변 타일 개수: ${surroundingTiles.length}');
      print('  - 주변 타일 목록: $surroundingTiles');
      print('  - 로컬 캐시 타일 개수: ${_currentFogLevel1TileIds.length}');
      
      for (final tileId in surroundingTiles) {
        // 로컬 캐시 우선 확인 (즉시 반영된 타일)
        if (_currentFogLevel1TileIds.contains(tileId)) {
          fogLevel1Tiles.add(tileId);
          print('    ✅ 로컬 캐시에서 발견 - 포그레벨 1 추가');
          continue;
        }
        
        final tileCenter = TileUtils.getKm1TileCenter(tileId);
        final distToCenterKm = _calculateDistance(center, tileCenter);
        
        // 타일 반대각선 절반(대략적) + 1km 원 교차 근사
        final tileBounds = TileUtils.getKm1TileBounds(tileId);
        final halfDiagKm = _approxTileHalfDiagonalKm(tileBounds);
        
        print('  - 타일 $tileId: 중심거리 ${distToCenterKm.toStringAsFixed(2)}km, 반대각선 ${halfDiagKm.toStringAsFixed(2)}km');
        
        if (distToCenterKm <= (1.0 + halfDiagKm)) {
          // 원과 타일이 겹친다고 간주
          fogLevel1Tiles.add(tileId);
          print('    ✅ 1km+버퍼 이내 - 포그레벨 1 추가');
        } else {
          // 1km 밖은 방문 기록 확인
          final fogLevel = await VisitTileService.getFogLevelForTile(tileId);
          print('    🔍 1km+버퍼 밖 - 포그레벨: $fogLevel');
          if (fogLevel == FogLevel.gray) { // clear 체크 제거
            fogLevel1Tiles.add(tileId);
            print('    ✅ 방문 기록 있음 - 포그레벨 1 추가');
          }
        }
      }
      
      print('✅ 최종 포그레벨 1 타일 개수: ${fogLevel1Tiles.length}');
      return fogLevel1Tiles;
    } catch (e) {
      print('포그레벨 1단계 타일 계산 실패: $e');
      return {};
    }
  }

  /// 타일 반대각선 절반 길이 계산 (km)
  double _approxTileHalfDiagonalKm(Map<String, double> bounds) {
    final center = LatLng(
      (bounds['minLat']! + bounds['maxLat']!) / 2, 
      (bounds['minLng']! + bounds['maxLng']!) / 2
    );
    final corner = LatLng(bounds['maxLat']!, bounds['maxLng']!);
    final diag = _calculateDistance(center, corner) * 2; // center→corner*2 ≈ 전체 대각선
    return diag / 2.0;
  }

  /// 방금 방문한 타일을 로컬에 즉시 반영
  void _setLevel1TileLocally(String tileId) {
    setState(() {
      _currentFogLevel1TileIds.add(tileId);
    });
    print('🚀 타일 $tileId 로컬에 즉시 반영됨');
  }

  // 두 타일 세트가 같은지 비교
  bool _areTileSetsEqual(Set<String> set1, Set<String> set2) {
    if (set1.length != set2.length) return false;
    return set1.every((tile) => set2.contains(tile));
  }

  // GPS 활성화 요청 다이얼로그
  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('위치 서비스 필요'),
            ],
          ),
          content: const Text(
            '지도에서 마커를 보려면 GPS를 활성화해주세요.\n\n'
            '설정 > 개인정보 보호 및 보안 > 위치 서비스에서\n'
            '앱의 위치 권한을 허용해주세요.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _getCurrentLocation(); // 위치 다시 요청
              },
              child: const Text('다시 시도'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('나중에'),
            ),
          ],
        );
      },
    );
  }

  // 🚀 서버 API를 통한 마커 조회
  Future<void> _updatePostsBasedOnFogLevel() async {
    // 위치가 없으면 GPS 활성화 요청
    if (_currentPosition == null) {
      _showLocationPermissionDialog();
      return;
    }
    
    final centers = <LatLng>[];
    centers.add(_currentPosition!);
    print('📍 현재 위치: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    
    // 집주소 추가
    if (_homeLocation != null) {
      centers.add(_homeLocation!);
      print('🏠 집주소: ${_homeLocation!.latitude}, ${_homeLocation!.longitude}');
    }
    
    // 등록한 일터들 추가
    centers.addAll(_workLocations);
    for (int i = 0; i < _workLocations.length; i++) {
      print('🏢 일터${i + 1}: ${_workLocations[i].latitude}, ${_workLocations[i].longitude}');
    }
    
    print('🎯 총 ${centers.length}개의 기준점에서 마커 검색');

    try {
      print('🔍 _updatePostsBasedOnFogLevel 호출됨');

      // 2. 필터 설정
      final filters = <String, dynamic>{
        'showCouponsOnly': _showCouponsOnly,
        'myPostsOnly': _showMyPostsOnly,
        'minReward': _minReward,
      };

      // 3. 서버에서 일반 포스트와 슈퍼포스트를 병렬로 조회
      final primaryCenter = centers.first; // 첫 번째 중심점 사용
      final additionalCenters = centers.skip(1).toList(); // 나머지는 추가 중심점
      
      print('🔍 서버 호출 시작:');
      print('  - 주 중심점: ${primaryCenter.latitude}, ${primaryCenter.longitude}');
      print('  - 추가 중심점: ${additionalCenters.length}개');
      print('  - 반경: ${_maxDistance / 1000.0}km');
      
      final futures = await Future.wait([
        // 일반 포스트 조회
        MarkerService.getMarkers(
          location: primaryCenter,
          radiusInKm: _maxDistance / 1000.0, // km로 변환
          additionalCenters: additionalCenters,
          filters: filters,
          pageSize: 500,
        ),
        // 슈퍼포스트 조회
        MarkerService.getSuperPosts(
          location: primaryCenter,
          radiusInKm: _maxDistance / 1000.0,
          additionalCenters: additionalCenters,
          pageSize: 200,
        ),
      ]);

      final normalMarkers = futures[0] as List<MapMarkerData>;
      final superMarkers = futures[1] as List<MapMarkerData>;
      
      print('📍 서버 응답:');
      print('  - 일반 포스트: ${normalMarkers.length}개');
      print('  - 슈퍼포스트: ${superMarkers.length}개');
      
      // 🔥 Fail-open: 마커가 없으면 경고 메시지
      if (normalMarkers.isEmpty && superMarkers.isEmpty) {
        print('⚠️ 마커가 없습니다! 가능한 원인:');
        print('  - 위치 권한 문제');
        print('  - 서버 필터가 너무 강함');
        print('  - 포그레벨 1 타일이 없음');
        print('  - Firestore 데이터 없음');
      }

      // 4. 모든 마커를 합치고 중복 제거
      final allMarkers = <MapMarkerData>[];
      final seenMarkerIds = <String>{};
      
      // 일반 포스트 추가
      for (final marker in normalMarkers) {
        if (!seenMarkerIds.contains(marker.id)) {
          allMarkers.add(marker);
          seenMarkerIds.add(marker.id);
        }
      }
      
      // 슈퍼포스트 추가
      for (final marker in superMarkers) {
        if (!seenMarkerIds.contains(marker.id)) {
          allMarkers.add(marker);
          seenMarkerIds.add(marker.id);
        }
      }

      // 5. MarkerData를 MarkerModel로 변환
      final uniqueMarkers = allMarkers.map((markerData) => 
        MarkerService.convertToMarkerModel(markerData)
      ).toList();

      // 6. 포스트 정보도 함께 가져오기
      final postIds = uniqueMarkers.map((marker) => marker.postId).toSet().toList();
      final posts = <PostModel>[];
      
      if (postIds.isNotEmpty) {
        try {
          final postSnapshots = await FirebaseFirestore.instance
              .collection('posts')
              .where('postId', whereIn: postIds)
              .get();
          
          for (final doc in postSnapshots.docs) {
            try {
              final post = PostModel.fromFirestore(doc);
              posts.add(post);
            } catch (e) {
              print('포스트 파싱 오류: $e');
            }
          }
          
          print('📄 포스트 정보 조회 완료: ${posts.length}개');
        } catch (e) {
          print('❌ 포스트 정보 조회 실패: $e');
        }
      }

      setState(() {
        _markers = uniqueMarkers;
        _posts = posts; // 포스트 정보도 업데이트
        _isLoading = false;
        print('✅ _updatePostsBasedOnFogLevel: 총 ${_markers.length}개의 고유 마커, ${_posts.length}개의 포스트 업데이트됨');
        _updateMarkers(); // 마커 업데이트 후 지도 마커도 업데이트
      });
      
    } catch (e, stackTrace) {
      print('❌ _updatePostsBasedOnFogLevel 오류: $e');
      print('📚 스택 트레이스: $stackTrace');
      
      // 🔥 Fail-open: 에러 발생 시에도 기본 마커라도 표시
      print('🔄 에러 발생 - 기본 마커 표시 시도');
      
      setState(() {
        _isLoading = false;
        _errorMessage = '마커를 불러오는 중 오류가 발생했습니다: $e';
        
        // 에러 발생 시 빈 마커 리스트로 설정 (무한 로딩 방지)
        _markers = [];
        _updateMarkers();
      });
    }
  }

  // 포그레벨에 따른 마커 필터링
  Future<void> _filterPostsByFogLevel(Set<String> fogLevel1Tiles) async {
    try {
      // 새로운 구조: MarkerService에서 직접 마커 조회
      await _updatePostsBasedOnFogLevel();
      
    } catch (e) {
      print('마커 필터링 실패: $e');
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
      
      final fogLevel = await VisitTileService.getFogLevelForTile(tileId);
      
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
      await osmFogService.updateFogOfWar(_currentPosition!);

      // 포그레벨 업데이트 후 UI 갱신
      setState(() {
        // 포그레벨 상태 업데이트 (실제 구현에 따라 조정)
      });
    } catch (e) {
      print('OSM 포그레벨 업데이트 실패: $e');
    }
  }

  // 마커 상세 정보 표시
  void _showMarkerDetails(MarkerModel marker) {
    // 거리 체크
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보를 가져올 수 없습니다')),
      );
      return;
    }

    final distance = _calculateDistance(_currentPosition!, marker.position);
    final isWithinRange = distance <= 100; // 100m 이내
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && marker.creatorId == currentUser.uid;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(marker.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('포스트 ID: ${marker.postId}'),
              const SizedBox(height: 8),
              Text('수량: ${marker.quantity}개'),
              const SizedBox(height: 8),
              Text('거리: ${distance.toStringAsFixed(0)}m'),
              const SizedBox(height: 8),
              Text('생성자: ${marker.creatorId}'),
              const SizedBox(height: 8),
              Text('생성일: ${marker.createdAt}'),
              if (marker.expiresAt != null) ...[
                const SizedBox(height: 8),
                Text('만료일: ${marker.expiresAt}'),
              ],
              if (isOwner) ...[
                const SizedBox(height: 8),
                const Text(
                  '내가 배포한 포스트',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ],
              if (!isWithinRange) ...[
                const SizedBox(height: 8),
                Text(
                  '수령 불가: 100m 이내에서만 수령 가능합니다',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (isOwner) ...[
              // 배포자는 회수 버튼
              TextButton(
                onPressed: () => _removeMarker(marker),
                child: const Text('회수하기', style: TextStyle(color: Colors.red)),
              ),
            ] else             if (isWithinRange && marker.quantity > 0) ...[
              // 다른 사용자는 수령 버튼
              TextButton(
                onPressed: () => _collectPostFromMarker(marker),
                child: Text('수령하기 (${marker.quantity}개 남음)'),
              ),
            ] else if (marker.quantity <= 0) ...[
              // 수량 소진
              const Text(
                '수령 완료',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        );
      },
    );
  }


  // 마커에서 포스트 수령
  Future<void> _collectPostFromMarker(MarkerModel marker) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      // 수량 확인
      if (marker.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수령 가능한 수량이 없습니다')),
        );
        return;
      }

      await PostService().collectPost(
        postId: marker.postId,
        userId: user.uid,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트를 수령했습니다! (${marker.quantity - 1}개 남음)')),
      );
      Navigator.of(context).pop(); // 다이얼로그 닫기
      _updatePostsBasedOnFogLevel(); // 마커 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  void _updateMarkers() {
    print('🔧 _updateMarkers 호출됨 - _markers 개수: ${_markers.length}');
    final markers = <Marker>[];
    
    // 새로운 마커 모델 사용
    for (final marker in _markers) {
      print('📍 마커 생성: ${marker.title} at (${marker.position.latitude}, ${marker.position.longitude}) - 수량: ${marker.quantity}');
      
      // ✅ 조인 제거: 마커에서 직접 reward 사용 (배포 시점 고정)
      final int markerReward = marker.reward;
      
      // 가격대에 따라 다른 이미지 사용
      final String imagePath = markerReward >= 1000 
          ? 'assets/images/ppam_super.png'  // 천원 이상은 슈퍼포스트 이미지
          : 'assets/images/ppam_work.png';  // 천원 미만은 일반 이미지
      
      print('💰 마커 ${marker.title}: 가격 ${markerReward}원 -> ${markerReward >= 1000 ? "슈퍼포스트" : "일반포스트"} 이미지 사용');
      print('🔍 디버그: marker.postId=${marker.postId}, marker.reward=${markerReward}, imagePath=$imagePath');
      
      markers.add(
        Marker(
          key: ValueKey(marker.markerId),
          point: marker.position,
          width: 35,
          height: 35,
          child: GestureDetector(
            onTap: () => _showMarkerDetails(marker),
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
                  imagePath,
                  width: 31,
                  height: 31,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
    }


    print('🎯 최종 마커 개수: ${markers.length}개');
    setState(() {
      _clusteredMarkers = markers;
    });
    print('✅ _clusteredMarkers 업데이트 완료: ${_clusteredMarkers.length}개');
    
    if (_clusteredMarkers.isEmpty) {
      print('⚠️ 경고: _clusteredMarkers가 비어있습니다!');
    } else {
      print('✅ 마커가 정상적으로 표시됩니다.');
    }
    print('✅ _clusteredMarkers 업데이트 완료: ${_clusteredMarkers.length}개');
    
    // 디버깅: 마커 상세 정보 출력
    for (int i = 0; i < _clusteredMarkers.length && i < 3; i++) {
      final marker = _clusteredMarkers[i];
      print('🎯 마커 $i: ${marker.key?.toString() ?? "key없음"} at (${marker.point.latitude}, ${marker.point.longitude})');
    }
  }



  Future<void> _collectMarker(MarkerModel marker) async {
    // TODO: 새로운 구조에 맞게 구현 예정
    print('마커 수집: ${marker.title}');
  }

  void _showMarkerDetail(MarkerModel marker) {
    // TODO: 새로운 구조에 맞게 구현 예정
    print('마커 상세: ${marker.title}');
  }

  // 마커 회수 (삭제)
  Future<void> _removeMarker(MarkerModel marker) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      // 배포자 확인
      if (marker.creatorId != user.uid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자신이 배포한 포스트만 회수할 수 있습니다')),
        );
        return;
      }

      // 확인 다이얼로그
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('포스트 회수'),
          content: const Text('이 포스트를 회수하시겠습니까? 회수된 포스트는 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('회수', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // 마커와 포스트 모두 삭제
      await PostService().deletePost(marker.postId);
      
      // 마커도 삭제 (markers 컬렉션에서)
      await MarkerService.deleteMarker(marker.markerId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 회수했습니다')),
      );
      
      Navigator.of(context).pop(); // 다이얼로그 닫기
      _updatePostsBasedOnFogLevel(); // 마커 목록 새로고침
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
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
        postId: post.postId, 
        userId: FirebaseAuth.instance.currentUser!.uid
      );
      // 🚀 실시간 스트림이 자동으로 업데이트되므로 별도 새로고침 불필요
      // _loadPosts(forceRefresh: true); // 포스트 목록 새로고침
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
      await PostService().deletePost(post.postId);
      // 🚀 실시간 스트림이 자동으로 업데이트되므로 별도 새로고침 불필요
      // _loadPosts(forceRefresh: true); // 포스트 목록 새로고침
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
                    // 거리 표시 (유료/무료에 따라)
                    Row(
                      children: [
                        const Text('검색 반경:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isPremiumUser ? Colors.amber[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isPremiumUser ? Colors.amber[200]! : Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_maxDistance.toInt()}m',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isPremiumUser ? Colors.amber[800] : Colors.blue,
                                ),
                              ),
                              if (_isPremiumUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[600],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
      _maxDistance = _isPremiumUser ? 3000.0 : 1000.0; // 유료: 3km, 무료: 1km
      _minReward = 0;
      _showCouponsOnly = false;
      _showMyPostsOnly = false;
    });
    _updateMarkers();
  }

  Future<void> _navigateToPostPlace() async {
    if (_longPressedLatLng == null) return;

    // PostDeploymentController를 사용한 위치 기반 포스트 배포
    final success = await PostDeploymentController.deployPostFromLocation(context, _longPressedLatLng!);

    // 포스트 배포 완료 후 처리
    if (success) {
      print('포스트 배포 완료');
      // 🚀 배포 완료 후 즉시 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
      
      // 마커 즉시 업데이트
      await _updatePostsBasedOnFogLevel();
      
      // 데이터베이스 반영을 위해 충분한 시간 대기 후 다시 한 번 업데이트
      await Future.delayed(const Duration(milliseconds: 1500));
      await _updatePostsBasedOnFogLevel();
      
      // 마지막으로 한 번 더 업데이트 (확실하게)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 배포를 취소한 경우 롱프레스 위치 초기화
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  Future<void> _navigateToPostAddress() async {
    if (_longPressedLatLng == null) return;

    // PostDeploymentController를 사용한 주소 기반 포스트 배포
    final success = await PostDeploymentController.deployPostFromAddress(context, _longPressedLatLng!);

    // 포스트 배포 완료 후 처리
    if (success) {
      print('포스트 배포 완료');
      // 🚀 배포 완료 후 즉시 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
      
      // 마커 즉시 업데이트
      await _updatePostsBasedOnFogLevel();
      
      // 데이터베이스 반영을 위해 충분한 시간 대기 후 다시 한 번 업데이트
      await Future.delayed(const Duration(milliseconds: 1500));
      await _updatePostsBasedOnFogLevel();
      
      // 마지막으로 한 번 더 업데이트 (확실하게)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 배포를 취소한 경우 롱프레스 위치 초기화
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  Future<void> _navigateToPostBusiness() async {
    if (_longPressedLatLng == null) return;

    // PostDeploymentController를 사용한 카테고리 기반 포스트 배포
    final success = await PostDeploymentController.deployPostFromCategory(context, _longPressedLatLng!);

    // 포스트 배포 완료 후 처리
    if (success) {
      print('포스트 배포 완료');
      // 🚀 배포 완료 후 즉시 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
      
      // 마커 즉시 업데이트
      await _updatePostsBasedOnFogLevel();
      
      // 데이터베이스 반영을 위해 충분한 시간 대기 후 다시 한 번 업데이트
      await Future.delayed(const Duration(milliseconds: 1500));
      await _updatePostsBasedOnFogLevel();
      
      // 마지막으로 한 번 더 업데이트 (확실하게)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 배포를 취소한 경우 롱프레스 위치 초기화
      setState(() {
        _longPressedLatLng = null;
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

  // 집으로 이동
  void _moveToHome() {
    if (_homeLocation != null) {
      _mapController?.move(_homeLocation!, _currentZoom);
    }
  }

  // 일터로 이동 (순차적으로)
  void _moveToWorkplace() {
    if (_workLocations.isNotEmpty) {
      final targetLocation = _workLocations[_currentWorkplaceIndex];
      _mapController?.move(targetLocation, _currentZoom);
      
      // 다음 일터로 인덱스 이동 (순환)
      setState(() {
        _currentWorkplaceIndex = (_currentWorkplaceIndex + 1) % _workLocations.length;
      });
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
                  // 롱프레스 위치만 저장하고 마커는 표시하지 않음
                  _longPressedLatLng = point;
                  
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
                // Fog of War 오버레이 (겹침 문제 해결)
                FogOverlayWidget(
                  mapController: _mapController!,
                  holeCenters: [
                    if (_currentPosition != null) _currentPosition!,
                    if (_homeLocation != null) _homeLocation!,
                    ..._workLocations,
                  ],
                  radiusMeters: 1000.0,
                  fogColor: Colors.black.withOpacity(1.0),
                ),
                // 1km 경계선 (제거됨 - 파란색 원 테두리 없음)
                // CircleLayer(circles: _ringCircles),
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
                      ],
                    ),
          ),
          // 로딩 인디케이터
          if (_isLoading)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    const Text('마커를 불러오는 중...'),
                  ],
                ),
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
            top: 10,
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
          // 위치 이동 버튼들 (우하단)
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              children: [
                // 집 버튼
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                    onPressed: _homeLocation != null ? _moveToHome : null,
                    icon: Icon(
                      Icons.home, 
                      color: _homeLocation != null ? Colors.green : Colors.grey,
                    ),
                    iconSize: 24,
                  ),
                ),
                // 일터 버튼
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                    onPressed: _workLocations.isNotEmpty ? _moveToWorkplace : null,
                    icon: Icon(
                      Icons.work, 
                      color: _workLocations.isNotEmpty ? Colors.orange : Colors.grey,
                    ),
                    iconSize: 24,
                  ),
                ),
                // 현재 위치 버튼
                Container(
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
                    onPressed: () async {
                      try {
                        await _getCurrentLocation();
                      } catch (e) {
                        print('현위치 버튼 오류: $e');
                      }
                    },
                    icon: const Icon(Icons.my_location, color: Colors.blue),
                    iconSize: 24,
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
 