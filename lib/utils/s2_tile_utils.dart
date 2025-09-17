import 'dart:math' as math;

/// S2 타일 유틸리티
/// S2 Geometry Library의 Dart 구현을 위한 기본 유틸리티
class S2TileUtils {
  static const int EARTH_RADIUS_KM = 6371;
  
  /// 위도/경도를 S2 Cell ID로 변환
  /// 
  /// [lat] - 위도 (degrees)
  /// [lng] - 경도 (degrees)  
  /// [level] - S2 레벨 (10 또는 12 권장)
  /// 
  /// Returns: S2 Cell ID 문자열
  static String latLngToS2CellId(double lat, double lng, int level) {
    // 위도/경도를 라디안으로 변환
    final latRad = lat * math.pi / 180.0;
    final lngRad = lng * math.pi / 180.0;
    
    // S2 Cell ID 계산 (간단한 구현)
    // 실제로는 S2 Geometry Library를 사용해야 함
    final x = (lngRad + math.pi) / (2 * math.pi);
    final y = (latRad + math.pi / 2) / math.pi;
    
    // 레벨에 따른 해상도 계산
    final resolution = math.pow(2, level).toInt();
    final cellX = (x * resolution).floor();
    final cellY = (y * resolution).floor();
    
    return '${level}_${cellX}_${cellY}';
  }
  
  /// 반경 내의 S2 Cell ID들을 계산
  /// 
  /// [centerLat] - 중심 위도
  /// [centerLng] - 중심 경도
  /// [radiusKm] - 반경 (km)
  /// [level] - S2 레벨
  /// 
  /// Returns: 반경 내의 S2 Cell ID 리스트
  static List<String> getS2CellsInRadius(
    double centerLat, 
    double centerLng, 
    double radiusKm, 
    int level
  ) {
    final cells = <String>{};
    
    // 간단한 그리드 기반 커버링
    // 실제로는 S2 covering 알고리즘을 사용해야 함
    final latStep = radiusKm / 111.0; // 1도 ≈ 111km
    final lngStep = radiusKm / (111.0 * math.cos(centerLat * math.pi / 180.0));
    
    final steps = math.max(1, (radiusKm / 0.1).ceil()); // 100m 간격
    
    for (int i = -steps; i <= steps; i++) {
      for (int j = -steps; j <= steps; j++) {
        final lat = centerLat + i * latStep / steps;
        final lng = centerLng + j * lngStep / steps;
        
        // 거리 체크
        final distance = _calculateDistance(centerLat, centerLng, lat, lng);
        if (distance <= radiusKm) {
          final cellId = latLngToS2CellId(lat, lng, level);
          cells.add(cellId);
        }
      }
    }
    
    return cells.toList();
  }
  
  /// 두 지점 간의 거리 계산 (Haversine 공식)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return EARTH_RADIUS_KM * c;
  }
  
  /// Firestore IN 쿼리 제한 (30개)을 고려한 배치 처리
  /// 
  /// [cells] - S2 Cell ID 리스트
  /// [batchSize] - 배치 크기 (기본 30)
  /// 
  /// Returns: 배치별로 나뉜 Cell ID 리스트
  static List<List<String>> batchS2Cells(List<String> cells, {int batchSize = 30}) {
    final batches = <List<String>>[];
    
    for (int i = 0; i < cells.length; i += batchSize) {
      final end = math.min(i + batchSize, cells.length);
      batches.add(cells.sublist(i, end));
    }
    
    return batches;
  }
}
