import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Nominatim 역지오코딩 서비스
class NominatimService {
  static const String _baseUrl = 'nominatim.openstreetmap.org';
  static const String _userAgent = 'ppam-app/1.0 (contact: admin@ppamalpha.com)';

  /// 좌표를 주소로 변환
  static Future<String> reverseGeocode(LatLng position) async {
    try {
      final uri = Uri.https(_baseUrl, '/reverse', {
        'format': 'jsonv2',
        'lat': position.latitude.toString(),
        'lon': position.longitude.toString(),
        'accept-language': 'ko',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
        },
      );

      if (response.statusCode != 200) {
        return '주소 변환 실패 (HTTP ${response.statusCode})';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        return data['display_name'] ?? '주소 변환 실패';
      }

      // 건물명만 추출 (가장 구체적인 정보 우선)
      final buildingName = address['building'] ?? 
                          address['amenity'] ?? 
                          address['shop'] ?? 
                          address['house_name'] ?? 
                          address['name'];
      
      // 건물명이 있으면 건물명만 반환, 없으면 도로명 + 번지 반환
      if (buildingName != null && buildingName.toString().trim().isNotEmpty) {
        return buildingName.toString().trim();
      }
      
      // 건물명이 없으면 도로명 + 번지로 대체
      final road = address['road'];
      final houseNumber = address['house_number'];
      if (road != null && road.toString().trim().isNotEmpty) {
        if (houseNumber != null && houseNumber.toString().trim().isNotEmpty) {
          return '${road.toString().trim()} ${houseNumber.toString().trim()}';
        }
        return road.toString().trim();
      }
      
      // 그것도 없으면 전체 display_name의 첫 부분 반환
      final displayName = data['display_name'] ?? '주소 변환 실패';
      final firstPart = displayName.toString().split(',').first.trim();
      return firstPart.isNotEmpty ? firstPart : displayName.toString();
    } catch (e) {
      return '주소 변환 오류: $e';
    }
  }

  /// 검색어 전처리: 특수문자 제거, 띄어쓰기 정규화
  static String _preprocessQuery(String query) {
    String processed = query;

    // 1. 특수문자 제거 (괄호, 쉼표, 마침표 등)
    processed = processed.replaceAll(RegExp(r'[(),.\[\]{}]'), ' ');

    // 2. 불필요한 단어 제거
    final unnecessaryWords = ['번지', '호', '층'];
    for (final word in unnecessaryWords) {
      processed = processed.replaceAll(word, ' ');
    }

    // 3. 연속 공백을 단일 공백으로 정규화
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();

    return processed;
  }

  /// 도로명 주소 우선 정렬
  static List<Map<String, dynamic>> _sortByRoadAddress(List<Map<String, dynamic>> results) {
    final roadAddresses = <Map<String, dynamic>>[];
    final otherAddresses = <Map<String, dynamic>>[];

    for (final result in results) {
      final address = result['address'] as Map<String, dynamic>?;
      if (address != null && address.containsKey('road')) {
        roadAddresses.add(result);
      } else {
        otherAddresses.add(result);
      }
    }

    return [...roadAddresses, ...otherAddresses];
  }

  /// 중복 결과 제거 (같은 좌표의 결과 제거)
  static List<Map<String, dynamic>> _removeDuplicates(List<Map<String, dynamic>> results) {
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];

    for (final result in results) {
      final lat = result['lat']?.toString() ?? '';
      final lon = result['lon']?.toString() ?? '';
      final key = '$lat,$lon';

      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(result);
      }
    }

    return unique;
  }

  /// 유사 주소 검색 (부분 검색)
  static Future<List<Map<String, dynamic>>> _searchSimilarAddress(String query) async {
    try {
      // 검색어를 토큰으로 분리
      final tokens = query.split(' ').where((t) => t.isNotEmpty).toList();

      if (tokens.isEmpty) {
        return [];
      }

      // 마지막 토큰을 제거하고 재검색 (점진적 축소)
      if (tokens.length > 1) {
        tokens.removeLast();
        final partialQuery = tokens.join(' ');

        final uri = Uri.https(_baseUrl, '/search', {
          'format': 'jsonv2',
          'q': '$partialQuery, South Korea',
          'accept-language': 'ko',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'kr',
        });

        final response = await http.get(
          uri,
          headers: {
            'User-Agent': _userAgent,
          },
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// 실제 API 호출 헬퍼 함수
  static Future<List<Map<String, dynamic>>> _performSearch(String searchQuery, {int retryCount = 0}) async {
    final uri = Uri.https(_baseUrl, '/search', {
      'format': 'jsonv2',
      'q': '$searchQuery, South Korea',
      'accept-language': 'ko',
      'addressdetails': '1',
      'limit': '10',
      'countrycodes': 'kr',
    });

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': _userAgent,
      },
    );

    // API 제한 시 재시도 (최대 2번)
    if (response.statusCode == 429 && retryCount < 2) {
      await Future.delayed(Duration(seconds: 1 + retryCount));
      return _performSearch(searchQuery, retryCount: retryCount + 1);
    }

    if (response.statusCode != 200) {
      return [];
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  /// 주소 검색 (정지오코딩)
  static Future<List<Map<String, dynamic>>> searchAddress(String query, {int retryCount = 0}) async {
    try {
      // 검색어 전처리
      final processedQuery = _preprocessQuery(query);

      if (processedQuery.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> allResults = [];

      // "도로명+숫자" 패턴 감지 (예: "도신로31")
      final roadNumberPattern = RegExp(r'^(.+[로길])(\d+)$');
      final match = roadNumberPattern.firstMatch(processedQuery);

      if (match != null) {
        final roadName = match.group(1)!; // "도신로"
        final number = match.group(2)!;   // "31"

        // 전략 1: "도로명+숫자+길" 검색 (예: "도신로31길")
        final query1 = '$roadName$number길';
        final results1 = await _performSearch(query1);
        allResults.addAll(results1);

        // 전략 2: "도로명 숫자" 검색 (번지 주소, 예: "도신로 31")
        final query2 = '$roadName $number';
        final results2 = await _performSearch(query2);
        allResults.addAll(results2);

        // 전략 3: 원본 쿼리 검색
        if (processedQuery != query1 && processedQuery != query2) {
          final results3 = await _performSearch(processedQuery);
          allResults.addAll(results3);
        }
      } else {
        // 일반 검색
        allResults = await _performSearch(processedQuery);
      }

      // 결과가 없을 경우 유사 주소 검색
      if (allResults.isEmpty) {
        allResults = await _searchSimilarAddress(processedQuery);
      }

      // 중복 제거
      allResults = _removeDuplicates(allResults);

      // 도로명 주소 우선 정렬
      allResults = _sortByRoadAddress(allResults);

      return allResults;
    } catch (e) {
      // 네트워크 오류 시 빈 배열 반환
      return [];
    }
  }

  /// 주소를 좌표로 변환 (정지오코딩)
  static Future<LatLng?> geocode(String address) async {
    try {
      final results = await searchAddress(address);
      if (results.isNotEmpty) {
        final lat = double.tryParse(results.first['lat']?.toString() ?? '');
        final lon = double.tryParse(results.first['lon']?.toString() ?? '');
        if (lat != null && lon != null) {
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
