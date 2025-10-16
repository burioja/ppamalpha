import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/place/place_model.dart';
import 'place_detail_helpers.dart';

/// 플레이스 상세 화면의 UI 위젯들
class PlaceDetailWidgets {
  // 플레이스 헤더 위젯
  static Widget buildPlaceHeader({
    required PlaceModel place,
    required int currentImageIndex,
    required PageController pageController,
    required Function(int) onImageChanged,
  }) {
    return Container(
      height: 300,
      child: Stack(
        children: [
          // 이미지 캐러셀
          if (place.imageUrls.isNotEmpty)
            PageView.builder(
              controller: pageController,
              onPageChanged: onImageChanged,
              itemCount: place.imageUrls.length,
              itemBuilder: (context, index) {
                return _buildImageWidget(place.imageUrls[index]);
              },
            )
          else
            PlaceDetailHelpers.buildEmptyImageWidget(),
          
          // 이미지 인디케이터
          if (place.imageUrls.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: _buildImageIndicator(
                place.imageUrls.length,
                currentImageIndex,
              ),
            ),
          
          // 플레이스 정보 오버레이
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildPlaceInfoOverlay(place),
          ),
        ],
      ),
    );
  }

  // 이미지 위젯
  static Widget _buildImageWidget(String imageUrl) {
    if (!PlaceDetailHelpers.isValidImageUrl(imageUrl)) {
      return PlaceDetailHelpers.buildImageErrorWidget();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return PlaceDetailHelpers.buildImageLoadingWidget();
      },
      errorBuilder: (context, error, stackTrace) {
        return PlaceDetailHelpers.buildImageErrorWidget();
      },
    );
  }

  // 이미지 인디케이터
  static Widget _buildImageIndicator(int totalImages, int currentIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalImages,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // 플레이스 정보 오버레이
  static Widget _buildPlaceInfoOverlay(PlaceModel place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            place.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (place.category != null) ...[
            const SizedBox(height: 4),
            Text(
              place.category!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
          if (place.address != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    place.address!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 기본 정보 섹션
  static Widget buildBasicInfoSection(PlaceModel place) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기본 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (place.description != null && place.description!.isNotEmpty)
              _buildInfoRow('설명', place.description!),
            
            if (place.category != null)
              _buildInfoRow('카테고리', place.category!),
            
            if (place.address != null)
              _buildInfoRow('주소', place.address!),
            
            if (place.detailAddress != null && place.detailAddress!.isNotEmpty)
              _buildInfoRow('상세주소', place.detailAddress!),
            
            if (place.contactInfo?['phone'] != null && place.contactInfo!['phone']!.toString().isNotEmpty)
              _buildInfoRow('전화번호', place.contactInfo!['phone']!.toString()),
            
            if (place.contactInfo?['email'] != null && place.contactInfo!['email']!.toString().isNotEmpty)
              _buildInfoRow('이메일', place.contactInfo!['email']!.toString()),
          ],
        ),
      ),
    );
  }

  // 운영 정보 섹션
  static Widget buildOperatingInfoSection(PlaceModel place) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '운영 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              '운영시간',
              PlaceDetailHelpers.formatOperatingHours(place.operatingHours),
            ),
            
            if (place.isOpen24Hours == true)
              _buildInfoRow('24시간 운영', '예'),
            
            _buildInfoRow(
              '정기 휴일',
              PlaceDetailHelpers.formatRegularHolidays(place.regularHolidays),
            ),
            
            _buildInfoRow(
              '휴게시간',
              PlaceDetailHelpers.formatBreakTimes(place.breakTimes),
            ),
            
            _buildInfoRow(
              '편의시설',
              PlaceDetailHelpers.formatFacilities(place.facilities),
            ),
            
            _buildInfoRow(
              '결제수단',
              PlaceDetailHelpers.formatPaymentMethods(place.paymentMethods),
            ),
            
            _buildInfoRow(
              '주차 정보',
              PlaceDetailHelpers.formatParkingInfo(
                parkingType: place.parkingType,
                parkingCapacity: place.parkingCapacity,
                parkingFee: place.parkingFee,
                hasValetParking: place.hasValetParking,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 추가 정보 섹션
  static Widget buildAdditionalInfoSection(PlaceModel place) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '추가 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow(
              '접근성',
              PlaceDetailHelpers.formatAccessibility(place.accessibility),
            ),
            
            _buildInfoRow(
              '가격대',
              PlaceDetailHelpers.formatPriceRange(place.priceRange),
            ),
            
            _buildInfoRow(
              '수용인원',
              PlaceDetailHelpers.formatCapacity(place.capacity),
            ),
            
            _buildInfoRow(
              '면적',
              PlaceDetailHelpers.formatAreaSize(place.areaSize),
            ),
            
            _buildInfoRow(
              '층수',
              PlaceDetailHelpers.formatFloor(place.floor),
            ),
            
            _buildInfoRow(
              '건물명',
              PlaceDetailHelpers.formatBuildingName(place.buildingName),
            ),
            
            _buildInfoRow(
              '랜드마크',
              PlaceDetailHelpers.formatLandmark(place.landmark),
            ),
            
            _buildInfoRow(
              '예약 시스템',
              PlaceDetailHelpers.formatReservationInfo(
                hasReservation: place.hasReservation,
                reservationUrl: place.reservationUrl,
                reservationPhone: place.reservationPhone,
              ),
            ),
            
            _buildInfoRow(
              '임시 휴업',
              PlaceDetailHelpers.formatTemporaryClosure(
                isTemporarilyClosed: place.isTemporarilyClosed,
                reopeningDate: place.reopeningDate,
                closureReason: place.closureReason,
              ),
            ),
            
            _buildInfoRow(
              '가상투어',
              PlaceDetailHelpers.formatVirtualTour(place.virtualTourUrl),
            ),
            
            _buildInfoRow(
              '쿠폰 정보',
              PlaceDetailHelpers.formatCouponInfo(
                enableCoupon: place.isCouponEnabled,
                couponPassword: place.couponPassword,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 지도 섹션
  static Widget buildMapSection(PlaceModel place) {
    if (place.location == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                '위치 정보',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('위치 정보가 없습니다.'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '위치 정보',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // 지도
            Container(
              height: PlaceDetailHelpers.getMapHeight(),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PlaceDetailHelpers.getMapBorderRadius()),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(PlaceDetailHelpers.getMapBorderRadius()),
                child: FlutterMap(
                  mapController: PlaceDetailHelpers.createMapController(),
                  options: MapOptions(
                    initialCenter: LatLng(place.location!.latitude, place.location!.longitude),
                    initialZoom: PlaceDetailHelpers.getMapZoom(),
                  ),
                  children: [
                    PlaceDetailHelpers.buildTileLayer(),
                    MarkerLayer(
                      markers: [
                        PlaceDetailHelpers.buildMapMarker(
                          latitude: place.location!.latitude,
                          longitude: place.location!.longitude,
                          placeName: place.name,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 위치 정보 텍스트
            _buildInfoRow(
              '위치',
              PlaceDetailHelpers.formatLocation(
                place.location!.latitude,
                place.location!.longitude,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 액션 버튼들
  static Widget buildActionButtons(PlaceModel place) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (place.contactInfo?['phone'] != null && place.contactInfo!['phone']!.toString().isNotEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => PlaceDetailHelpers.makePhoneCall(place.contactInfo!['phone']!.toString()),
                icon: const Icon(Icons.phone),
                label: const Text('전화걸기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          
          if (place.contactInfo?['phone'] != null && place.contactInfo!['phone']!.toString().isNotEmpty && 
              place.contactInfo?['email'] != null && place.contactInfo!['email']!.toString().isNotEmpty)
            const SizedBox(width: 8),
          
          if (place.contactInfo?['email'] != null && place.contactInfo!['email']!.toString().isNotEmpty)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => PlaceDetailHelpers.sendEmail(place.contactInfo!['email']!.toString()),
                icon: const Icon(Icons.email),
                label: const Text('이메일'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          
          if ((place.contactInfo?['phone'] != null && place.contactInfo!['phone']!.toString().isNotEmpty) || 
              (place.contactInfo?['email'] != null && place.contactInfo!['email']!.toString().isNotEmpty))
            const SizedBox(width: 8),
          
          if (place.location != null)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => PlaceDetailHelpers.openInMap(
                  place.location!.latitude,
                  place.location!.longitude,
                  place.name,
                ),
                icon: const Icon(Icons.map),
                label: const Text('지도에서 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 정보 행 위젯
  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 로딩 위젯
  static Widget buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('플레이스 정보를 불러오는 중...'),
        ],
      ),
    );
  }

  // 에러 위젯
  static Widget buildErrorWidget(String message, VoidCallback? onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            '오류 발생',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  // 빈 상태 위젯
  static Widget buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '플레이스 없음',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 섹션 헤더 위젯
  static Widget buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 정보 카드 위젯
  static Widget buildInfoCard({
    required String title,
    required String content,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Colors.blue, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // 설정 항목 위젯
  static Widget buildSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // 스위치 설정 항목 위젯
  static Widget buildSwitchSettingItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  // 정보 행 위젯 (공개)
  static Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

