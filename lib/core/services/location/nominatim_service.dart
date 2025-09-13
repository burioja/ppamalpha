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

      // 한국식 가독 포맷 (넓은 범위 → 세부)
      final parts = [
        address['state'], // 시/도
        address['county'] ?? address['city'] ?? address['town'] ?? address['municipality'], // 시/군/구
        address['suburb'] ?? address['village'] ?? address['neighbourhood'], // 동/읍/면
        address['road'], // 도로명
        address['house_number'], // 건물번호
      ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

      return parts.isEmpty 
          ? (data['display_name'] ?? '주소 변환 실패')
          : parts.join(' ');
    } catch (e) {
      return '주소 변환 오류: $e';
    }
  }

  /// 주소 검색 (정지오코딩)
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    try {
      final uri = Uri.https(_baseUrl, '/search', {
        'format': 'jsonv2',
        'q': query,
        'accept-language': 'ko',
        'addressdetails': '1',
        'limit': '10',
      });

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
        },
      );

      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
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
