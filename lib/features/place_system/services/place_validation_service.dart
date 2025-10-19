import 'package:latlong2/latlong.dart';

/// 장소 유효성 검증 서비스
/// 
/// **책임**: 장소 데이터 유효성 검증
/// **원칙**: 순수 비즈니스 로직만
class PlaceValidationService {
  // ==================== 유효성 검증 ====================

  /// 장소 정보 전체 유효성 검증
  /// 
  /// Returns: (isValid, errors)
  static (bool, List<String>) validatePlace({
    required String buildingName,
    required String address,
    required LatLng? location,
    String? detailAddress,
    String? phoneNumber,
    Map<String, String>? businessHours,
  }) {
    final errors = <String>[];

    // 건물명 검증
    final buildingNameError = validateBuildingName(buildingName);
    if (buildingNameError != null) errors.add(buildingNameError);

    // 주소 검증
    final addressError = validateAddress(address);
    if (addressError != null) errors.add(addressError);

    // 위치 검증
    final locationError = validateLocation(location);
    if (locationError != null) errors.add(locationError);

    // 전화번호 검증 (옵션)
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      final phoneError = validatePhoneNumber(phoneNumber);
      if (phoneError != null) errors.add(phoneError);
    }

    // 운영시간 검증 (옵션)
    if (businessHours != null && businessHours.isNotEmpty) {
      final hoursError = validateBusinessHours(businessHours);
      if (hoursError != null) errors.add(hoursError);
    }

    return (errors.isEmpty, errors);
  }

  /// 건물명 검증
  static String? validateBuildingName(String name) {
    if (name.trim().isEmpty) {
      return '건물명을 입력해주세요';
    }
    
    if (name.length < 2) {
      return '건물명은 2자 이상이어야 합니다';
    }
    
    if (name.length > 100) {
      return '건물명은 100자 이하여야 합니다';
    }
    
    return null;
  }

  /// 주소 검증
  static String? validateAddress(String address) {
    if (address.trim().isEmpty) {
      return '주소를 입력해주세요';
    }
    
    if (address.length < 5) {
      return '올바른 주소를 입력해주세요';
    }
    
    if (address.length > 200) {
      return '주소는 200자 이하여야 합니다';
    }
    
    return null;
  }

  /// 위치 검증
  static String? validateLocation(LatLng? location) {
    if (location == null) {
      return '위치를 선택해주세요';
    }
    
    // 한국 영역 확인 (대략)
    if (location.latitude < 33.0 || location.latitude > 39.0) {
      return '한국 영역 내 위치를 선택해주세요';
    }
    
    if (location.longitude < 124.0 || location.longitude > 132.0) {
      return '한국 영역 내 위치를 선택해주세요';
    }
    
    return null;
  }

  /// 전화번호 검증
  static String? validatePhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.length < 9 || cleaned.length > 11) {
      return '올바른 전화번호 형식이 아닙니다';
    }
    
    // 한국 전화번호 패턴 (02, 010 등)
    if (!RegExp(r'^(02|0[3-9]{1}[0-9]{1}|01[0-9]{1})[0-9]{3,4}[0-9]{4}$')
        .hasMatch(cleaned)) {
      return '올바른 한국 전화번호를 입력해주세요';
    }
    
    return null;
  }

  /// 운영시간 검증
  static String? validateBusinessHours(Map<String, String> hours) {
    if (hours.isEmpty) {
      return null; // 운영시간은 선택사항
    }

    for (final entry in hours.entries) {
      final time = entry.value;
      
      // "09:00-18:00" 형식 확인
      if (!RegExp(r'^\d{2}:\d{2}-\d{2}:\d{2}$').hasMatch(time)) {
        return '운영시간 형식이 올바르지 않습니다 (예: 09:00-18:00)';
      }
    }
    
    return null;
  }

  // ==================== 데이터 정규화 ====================

  /// 건물명 정규화
  static String normalizeBuildingName(String name) {
    return name.trim();
  }

  /// 주소 정규화
  static String normalizeAddress(String address) {
    return address.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 전화번호 정규화 (하이픈 제거)
  static String normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// 전화번호 포맷 (010-1234-5678)
  static String formatPhoneNumber(String phone) {
    final cleaned = normalizePhoneNumber(phone);
    
    if (cleaned.length == 10) {
      // 02-1234-5678
      return '${cleaned.substring(0, 2)}-${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11) {
      // 010-1234-5678
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    
    return phone;
  }
}

