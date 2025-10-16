part of '../map_screen.dart';

// ==================== 초기화 관련 메서드들 ====================

/// 사용자 데이터 리스너 설정
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
        
        // ✅ 일터 변경 감지를 위한 리스너 설정
        final workplaceId = data['workplaceId'] as String?;
        if (workplaceId != null && workplaceId.isNotEmpty) {
          _setupWorkplaceListener(workplaceId);
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

/// 일터(Place) 변경사항 실시간 감지 리스너
void _setupWorkplaceListener(String workplaceId) {
  print('💼 일터 리스너 설정 시작: $workplaceId');
  
  // ✅ 기존 리스너 취소 (중복 방지)
  _workplaceSubscription?.cancel();
  
  // ✅ 새로운 리스너 설정
  _workplaceSubscription = FirebaseFirestore.instance
      .collection('places')
      .doc(workplaceId)
      .snapshots()
      .listen((snapshot) {
    if (snapshot.exists) {
      print('💼 일터 정보 변경 감지됨 - 타임스탬프: ${DateTime.now()}');
      final data = snapshot.data();
      if (data != null) {
        final location = data['location'] as GeoPoint?;
        print('💼 변경된 일터 좌표: ${location?.latitude}, ${location?.longitude}');
        
        // 일터 위치 정보 새로고침
        _loadUserLocations();
      }
    }
  }, onError: (error) {
    print('❌ 일터 리스너 오류: $error');
  });
}

/// 마커 리스너 설정
void _setupMarkerListener() {
  if (_currentPosition == null) return;
  print('마커 리스너 설정 시작');
}

/// 유료 사용자 상태 확인
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

/// 포스트 스트림 리스너 설정
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

/// 커스텀 마커 로드
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

/// 위치 초기화
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

/// 현재 위치 가져오기
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

/// 현재 위치 마커 생성
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

