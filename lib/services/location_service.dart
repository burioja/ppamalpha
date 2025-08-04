import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // ?„ì¬ ?„ì¹˜ ê°€?¸ì˜¤ê¸?
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('?„ì¹˜ ?œë¹„?¤ê? ë¹„í™œ?±í™”?˜ì—ˆ?µë‹ˆ??');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('?„ì¹˜ ê¶Œí•œ??ê±°ë??˜ì—ˆ?µë‹ˆ??');
      }

      if (permission == LocationPermission.deniedForever) throw Exception('?„ì¹˜ ê¶Œí•œ???êµ¬?ìœ¼ë¡?ê±°ë??˜ì—ˆ?µë‹ˆ??');

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      // ?„ì¹˜ ê°€?¸ì˜¤ê¸??¤ë¥˜: $e
      return null;
    }
  }

  // ì¢Œí‘œë¥?ì£¼ì†Œë¡?ë³€??
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        return place.subLocality ?? place.locality ?? 'ì£¼ì†Œ ?•ë³´ ?†ìŒ';
      }
      return 'ì£¼ì†Œë¥?ì°¾ì„ ???†ìŠµ?ˆë‹¤.';
    } catch (e) {
      // ì£¼ì†Œ ë³€???¤ë¥˜: $e
      return 'ì£¼ì†Œ ë³€???¤íŒ¨';
    }
  }

  // ?µí•©: ?„ì¬ ?„ì¹˜ë¥?ì£¼ì†Œë¡?ë³€??
  static Future<String> getCurrentAddress() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return await getAddressFromCoordinates(position.latitude, position.longitude);
      } else {
        return '?„ì¹˜ë¥?ê°€?¸ì˜¬ ???†ìŠµ?ˆë‹¤.';
      }
    } catch (e) {
      // ?„ì¬ ?„ì¹˜ ì£¼ì†Œ ë³€???¤ë¥˜: $e
      return 'ì£¼ì†Œ ë³€???¤íŒ¨';
    }
  }
}
