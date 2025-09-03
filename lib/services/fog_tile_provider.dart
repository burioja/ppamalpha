import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/fog_level.dart';
import '../utils/tile_utils.dart';

/// 포그 오브 워 타일 제공자
class FogTileProvider extends TileProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 캐시된 포그 레벨 (메모리 캐시)
  final Map<String, FogLevel> _fogLevelCache = {};
  
  // 현재 사용자 위치
  LatLng? _currentPosition;
  
  // 현재 줌 레벨
  int _currentZoom = 13;
  
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
    final fogLevel = _getFogLevelForTile(coords);
    return _getImageForFogLevel(fogLevel);
  }
  
  /// 타일에 대한 포그 레벨 결정
  FogLevel _getFogLevelForTile(Coords coords) {
    final tileKey = TileUtils.generateTileKey(_currentZoom, coords.x, coords.y);
    
    // 메모리 캐시에서 먼저 확인
    if (_fogLevelCache.containsKey(tileKey)) {
      return _fogLevelCache[tileKey]!;
    }
    
    FogLevel level;
    
    // 1. 현재 위치 1km 반경 체크
    if (_currentPosition != null && 
        TileUtils.isTileInRadius(coords, _currentPosition!, _currentZoom, 1.0)) {
      level = FogLevel.clear;
    }
    // 2. 30일 이내 방문 타일 체크
    else if (_isRecentlyVisited(coords)) {
      level = FogLevel.gray;
    }
    // 3. 기본값: 검정
    else {
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
  
  /// 포그 레벨에 따른 이미지 반환
  ImageProvider _getImageForFogLevel(FogLevel level) {
    // 실제 구현에서는 동적으로 색상 오버레이 이미지를 생성
    // 여기서는 간단한 색상 기반 이미지 사용
    switch (level) {
      case FogLevel.clear:
        // 투명 이미지 (지도 완전 노출)
        return _createColorImage(Colors.transparent);
      case FogLevel.gray:
        // 회색 반투명 오버레이
        return _createColorImage(Colors.black.withValues(alpha: 0.3));
      case FogLevel.black:
        // 검정 오버레이 (지도 완전 가림)
        return _createColorImage(Colors.black);
    }
  }
  
  /// 색상 기반 이미지 생성
  ImageProvider _createColorImage(Color color) {
    // 실제 구현에서는 Canvas를 사용해서 이미지를 생성
    // 여기서는 간단한 색상 이미지 반환
    return MemoryImage(_createColorImageData(color));
  }
  
  /// 색상 이미지 데이터 생성
  Uint8List _createColorImageData(Color color) {
    // 1x1 픽셀 이미지 생성 (실제로는 256x256이어야 함)
    final bytes = Uint8List(4);
    bytes[0] = color.red;
    bytes[1] = color.green;
    bytes[2] = color.blue;
    bytes[3] = color.alpha;
    return bytes;
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
}
