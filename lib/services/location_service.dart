// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // 현재 위치 가져오기
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('위치 서비스가 비활성화되었습니다.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다.');
      }

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('위치 가져오기 오류: $e');
      return null; // 오류 시 null 반환
    }
  }

  // 좌표를 주소로 변환 (동 단위)
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        return place.subLocality ?? '주소 정보 없음'; // 동 단위 주소 반환
      }
      return '주소를 찾을 수 없습니다.';
    } catch (e) {
      print('주소 변환 오류: $e');
      return '주소 변환 실패';
    }
  }

  // 통합: 현재 위치를 주소로 변환 (동 단위)
  static Future<String> getCurrentAddress() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return await getAddressFromCoordinates(position.latitude, position.longitude);
      } else {
        return '위치를 가져올 수 없습니다.';
      }
    } catch (e) {
      print('현재 위치 주소 변환 오류: $e');
      return '주소 변환 실패';
    }
  }
}
