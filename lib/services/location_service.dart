import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  // 현재 위치 가져오기 (GeoPoint 반환)
  static Future<GeoPoint?> getCurrentLocation() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return GeoPoint(position.latitude, position.longitude);
      }
      return null;
    } catch (e) {
      // 위치 가져오기 오류: $e
      return null;
    }
  }

  // 현재 위치 가져오기
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('위치 서비스가 비활성화되었습니다.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('위치 권한이 거부되었습니다.');
      }

      if (permission == LocationPermission.deniedForever) throw Exception('위치 권한이 영구적으로 거부되었습니다.');

      return await Geolocator.getCurrentPosition();
    } catch (e) {
      // 위치 가져오기 오류: $e
      return null;
    }
  }

  // 좌표에서 주소로 변환 (상세 주소)
  static Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        
        // 상세 주소 구성
        List<String> addressParts = [];
        
        // 건물명이 있으면 추가
        if (place.name != null && place.name!.isNotEmpty && place.name != place.street) {
          addressParts.add(place.name!);
        }
        
        // 도로명 주소
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        
        // 건물번호
        if (place.subThoroughfare != null && place.subThoroughfare!.isNotEmpty) {
          addressParts.add(place.subThoroughfare!);
        }
        
        // 동/읍/면
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        
        // 구/군
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        
        // 시/도
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        
        // 우편번호
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add('(${place.postalCode})');
        }
        
        // 주소 구성
        if (addressParts.isNotEmpty) {
          return addressParts.join(' ');
        } else {
          // 기본 주소 (기존 방식)
          return place.subLocality ?? place.locality ?? '주소 정보 없음';
        }
      }
      return '주소를 찾을 수 없습니다.';
    } catch (e) {
      // 주소 변환 오류: $e
      return '주소 변환 실패';
    }
  }

  // 통합: 현재 위치를 주소로 변환
  static Future<String> getCurrentAddress() async {
    try {
      Position? position = await getCurrentPosition();
      if (position != null) {
        return await getAddressFromCoordinates(position.latitude, position.longitude);
      } else {
        return '위치를 가져올 수 없습니다.';
      }
    } catch (e) {
      // 현재 위치 주소 변환 오류: $e
      return '주소 변환 실패';
    }
  }
}
