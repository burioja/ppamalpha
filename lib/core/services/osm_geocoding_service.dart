import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSMGeocodingService {
  // 캐시를 위한 Map
  static final Map<String, String> _locationCache = {};
  
  /// 위도/경도로부터 건물명을 조회합니다
  static Future<String?> getBuildingName(LatLng position) async {
    final cacheKey = '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    
    // 캐시에서 먼저 확인
    if (_locationCache.containsKey(cacheKey)) {
      print('📍 OSM 캐시에서 건물명 반환: ${_locationCache[cacheKey]}');
      return _locationCache[cacheKey];
    }
    
    try {
      print('🌐 OSM API 호출: ${position.latitude}, ${position.longitude}');
      
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?'
          'format=json&lat=${position.latitude}&lon=${position.longitude}'
          '&zoom=18&addressdetails=1&accept-language=ko'
        ),
        headers: {
          'User-Agent': 'PPAM-App/1.0', // OSM API 요청 시 필수
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        
        // 건물명만 추출 (가장 구체적인 정보 우선)
        String? buildingName = address?['building'] ?? 
                               address?['amenity'] ?? 
                               address?['shop'] ?? 
                               address?['house_name'] ?? 
                               address?['name'];
        
        // 건물명이 없으면 도로명 + 번지
        if (buildingName == null || buildingName.trim().isEmpty) {
          final road = address?['road'];
          final houseNumber = address?['house_number'];
          if (road != null && road.toString().trim().isNotEmpty) {
            if (houseNumber != null && houseNumber.toString().trim().isNotEmpty) {
              buildingName = '${road.toString().trim()} ${houseNumber.toString().trim()}';
            } else {
              buildingName = road.toString().trim();
            }
          }
        }
        
        // 그것도 없으면 display_name의 첫 부분
        if (buildingName == null || buildingName.trim().isEmpty) {
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            buildingName = displayName.split(',').first.trim();
          }
        }
        
        if (buildingName != null && buildingName.isNotEmpty) {
          // 캐시에 저장
          _locationCache[cacheKey] = buildingName;
          print('✅ OSM 건물명 조회 성공: $buildingName');
          return buildingName;
        }
      } else {
        print('❌ OSM API 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ OSM API 호출 실패: $e');
    }
    
    return null;
  }
  
  /// 주소 검색을 위한 메서드
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      print('🔍 OSM 주소 검색: $query');
      
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?'
          'format=json&q=${Uri.encodeComponent(query)}&limit=10&addressdetails=1&accept-language=ko'
        ),
        headers: {
          'User-Agent': 'PPAM-App/1.0',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ OSM 주소 검색 성공: ${data.length}개 결과');
        
        return data.map((item) => {
          'display_name': item['display_name'] as String?,
          'lat': double.tryParse(item['lat'].toString()),
          'lon': double.tryParse(item['lon'].toString()),
          'place_id': item['place_id'] as String?,
        }).where((item) => 
          item['lat'] != null && 
          item['lon'] != null && 
          item['display_name'] != null
        ).toList();
      }
    } catch (e) {
      print('❌ OSM 주소 검색 실패: $e');
    }
    
    return [];
  }
  
  /// 캐시 초기화
  static void clearCache() {
    _locationCache.clear();
    print('🗑️ OSM 캐시 초기화');
  }
  
  /// 캐시 크기 반환
  static int getCacheSize() {
    return _locationCache.length;
  }
}




