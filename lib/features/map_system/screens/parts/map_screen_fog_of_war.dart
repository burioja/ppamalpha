part of '../map_screen.dart';

// ==================== Fog of War 관련 메서드들 ====================

/// Fog of War 재구성
void _rebuildFogWithUserLocations(LatLng currentPosition) {
  final allPositions = <LatLng>[currentPosition];
  final ringCircles = <CircleMarker>[];

  // 현재 위치
  ringCircles.add(OSMFogService.createRingCircle(currentPosition));

  // 집 위치
  if (_homeLocation != null) {
    allPositions.add(_homeLocation!);
    ringCircles.add(OSMFogService.createRingCircle(_homeLocation!));
  }

  // 일터 위치들
  for (int i = 0; i < _workLocations.length; i++) {
    final workLocation = _workLocations[i];
    allPositions.add(workLocation);
    ringCircles.add(OSMFogService.createRingCircle(workLocation));
  }

  if (mounted) {
    setState(() {
      _ringCircles = ringCircles;
    });
  }
}

/// 사용자 위치(집, 일터) 로드
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
      _rebuildFogWithUserLocations(_currentPosition!);
    }
  } catch (e) {
    debugPrint('사용자 위치 로드 실패: $e');
  }
}

/// 과거 방문 위치 로드
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

/// 타일 ID에서 좌표 추출하는 헬퍼 메서드
LatLng? _extractPositionFromTileId(String tileId) {
  try {
    // ✅ TileUtils의 표준 메서드 사용 (중복 로직 제거)
    return TileUtils.getKm1TileCenter(tileId);
  } catch (e) {
    debugPrint('타일 ID 변환 실패: $tileId - $e');
    return null;
  }
}

/// 현재 주소 업데이트
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

/// 이전 위치를 포함한 회색 영역 업데이트
Future<void> _updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
  if (previousPosition == null) {
    await _loadVisitedLocations();
    return;
  }

  try {
    // 기존 방문 위치 로드
    await _loadVisitedLocations();
    
    // 이전 위치도 회색 영역에 추가
    final previousGrayArea = OSMFogService.createGrayAreas([previousPosition]);
    
    if (mounted) {
      setState(() {
        _grayPolygons = [..._grayPolygons, ...previousGrayArea];
      });
    }
  } catch (e) {
    debugPrint('회색 영역 업데이트 실패: $e');
  }
}

/// 로컬 포그레벨 1 타일 설정
void _setLevel1TileLocally(String tileId) {
  setState(() {
    _currentFogLevel1TileIds.add(tileId);
    _fogLevel1CacheTimestamp = DateTime.now();
  });
}

/// 포그레벨 1 캐시 초기화
void _clearFogLevel1Cache() {
  setState(() {
    _currentFogLevel1TileIds.clear();
    _fogLevel1CacheTimestamp = null;
  });
}

/// 만료된 포그레벨 1 캐시 확인 및 초기화
void _checkAndClearExpiredFogLevel1Cache() {
  if (_fogLevel1CacheTimestamp != null) {
    final elapsed = DateTime.now().difference(_fogLevel1CacheTimestamp!);
    if (elapsed > _fogLevel1CacheExpiry) {
      _clearFogLevel1Cache();
    }
  }
}

/// 포그레벨 1 캐시 타임스탬프 업데이트
void _updateFogLevel1CacheTimestamp() {
  setState(() {
    _fogLevel1CacheTimestamp = DateTime.now();
  });
}

