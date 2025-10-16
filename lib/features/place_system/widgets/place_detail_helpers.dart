import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/utils/logger.dart';

/// 플레이스 상세 화면의 헬퍼 함수들
class PlaceDetailHelpers {
  // 플레이스 데이터 로드
  static Future<PlaceModel?> loadPlace(String placeId) async {
    try {
      final placeService = PlaceService();
      final place = await placeService.getPlaceById(placeId);
      
      if (place != null) {
        Logger.info('📍 Place loaded: ${place.name}');
        Logger.info('🖼️ Has images: ${place.hasImages}');
        Logger.info('🖼️ Image count: ${place.imageUrls.length}');
        
        if (place.imageUrls.isNotEmpty) {
          for (int i = 0; i < place.imageUrls.length; i++) {
            final imageUrl = place.imageUrls[i];
            final preview = imageUrl.length > 100 
                ? '${imageUrl.substring(0, 100)}...' 
                : imageUrl;
            Logger.info('  Image[$i]: $preview');
          }
        }
      }
      
      return place;
    } catch (e) {
      Logger.error('플레이스 로드 실패: $e');
      return null;
    }
  }

  // 전화번호로 전화 걸기
  static Future<void> makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Logger.error('전화 걸기 실패: $phoneNumber');
      }
    } catch (e) {
      Logger.error('전화 걸기 중 오류: $e');
    }
  }

  // 이메일 보내기
  static Future<void> sendEmail(String email) async {
    try {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=문의사항',
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        Logger.error('이메일 보내기 실패: $email');
      }
    } catch (e) {
      Logger.error('이메일 보내기 중 오류: $e');
    }
  }

  // 웹사이트 열기
  static Future<void> openWebsite(String url) async {
    try {
      // URL이 http:// 또는 https://로 시작하지 않으면 https://를 추가
      String formattedUrl = url;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        formattedUrl = 'https://$url';
      }
      
      final Uri websiteUri = Uri.parse(formattedUrl);
      if (await canLaunchUrl(websiteUri)) {
        await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
      } else {
        Logger.error('웹사이트 열기 실패: $url');
      }
    } catch (e) {
      Logger.error('웹사이트 열기 중 오류: $e');
    }
  }

  // 지도에서 위치 보기
  static Future<void> openInMap(double latitude, double longitude, String placeName) async {
    try {
      // Google Maps URL 생성
      final Uri mapUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude&query_place_id=$placeName'
      );
      
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      } else {
        Logger.error('지도 열기 실패: $latitude, $longitude');
      }
    } catch (e) {
      Logger.error('지도 열기 중 오류: $e');
    }
  }

  // 운영시간 포맷팅
  static String formatOperatingHours(Map<String, dynamic>? operatingHours) {
    if (operatingHours == null || operatingHours.isEmpty) {
      return '운영시간 정보 없음';
    }

    final List<String> formattedHours = [];
    
    // 요일 순서 정의
    const List<String> weekdays = [
      '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'
    ];

    for (final weekday in weekdays) {
      if (operatingHours.containsKey(weekday)) {
        final hours = operatingHours[weekday]?.toString() ?? '';
        if (hours.isNotEmpty && hours != '휴무') {
          formattedHours.add('$weekday: $hours');
        } else if (hours == '휴무') {
          formattedHours.add('$weekday: 휴무');
        }
      }
    }

    return formattedHours.isEmpty ? '운영시간 정보 없음' : formattedHours.join('\n');
  }

  // 정기 휴일 포맷팅
  static String formatRegularHolidays(List<String>? holidays) {
    if (holidays == null || holidays.isEmpty) {
      return '정기 휴일 없음';
    }
    return holidays.join(', ');
  }

  // 휴게시간 포맷팅
  static String formatBreakTimes(Map<String, String>? breakTimes) {
    if (breakTimes == null || breakTimes.isEmpty) {
      return '휴게시간 없음';
    }

    final List<String> formattedBreaks = [];
    breakTimes.forEach((key, value) {
      if (value.isNotEmpty) {
        formattedBreaks.add('$key: $value');
      }
    });

    return formattedBreaks.isEmpty ? '휴게시간 없음' : formattedBreaks.join('\n');
  }

  // 편의시설 포맷팅
  static String formatFacilities(List<String>? facilities) {
    if (facilities == null || facilities.isEmpty) {
      return '편의시설 정보 없음';
    }
    return facilities.join(', ');
  }

  // 결제수단 포맷팅
  static String formatPaymentMethods(List<String>? paymentMethods) {
    if (paymentMethods == null || paymentMethods.isEmpty) {
      return '결제수단 정보 없음';
    }
    return paymentMethods.join(', ');
  }

  // 주차 정보 포맷팅
  static String formatParkingInfo({
    String? parkingType,
    int? parkingCapacity,
    String? parkingFee,
    bool? hasValetParking,
  }) {
    final List<String> parkingInfo = [];

    if (parkingType != null && parkingType.isNotEmpty) {
      parkingInfo.add('주차 유형: $parkingType');
    }

    if (parkingCapacity != null && parkingCapacity > 0) {
      parkingInfo.add('주차 대수: ${parkingCapacity}대');
    }

    if (parkingFee != null && parkingFee.isNotEmpty) {
      parkingInfo.add('주차 요금: $parkingFee');
    }

    if (hasValetParking == true) {
      parkingInfo.add('발렛파킹: 가능');
    }

    return parkingInfo.isEmpty ? '주차 정보 없음' : parkingInfo.join('\n');
  }

  // 접근성 정보 포맷팅
  static String formatAccessibility(List<String>? accessibility) {
    if (accessibility == null || accessibility.isEmpty) {
      return '접근성 정보 없음';
    }
    return accessibility.join(', ');
  }

  // 가격대 포맷팅
  static String formatPriceRange(String? priceRange) {
    if (priceRange == null || priceRange.isEmpty) {
      return '가격대 정보 없음';
    }
    return priceRange;
  }

  // 수용인원 포맷팅
  static String formatCapacity(int? capacity) {
    if (capacity == null || capacity <= 0) {
      return '수용인원 정보 없음';
    }
    return '${capacity}명';
  }

  // 면적 포맷팅
  static String formatAreaSize(String? areaSize) {
    if (areaSize == null || areaSize.isEmpty) {
      return '면적 정보 없음';
    }
    return areaSize;
  }

  // 층수 포맷팅
  static String formatFloor(String? floor) {
    if (floor == null || floor.isEmpty) {
      return '층수 정보 없음';
    }
    return floor;
  }

  // 건물명 포맷팅
  static String formatBuildingName(String? buildingName) {
    if (buildingName == null || buildingName.isEmpty) {
      return '건물명 정보 없음';
    }
    return buildingName;
  }

  // 랜드마크 포맷팅
  static String formatLandmark(String? landmark) {
    if (landmark == null || landmark.isEmpty) {
      return '랜드마크 정보 없음';
    }
    return landmark;
  }

  // 예약 시스템 정보 포맷팅
  static String formatReservationInfo({
    bool? hasReservation,
    String? reservationUrl,
    String? reservationPhone,
  }) {
    if (hasReservation != true) {
      return '예약 시스템 없음';
    }

    final List<String> reservationInfo = ['예약 가능'];
    
    if (reservationUrl != null && reservationUrl.isNotEmpty) {
      reservationInfo.add('예약 URL: $reservationUrl');
    }
    
    if (reservationPhone != null && reservationPhone.isNotEmpty) {
      reservationInfo.add('예약 전화: $reservationPhone');
    }

    return reservationInfo.join('\n');
  }

  // 임시 휴업 정보 포맷팅
  static String formatTemporaryClosure({
    bool? isTemporarilyClosed,
    DateTime? reopeningDate,
    String? closureReason,
  }) {
    if (isTemporarilyClosed != true) {
      return '정상 운영';
    }

    final List<String> closureInfo = ['임시 휴업'];
    
    if (reopeningDate != null) {
      final formattedDate = '${reopeningDate.year}년 ${reopeningDate.month}월 ${reopeningDate.day}일';
      closureInfo.add('재개 예정일: $formattedDate');
    }
    
    if (closureReason != null && closureReason.isNotEmpty) {
      closureInfo.add('휴업 사유: $closureReason');
    }

    return closureInfo.join('\n');
  }

  // 가상투어 URL 포맷팅
  static String formatVirtualTour(String? virtualTourUrl) {
    if (virtualTourUrl == null || virtualTourUrl.isEmpty) {
      return '가상투어 없음';
    }
    return virtualTourUrl;
  }

  // 쿠폰 정보 포맷팅
  static String formatCouponInfo({
    bool? enableCoupon,
    String? couponPassword,
  }) {
    if (enableCoupon != true) {
      return '쿠폰 사용 불가';
    }
    
    if (couponPassword != null && couponPassword.isNotEmpty) {
      return '쿠폰 사용 가능 (암호: $couponPassword)';
    }
    
    return '쿠폰 사용 가능';
  }

  // 거리 계산 (미터 단위)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  // 거리 포맷팅
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  // 평점 포맷팅
  static String formatRating(double? rating) {
    if (rating == null) {
      return '평점 없음';
    }
    return '${rating.toStringAsFixed(1)}/5.0';
  }

  // 리뷰 수 포맷팅
  static String formatReviewCount(int? reviewCount) {
    if (reviewCount == null || reviewCount == 0) {
      return '리뷰 없음';
    }
    return '리뷰 ${reviewCount}개';
  }

  // 생성일 포맷팅
  static String formatCreatedAt(DateTime? createdAt) {
    if (createdAt == null) {
      return '생성일 정보 없음';
    }
    return '${createdAt.year}년 ${createdAt.month}월 ${createdAt.day}일';
  }

  // 업데이트일 포맷팅
  static String formatUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) {
      return '업데이트일 정보 없음';
    }
    return '${updatedAt.year}년 ${updatedAt.month}월 ${updatedAt.day}일';
  }

  // 상태 포맷팅
  static String formatStatus(String? status) {
    if (status == null || status.isEmpty) {
      return '상태 정보 없음';
    }
    return status;
  }

  // 소유자 ID 포맷팅
  static String formatOwnerId(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) {
      return '소유자 정보 없음';
    }
    return ownerId;
  }

  // 위치 정보 포맷팅
  static String formatLocation(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return '위치 정보 없음';
    }
    return '위도: ${latitude.toStringAsFixed(6)}, 경도: ${longitude.toStringAsFixed(6)}';
  }

  // 이미지 URL 유효성 검사
  static bool isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // 이미지 로딩 에러 처리
  static Widget buildImageErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }

  // 이미지 로딩 위젯
  static Widget buildImageLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 빈 이미지 위젯
  static Widget buildEmptyImageWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }

  // 지도 마커 생성
  static Marker buildMapMarker({
    required double latitude,
    required double longitude,
    required String placeName,
  }) {
    return Marker(
      point: LatLng(latitude, longitude),
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.location_on,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  // 지도 타일 레이어 생성
  static TileLayer buildTileLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.ppamalpha',
      maxZoom: 18,
    );
  }

  // 지도 컨트롤러 설정
  static MapController createMapController() {
    return MapController();
  }

  // 지도 중심점 설정
  static LatLngBounds createMapBounds(double latitude, double longitude) {
    const double offset = 0.001; // 약 100m
    return LatLngBounds(
      LatLng(latitude - offset, longitude - offset),
      LatLng(latitude + offset, longitude + offset),
    );
  }

  // 지도 줌 레벨 설정
  static double getMapZoom() {
    return 16.0;
  }

  // 지도 높이 설정
  static double getMapHeight() {
    return 200.0;
  }

  // 지도 테두리 반지름 설정
  static double getMapBorderRadius() {
    return 12.0;
  }

  // 지도 마커 크기 설정
  static double getMarkerSize() {
    return 40.0;
  }

  // 지도 마커 아이콘 크기 설정
  static double getMarkerIconSize() {
    return 20.0;
  }

  // 지도 마커 테두리 두께 설정
  static double getMarkerBorderWidth() {
    return 2.0;
  }

  // 지도 마커 그림자 블러 반지름 설정
  static double getMarkerShadowBlur() {
    return 4.0;
  }

  // 지도 마커 그림자 오프셋 설정
  static Offset getMarkerShadowOffset() {
    return const Offset(0, 2);
  }

  // 지도 마커 그림자 투명도 설정
  static double getMarkerShadowOpacity() {
    return 0.3;
  }

  // 지도 마커 색상 설정
  static Color getMarkerColor() {
    return Colors.red;
  }

  // 지도 마커 테두리 색상 설정
  static Color getMarkerBorderColor() {
    return Colors.white;
  }

  // 지도 마커 아이콘 색상 설정
  static Color getMarkerIconColor() {
    return Colors.white;
  }

  // 지도 마커 아이콘 설정
  static IconData getMarkerIcon() {
    return Icons.location_on;
  }

  // 지도 타일 URL 템플릿 설정
  static String getTileUrlTemplate() {
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  // 지도 사용자 에이전트 패키지명 설정
  static String getUserAgentPackageName() {
    return 'com.example.ppamalpha';
  }

  // 지도 최대 줌 레벨 설정
  static int getMaxZoom() {
    return 18;
  }

  // 지도 오프셋 설정
  static double getMapOffset() {
    return 0.001; // 약 100m
  }

  // 지도 줌 레벨 범위 설정
  static double getMapZoomRange() {
    return 16.0;
  }

  // 지도 높이 범위 설정
  static double getMapHeightRange() {
    return 200.0;
  }

  // 지도 테두리 반지름 범위 설정
  static double getMapBorderRadiusRange() {
    return 12.0;
  }

  // 지도 마커 크기 범위 설정
  static double getMarkerSizeRange() {
    return 40.0;
  }

  // 지도 마커 아이콘 크기 범위 설정
  static double getMarkerIconSizeRange() {
    return 20.0;
  }

  // 지도 마커 테두리 두께 범위 설정
  static double getMarkerBorderWidthRange() {
    return 2.0;
  }

  // 지도 마커 그림자 블러 반지름 범위 설정
  static double getMarkerShadowBlurRange() {
    return 4.0;
  }

  // 지도 마커 그림자 오프셋 범위 설정
  static Offset getMarkerShadowOffsetRange() {
    return const Offset(0, 2);
  }

  // 지도 마커 그림자 투명도 범위 설정
  static double getMarkerShadowOpacityRange() {
    return 0.3;
  }

  // 지도 마커 색상 범위 설정
  static Color getMarkerColorRange() {
    return Colors.red;
  }

  // 지도 마커 테두리 색상 범위 설정
  static Color getMarkerBorderColorRange() {
    return Colors.white;
  }

  // 지도 마커 아이콘 색상 범위 설정
  static Color getMarkerIconColorRange() {
    return Colors.white;
  }

  // 지도 마커 아이콘 범위 설정
  static IconData getMarkerIconRange() {
    return Icons.location_on;
  }

  // 지도 타일 URL 템플릿 범위 설정
  static String getTileUrlTemplateRange() {
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  // 지도 사용자 에이전트 패키지명 범위 설정
  static String getUserAgentPackageNameRange() {
    return 'com.example.ppamalpha';
  }

  // 지도 최대 줌 레벨 범위 설정
  static int getMaxZoomRange() {
    return 18;
  }

  // 지도 오프셋 범위 설정
  static double getMapOffsetRange() {
    return 0.001; // 약 100m
  }
}

