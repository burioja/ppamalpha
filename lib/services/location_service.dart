// lib/services/location_service.dart
import 'package:geocoding/geocoding.dart';

Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks.first;
      return '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
    }
    return "주소를 찾을 수 없습니다.";
  } catch (e) {
    return "오류 발생: $e";
  }
}