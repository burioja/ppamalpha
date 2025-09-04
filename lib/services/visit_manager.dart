import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../utils/tile_utils.dart';

/// 방문 기록 관리자
class VisitManager {
  static const int _cacheExpiryDays = 30;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// 방문 기록 저장
  Future<void> recordVisit(LatLng position, int zoom) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final tile = TileUtils.latLngToTile(position, zoom);
    final tileKey = TileUtils.generateTileKey(zoom, tile.x, tile.y);
    
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .doc(tileKey)
          .set({
        'timestamp': FieldValue.serverTimestamp(),
        'level': 2, // gray level
        'weight': FieldValue.increment(1),
        'position': GeoPoint(position.latitude, position.longitude),
        'zoom': zoom,
      });
    } catch (e) {
      debugPrint('Error recording visit: $e');
    }
  }
  
  /// 최근 방문한 타일인지 확인
  Future<bool> isRecentlyVisited(Coords coords, int zoom) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    
    final tileKey = TileUtils.generateTileKey(zoom, coords.x, coords.y);
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .doc(tileKey)
          .get();
      
      if (!doc.exists) return false;
      
      final timestamp = doc.data()?['timestamp'] as Timestamp?;
      if (timestamp == null) return false;
      
      final daysSinceVisit = DateTime.now().difference(timestamp.toDate()).inDays;
      return daysSinceVisit <= _cacheExpiryDays;
    } catch (e) {
      debugPrint('Error checking visited tile: $e');
      return false;
    }
  }
  
  /// 사용자의 방문 타일 목록 가져오기
  Future<List<Map<String, dynamic>>> getVisitedTiles() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'tileKey': doc.id,
          'timestamp': data['timestamp'],
          'level': data['level'],
          'weight': data['weight'],
          'position': data['position'],
          'zoom': data['zoom'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting visited tiles: $e');
      return [];
    }
  }
  
  /// 오래된 방문 기록 정리 (30일 이상)
  Future<void> cleanupOldVisits() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    final cutoffDate = DateTime.now().subtract(const Duration(days: _cacheExpiryDays));
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('visited_tiles')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error cleaning up old visits: $e');
    }
  }
  
  /// 현재 위치 방문 기록 저장
  Future<void> recordCurrentLocationVisit(LatLng position, int zoom) async {
    await recordVisit(position, zoom);
  }
}
