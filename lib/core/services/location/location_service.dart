import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import './nominatim_service.dart';

class LocationService {
  // 현재 위치 가져오기
  static Future<Position?> getCurrentPosition() async {
    try {
      // 웹 플랫폼에서는 HTTPS 요구사항 체크
      if (kIsWeb) {
        debugPrint('웹 환경에서 위치 요청 중... (HTTPS 필수)');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('위치 서비스가 비활성화되었습니다.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kIsWeb) {
            throw Exception('브라우저에서 위치 권한이 거부되었습니다. 브라우저 설정을 확인해주세요.');
          } else {
            throw Exception('위치 권한이 거부되었습니다.');
          }
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kIsWeb) {
          throw Exception('브라우저에서 위치 권한이 차단되었습니다. 브라우저 설정에서 권한을 허용해주세요.');
        } else {
          throw Exception('위치 권한이 영구적으로 거부되었습니다.');
        }
      }

      // geolocator 12.0.0에서는 LocationSettings 대신 직접 파라미터 사용
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      // 위치 가져오기 오류: $e
      return null;
    }
  }

  // 스푸핑 감지(간단): 과도한 속도/급격한 점프 감지
  static bool isSuspectedSpoof({required Position prev, required Position next}) {
    try {
      final meters = Geolocator.distanceBetween(prev.latitude, prev.longitude, next.latitude, next.longitude);
      final dtSec = (next.timestamp?.difference(prev.timestamp ?? DateTime.now()).inSeconds ?? 1).abs();
      if (dtSec == 0) return false;
      final speed = meters / dtSec; // m/s
      // 50 m/s (~180 km/h) 이상이면 의심
      return speed > 50.0;
    } catch (_) {
      return false;
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
        // Nominatim 서비스 사용 (더 안정적)
        try {
          final address = await NominatimService.reverseGeocode(
            LatLng(position.latitude, position.longitude),
          );
          
          // 주소 변환 실패 메시지가 아니면 성공
          if (!address.contains('실패') && !address.contains('오류')) {
            return address;
          }
        } catch (e) {
          debugPrint('⚠️ Nominatim 서비스 실패, geocoding 패키지로 폴백: $e');
        }
        
        // 폴백: geocoding 패키지 사용
        return await getAddressFromCoordinates(position.latitude, position.longitude);
      } else {
        return '위치를 가져올 수 없습니다.';
      }
    } catch (e) {
      debugPrint('❌ 현재 위치 주소 변환 오류: $e');
      return '주소 변환 실패';
    }
  }
}
