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
import '../../../core/models/user/user_model.dart';  // UserModel과 UserType 추가
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/marker_service.dart';  // MarkerService 추가
import '../../../core/services/data/user_service.dart';  // UserService 추가
import '../../../core/constants/app_constants.dart';
import '../services/markers/marker_service.dart';
import '../../../core/models/marker/marker_model.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/marker_layer_widget.dart';
import '../utils/client_cluster.dart';
import '../widgets/cluster_widgets.dart';
import '../../post_system/controllers/post_deployment_controller.dart';
import '../../../core/services/osm_geocoding_service.dart';
import '../../post_system/widgets/address_search_dialog.dart';
// OSM 기반 Fog of War 시스템
import '../services/external/osm_fog_service.dart';
import '../services/fog_of_war/visit_tile_service.dart';
import '../widgets/unified_fog_overlay_widget.dart';
import '../../../core/services/location/nominatim_service.dart';
import '../../../core/services/location/location_service.dart';
import '../../../utils/tile_utils.dart';
import '../../../core/models/map/fog_level.dart';
import '../models/receipt_item.dart';
import '../widgets/receive_carousel.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart' as audio;

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
  final VoidCallback? onNavigateToInbox;
  
  const MapScreen({super.key, this.onAddressChanged, this.onNavigateToInbox});
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OSM 기반 Fog of War 상태
  List<Polygon> _grayPolygons = []; // 회색 영역들 (과거 방문 위치)
  List<CircleMarker> _ringCircles = [];
  List<Marker> _currentMarkers = [];
  
  // 클러스터링 관련 변수들
  List<Marker> _clusteredMarkers = [];
  Size _lastMapSize = const Size(0, 0);
  LatLng _mapCenter = const LatLng(37.5665, 126.9780); // 서울 기본값
  double _mapZoom = 10.0;
  
  // 새로운 클러스터링 시스템용 변수들
  Timer? _clusterDebounceTimer;
  List<ClusterMarkerModel> _visibleMarkerModels = [];
  
  // 사용자 위치 정보
  LatLng? _homeLocation;
  List<LatLng> _workLocations = [];
  
  // 기본 상태
  MapController? _mapController;
  LatLng? _currentPosition;
  double _currentZoom = 14.0;
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
  bool _showUrgentOnly = false; // 마감임박 필터 추가
  bool _showVerifiedOnly = false; // 인증 포스트만 필터 추가
  bool _showUnverifiedOnly = false; // 미인증 포스트만 필터 추가
  bool _isPremiumUser = false; // 유료 사용자 여부
  UserType _userType = UserType.normal; // 사용자 타입 추가
  
  // 실시간 업데이트 관련
  Timer? _mapMoveTimer;
  LatLng? _lastMapCenter;
  Set<String> _lastFogLevel1Tiles = {};
  bool _isUpdatingPosts = false;

  // 포스트 수령 관련
  int _receivablePostCount = 0;
  bool _isReceiving = false;
  String? _lastCacheKey; // 캐시 키 기반 스킵용
  
  // 로컬 포그레벨 1 타일 캐시 (즉시 반영용)
  Set<String> _currentFogLevel1TileIds = {};
  DateTime? _fogLevel1CacheTimestamp;
  static const Duration _fogLevel1CacheExpiry = Duration(minutes: 5); // 5분 후 캐시 만료
  
  // 포그레벨 변경 감지 관련
  Map<String, int> _tileFogLevels = {}; // 타일별 포그레벨 캐시
  Set<String> _visiblePostIds = {}; // 현재 표시 중인 포스트 ID들
  
  
  // 클러스터링 관련
  bool _isClustered = false;
  static const double _clusterRadius = 50.0; // 픽셀 단위
  
  // 위치 이동 관련
  int _currentWorkplaceIndex = 0; // 현재 일터 인덱스
  
  // Mock 위치 관련 상태
  bool _isMockModeEnabled = false;
  bool _isMockControllerVisible = false;
  LatLng? _mockPosition;
  LatLng? _originalGpsPosition; // 원래 GPS 위치 백업
  LatLng? _previousMockPosition; // 이전 Mock 위치 (회색 영역 표시용)
  LatLng? _previousGpsPosition; // 이전 GPS 위치 (회색 영역 표시용)

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _initializeLocation();
    _loadCustomMarker();
    _loadUserLocations();
    _setupUserDataListener();
    _setupMarkerListener();
    _updateReceivablePosts(); // 수령 가능 포스트 개수 초기화
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
          
          // 사용자 타입 로드
          final userModel = UserModel.fromFirestore(snapshot);
          if (mounted) {
            setState(() {
              _userType = userModel.userType;
              _isPremiumUser = userModel.userType == UserType.superSite;
            });
          }
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

        if (mounted) {
          setState(() {
            _isPremiumUser = isPremium;
            _maxDistance = isPremium ? 3000.0 : 1000.0; // 유료: 3km, 무료: 1km
          });
        }

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
          if (mounted) {
            setState(() {
              _errorMessage = '위치 권한이 거부되었습니다.';
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _errorMessage = '위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
          });
        }
        return;
      }

      await _getCurrentLocation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '위치를 가져오는 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    // Mock 모드가 활성화되어 있으면 GPS 위치 요청하지 않음
    if (_isMockModeEnabled && _mockPosition != null) {
      print('🎭 Mock 모드 활성화 - GPS 위치 요청 스킵');
      return;
    }
    
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

      // 이전 GPS 위치 저장 (회색 영역 표시용)
      final previousGpsPosition = _currentPosition;

      if (mounted) {
        setState(() {
          _currentPosition = newPosition;
          _errorMessage = null;
        });
      }

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
      
      // 회색 영역 업데이트 (이전 위치 포함)
      _updateGrayAreasWithPreviousPosition(previousGpsPosition);
      
      // 유료 상태 확인 후 포스트 스트림 설정
      await _checkPremiumStatus();
      
      // 🚀 실시간 포스트 스트림 리스너 설정 (위치 확보 후)
      _setupPostStreamListener();
      
      // 추가로 마커 조회 강제 실행 (위치 기반으로 더 정확하게)
      print('🚀 위치 설정 완료 후 마커 조회 강제 실행');
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      _updatePostsBasedOnFogLevel();
      
      // 현재 위치 마커 생성
      _createCurrentLocationMarker(newPosition);
      
      // 지도 중심 이동
      _mapController?.move(newPosition, _currentZoom);

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '현재 위치를 가져올 수 없습니다: $e';
        });
      }
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

        if (mounted) {
          setState(() {
            _currentMarkers = [marker];
          });
        }
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

    if (mounted) {
      setState(() {
        _ringCircles = ringCircles;
      });
    }

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

        // ===== 집 주소 로드 =====
        final homeLocation = userData?['homeLocation'] as GeoPoint?;
        final secondAddress = userData?['secondAddress'] as String?;

        if (homeLocation != null) {
          // 저장된 GeoPoint 직접 사용 (geocoding 불필요)
          debugPrint('✅ 집주소 좌표 로드: ${homeLocation.latitude}, ${homeLocation.longitude}');
          if (secondAddress != null && secondAddress.isNotEmpty) {
            debugPrint('   상세주소: $secondAddress');
          }
          if (mounted) {
            setState(() {
              _homeLocation = LatLng(homeLocation.latitude, homeLocation.longitude);
            });
          }
        } else {
          // 구버전 데이터: 주소 문자열만 있는 경우 (geocoding 시도)
          final address = userData?['address'] as String?;
          debugPrint('⚠️ 집주소 좌표 미저장 (구버전 데이터)');
          debugPrint('   주소: $address');

          if (address != null && address.isNotEmpty) {
            final homeCoords = await NominatimService.geocode(address);
            if (homeCoords != null) {
              debugPrint('✅ geocoding 성공: ${homeCoords.latitude}, ${homeCoords.longitude}');
              if (mounted) {
                setState(() {
                  _homeLocation = homeCoords;
                });
              }
            } else {
              debugPrint('❌ geocoding 실패 - 프로필에서 주소를 다시 설정하세요');
            }
          } else {
            debugPrint('❌ 집주소 정보 없음');
          }
        }

        // ===== 일터 주소 로드 =====
        final workplaceId = userData?['workplaceId'] as String?;
        final workLocations = <LatLng>[];

        if (workplaceId != null && workplaceId.isNotEmpty) {
          debugPrint('📍 일터 로드 시도: $workplaceId');

          // places 컬렉션에서 일터 정보 가져오기
          final placeDoc = await FirebaseFirestore.instance
              .collection('places')
              .doc(workplaceId)
              .get();

          if (placeDoc.exists) {
            final placeData = placeDoc.data();
            final workLocation = placeData?['location'] as GeoPoint?;

            if (workLocation != null) {
              // 저장된 GeoPoint 직접 사용
              debugPrint('✅ 일터 좌표 로드: ${workLocation.latitude}, ${workLocation.longitude}');
              workLocations.add(LatLng(workLocation.latitude, workLocation.longitude));
            } else {
              // 구버전: 주소만 있는 경우 geocoding 시도
              final workAddress = placeData?['address'] as String?;
              debugPrint('⚠️ 일터 좌표 미저장 (구버전 데이터)');
              debugPrint('   주소: $workAddress');

              if (workAddress != null && workAddress.isNotEmpty) {
                final workCoords = await NominatimService.geocode(workAddress);
                if (workCoords != null) {
                  debugPrint('✅ geocoding 성공: ${workCoords.latitude}, ${workCoords.longitude}');
                  workLocations.add(workCoords);
                } else {
                  debugPrint('❌ geocoding 실패');
                }
              }
            }
          } else {
            debugPrint('❌ 일터 정보 없음 (placeId: $workplaceId)');
          }
        } else {
          debugPrint('일터 미설정');
        }

        if (mounted) {
          setState(() {
            _workLocations = workLocations;
          });
        }

        debugPrint('최종 일터 좌표 개수: ${workLocations.length}');
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

      // 30일 이내 방문 기록 가져오기 (올바른 컬렉션 경로 사용)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final visitedTiles = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final visitedPositions = <LatLng>[];
      
      for (final doc in visitedTiles.docs) {
        final tileId = doc.id;
        // 타일 ID에서 좌표 추출
        final position = _extractPositionFromTileId(tileId);
        if (position != null) {
          visitedPositions.add(position);
        }
      }

      print('과거 방문 위치 개수: ${visitedPositions.length}');
      
      // 회색 영역 생성
      final grayPolygons = OSMFogService.createGrayAreas(visitedPositions);

      if (mounted) {
        setState(() {
          _grayPolygons = grayPolygons;
        });
      }

    } catch (e) {
      debugPrint('방문 위치 로드 실패: $e');
    }
  }

  // 타일 ID에서 좌표 추출하는 헬퍼 메서드
  LatLng? _extractPositionFromTileId(String tileId) {
    try {
      if (tileId.startsWith('tile_')) {
        // 1km 근사 그리드 형식: tile_lat_lng
        final parts = tileId.split('_');
        if (parts.length == 3) {
          final tileLat = int.tryParse(parts[1]);
          final tileLng = int.tryParse(parts[2]);
          if (tileLat != null && tileLng != null) {
            const double tileSize = 0.009;
            return LatLng(
              tileLat * tileSize + (tileSize / 2),
              tileLng * tileSize + (tileSize / 2),
            );
          }
        }
      }
      return null;
    } catch (e) {
      print('타일 ID에서 좌표 추출 실패: $e');
      return null;
    }
  }

  Future<void> _updateCurrentAddress() async {
    if (_currentPosition == null) return;
    
    try {
      final address = await NominatimService.reverseGeocode(_currentPosition!);
      if (mounted) {
        setState(() {
          _currentAddress = address;
        });
      }

      // 상위 위젯에 주소 전달
      widget.onAddressChanged?.call(address);
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = '주소 변환 실패';
        });
      }
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


  // 맵 상태 업데이트 (클러스터링용)
  void _updateMapState() {
    if (_mapController != null) {
      final camera = _mapController!.camera;
      _mapCenter = camera.center;
      _mapZoom = camera.zoom;
      
      // 화면 크기 업데이트 (MediaQuery 사용)
      final size = MediaQuery.of(context).size;
      _lastMapSize = size;
      
      // 클러스터링 디바운스 타이머
      _clusterDebounceTimer?.cancel();
      _clusterDebounceTimer = Timer(const Duration(milliseconds: 32), _rebuildClusters);
    }
  }

  // 🚀 실시간 업데이트: 지도 이동 감지 및 마커 새로고침
  void _onMapMoved(MapEvent event) {
    // 맵 상태 업데이트
    _updateMapState();
    
    if (event is MapEventMove || event is MapEventMoveStart) {
      // 지도 이동 중이면 타이머 리셋 (디바운스 시간 증가)
      _mapMoveTimer?.cancel();
      _mapMoveTimer = Timer(const Duration(milliseconds: 500), () {
        _handleMapMoveComplete();
      });
      
      // 실시간으로 수령 가능 마커 개수 업데이트
      _updateReceivablePosts();
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
      
      // 🔥 위치 이동 시 1단계 타일 캐시 초기화 (중요한 수정!)
      print('🧹 지도 이동 감지 - 1단계 타일 캐시 초기화');
      _clearFogLevel1Cache();
    }
    
    _isUpdatingPosts = true;
    
    try {
      print('🔄 지도 이동 감지 - 마커 업데이트 시작');
        
        // 현재 위치는 GPS에서만 업데이트 (맵센터로 업데이트하지 않음)
        
      // 🚀 서버 API를 통한 마커 조회
        await _updatePostsBasedOnFogLevel();
        
        // 수령 가능 포스트 개수 업데이트
        _updateReceivablePosts();
        
        // 마지막 상태 저장
        _lastMapCenter = currentCenter;
      _lastCacheKey = newCacheKey;
      
    } catch (e) {
      print('지도 이동 후 포스트 업데이트 실패: $e');
    } finally {
      _isUpdatingPosts = false;
    }
  }
  
  // 위치 기반 캐시 키 생성 - 주변 타일들도 고려하여 개선
  String _generateCacheKeyForLocation(LatLng location) {
    // 현재 위치의 1km 타일 ID
    final currentTileId = TileUtils.getKm1TileId(location.latitude, location.longitude);
    
    // 주변 1단계 타일들도 캐시 키에 포함 (정확도 향상)
    final surroundingTiles = TileUtils.getKm1SurroundingTiles(location.latitude, location.longitude);
    final tileIds = surroundingTiles.take(9).toList(); // 3x3 그리드만 고려
    
    // 타일 ID들을 정렬하여 일관된 캐시 키 생성
    tileIds.sort();
    final tileKey = tileIds.join('_');
    
    return 'fog_${currentTileId}_${tileKey.hashCode}';
  }

  // 현재 위치의 포그레벨 1단계 타일들 계산 - 개선된 로직
  Future<Set<String>> _getCurrentFogLevel1Tiles(LatLng center) async {
    try {
      // 🔥 캐시 만료 확인 및 초기화
      _checkAndClearExpiredFogLevel1Cache();
      
      final surroundingTiles = TileUtils.getKm1SurroundingTiles(center.latitude, center.longitude);
      final fogLevel1Tiles = <String>{};
      
      print('🔍 포그레벨 1+2단계 타일 계산 시작 (개선된 로직):');
      print('  - 중심 위치: ${center.latitude}, ${center.longitude}');
      print('  - 주변 타일 개수: ${surroundingTiles.length}');
      print('  - 로컬 캐시 타일 개수: ${_currentFogLevel1TileIds.length}');
      
      for (final tileId in surroundingTiles) {
        final tileCenter = TileUtils.getKm1TileCenter(tileId);
        final distToCenterKm = _calculateDistance(center, tileCenter);
        
        // 타일의 실제 크기 계산 (정확한 반지름)
        final tileBounds = TileUtils.getKm1TileBounds(tileId);
        final tileRadiusKm = _calculateTileRadiusKm(tileBounds);
        
        print('  - 타일 $tileId: 중심거리 ${distToCenterKm.toStringAsFixed(2)}km, 타일반지름 ${tileRadiusKm.toStringAsFixed(2)}km');
        
        // 🔥 개선된 로직: 거리 기반 우선 판단, 로컬 캐시는 보조적으로만 사용
        if (distToCenterKm <= (1.0 + tileRadiusKm)) {
          // 1km 반지름과 타일이 겹침 - 무조건 1단계
          fogLevel1Tiles.add(tileId);
          print('    ✅ 1km+타일반지름 이내 - 포그레벨 1 추가');
          
          // 로컬 캐시에도 추가 (다음 계산 시 빠른 접근용)
          if (!_currentFogLevel1TileIds.contains(tileId)) {
            _currentFogLevel1TileIds.add(tileId);
          }
        } else {
          // 1km 밖은 방문 기록 확인 (포그레벨 2)
          final fogLevel = await VisitTileService.getFogLevelForTile(tileId);
          print('    🔍 1km+타일반지름 밖 - 포그레벨: $fogLevel');
          if (fogLevel == FogLevel.clear || fogLevel == FogLevel.gray) {
            fogLevel1Tiles.add(tileId);
            print('    ✅ 포그레벨 1+2 영역 - 마커 표시 가능');
            
            // 방문 기록이 있는 타일도 로컬 캐시에 추가
            if (!_currentFogLevel1TileIds.contains(tileId)) {
              _currentFogLevel1TileIds.add(tileId);
            }
          } else {
            // 포그레벨 3 이상이면 로컬 캐시에서 제거 (정확성 향상)
            if (_currentFogLevel1TileIds.contains(tileId)) {
              _currentFogLevel1TileIds.remove(tileId);
              print('    🗑️ 로컬 캐시에서 제거됨 (포그레벨 3 이상): $tileId');
            }
          }
        }
      }
      
      print('✅ 최종 포그레벨 1+2 타일 개수: ${fogLevel1Tiles.length}');
      
      // 🔥 캐시 계산 완료 시 타임스탬프 업데이트
      _updateFogLevel1CacheTimestamp();
      
      return fogLevel1Tiles;
    } catch (e) {
      print('포그레벨 1+2단계 타일 계산 실패: $e');
      return {};
    }
  }

  /// 타일 반지름 계산 (km) - 정확한 계산
  double _calculateTileRadiusKm(Map<String, double> bounds) {
    // 타일의 중심점
    final center = LatLng(
      (bounds['minLat']! + bounds['maxLat']!) / 2, 
      (bounds['minLng']! + bounds['maxLng']!) / 2,
    );
    
    // 타일의 네 모서리 중 가장 먼 거리 계산
    final corners = [
      LatLng(bounds['minLat']!, bounds['minLng']!), // 남서쪽
      LatLng(bounds['minLat']!, bounds['maxLng']!), // 남동쪽
      LatLng(bounds['maxLat']!, bounds['minLng']!), // 북서쪽
      LatLng(bounds['maxLat']!, bounds['maxLng']!), // 북동쪽
    ];
    
    double maxDistance = 0;
    for (final corner in corners) {
      final distance = _calculateDistance(center, corner);
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    
    return maxDistance;
  }

  /// 타일 반대각선 절반 길이 계산 (km) - 기존 호환성 유지
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


  /// 1단계 타일 캐시 초기화 (지도 이동 시 호출)
  void _clearFogLevel1Cache() {
    setState(() {
      _currentFogLevel1TileIds.clear();
      _fogLevel1CacheTimestamp = null;
    });
    print('🧹 1단계 타일 캐시 초기화 완료');
  }

  /// 1단계 타일 캐시 만료 확인 및 초기화
  void _checkAndClearExpiredFogLevel1Cache() {
    if (_fogLevel1CacheTimestamp != null) {
      final now = DateTime.now();
      if (now.difference(_fogLevel1CacheTimestamp!) > _fogLevel1CacheExpiry) {
        print('⏰ 1단계 타일 캐시 만료 - 자동 초기화');
        _clearFogLevel1Cache();
      }
    }
  }

  /// 1단계 타일 캐시 업데이트 (타임스탬프 포함)
  void _updateFogLevel1CacheTimestamp() {
    _fogLevel1CacheTimestamp = DateTime.now();
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
    // Mock 모드에서는 Mock 위치 사용, 아니면 실제 GPS 위치 사용
    LatLng? effectivePosition;
    if (_isMockModeEnabled && _mockPosition != null) {
      effectivePosition = _mockPosition;
      print('🎭 Mock 모드 - Mock 위치 사용: ${_mockPosition!.latitude}, ${_mockPosition!.longitude}');
    } else {
      effectivePosition = _currentPosition;
      print('📍 GPS 모드 - 실제 위치 사용: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    }
    
    // 위치가 없으면 GPS 활성화 요청
    if (effectivePosition == null) {
      _showLocationPermissionDialog();
      return;
    }
    
    final centers = <LatLng>[];
    centers.add(effectivePosition);
    print('📍 기준 위치: ${effectivePosition.latitude}, ${effectivePosition.longitude}');
      
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
        'showUrgentOnly': _showUrgentOnly,
        'showVerifiedOnly': _showVerifiedOnly, // 인증 필터 추가
        'showUnverifiedOnly': _showUnverifiedOnly, // 미인증 필터 추가
      };
      
      print('');
      print('🟢🟢🟢 ========== 필터 상태 확인 ========== 🟢🟢🟢');
      print('🟢 _showMyPostsOnly: $_showMyPostsOnly');
      print('🟢 _showVerifiedOnly: $_showVerifiedOnly');
      print('🟢 _showUnverifiedOnly: $_showUnverifiedOnly');
      print('🟢 _showCouponsOnly: $_showCouponsOnly');
      print('🟢 _showUrgentOnly: $_showUrgentOnly');
      print('🟢 전달되는 filters 맵: $filters');
      print('🟢🟢🟢 ====================================== 🟢🟢🟢');
      print('');

      // 3. 서버에서 일반 포스트와 슈퍼포스트를 병렬로 조회
      final primaryCenter = centers.first; // 첫 번째 중심점 사용
      final additionalCenters = centers.skip(1).toList(); // 나머지는 추가 중심점
      
      // 사용자 타입에 따른 거리 계산
      final normalRadiusKm = MarkerService.getMarkerDisplayRadius(_userType, false) / 1000.0;
      final superRadiusKm = MarkerService.getMarkerDisplayRadius(_userType, true) / 1000.0;
      
      print('🔍 서버 호출 시작:');
      print('  - 주 중심점: ${primaryCenter.latitude}, ${primaryCenter.longitude}');
      print('  - 추가 중심점: ${additionalCenters.length}개');
      print('  - 일반 포스트 반경: ${normalRadiusKm}km');
      print('  - 슈퍼포스트 반경: ${superRadiusKm}km');
      
      final futures = await Future.wait([
        // 일반 포스트 조회
        MapMarkerService.getMarkers(
          location: primaryCenter,
          radiusInKm: normalRadiusKm, // 사용자 타입에 따른 거리
          additionalCenters: additionalCenters,
          filters: filters,
          pageSize: 1000, // ✅ 제한 증가 (영역 내에서만 조회하므로)
        ),
        // 슈퍼마커 조회
        MapMarkerService.getSuperMarkers(
          location: primaryCenter,
          radiusInKm: superRadiusKm, // 슈퍼포스트는 항상 5km
          additionalCenters: additionalCenters,
          filters: filters, // ✅ 필터 전달
          pageSize: 500, // ✅ 제한 증가
        ),
      ]);

      final normalMarkers = futures[0] as List<MapMarkerData>;
      final superMarkers = futures[1] as List<MapMarkerData>;
      
      print('📍 서버 응답:');
      print('  - 일반 마커: ${normalMarkers.length}개');
      print('  - 슈퍼마커: ${superMarkers.length}개');
      
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
      
      // 슈퍼마커 추가
      for (final marker in superMarkers) {
        if (!seenMarkerIds.contains(marker.id)) {
          allMarkers.add(marker);
          seenMarkerIds.add(marker.id);
        }
      }

      // 5. MarkerData를 MarkerModel로 변환
      final uniqueMarkers = allMarkers.map((markerData) => 
        MapMarkerService.convertToMarkerModel(markerData)
      ).toList();

      // 6. 이미 수령한 포스트 필터링
      final currentUser = FirebaseAuth.instance.currentUser;
      Set<String> collectedPostIds = {};
      
      if (currentUser != null) {
        try {
          print('🔍 이미 수령한 포스트 확인 중...');
          final collectedSnapshot = await FirebaseFirestore.instance
              .collection('post_collections')
              .where('userId', isEqualTo: currentUser.uid)
              .get();
          
          collectedPostIds = collectedSnapshot.docs
              .map((doc) => doc.data()['postId'] as String)
              .toSet();
          
          print('📦 이미 수령한 포스트: ${collectedPostIds.length}개');
        } catch (e) {
          print('❌ 수령 기록 조회 실패: $e');
        }
      }
      
      // 이미 수령한 포스트의 마커 제거
      final filteredMarkers = uniqueMarkers.where((marker) {
        final isCollected = collectedPostIds.contains(marker.postId);
        if (isCollected) {
          print('🚫 이미 수령한 포스트의 마커 제거: ${marker.title} (postId: ${marker.postId})');
        }
        return !isCollected;
      }).toList();
      
      print('✅ 필터링 후 마커: ${filteredMarkers.length}개 (${uniqueMarkers.length - filteredMarkers.length}개 제거됨)');

      // 7. 포스트 정보도 함께 가져오기
      final postIds = filteredMarkers.map((marker) => marker.postId).toSet().toList();
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
        _markers = filteredMarkers;
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

  /// 현재위치, 집, 일터 주변에서 롱프레스 가능한지 확인
  bool _canLongPressAtLocation(LatLng point) {
    final maxRadius = MarkerService.getMarkerDisplayRadius(_userType, false);
    
    // Mock 모드에서는 Mock 위치를 기준으로, 아니면 실제 GPS 위치를 기준으로 확인
    LatLng? referencePosition;
    if (_isMockModeEnabled && _mockPosition != null) {
      referencePosition = _mockPosition;
    } else {
      referencePosition = _currentPosition;
    }
    
    // 기준 위치 주변 확인
    if (referencePosition != null) {
      final distanceToCurrent = MarkerService.calculateDistance(
        LatLng(referencePosition.latitude, referencePosition.longitude),
        point,
      );
      if (distanceToCurrent <= maxRadius) {
        return true;
      }
    }
    
    // 집 주변 확인
    if (_homeLocation != null) {
      final distanceToHome = MarkerService.calculateDistance(
        LatLng(_homeLocation!.latitude, _homeLocation!.longitude),
        point,
      );
      if (distanceToHome <= maxRadius) {
        return true;
      }
    }
    
    // 일터 주변 확인
    for (final workLocation in _workLocations) {
      final distanceToWork = MarkerService.calculateDistance(
        LatLng(workLocation.latitude, workLocation.longitude),
        point,
      );
      if (distanceToWork <= maxRadius) {
        return true;
      }
    }
    
    return false;
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
  void _showMarkerDetails(MarkerModel marker) async {
    // 🔍 마커 탭 시 데이터 확인
    print('[MARKER_TAP_DEBUG] 마커 탭됨:');
    print('  - markerId: "${marker.markerId}"');
    print('  - postId: "${marker.postId}"');
    print('  - title: "${marker.title}"');
    print('  - postId == markerId: ${marker.postId == marker.markerId}');

    // 거리 체크
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보를 가져올 수 없습니다')),
      );
      return;
    }

    final distance = _calculateDistance(_currentPosition!, marker.position);
    final isWithinRange = distance <= 200; // 200m 이내
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = currentUser != null && marker.creatorId == currentUser.uid;

    // 포스트 정보 가져오기 (이미지 포함)
    String imageUrl = '';
    String description = '';
    int reward = 0;
    
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(marker.postId)
          .get();
          
      if (postDoc.exists) {
        final postData = postDoc.data()!;
        final mediaUrls = postData['mediaUrl'] as List<dynamic>?;
        if (mediaUrls != null && mediaUrls.isNotEmpty) {
          imageUrl = mediaUrls.first as String;
        }
        description = postData['description'] as String? ?? '';
        reward = postData['reward'] as int? ?? 0;
      }
    } catch (e) {
      print('포스트 정보 조회 실패: $e');
    }

    // 거리가 멀면 토스트 메시지 표시
    if (!isWithinRange) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${distance.toStringAsFixed(0)}m 떨어져 있습니다. 200m 이내로 접근해주세요.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        marker.title.replaceAll(' 관련 포스트', '').replaceAll('관련 포스트', ''),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 포스트 설명
                      if (description.isNotEmpty) ...[
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // 포스트 이미지 (오버레이 배지 포함)
                      if (imageUrl.isNotEmpty) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                width: double.infinity,
                                height: MediaQuery.of(context).size.height * 0.6,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 300,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                  );
                                },
                              ),
                            ),
                            // 오버레이 배지들
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Row(
                                children: [
                                  // 수령 가능/범위 밖 배지
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isWithinRange ? Colors.green : Colors.grey,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      isWithinRange ? '수령 가능' : '범위 밖',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  // 수량 배지
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: marker.quantity > 0 ? Colors.blue : Colors.red,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${marker.quantity}개 남음',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // 내 포스트 배지 (우상단)
                            if (isOwner)
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '내 포스트',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // 포인트 배지 (좌하단)
                            if (reward > 0)
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green[400]!, Colors.green[600]!],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.monetization_on, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        '+${reward}포인트',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ] else if (description.isEmpty) ...[
                        // 이미지도 없고 설명도 없으면 기본 아이콘 표시
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.card_giftcard,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      
                    ],
                  ),
                ),
              ),
              
              // 하단 버튼
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('닫기'),
                      ),
                    ),
                    if (isOwner) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _removeMarker(marker);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '회수하기',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (isWithinRange && marker.quantity > 0) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _collectPostFromMarker(marker);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '수령하기 (${marker.quantity}개)',
                            style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ] else if (marker.quantity <= 0) ...[
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '수량 소진',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
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

      // 현재 위치 확인
      if (_currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 확인할 수 없습니다')),
        );
        return;
      }

      // 마커 수집 가능 거리 확인 (200m 이내)
      final canCollect = MarkerService.canCollectMarker(
        _currentPosition!,
        LatLng(marker.position.latitude, marker.position.longitude),
      );

      if (!canCollect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마커에서 200m 이내로 접근해주세요')),
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

      // 🔍 수령 시도 전 데이터 확인
      print('[COLLECT_DEBUG] 수령 시도:');
      print('  - markerId: "${marker.markerId}"');
      print('  - 현재 postId: "${marker.postId}"');
      print('  - postId == markerId: ${marker.postId == marker.markerId}');

      // 🚨 CRITICAL FIX: markerId로 실제 마커를 조회해서 올바른 postId 가져오기
      if (marker.postId == marker.markerId || marker.postId.isEmpty) {
        print('[COLLECT_FIX] postId가 잘못됨. markerId로 실제 마커 조회 중...');

        try {
          final markerDoc = await FirebaseFirestore.instance
              .collection('markers')
              .doc(marker.markerId)
              .get();

          if (markerDoc.exists && markerDoc.data() != null) {
            final markerData = markerDoc.data()!;
            final realPostId = markerData['postId'] as String?;

            print('[COLLECT_FIX] 실제 마커 데이터에서 postId 발견: "$realPostId"');

            if (realPostId != null && realPostId.isNotEmpty && realPostId != marker.markerId) {
              print('[COLLECT_FIX] 올바른 postId로 수령 진행: $realPostId');
              await PostService().collectPost(
                postId: realPostId,
                userId: user.uid,
              );
            } else {
              throw Exception('마커에서 유효한 postId를 찾을 수 없습니다');
            }
          } else {
            throw Exception('마커 문서를 찾을 수 없습니다: ${marker.markerId}');
          }
        } catch (e) {
          print('[COLLECT_FIX] 마커 조회 실패: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('마커 정보를 가져올 수 없습니다: $e')),
          );
          return;
        }
      } else {
        print('[COLLECT_DEBUG] 기존 postId 사용: ${marker.postId}');
      await PostService().collectPost(
        postId: marker.postId,
        userId: user.uid,
      );
      }

      // 포인트 보상 정보와 함께 성공 메시지 표시
      final reward = marker.reward ?? 0;
      final message = reward > 0
          ? '포스트를 수령했습니다! 🎉\n${reward}포인트가 지급되었습니다! (${marker.quantity - 1}개 남음)'
          : '포스트를 수령했습니다! (${marker.quantity - 1}개 남음)';

      Navigator.of(context).pop(); // 다이얼로그 먼저 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 수령 완료 후 즉시 마커 목록 새로고침
      print('🔄 마커 수령 완료 - 마커 목록 새로고침 시작');
      
      // 1. 로컬에서 같은 포스트의 모든 마커 즉시 제거 (UI 반응성)
      setState(() {
        final postId = marker.postId;
        final removedCount = _markers.where((m) => m.postId == postId).length;
        _markers.removeWhere((m) => m.postId == postId);
        print('🗑️ 같은 포스트의 모든 마커 제거: ${marker.title} (${removedCount}개 마커 제거됨)');
        print('   - postId: $postId');
        _updateMarkers(); // 클러스터 재계산
      });
      
      // 2. 서버에서 실제 마커 상태 확인 및 동기화
      await Future.delayed(const Duration(milliseconds: 500));
      await _updatePostsBasedOnFogLevel();
      _updateReceivablePosts(); // 수령 가능 개수 업데이트
      
      print('✅ 마커 목록 새로고침 완료');

      // 메인 스크린의 포인트 새로고침 (GlobalKey 사용)
      try {
        final mainScreenState = MapScreen.mapKey.currentState;
        if (mainScreenState != null) {
          // MainScreen에 포인트 새로고침 메서드가 있다면 호출
          debugPrint('📱 메인 스크린 포인트 새로고침 요청');
        }
      } catch (e) {
        debugPrint('⚠️ 메인 스크린 포인트 새로고침 실패: $e');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  void _updateMarkers() {
    print('🔧 _updateMarkers 호출됨 - _markers 개수: ${_markers.length}');

    // MarkerModel을 새로운 클러스터링 시스템용으로 변환
    _visibleMarkerModels = _markers.map((marker) => ClusterMarkerModel(
      markerId: marker.markerId,
      position: marker.position,
    )).toList();

    // 새로운 클러스터링 시스템 적용
    _rebuildClusters();
    
    // 마커 업데이트 시 수령 가능 개수도 업데이트
    _updateReceivablePosts();
  }

  // LatLng -> 화면 좌표 변환 함수
  Offset _latLngToScreen(LatLng ll) {
    return latLngToScreenWebMercator(
      ll, 
      mapCenter: _mapCenter, 
      zoom: _mapZoom, 
      viewSize: _lastMapSize,
    );
  }

  // 새로운 클러스터링 시스템 - 근접 기반
  void _rebuildClusters() {
    if (_visibleMarkerModels.isEmpty) {
      setState(() {
        _clusteredMarkers = [];
      });
      return;
    }

    final thresholdPx = clusterThresholdPx(_mapZoom);
    
    // 근접 클러스터링 수행
    final buckets = buildProximityClusters(
      source: _visibleMarkerModels,
      toScreen: _latLngToScreen,
      thresholdPx: thresholdPx,
    );

    final markers = <Marker>[];
    
    for (final bucket in buckets) {
      if (!bucket.isCluster) {
        // 단일 마커
        final marker = bucket.single!;
        final isSuper = _isSuperMarker(marker);
        final imagePath = isSuper ? 'assets/images/ppam_super.png' : 'assets/images/ppam_work.png';
        final imageSize = isSuper ? 36.0 : 31.0;
        
        // 원본 MarkerModel에서 creatorId 가져오기
        final originalMarker = _markers.firstWhere(
          (m) => m.markerId == marker.markerId,
          orElse: () => throw Exception('Marker not found'),
        );
        
      markers.add(
        Marker(
            key: ValueKey('single_${marker.markerId}'),
          point: marker.position,
          width: 35,
          height: 35,
            child: SingleMarkerWidget(
              imagePath: imagePath,
              size: imageSize,
              isSuper: isSuper,
              userId: originalMarker.creatorId,
              onTap: () => _onTapSingleMarker(marker),
            ),
          ),
        );
      } else {
        // 클러스터 마커
        final rep = bucket.representative!;
        markers.add(
          Marker(
            key: ValueKey('cluster_${rep.markerId}_${bucket.items!.length}'),
            point: rep.position,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _zoomIntoCluster(bucket),
              child: SimpleClusterDot(count: bucket.items!.length),
          ),
        ),
      );
      }
    }

    setState(() {
      _clusteredMarkers = markers;
    });

    print('🔧 근접 클러스터링 완료 (줌 ${_mapZoom.toStringAsFixed(1)}, 임계값 ${thresholdPx.toInt()}px): ${buckets.length}개 그룹, ${markers.length}개 마커');
  }

  // 슈퍼 마커인지 확인
  bool _isSuperMarker(ClusterMarkerModel marker) {
    // 원본 MarkerModel에서 reward 확인
    final originalMarker = _markers.firstWhere(
      (m) => m.markerId == marker.markerId,
      orElse: () => throw Exception('Marker not found'),
    );
    final markerReward = originalMarker.reward ?? 0;
    return markerReward >= AppConsts.superRewardThreshold;
  }

  // 단일 마커 탭 처리
  void _onTapSingleMarker(ClusterMarkerModel marker) {
    // 기존 MarkerModel을 찾아서 상세 정보 표시
    final originalMarker = _markers.firstWhere(
      (m) => m.markerId == marker.markerId,
      orElse: () => throw Exception('Marker not found'),
    );
    _showMarkerDetails(originalMarker);
  }

  // 클러스터 탭 시 확대
  void _zoomIntoCluster(ClusterOrMarker cluster) {
    final rep = cluster.representative!;
    final targetZoom = (_mapZoom + 1.5).clamp(14.0, 16.0); // 앱의 줌 범위 내에서
    _mapController?.move(rep.position, targetZoom);
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      // 배포자 확인
      if (marker.creatorId != user.uid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자신이 배포한 포스트만 회수할 수 있습니다')),
        );
        return;
      }

      debugPrint('');
      debugPrint('🟢🟢🟢 [map_screen] 회수 버튼 클릭 - 마커 정보 🟢🟢🟢');
      debugPrint('🟢 marker.markerId: ${marker.markerId}');
      debugPrint('🟢 marker.postId: ${marker.postId}');
      debugPrint('🟢 PostService().recallMarker() 호출 시작...');
      debugPrint('');

      // 개별 마커 회수 (포스트와 다른 마커는 유지)
      await PostService().recallMarker(marker.markerId);

      debugPrint('');
      debugPrint('🟢 [map_screen] PostService().recallMarker() 완료');
      debugPrint('🟢🟢🟢 ========================================== 🟢🟢🟢');
      debugPrint('');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커를 회수했습니다')),
      );
      
      // ❌ Navigator.of(context).pop() 제거 - 버튼에서 이미 닫음
      _updatePostsBasedOnFogLevel(); // 마커 목록 새로고침
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 클라이언트사이드 필터링 제거됨 - 서버사이드에서 처리
  // bool _matchesFilter(PostModel post) { ... } // 제거됨


  void _showPostDetail(PostModel post) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = post.creatorId == currentUserId;
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>?>(
        future: isOwner ? null : UserService().getUserById(post.creatorId),
        builder: (context, snapshot) {
          String creatorInfo = isOwner ? '본인' : post.creatorName;
          String creatorEmail = '';
          
          if (!isOwner && snapshot.hasData && snapshot.data != null) {
            creatorEmail = snapshot.data!['email'] ?? '';
          }
          
          return AlertDialog(
        title: Text(post.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('리워드: ${post.reward}원'),
                SizedBox(height: 8),
            Text('설명: ${post.description}'),
                SizedBox(height: 8),
            Text('기본 만료일: ${post.defaultExpiresAt.toString().split(' ')[0]}'),
                SizedBox(height: 8),
            if (isOwner)
                  Text('배포자: 본인', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                else ...[
                  Text('배포자: $creatorInfo', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  if (creatorEmail.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text('이메일: $creatorEmail', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
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
          );
        },
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

      // 효과음/진동
      await _playReceiveEffects(1);

      // 캐러셀 팝업으로 포스트 내용 표시
      await _showPostReceivedCarousel([post]);

    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 수집 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _removePost(PostModel post) async {
    try {
      // 포스트 회수 (마커도 함께 회수 처리됨)
      await PostService().recallPost(post.postId);
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

  // 포스트 수령 캐러셀 팝업
  Future<void> _showPostReceivedCarousel(List<PostModel> posts) async {
    if (posts.isEmpty) return;

    // 확인 상태 추적
    final confirmedPosts = <String>{};
    final postService = PostService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) return;

    final totalReward = posts.fold(0, (sum, post) => sum + (post.reward ?? 0));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true, // 뒤로가기/외부 터치로 닫을 수 있음 (미확인 포스트로 이동)
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        child: Column(
          children: [
            // 상단 헤더
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '${posts.length}개 포스트 수령됨 (확인 대기)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (totalReward > 0) ...[
                    SizedBox(height: 4),
                    Text(
                      '총 +${totalReward}포인트',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.green, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 캐러셀 영역
            Expanded(
              child: PageView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final isConfirmed = confirmedPosts.contains(post.postId);
                  
                  return GestureDetector(
                    onTap: () async {
                      if (isConfirmed) return; // 이미 확인한 포스트는 무시
                      
                      try {
                        // 멱등 ID로 직접 조회
                        final collectionId = '${post.postId}_$currentUserId';
                        final collectionDoc = await FirebaseFirestore.instance
                            .collection('post_collections')
                            .doc(collectionId)
                            .get();
                        
                        if (!collectionDoc.exists) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('수령 기록을 찾을 수 없습니다')),
                          );
                          return;
                        }
                        
                        final collectionData = collectionDoc.data()!;
                        final creatorId = collectionData['postCreatorId'] ?? '';
                        final reward = collectionData['reward'] ?? 0;
                        
                        // 포스트 확인 처리
                        await postService.confirmPost(
                          collectionId: collectionId,
                          userId: currentUserId,
                          postId: post.postId,
                          creatorId: creatorId,
                          reward: reward,
                        );
                        
                        // 확인 상태 업데이트
                        setState(() {
                          confirmedPosts.add(post.postId);
                        });
                        
                        // 피드백
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ 포스트 확인 완료! +${reward}포인트'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } catch (e) {
                        debugPrint('포스트 확인 실패: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('포스트 확인에 실패했습니다')),
                        );
                      }
                    },
                    child: _buildPostCarouselPage(post, index + 1, posts.length, isConfirmed),
                  );
                },
              ),
            ),
            
            // 하단 인디케이터 + 버튼
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // 페이지 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(posts.length, (index) {
                      final post = posts[index];
                      final isConfirmed = confirmedPosts.contains(post.postId);
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConfirmed ? Colors.green : Colors.grey[300],
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 12),
                  // 확인 상태 표시
                  Text(
                    '${confirmedPosts.length}/${posts.length} 확인 완료',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 항상 표시되는 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // 다이얼로그 닫기
                            // 인박스로 이동
                            if (widget.onNavigateToInbox != null) {
                              widget.onNavigateToInbox!();
                            }
                          },
                          icon: Icon(Icons.inbox),
                          label: Text('인박스 보기'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '나중에 확인',
                            style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // 캐러셀 개별 페이지 위젯
  Widget _buildPostCarouselPage(PostModel post, int currentIndex, int totalCount, bool isConfirmed) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행률 및 상태 표시
          Row(
            children: [
              Text(
                '$currentIndex/$totalCount',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmed ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConfirmed ? '✓ 확인완료' : '터치하여 확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Spacer(),
              if (totalCount > 1)
                Text(
                  '👈 스와이프',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // 포스트 제목
          Text(
            post.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: 12),
          
          // 포스트 설명
          if (post.description.isNotEmpty) ...[
            Text(
              post.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // 포스트 이미지
          if (post.mediaUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.mediaUrl.first,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // 포인트 정보
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '포인트 지급',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '+${post.reward ?? 0}포인트',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 확인 안내 (확인되지 않은 경우에만)
          if (!isConfirmed) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 24, color: Colors.orange[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '이 영역을 터치하면\n포인트를 받고 확인됩니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_upward, size: 28, color: Colors.orange[700]),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 24, color: Colors.green[700]),
                  SizedBox(width: 12),
                  Text(
                    '확인 완료!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
      _showUrgentOnly = false;
      _showVerifiedOnly = false; // 인증 필터 초기화
      _showUnverifiedOnly = false; // 미인증 필터 초기화
    });
    _updateMarkers();
  }

  // 필터 칩 빌더 헬퍼 함수
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required Color selectedColor,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected ? [
          BoxShadow(
            color: selectedColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : selectedColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : selectedColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: onSelected,
        selectedColor: selectedColor,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? selectedColor : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Future<void> _navigateToPostPlace() async {
    if (_longPressedLatLng == null) return;

    // 현재위치, 집, 일터 주변에서 배포 가능한지 확인
    final canDeploy = _canLongPressAtLocation(_longPressedLatLng!);

    if (!canDeploy) {
      // 거리 초과 시 아무 동작도 하지 않음 (사용자 경험 개선)
      return;
    }

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

    try {
      // 1. OSM에서 건물명 조회
      print('🌐 OSM에서 건물명 조회 중...');
      final buildingName = await OSMGeocodingService.getBuildingName(_longPressedLatLng!);
      
      if (buildingName == null) {
        _showToast('건물명을 찾을 수 없습니다.');
        return;
      }
      
      print('✅ 건물명 조회 성공: $buildingName');
      
      // 2. 건물명 확인 팝업
      final isCorrect = await _showBuildingNameConfirmation(buildingName);
      
      if (isCorrect) {
        // 3. 포스트 배포 화면으로 이동 (주소 모드)
        _navigateToPostDeploy('address', buildingName);
    } else {
        // 4. 주소 검색 팝업
        final selectedAddress = await _showAddressSearchDialog();
        if (selectedAddress != null) {
          _navigateToPostDeploy('address', selectedAddress['display_name']);
        }
      }
    } catch (e) {
      print('❌ 주소 배포 오류: $e');
      _showToast('주소 정보를 가져오는 중 오류가 발생했습니다.');
    }
  }

  /// 건물명 확인 팝업
  Future<bool> _showBuildingNameConfirmation(String buildingName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 확인'),
        content: Text('$buildingName이 맞습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('예'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 주소 검색 팝업
  Future<Map<String, dynamic>?> _showAddressSearchDialog() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddressSearchDialog(),
    );
  }

  /// 포스트 배포 화면으로 네비게이션
  Future<void> _navigateToPostDeploy(String type, String buildingName) async {
    final result = await Navigator.pushNamed(
      context,
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng!,
        'type': type,
        'buildingName': buildingName,
      },
    );

    if (result != null && mounted) {
      // 배포 완료 후 마커 새로고침 (인덱싱 대기: 7초)
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null;
      });
      
      print('🚀 배포 완료 - Firestore 인덱싱 대기 중 (7초)...');
      await Future.delayed(const Duration(seconds: 7));
      
      print('✅ 인덱싱 대기 완료 - 마커 조회 시작');
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 취소한 경우
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  /// 토스트 메시지 표시
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
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
                    
                    // 근처 업종에 뿌리기 (작업중)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: null, // 비활성화
                        icon: const Icon(Icons.business, color: Colors.white),
                        label: const Text(
                          '근처 업종에 뿌리기 (작업중)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey, // 회색으로 변경
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
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

  // Mock 위치 관련 메서드들
  void _toggleMockMode() {
    setState(() {
      _isMockModeEnabled = !_isMockModeEnabled;
      if (_isMockModeEnabled) {
        _isMockControllerVisible = true;
        // 원래 GPS 위치 백업
        _originalGpsPosition = _currentPosition;
        // Mock 위치가 없으면 현재 GPS 위치를 기본값으로 설정
        if (_mockPosition == null && _currentPosition != null) {
          _mockPosition = _currentPosition;
        }
      } else {
        _isMockControllerVisible = false;
        // Mock 모드 비활성화 시 원래 GPS 위치로 복원
        if (_originalGpsPosition != null) {
          _currentPosition = _originalGpsPosition;
          _mapController?.move(_originalGpsPosition!, _currentZoom);
          _createCurrentLocationMarker(_originalGpsPosition!);
          _updateCurrentAddress();
          _updatePostsBasedOnFogLevel();
        }
      }
    });
  }

  Future<void> _setMockPosition(LatLng position) async {
    // 이전 Mock 위치 저장 (회색 영역 표시용)
    final previousPosition = _mockPosition;
    
    setState(() {
      _mockPosition = position;
      // Mock 모드에서는 실제 위치도 업데이트 (실제 기능처럼 동작)
      if (_isMockModeEnabled) {
        _currentPosition = position;
      }
    });

    // Mock 위치로 지도 중심 이동 (현재 줌 레벨 유지)
    final currentZoom = _mapController?.camera.zoom ?? _currentZoom;
    _mapController?.move(position, currentZoom);
    
    // Mock 위치 마커 생성
    _createCurrentLocationMarker(position);
    
    // 주소 업데이트 (Mock 위치 기준)
    _updateMockAddress(position);
    
    // 타일 방문 기록 업데이트 (실제 기능처럼 동작)
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    print('🎭 Mock 위치 타일 방문 기록 업데이트: $tileId');
    await VisitTileService.updateCurrentTileVisit(tileId);
    _setLevel1TileLocally(tileId);
    
    // 포그 오브 워 재구성 (실제 기능처럼 동작)
    _rebuildFogWithUserLocations(position);
    
    // 회색 영역 업데이트 (이전 위치 포함)
    _updateGrayAreasWithPreviousPosition(previousPosition);
    
    // 마커 업데이트
    _updatePostsBasedOnFogLevel();
  }

  Future<void> _updateMockAddress(LatLng position) async {
    try {
      final address = await NominatimService.reverseGeocode(position);
      setState(() {
        _currentAddress = address;
      });
      widget.onAddressChanged?.call(address);
    } catch (e) {
      setState(() {
        _currentAddress = '주소 변환 실패';
      });
    }
  }

  // 화살표 방향에 따른 Mock 위치 이동
  void _moveMockPosition(String direction) async {
    if (_mockPosition == null) return;

    const double moveDistance = 0.000225; // 약 25m 이동
    LatLng newPosition;
    
    switch (direction) {
      case 'up':
        newPosition = LatLng(_mockPosition!.latitude + moveDistance, _mockPosition!.longitude);
        break;
      case 'down':
        newPosition = LatLng(_mockPosition!.latitude - moveDistance, _mockPosition!.longitude);
        break;
      case 'left':
        newPosition = LatLng(_mockPosition!.latitude, _mockPosition!.longitude - moveDistance);
        break;
      case 'right':
        newPosition = LatLng(_mockPosition!.latitude, _mockPosition!.longitude + moveDistance);
        break;
      default:
        return;
    }
    
    await _setMockPosition(newPosition);
  }

  void _hideMockController() {
    setState(() {
      _isMockControllerVisible = false;
    });
  }

  Future<void> _showMockPositionInputDialog() async {
    final latController = TextEditingController(
      text: _mockPosition?.latitude.toStringAsFixed(6) ?? '',
    );
    final lngController = TextEditingController(
      text: _mockPosition?.longitude.toStringAsFixed(6) ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mock 위치 직접 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: '위도 (Latitude)',
                hintText: '37.5665',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: '경도 (Longitude)',
                hintText: '126.9780',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '예시: 서울시청 (37.5665, 126.9780)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('이동'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final lat = double.parse(latController.text);
        final lng = double.parse(lngController.text);
        
        // 유효 범위 체크 (대략적인 한국 범위)
        if (lat < 33.0 || lat > 39.0 || lng < 124.0 || lng > 132.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('한국 범위 내의 좌표를 입력해주세요')),
          );
          return;
        }

        final newPosition = LatLng(lat, lng);
        await _setMockPosition(newPosition);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mock 위치 이동: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 숫자를 입력해주세요')),
        );
      }
    }

    latController.dispose();
    lngController.dispose();
  }

  // 통합된 회색 영역 업데이트 (DB에서 최신 방문 기록 로드)
  void _updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
    try {
      // DB에서 최신 방문 기록 로드 (서버 강제 읽기)
      final visitedPositions = await _loadVisitedPositionsFromDB();
      
      // 이전 위치도 추가 (즉시 반영용)
      if (previousPosition != null) {
        visitedPositions.add(previousPosition);
        print('🎯 이전 위치를 회색 영역으로 추가: ${previousPosition.latitude}, ${previousPosition.longitude}');
      }
      
      // 새로운 회색 영역 생성
      final grayPolygons = OSMFogService.createGrayAreas(visitedPositions);
      
      setState(() {
        _grayPolygons = grayPolygons;
      });
      
      print('✅ 회색 영역 업데이트 완료: ${visitedPositions.length}개 위치');
    } catch (e) {
      print('❌ 회색 영역 업데이트 실패: $e');
    }
  }

  // DB에서 최신 방문 기록 로드 (서버 강제 읽기)
  Future<List<LatLng>> _loadVisitedPositionsFromDB() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // 30일 이내 방문 기록 가져오기 (서버 강제 읽기)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final visitedTiles = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get(const GetOptions(source: Source.server)); // 서버 강제 읽기

      final visitedPositions = <LatLng>[];
      
      for (final doc in visitedTiles.docs) {
        final tileId = doc.id;
        // 타일 ID에서 좌표 추출
        final position = _extractPositionFromTileId(tileId);
        if (position != null) {
          visitedPositions.add(position);
        }
      }

      print('🔍 DB에서 로드된 방문 위치 개수: ${visitedPositions.length}');
      return visitedPositions;
    } catch (e) {
      print('❌ DB에서 방문 위치 로드 실패: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _mapMoveTimer?.cancel(); // 타이머 정리
    _clusterDebounceTimer?.cancel(); // 클러스터 디바운스 타이머 정리
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
                minZoom: 14.0,  // 최소 줌 레벨 (줌 아웃 한계)
                maxZoom: 17.0,  // 최대 줌 레벨 (줌 인 한계)
          onMapReady: _onMapReady,
                onMapEvent: _onMapMoved, // 🚀 지도 이동 감지
                onTap: (tapPosition, point) {
                  setState(() {
                    _longPressedLatLng = null;
                  });
                },
                onLongPress: (tapPosition, point) async {
                  // Mock 모드에서는 Mock 위치를 기준으로, 아니면 실제 GPS 위치를 기준으로 확인
                  LatLng? referencePosition;
                  if (_isMockModeEnabled && _mockPosition != null) {
                    referencePosition = _mockPosition;
                  } else {
                    referencePosition = _currentPosition;
                  }

                  // 기준 위치 확인
                  if (referencePosition == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('현재 위치를 확인할 수 없습니다')),
                    );
                    return;
                  }

                  // 현재위치, 집, 일터 주변에서 롱프레스 가능한지 확인
                  final canLongPress = _canLongPressAtLocation(point);

                  if (!canLongPress) {
                    // 거리 초과 시 아무 동작도 하지 않음 (사용자 경험 개선)
                    return;
                  }

                  // 롱프레스 위치 저장
                  _longPressedLatLng = point;
                  
                  // 바로 배포 메뉴 표시 (포그레벨 확인 생략)
                  _showLongPressMenu();
                },
              ),
        children: [
                // OSM 기반 CartoDB Voyager 타일 (라벨 없음)
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.ppamalpha.app',
                  minZoom: 14.0,  // 타일 서버 최소 줌
                  maxZoom: 17.0,  // 타일 서버 최대 줌
                ),
                // 통합 포그 오버레이 (검정 → 펀칭 → 회색)
                UnifiedFogOverlayWidget(
                  mapController: _mapController!,
                  level1Centers: [
                    if (_currentPosition != null) _currentPosition!,
                    if (_homeLocation != null) _homeLocation!,
                    ..._workLocations,
                  ],
                  level2CentersRaw: _grayPolygons.isNotEmpty 
                    ? _grayPolygons.map((polygon) {
                        // 폴리곤의 중심점 계산
                        if (polygon.points.isEmpty) return const LatLng(0, 0);
                        double sumLat = 0, sumLng = 0;
                        for (final point in polygon.points) {
                          sumLat += point.latitude;
                          sumLng += point.longitude;
                        }
                        return LatLng(
                          sumLat / polygon.points.length,
                          sumLng / polygon.points.length,
                        );
                      }).toList()
                    : [],
                  radiusMeters: 1000.0,
                  fogColor: Colors.black.withOpacity(1.0),
                  grayColor: Colors.grey.withOpacity(0.33),
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
          // 필터 버튼들 (상단) - 개선된 디자인
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
               child: Row(
                 children: [
                  // 필터 아이콘
                  Icon(Icons.tune, color: Colors.blue[600], size: 18),
                  const SizedBox(width: 8),
                  
                  // 필터 버튼들
                Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // 내 포스트 필터
                          _buildFilterChip(
                            label: '내 포스트',
                    selected: _showMyPostsOnly,
                    onSelected: (selected) {
                      setState(() {
                        _showMyPostsOnly = selected;
                                if (selected) {
                                  _showCouponsOnly = false;
                                  _showUrgentOnly = false;
                                }
                      });
                      _updatePostsBasedOnFogLevel();
                    },
                            selectedColor: Colors.blue,
                            icon: Icons.person,
                          ),
                          const SizedBox(width: 6),
                          
                // 쿠폰 필터
                          _buildFilterChip(
                            label: '쿠폰',
                    selected: _showCouponsOnly,
                    onSelected: (selected) {
                      setState(() {
                        _showCouponsOnly = selected;
                                if (selected) {
                                  _showMyPostsOnly = false;
                                  _showUrgentOnly = false;
                                }
                      });
                      _updatePostsBasedOnFogLevel();
                    },
                            selectedColor: Colors.green,
                            icon: Icons.card_giftcard,
                          ),
                          const SizedBox(width: 6),
                          
                          // 마감임박 필터
                          _buildFilterChip(
                            label: '마감임박',
                            selected: _showUrgentOnly,
                            onSelected: (selected) {
                              setState(() {
                                _showUrgentOnly = selected;
                                if (selected) {
                                  _showMyPostsOnly = false;
                                  _showCouponsOnly = false;
                                }
                              });
                              _updatePostsBasedOnFogLevel();
                            },
                            selectedColor: Colors.orange,
                            icon: Icons.access_time_filled,
                          ),
                          const SizedBox(width: 6),
                          
                          // 인증 필터
                          _buildFilterChip(
                            label: '인증',
                            selected: _showVerifiedOnly,
                            onSelected: (selected) {
                              setState(() {
                                _showVerifiedOnly = selected;
                                if (selected) _showUnverifiedOnly = false; // 둘 중 하나만
                              });
                              _updatePostsBasedOnFogLevel();
                            },
                            selectedColor: Colors.blue,
                            icon: Icons.verified,
                          ),
                          const SizedBox(width: 6),
                          
                          // 미인증 필터
                          _buildFilterChip(
                            label: '미인증',
                            selected: _showUnverifiedOnly,
                            onSelected: (selected) {
                              setState(() {
                                _showUnverifiedOnly = selected;
                                if (selected) _showVerifiedOnly = false; // 둘 중 하나만
                              });
                              _updatePostsBasedOnFogLevel();
                            },
                            selectedColor: Colors.grey,
                            icon: Icons.work_outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                   const SizedBox(width: 8),
                  
                // 필터 초기화 버튼
                Container(
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
               ),
                  child: IconButton(
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                      iconSize: 18,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                  ),
                ),
              ],
              ),
            ),
          ),
          // Mock 위치 토글 버튼 (우상단)
          Positioned(
            top: 10,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: _isMockModeEnabled ? Colors.purple : Colors.white,
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
                onPressed: _toggleMockMode,
                icon: Icon(
                  Icons.location_searching,
                  color: _isMockModeEnabled ? Colors.white : Colors.purple,
                ),
                iconSize: 20,
              ),
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
          // Mock 위치 화살표 컨트롤러 (왼쪽하단)
          if (_isMockControllerVisible)
            Positioned(
              bottom: 80,
              left: 16,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목과 닫기 버튼
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_searching, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          const Text(
                            'Mock 위치',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _hideMockController,
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ),
                    // 화살표 컨트롤러
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          // 위쪽 화살표
                          GestureDetector(
                            onTap: () => _moveMockPosition('up'),
                            child: Container(
                              width: 40,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 좌우 화살표
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => _moveMockPosition('left'),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_left, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 2),
                              // 중앙 위치 표시
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                ),
                                child: const Icon(Icons.my_location, color: Colors.purple, size: 16),
                              ),
                              const SizedBox(width: 2),
                              GestureDetector(
                                onTap: () => _moveMockPosition('right'),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 아래쪽 화살표
                          GestureDetector(
                            onTap: () => _moveMockPosition('down'),
                            child: Container(
                              width: 40,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 현재 위치 정보 (클릭하여 직접 입력 가능)
                    if (_mockPosition != null)
                      GestureDetector(
                        onTap: _showMockPositionInputDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '위도: ${_mockPosition!.latitude.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 10, color: Colors.grey),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '경도: ${_mockPosition!.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 10, color: Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // 미확인 포스트 아이콘 (좌하단)
          Positioned(
            left: 16,
            bottom: 32,
            child: StreamBuilder<int>(
              stream: PostService().getUnconfirmedPostCountStream(
                FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
              builder: (context, snapshot) {
                final unconfirmedCount = snapshot.data ?? 0;
                
                if (unconfirmedCount == 0) {
                  return SizedBox.shrink(); // 미확인 포스트가 없으면 숨김
                }
                
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    onTap: () async {
                      await _showUnconfirmedPostsDialog();
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, color: Colors.orange, size: 24),
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unconfirmedCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // 포스트 수령 FAB
      floatingActionButton: _buildReceiveFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 수령 가능한 포스트 개수 업데이트 (마커 기준)
  Future<void> _updateReceivablePosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 현재 화면에 표시된 마커들 중에서 200m 이내인 것들을 계산
      int receivableCount = 0;
      
      for (final marker in _markers) {
        // 현재 위치가 null이면 건너뛰기
        if (_currentPosition == null) continue;
        
        // 마커와 현재 위치 간의 거리 계산
        final distance = _calculateDistance(_currentPosition!, marker.position);
        
        // 200m 이내이고, 본인이 배포한 마커가 아닌 경우
        if (distance <= 200 && marker.creatorId != user.uid) {
          receivableCount++;
        }
      }

      if (mounted) {
        setState(() {
          _receivablePostCount = receivableCount;
        });
      }
      
      print('📍 수령 가능 마커 개수: $receivableCount개 (200m 이내)');
    } catch (e) {
      print('수령 가능 포스트 조회 실패: $e');
      // 에러 발생 시에도 UI 업데이트
      if (mounted) {
        setState(() {
          _receivablePostCount = 0;
        });
      }
    }
  }

  // 수령 FAB 위젯
  Widget _buildReceiveFab() {
    // 받을 게 없으면 아예 숨김
    if (_receivablePostCount <= 0 && !_isReceiving) {
      return const SizedBox.shrink();
    }
    
    final enabled = _receivablePostCount > 0 && !_isReceiving;
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          height: 48, // 높이 줄임 (기본 56에서 48로)
        child: FloatingActionButton.extended(
          onPressed: enabled ? _receiveNearbyPosts : null,
          backgroundColor: enabled ? Colors.blue : Colors.grey,
          label: _isReceiving 
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('수령 중...', style: TextStyle(color: Colors.white)),
                  ],
                )
              : Text(
                  enabled ? '모두 수령 ($_receivablePostCount개)' : '포스트 받기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
          icon: _isReceiving ? null : Icon(Icons.download, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // 주변 마커에서 포스트 수령 처리 (마커 기준)
  Future<void> _receiveNearbyPosts() async {
    setState(() => _isReceiving = true);
    
    // 스코프 밖에 변수 선언 (finally 블록에서 접근 가능)
    final actuallyReceived = <ReceiptItem>[];
    final failedToReceive = <String>[];
    final nearbyMarkers = <MarkerModel>[];
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      // 1. 현재 위치에서 200m 이내의 마커들 찾기
      
      for (final marker in _markers) {
        if (_currentPosition == null) continue;
        
        // 마커와 현재 위치 간의 거리 계산
        final distance = _calculateDistance(_currentPosition!, marker.position);
        
        // 200m 이내이고, 본인이 배포한 마커가 아닌 경우
        if (distance <= 200 && marker.creatorId != user.uid) {
          nearbyMarkers.add(marker);
        }
      }

      if (nearbyMarkers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('200m 이내에 수령 가능한 마커가 없습니다'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2. 수령 처리 (PostService 사용하여 수량 차감 포함)

      for (final marker in nearbyMarkers) {
        try {
          // 🔍 수령 시도 전 데이터 확인 (개별 클릭과 동일한 검증 로직)
          print('[BATCH_COLLECT_DEBUG] 수령 시도:');
          print('  - markerId: "${marker.markerId}"');
          print('  - 현재 postId: "${marker.postId}"');
          print('  - postId == markerId: ${marker.postId == marker.markerId}');

          String actualPostId = marker.postId;
          
          // 🚨 CRITICAL FIX: markerId로 실제 마커를 조회해서 올바른 postId 가져오기
          if (marker.postId == marker.markerId || marker.postId.isEmpty) {
            print('[BATCH_COLLECT_FIX] postId가 잘못됨. markerId로 실제 마커 조회 중...');

            try {
              final markerDoc = await FirebaseFirestore.instance
                  .collection('markers')
                  .doc(marker.markerId)
                  .get();

              if (markerDoc.exists && markerDoc.data() != null) {
                final markerData = markerDoc.data()!;
                final realPostId = markerData['postId'] as String?;

                print('[BATCH_COLLECT_FIX] 실제 마커 데이터에서 postId 발견: "$realPostId"');

                if (realPostId != null && realPostId.isNotEmpty && realPostId != marker.markerId) {
                  actualPostId = realPostId;
                  print('[BATCH_COLLECT_FIX] 올바른 postId로 수령 진행: $actualPostId');
                } else {
                  throw Exception('마커에서 유효한 postId를 찾을 수 없습니다');
                }
              } else {
                throw Exception('마커 문서를 찾을 수 없습니다: ${marker.markerId}');
              }
            } catch (e) {
              print('[BATCH_COLLECT_FIX] 마커 조회 실패: $e');
              failedToReceive.add('${marker.title} (마커 정보 오류: $e)');
              continue; // 다음 마커로 진행
            }
          } else {
            print('[BATCH_COLLECT_DEBUG] 기존 postId 사용: ${marker.postId}');
          }

          // 🔥 PostService를 통한 실제 포스트 수령 (수량 차감 포함)
          await PostService().collectPost(
            postId: actualPostId,
            userId: user.uid,
          );

          // 수령 기록을 receipts 컬렉션에도 저장
          final ref = FirebaseFirestore.instance
              .collection('receipts')
              .doc(user.uid)
              .collection('items')
              .doc(marker.markerId);

            // 포스트 이미지 가져오기
            String postImageUrl = '';
            try {
              final postDoc = await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(marker.postId)
                  .get();
              if (postDoc.exists) {
                postImageUrl = postDoc.data()?['imageUrl'] ?? '';
              }
            } catch (e) {
              print('포스트 이미지 조회 실패: $e');
            }

          await ref.set({
              'markerId': marker.markerId,
              'imageUrl': postImageUrl,
              'title': marker.title,
              'receivedAt': FieldValue.serverTimestamp(),
              'confirmed': false,
              'statusBadge': '미션 중',
            });
            
            actuallyReceived.add(ReceiptItem(
              markerId: marker.markerId,
              imageUrl: postImageUrl,
              title: marker.title,
              receivedAt: DateTime.now(),
              confirmed: false,
              statusBadge: '미션 중',
            ));
        } catch (e) {
          // 개별 수령 실패
          failedToReceive.add('${marker.title} (수령 실패: ${e.toString()})');
        }
      }

      if (actuallyReceived.isNotEmpty) {
        // 3. 효과음/진동
        await _playReceiveEffects(actuallyReceived.length);

        // 4. 캐러셀 팝업으로 수령한 포스트들 표시
        final receivedPosts = <PostModel>[];
        for (final receipt in actuallyReceived) {
          // ReceiptItem에서 PostModel로 변환
          final post = PostModel(
            postId: receipt.markerId,
            title: receipt.title,
            description: '수령 완료',
            reward: 0, // 실제 reward는 PostService에서 처리됨
            creatorId: '',
            creatorName: '',
            createdAt: DateTime.now(),
            defaultExpiresAt: DateTime.now().add(Duration(days: 1)),
            targetAge: [],
            targetGender: 'all',
            targetInterest: [],
            targetPurchaseHistory: [],
            mediaType: [],
            mediaUrl: receipt.imageUrl.isNotEmpty ? [receipt.imageUrl] : [],
            canRespond: false,
            canForward: false,
            canRequestReward: false,
            canUse: false,
          );
          receivedPosts.add(post);
        }
        await _showPostReceivedCarousel(receivedPosts);
      } else if (failedToReceive.isNotEmpty) {
        // 수령할 수 있는 포스트가 없는 경우
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수령할 수 있는 마커가 없습니다 (${failedToReceive.length}개 실패)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('마커 수령 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('마커 수령에 실패했습니다: $e')),
      );
    } finally {
      setState(() => _isReceiving = false);
      
      // 수령 완료 후 즉시 마커 새로고침
      print('🔄 배치 수령 완료 - 마커 목록 새로고침 시작');
      
      // 1. 로컬에서 수령한 포스트의 모든 마커 즉시 제거 (UI 반응성)
      if (actuallyReceived.isNotEmpty) {
        setState(() {
          // 수령한 포스트 ID들 수집
          final collectedPostIds = <String>{};
          for (final receipt in actuallyReceived) {
            // markerId로 원본 마커 찾기
            final originalMarker = nearbyMarkers.firstWhere(
              (m) => m.markerId == receipt.markerId,
              orElse: () => nearbyMarkers.first,
            );
            collectedPostIds.add(originalMarker.postId);
          }
          
          // 수령한 포스트들의 모든 마커 제거 (같은 postId를 가진 다른 마커들도 함께)
          final removedCount = _markers.where((m) => collectedPostIds.contains(m.postId)).length;
          _markers.removeWhere((m) => collectedPostIds.contains(m.postId));
          print('🗑️ 수령한 포스트들의 모든 마커 제거: ${removedCount}개');
          print('   - 수령한 포스트 IDs: $collectedPostIds');
          
          _updateMarkers(); // 클러스터 재계산
        });
      }
      
      // 2. 서버에서 실제 마커 상태 확인 및 동기화
      await Future.delayed(const Duration(milliseconds: 500));
      await _updatePostsBasedOnFogLevel(); // 마커 목록 새로고침
      _updateReceivablePosts(); // 개수 업데이트
      
      print('✅ 배치 마커 새로고침 완료');
    }
  }

  // 수령 효과음/진동
  Future<void> _playReceiveEffects(int count) async {
    try {
      // 진동
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 100);
      }

      // 사운드 (count만큼 반복)
      final player = audio.AudioPlayer();
      await player.setSource(audio.AssetSource('sounds/receive.mp3'));
      
      for (int i = 0; i < count; i++) {
        await player.resume();
        await Future.delayed(const Duration(milliseconds: 250));
        await player.stop();
        if (i < count - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      await player.dispose();
    } catch (e) {
      print('효과음 재생 실패: $e');
    }
  }

  /// 미확인 포스트 다이얼로그 표시
  Future<void> _showUnconfirmedPostsDialog() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // 미확인 포스트 목록 조회
      final postService = PostService();
      final unconfirmedPosts = await postService.getUnconfirmedPosts(currentUserId);

      if (unconfirmedPosts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('미확인 포스트가 없습니다')),
        );
        return;
      }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.orange, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '미확인 포스트 (${unconfirmedPosts.length}개)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // 캐러셀 영역
              Expanded(
                child: PageView.builder(
                  itemCount: unconfirmedPosts.length,
                  itemBuilder: (context, index) {
                    final post = unconfirmedPosts[index];
                    final title = post['postTitle'] ?? 'Unknown Title';
                    final collectedAt = post['collectedAt'] as Timestamp?;
                    final reward = post['reward'] ?? 0;
                    final collectionId = post['collectionId'] as String;
                    final postId = post['postId'] as String;
                    final creatorId = post['postCreatorId'] ?? '';
                    final imageUrls = post['imageUrls'] as List<dynamic>? ?? [];
                    final thumbnailUrls = post['thumbnailUrls'] as List<dynamic>? ?? [];
                    
                    // 표시할 이미지 URL (썸네일 우선, 없으면 원본, 둘 다 없으면 null)
                    final displayImageUrl = thumbnailUrls.isNotEmpty 
                        ? thumbnailUrls.first as String?
                        : (imageUrls.isNotEmpty ? imageUrls.first as String? : null);

                    return GestureDetector(
                      onTap: () async {
                        // 터치하여 확인
                        await _confirmUnconfirmedPost(
                          collectionId: collectionId,
                          userId: currentUserId,
                          postId: postId,
                          creatorId: creatorId,
                          reward: reward,
                          title: title,
                        );
                      },
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 상태 배지
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '터치하여 확인',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Spacer(),
                                if (unconfirmedPosts.length > 1)
                                  Text(
                                    '${index + 1}/${unconfirmedPosts.length} 👈 스와이프',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                            
                            SizedBox(height: 20),
                            
                            // 포스트 제목
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            
                            SizedBox(height: 12),
                            
                            // 수령일 정보
                            if (collectedAt != null) ...[
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  SizedBox(width: 4),
                                  Text(
                                    '수령일: ${_formatDate(collectedAt.toDate())}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                            ],
                            
                            // 포스트 이미지 (중앙에 크게)
                            if (displayImageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  displayImageUrl,
                                  width: double.infinity,
                                  height: 300,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: 20),
                            ] else ...[
                              // 이미지가 없으면 큰 카드 형태로 텍스트 표시
                              Container(
                                height: 200,
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.card_giftcard,
                                        size: 64,
                                        color: Colors.orange[400],
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                            ],
                            
                            // 포인트 정보
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.monetization_on, color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '포인트 지급',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        '+${reward}포인트',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            // 확인 안내
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.touch_app, size: 16, color: Colors.orange[700]),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '이 영역을 터치하면 확인하고 포인트를 받습니다',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // 페이지 인디케이터
              if (unconfirmedPosts.length > 1)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(unconfirmedPosts.length, (index) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange,
                        ),
                      );
                    }),
                  ),
                ),
              
              // 하단 버튼
              Container(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('나중에 확인하기'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    } catch (e) {
      debugPrint('미확인 포스트 조회 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('미확인 포스트를 불러올 수 없습니다: $e')),
      );
    }
  }

  /// 미확인 포스트 확인 처리
  Future<void> _confirmUnconfirmedPost({
    required String collectionId,
    required String userId,
    required String postId,
    required String creatorId,
    required int reward,
    required String title,
  }) async {
    try {
      final postService = PostService();
      
      // 포스트 확인 처리
      await postService.confirmPost(
        collectionId: collectionId,
        userId: userId,
        postId: postId,
        creatorId: creatorId,
        reward: reward,
      );

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $title 확인 완료! +${reward}포인트'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // 다이얼로그 새로고침을 위해 닫고 다시 열기
      Navigator.pop(context);
      await _showUnconfirmedPostsDialog();
      
    } catch (e) {
      debugPrint('미확인 포스트 확인 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 확인에 실패했습니다: $e')),
      );
    }
  }

  /// 미확인 포스트 삭제 처리 (보상 없이 제거)
  Future<void> _deleteUnconfirmedPost({
    required String collectionId,
    required String title,
  }) async {
    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('포스트 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('이 포스트를 삭제하시겠습니까?'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 주의',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• 삭제하면 보상을 받을 수 없습니다\n• 이 작업은 되돌릴 수 없습니다',
                    style: TextStyle(
                      color: Colors.red[600],
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
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // post_collections에서 삭제 (보상 없음)
      await FirebaseFirestore.instance
          .collection('post_collections')
          .doc(collectionId)
          .delete();

      debugPrint('✅ 미확인 포스트 삭제 성공: $collectionId');

      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ $title 삭제되었습니다'),
          backgroundColor: Colors.grey[700],
          duration: Duration(seconds: 2),
        ),
      );

      // 다이얼로그 새로고침을 위해 닫고 다시 열기
      Navigator.pop(context);
      await _showUnconfirmedPostsDialog();
      
    } catch (e) {
      debugPrint('❌ 미확인 포스트 삭제 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('포스트 삭제에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 날짜 포맷팅 헬퍼 함수
  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }


}
 
 