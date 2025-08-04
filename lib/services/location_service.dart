import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // ?�재 ?�치 가?�오�?
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('?�치 ?�비?��? 비활?�화?�었?�니??');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('?�치 권한??거�??�었?�니??');
      }

      if (permission == LocationPermission.deniedForever) throw Exception('?�치 권한???�구?�으�?거�??�었?�니??');

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      // ?�치 가?�오�??�류: $e
      return null;
    }
  }

  // 좌표�?주소�?변??
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        return place.subLocality ?? place.locality ?? '주소 ?�보 ?�음';
      }
      return '주소�?찾을 ???�습?�다.';
    } catch (e) {
      // 주소 변???�류: $e
      return '주소 변???�패';
    }
  }

  // ?�합: ?�재 ?�치�?주소�?변??
  static Future<String> getCurrentAddress() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return await getAddressFromCoordinates(position.latitude, position.longitude);
      } else {
        return '?�치�?가?�올 ???�습?�다.';
      }
    } catch (e) {
      // ?�재 ?�치 주소 변???�류: $e
      return '주소 변???�패';
    }
  }
}
