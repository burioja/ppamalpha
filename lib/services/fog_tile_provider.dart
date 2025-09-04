import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fog_level.dart';
import '../utils/tile_utils.dart';
import 'tile_cache_manager.dart';
import 'performance_monitor.dart';
import 'firebase_functions_service.dart';

/// 포그 오브 워 타일 제공자
class FogTileProvider extends TileProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TileCacheManager _cacheManager = TileCacheManager();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final FirebaseFunctionsService _functionsService = FirebaseFunctionsService();
  
  // 캐시된 포그 레벨 (메모리 캐시)
  final Map<String, FogLevel> _fogLevelCache = {};
  
  // 현재 사용자 위치
  LatLng? _currentPosition;
  
  // 현재 줌 레벨
  int _currentZoom = 13;
  
  // 배치 요청 큐
  final List<String> _pendingTileRequests = [];
  Timer? _batchTimer;
  
  /// 현재 위치 설정
  void setCurrentPosition(LatLng position) {
    _currentPosition = position;
    _clearCache(); // 위치 변경 시 캐시 초기화
  }
  
  /// 현재 줌 레벨 설정
  void setCurrentZoom(int zoom) {
    _currentZoom = zoom;
  }
  
  /// 캐시 초기화
  void _clearCache() {
    _fogLevelCache.clear();
  }
  
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final coords = Coords(coordinates.x, coordinates.y);
    final tileKey = TileUtils.generateTileKey(_currentZoom, coords.x, coords.y);
    
    // 성능 모니터링 시작
    _performanceMonitor.startTileLoadTimer(tileKey);
    
    // 포그 레벨 결정
    final fogLevel = _getFogLevelForTile(coords);
    
    // 배치 요청에 추가
    _addToBatchRequest(tileKey);
    
    // 성능 모니터링 완료
    _performanceMonitor.endTileLoadTimer(tileKey, fogLevel, false);
    
    // 현재 위치 1km 반경 내에서는 밝은 지도 타일 반환
    if (fogLevel == FogLevel.clear) {
      return _getBrightMapTile(coords);
    } else {
      // 나머지 모든 지역은 검은색 다크 테마 지도 타일 사용
      return _getDarkMapTile(coords);
    }
  }
  
  /// 타일에 대한 포그 레벨 결정
  FogLevel _getFogLevelForTile(Coords coords) {
    final tileKey = TileUtils.generateTileKey(_currentZoom, coords.x, coords.y);
    
    // 메모리 캐시에서 먼저 확인
    if (_fogLevelCache.containsKey(tileKey)) {
      return _fogLevelCache[tileKey]!;
    }
    
    FogLevel level;
    
    // 현재 위치 1km 반경 체크 (정확한 거리 계산)
    if (_currentPosition != null) {
      final tileCenter = TileUtils.tileToLatLng(coords, _currentZoom);
      final distance = TileUtils.calculateDistance(_currentPosition!, tileCenter);
      
      // 타일의 모서리까지의 거리도 고려하여 원형 반경 구현
      final tileSize = 256; // 타일 크기
      final tileSizeInKm = _getTileSizeInKm(_currentZoom);
      final tileRadius = tileSizeInKm / 2; // 타일 반지름
      
      // 타일 중심에서 가장 가까운 모서리까지의 거리
      final minDistance = distance - tileRadius;
      final maxDistance = distance + tileRadius;
      
      if (maxDistance <= 1.0) {
        // 타일 전체가 1km 반경 내에 있음
        level = FogLevel.clear;
        debugPrint('🗺️ 타일 ${coords.x},${coords.y}: CLEAR (${distance.toStringAsFixed(2)}km)');
      } else if (minDistance > 1.0) {
        // 타일 전체가 1km 반경 밖에 있음
        level = FogLevel.black;
        debugPrint('⚫ 타일 ${coords.x},${coords.y}: BLACK (${distance.toStringAsFixed(2)}km)');
      } else {
        // 타일이 1km 반경과 겹침 - 원형 마스크 적용
        level = _isTileInCircularRadius(coords) ? FogLevel.clear : FogLevel.black;
        debugPrint('🔍 타일 ${coords.x},${coords.y}: ${level == FogLevel.clear ? 'CLEAR' : 'BLACK'} (${distance.toStringAsFixed(2)}km)');
      }
    } else {
      // 위치 정보가 없으면 모든 지역을 검정으로
      level = FogLevel.black;
    }
    
    // 캐시에 저장
    _fogLevelCache[tileKey] = level;
    
    return level;
  }
  
  /// 최근 방문한 타일인지 확인 (동기적)
  bool _isRecentlyVisited(Coords coords) {
    // 실제 구현에서는 비동기로 Firebase에서 확인해야 하지만,
    // TileProvider의 getImage는 동기적이므로 임시로 false 반환
    // 실제 방문 기록은 별도로 관리
    return false;
  }
  
  /// 밝은 지도 타일 반환 (현재 위치 1km 반경)
  ImageProvider _getBrightMapTile(Coords coords) {
    // 밝은 지도 타일 URL 생성
    final url = 'https://a.basemaps.cartocdn.com/rastertiles/voyager_nolabels/${_currentZoom}/${coords.x}/${coords.y}.png';
    return NetworkImage(url);
  }

  /// 검은색 다크 테마 지도 타일 반환 (미방문 지역)
  ImageProvider _getDarkMapTile(Coords coords) {
    // 검은색 다크 테마 지도 타일 URL 생성
    final url = 'https://a.basemaps.cartocdn.com/dark_nolabels/${_currentZoom}/${coords.x}/${coords.y}.png';
    return NetworkImage(url);
  }

  /// 줌 레벨에 따른 타일 크기 계산 (km)
  double _getTileSizeInKm(int zoom) {
    // 위도 0도에서의 타일 크기 계산
    final earthCircumference = 40075.0; // 지구 둘레 (km)
    return earthCircumference / (1 << zoom);
  }

  /// 타일이 원형 반경 내에 있는지 확인
  bool _isTileInCircularRadius(Coords coords) {
    if (_currentPosition == null) return false;
    
    final tileCenter = TileUtils.tileToLatLng(coords, _currentZoom);
    final distance = TileUtils.calculateDistance(_currentPosition!, tileCenter);
    
    // 타일의 4개 모서리 중 하나라도 1km 반경 내에 있으면 CLEAR
    final tileSizeInKm = _getTileSizeInKm(_currentZoom);
    final halfTileSize = tileSizeInKm / 2;
    
    // 타일의 4개 모서리 좌표 계산
    final corners = [
      LatLng(tileCenter.latitude + halfTileSize / 111.32, tileCenter.longitude - halfTileSize / 111.32),
      LatLng(tileCenter.latitude + halfTileSize / 111.32, tileCenter.longitude + halfTileSize / 111.32),
      LatLng(tileCenter.latitude - halfTileSize / 111.32, tileCenter.longitude - halfTileSize / 111.32),
      LatLng(tileCenter.latitude - halfTileSize / 111.32, tileCenter.longitude + halfTileSize / 111.32),
    ];
    
    // 모서리 중 하나라도 1km 반경 내에 있으면 true
    for (final corner in corners) {
      final cornerDistance = TileUtils.calculateDistance(_currentPosition!, corner);
      if (cornerDistance <= 1.0) {
        return true;
      }
    }
    
    return false;
  }

  /// 색상 기반 이미지 생성
  ImageProvider _createColorImage(Color color) {
    // 실제 구현에서는 Canvas를 사용해서 이미지를 생성
    // 여기서는 간단한 색상 이미지 반환
    return MemoryImage(_createColorImageData(color));
  }
  
  /// 색상 이미지 데이터 생성 (PNG 형식)
  Uint8List _createColorImageData(Color color) {
    // 간단한 1x1 픽셀 PNG 이미지 생성 (실제로는 256x256이어야 하지만 성능상 1x1 사용)
    // PNG 헤더 + 1x1 픽셀 데이터
    final List<int> pngData = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG 시그니처
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR 청크
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 크기
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // 8비트 RGBA
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT 청크
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, // 압축된 픽셀 데이터
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // CRC
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND 청크
      0x42, 0x60, 0x82
    ];
    
    // 실제로는 더 간단한 방법으로 검은색 이미지 생성
    if (color == Colors.black) {
      // 완전히 검은색 1x1 픽셀
      return Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ]);
    } else if (color == Colors.transparent) {
      // 투명한 1x1 픽셀
      return Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
      ]);
    }
    
    return Uint8List.fromList(pngData);
  }
  
  /// 비동기적으로 방문 기록 확인
  Future<bool> isRecentlyVisitedAsync(Coords coords) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final tileKey = TileUtils.generateTileKey(_currentZoom, coords.x, coords.y);
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .doc(tileKey)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data();
      final timestamp = data?['timestamp'] as Timestamp?;
      
      if (timestamp == null) return false;
      
      final daysSinceVisit = DateTime.now().difference(timestamp.toDate()).inDays;
      return daysSinceVisit <= 30;
    } catch (e) {
      debugPrint('Error checking visited tile: $e');
      return false;
    }
  }
  
  /// 배치 요청에 타일 추가
  void _addToBatchRequest(String tileKey) {
    if (!_pendingTileRequests.contains(tileKey)) {
      _pendingTileRequests.add(tileKey);
    }
    
    // 배치 타이머 시작 (100ms 후 실행)
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), () {
      _processBatchRequests();
    });
  }
  
  /// 배치 요청 처리
  Future<void> _processBatchRequests() async {
    if (_pendingTileRequests.isEmpty) return;
    
    try {
      final tileKeys = List<String>.from(_pendingTileRequests);
      _pendingTileRequests.clear();
      
      // Firebase Functions를 통한 배치 조회
      final fogLevels = await _functionsService.getBatchFogLevels(tileKeys);
      
      // 캐시 업데이트
      for (final entry in fogLevels.entries) {
        _fogLevelCache[entry.key] = entry.value;
        await _cacheManager.cacheFogTile(entry.key, entry.value);
      }
      
      debugPrint('✅ 배치 포그 레벨 처리: ${fogLevels.length}개 타일');
      
    } catch (e) {
      debugPrint('❌ 배치 요청 처리 오류: $e');
    }
  }
  
  /// 시스템 초기화
  Future<void> initialize() async {
    await _cacheManager.initialize();
    _performanceMonitor.startPeriodicMetricsSending();
    debugPrint('✅ 포그 오브 워 시스템 초기화 완료');
  }
  
  /// 리소스 정리
  void dispose() {
    _batchTimer?.cancel();
    _cacheManager.dispose();
    _performanceMonitor.dispose();
  }
}
