import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final String placeId;

  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final PlaceService _placeService = PlaceService();
  Future<PlaceModel?>? _placeFuture; // Future 캐싱
  PageController? _pageController; // 이미지 캐러셀 컨트롤러 (nullable)
  int _currentImageIndex = 0; // 현재 이미지 인덱스

  @override
  void initState() {
    super.initState();
    // initState에서 Future를 한 번만 생성
    _placeFuture = _loadPlace();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<PlaceModel?> _loadPlace() async {
    final place = await _placeService.getPlaceById(widget.placeId);
    if (place != null) {
      debugPrint('📍 Place loaded: ${place.name}');
      debugPrint('🖼️ Has images: ${place.hasImages}');
      debugPrint('🖼️ Image count: ${place.imageUrls.length}');
      if (place.imageUrls.isNotEmpty) {
        for (int i = 0; i < place.imageUrls.length; i++) {
          debugPrint('  Image[$i]: ${place.imageUrls[i].substring(0, place.imageUrls[i].length > 100 ? 100 : place.imageUrls[i].length)}...');
        }
      }
    }
    return place;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlaceModel?>(
      future: _placeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('플레이스 상세')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('플레이스 로드 오류', style: TextStyle(fontSize: 18, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('플레이스 상세')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('플레이스를 찾을 수 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
        } else {
          final place = snapshot.data!;
          return _buildGooglePlaceStyleUI(place);
        }
      },
    );
  }

  // Google Place 스타일 UI (Store 화면 참조)
  Widget _buildGooglePlaceStyleUI(PlaceModel place) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 상단 이미지 슬라이더 앱바
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            title: Text(place.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPlace(context),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _sharePlace(context, place),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight,
                ),
                child: _buildImageSlider(place),
              ),
            ),
          ),

          // 플레이스 정보 섹션
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlaceHeader(place),
                  const SizedBox(height: 24),
                  if (place.location != null) ...[
                    _buildPlaceMap(place),
                    const SizedBox(height: 24),
                  ],
                  _buildOperatingHours(place),
                  const SizedBox(height: 24),
                  _buildContactInfo(place),
                  const SizedBox(height: 24),
                  // Phase 1 새 섹션들
                  if (place.parkingType != null || place.facilities.isNotEmpty) ...[
                    _buildParkingInfo(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.facilities.isNotEmpty) ...[
                    _buildFacilities(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.paymentMethods.isNotEmpty) ...[
                    _buildPaymentMethods(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.socialMedia != null && place.socialMedia!.isNotEmpty) ...[
                    _buildSocialMedia(place),
                    const SizedBox(height: 24),
                  ],
                  // Phase 2 섹션들
                  if (place.accessibility != null && place.accessibility!.isNotEmpty) ...[
                    _buildAccessibility(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.priceRange != null || place.capacity != null || place.areaSize != null) ...[
                    _buildCapacityInfo(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.floor != null || place.buildingName != null || place.landmark != null) ...[
                    _buildLocationDetails(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.nearbyTransit != null && place.nearbyTransit!.isNotEmpty) ...[
                    _buildTransitInfo(place),
                    const SizedBox(height: 24),
                  ],
                  // Phase 3 섹션들
                  if (place.isTemporarilyClosed) ...[
                    _buildClosureBanner(place),
                    const SizedBox(height: 24),
                  ],
                  if ((place.certifications != null && place.certifications!.isNotEmpty) ||
                      (place.awards != null && place.awards!.isNotEmpty)) ...[
                    _buildCertificationsAndAwards(place),
                    const SizedBox(height: 24),
                  ],
                  if (place.hasReservation) ...[
                    _buildReservationInfo(place),
                    const SizedBox(height: 24),
                  ],
                  if ((place.videoUrls != null && place.videoUrls!.isNotEmpty) ||
                      place.virtualTourUrl != null ||
                      (place.interiorImageUrls != null && place.interiorImageUrls!.isNotEmpty) ||
                      (place.exteriorImageUrls != null && place.exteriorImageUrls!.isNotEmpty)) ...[
                    _buildMediaGallery(place),
                    const SizedBox(height: 24),
                  ],
                  _buildActionButtons(context, place),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 이미지 슬라이더 위젯
  Widget _buildImageSlider(PlaceModel place) {
    if (!place.hasImages) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '등록된 사진이 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // PageController 초기화 (이미지가 있을 때만)
    _pageController ??= PageController(initialPage: 0);

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: place.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final imageUrl = place.imageUrls[index];
            debugPrint('🖼️ Loading image[$index]: $imageUrl');

            return Image.network(
              imageUrl,
              key: ValueKey('place_image_${place.id}_$index'),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  debugPrint('✅ Image loaded successfully[$index]');
                  return child;
                }
                debugPrint('⏳ Loading image[$index]: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? "?"}');
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('❌ Image load error: $error');
                debugPrint('❌ Failed URL: $imageUrl');
                return Container(
                  color: Colors.grey[200],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        '이미지 로드 실패',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          error.toString(),
                          style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),

        // 좌측 화살표
        if (place.imageUrls.length > 1 && _currentImageIndex > 0)
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_pageController != null) {
                      _pageController!.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_left, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),

        // 우측 화살표
        if (place.imageUrls.length > 1 && _currentImageIndex < place.imageUrls.length - 1)
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_pageController != null) {
                      _pageController!.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),

        // 이미지 카운터
        if (place.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentImageIndex + 1}/${place.imageUrls.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
      ],
    );
  }

  // 플레이스 헤더 (이름, 업종, 인증)
  Widget _buildPlaceHeader(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (place.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      place.category!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (place.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('인증됨', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        if (place.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            place.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  // 운영시간
  Widget _buildOperatingHours(PlaceModel place) {
    if (place.operatingHours == null || place.operatingHours!.isEmpty) {
      return const SizedBox.shrink();
    }

    // operatingHours를 읽기 쉬운 문자열로 변환
    String hoursText = '';
    place.operatingHours!.forEach((day, hours) {
      if (hours != null && hours is Map) {
        final hour = hours['hour']?.toString().padLeft(2, '0') ?? '00';
        final minute = hours['minute']?.toString().padLeft(2, '0') ?? '00';
        hoursText += '$day: $hour:$minute\n';
      }
    });

    if (hoursText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운영 시간',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            hoursText.trim(),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  // 연락처 정보
  Widget _buildContactInfo(PlaceModel place) {
    // contactInfo에서 정보 추출 (PlaceModel getter와 일치하도록 'phone' 사용)
    final phoneNumber = place.phoneNumber; // PlaceModel getter 사용
    final email = place.contactInfo?['email'] as String?;
    final website = place.website; // PlaceModel getter 사용

    // Phase 1 추가 연락처
    final mobile = place.mobile;
    final fax = place.fax;

    final hasContact = phoneNumber != null ||
                       email != null ||
                       website != null ||
                       mobile != null ||
                       fax != null ||
                       place.address != null;

    if (!hasContact) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '연락처',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (phoneNumber != null) ...[
                _buildContactRow(Icons.phone, '전화', phoneNumber),
                const SizedBox(height: 12),
              ],
              if (mobile != null) ...[
                _buildContactRow(Icons.phone_android, '휴대전화', mobile),
                const SizedBox(height: 12),
              ],
              if (fax != null) ...[
                _buildContactRow(Icons.print, '팩스', fax),
                const SizedBox(height: 12),
              ],
              if (email != null) ...[
                _buildContactRow(Icons.email, '이메일', email),
                const SizedBox(height: 12),
              ],
              if (website != null) ...[
                _buildContactRow(Icons.language, '웹사이트', website),
                const SizedBox(height: 12),
              ],
              if (place.address != null)
                _buildContactRow(Icons.location_on, '주소', place.address!),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildPlaceMap(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '위치',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          height: 150, // 지도 높이 1.5cm (약 150px)
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(
                  place.location!.latitude,
                  place.location!.longitude,
                ),
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.ppam.alpha',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        place.location!.latitude,
                        place.location!.longitude,
                      ),
                      width: 50,
                      height: 50,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue.shade700, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.work,
                          size: 30,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, PlaceModel place) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _viewPlaceStatistics(context, place),
            icon: const Icon(Icons.analytics),
            label: const Text('플레이스 통계'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => _viewOnMap(context, place),
            icon: const Icon(Icons.map),
            label: const Text('지도에서 보기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => _sharePlace(context, place),
            icon: const Icon(Icons.share),
            label: const Text('공유하기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  // === Phase 1: 새로운 섹션 위젯들 ===

  // 주차 정보 섹션
  Widget _buildParkingInfo(PlaceModel place) {
    if (place.parkingType == null && place.parkingCapacity == null && place.parkingFee == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주차 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (place.parkingType != null) ...[
                _buildInfoRow(Icons.local_parking, '주차 형태', _getParkingTypeLabel(place.parkingType!)),
                if (place.parkingCapacity != null || place.parkingFee != null || place.hasValetParking) const SizedBox(height: 12),
              ],
              if (place.parkingCapacity != null) ...[
                _buildInfoRow(Icons.pin_drop, '주차 가능 대수', '${place.parkingCapacity}대'),
                if (place.parkingFee != null || place.hasValetParking) const SizedBox(height: 12),
              ],
              if (place.parkingFee != null) ...[
                _buildInfoRow(Icons.payments, '주차 요금', place.parkingFee!),
                if (place.hasValetParking) const SizedBox(height: 12),
              ],
              if (place.hasValetParking)
                _buildInfoRow(Icons.car_rental, '발레파킹', '제공'),
            ],
          ),
        ),
      ],
    );
  }

  String _getParkingTypeLabel(String type) {
    switch (type) {
      case 'self':
        return '자체 주차장';
      case 'valet':
        return '발레파킹';
      case 'nearby':
        return '인근 주차장';
      case 'none':
        return '주차 불가';
      default:
        return type;
    }
  }

  // 편의시설 섹션
  Widget _buildFacilities(PlaceModel place) {
    if (place.facilities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '편의시설',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: place.facilities.map((facility) {
            final facilityInfo = _getFacilityInfo(facility);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(facilityInfo['icon'] as IconData, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                    facilityInfo['label'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, dynamic> _getFacilityInfo(String facility) {
    switch (facility) {
      case 'wifi':
        return {'icon': Icons.wifi, 'label': 'Wi-Fi'};
      case 'wheelchair':
        return {'icon': Icons.accessible, 'label': '휠체어 이용 가능'};
      case 'kids_zone':
        return {'icon': Icons.child_care, 'label': '키즈존'};
      case 'pet_friendly':
        return {'icon': Icons.pets, 'label': '반려동물 동반 가능'};
      case 'smoking_area':
        return {'icon': Icons.smoking_rooms, 'label': '흡연 구역'};
      case 'restroom':
        return {'icon': Icons.wc, 'label': '화장실'};
      case 'elevator':
        return {'icon': Icons.elevator, 'label': '엘리베이터'};
      case 'ac':
        return {'icon': Icons.ac_unit, 'label': '에어컨'};
      case 'heating':
        return {'icon': Icons.local_fire_department, 'label': '난방'};
      default:
        return {'icon': Icons.check_circle, 'label': facility};
    }
  }

  // 결제 수단 섹션
  Widget _buildPaymentMethods(PlaceModel place) {
    if (place.paymentMethods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 수단',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: place.paymentMethods.map((method) {
            final methodInfo = _getPaymentMethodInfo(method);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(methodInfo['icon'] as IconData, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    methodInfo['label'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, dynamic> _getPaymentMethodInfo(String method) {
    switch (method) {
      case 'card':
        return {'icon': Icons.credit_card, 'label': '카드'};
      case 'cash':
        return {'icon': Icons.money, 'label': '현금'};
      case 'mobile_pay':
        return {'icon': Icons.phone_android, 'label': '모바일 결제'};
      case 'cryptocurrency':
        return {'icon': Icons.currency_bitcoin, 'label': '암호화폐'};
      case 'account_transfer':
        return {'icon': Icons.account_balance, 'label': '계좌이체'};
      default:
        return {'icon': Icons.payment, 'label': method};
    }
  }

  // 소셜미디어 섹션
  Widget _buildSocialMedia(PlaceModel place) {
    if (place.socialMedia == null || place.socialMedia!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '소셜미디어',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: place.socialMedia!.entries.map((entry) {
            final platform = entry.key;
            final handle = entry.value;
            final platformInfo = _getSocialMediaInfo(platform);

            return InkWell(
              onTap: () {
                // TODO: 소셜미디어 링크 열기
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$platform: $handle')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: platformInfo['color'] as Color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(platformInfo['icon'] as IconData, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      handle,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, dynamic> _getSocialMediaInfo(String platform) {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return {'icon': Icons.camera_alt, 'color': Colors.purple};
      case 'facebook':
        return {'icon': Icons.facebook, 'color': Colors.blue.shade800};
      case 'twitter':
        return {'icon': Icons.alternate_email, 'color': Colors.lightBlue};
      case 'youtube':
        return {'icon': Icons.play_circle_filled, 'color': Colors.red};
      case 'blog':
        return {'icon': Icons.article, 'color': Colors.orange};
      default:
        return {'icon': Icons.link, 'color': Colors.grey};
    }
  }

  // 공통 정보 행 위젯
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === Phase 2: 부가 정보 섹션 위젯들 ===

  // 접근성 정보
  Widget _buildAccessibility(PlaceModel place) {
    if (place.accessibility == null || place.accessibility!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '접근성',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: place.accessibility!.map((item) {
            final info = _getAccessibilityInfo(item);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(info['icon'] as IconData, size: 16, color: Colors.teal.shade700),
                  const SizedBox(width: 6),
                  Text(
                    info['label'] as String,
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade700),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Map<String, dynamic> _getAccessibilityInfo(String item) {
    switch (item) {
      case 'wheelchair_ramp':
        return {'icon': Icons.accessible, 'label': '휠체어 경사로'};
      case 'elevator':
        return {'icon': Icons.elevator, 'label': '엘리베이터'};
      case 'braille':
        return {'icon': Icons.text_fields, 'label': '점자 안내'};
      case 'accessible_restroom':
        return {'icon': Icons.wc, 'label': '장애인 화장실'};
      case 'accessible_parking':
        return {'icon': Icons.local_parking, 'label': '장애인 주차'};
      case 'guide_dog':
        return {'icon': Icons.pets, 'label': '안내견 동반 가능'};
      default:
        return {'icon': Icons.accessibility_new, 'label': item};
    }
  }

  // 용량 및 가격대 정보
  Widget _buildCapacityInfo(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '규모 및 가격',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (place.priceRange != null) ...[
                _buildInfoRow(Icons.attach_money, '가격대', place.priceRange!),
                if (place.capacity != null || place.areaSize != null) const SizedBox(height: 12),
              ],
              if (place.capacity != null) ...[
                _buildInfoRow(Icons.people, '최대 수용 인원', '${place.capacity}명'),
                if (place.areaSize != null) const SizedBox(height: 12),
              ],
              if (place.areaSize != null)
                _buildInfoRow(Icons.square_foot, '면적', place.areaSize!),
            ],
          ),
        ),
      ],
    );
  }

  // 상세 위치 정보
  Widget _buildLocationDetails(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상세 위치',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (place.buildingName != null) ...[
                _buildInfoRow(Icons.business, '건물명', place.buildingName!),
                if (place.floor != null || place.landmark != null) const SizedBox(height: 12),
              ],
              if (place.floor != null) ...[
                _buildInfoRow(Icons.layers, '층', place.floor!),
                if (place.landmark != null) const SizedBox(height: 12),
              ],
              if (place.landmark != null)
                _buildInfoRow(Icons.location_on, '랜드마크', place.landmark!),
            ],
          ),
        ),
      ],
    );
  }

  // 대중교통 정보
  Widget _buildTransitInfo(PlaceModel place) {
    if (place.nearbyTransit == null || place.nearbyTransit!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대중교통',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: place.nearbyTransit!.map((transit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.directions_transit, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(transit, style: const TextStyle(fontSize: 14)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // === Phase 3: 고급 기능 섹션 위젯들 ===

  // 임시 휴업 배너
  Widget _buildClosureBanner(PlaceModel place) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              Text(
                '임시 휴업 중',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          if (place.reopeningDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '재개업 예정: ${place.reopeningDate!.year}-${place.reopeningDate!.month.toString().padLeft(2, '0')}-${place.reopeningDate!.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 14, color: Colors.red.shade900),
            ),
          ],
          if (place.closureReason != null) ...[
            const SizedBox(height: 8),
            Text(
              '사유: ${place.closureReason}',
              style: TextStyle(fontSize: 14, color: Colors.red.shade900),
            ),
          ],
        ],
      ),
    );
  }

  // 인증 및 수상 내역
  Widget _buildCertificationsAndAwards(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '인증 및 수상',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.certifications != null && place.certifications!.isNotEmpty) ...[
              const Text('인증', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: place.certifications!.map((cert) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 6),
                        Text(
                          cert,
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (place.awards != null && place.awards!.isNotEmpty) ...[
              if (place.certifications != null && place.certifications!.isNotEmpty)
                const SizedBox(height: 16),
              const Text('수상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: place.awards!.map((award) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          award,
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // 예약 정보
  Widget _buildReservationInfo(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '예약',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  const Text('예약 가능', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              if (place.reservationPhone != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.phone, '예약 전화', place.reservationPhone!),
              ],
              if (place.reservationUrl != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    // TODO: 예약 URL 열기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('예약 페이지: ${place.reservationUrl}')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.open_in_new, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '예약하기',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 미디어 갤러리
  Widget _buildMediaGallery(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '미디어',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (place.virtualTourUrl != null) ...[
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('가상 투어 열기')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.view_in_ar, color: Colors.purple.shade700, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('360도 가상 투어', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('내부를 둘러보세요', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (place.videoUrls != null && place.videoUrls!.isNotEmpty) ...[
              const Text('동영상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...place.videoUrls!.map((videoUrl) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('동영상 재생: $videoUrl')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_filled, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          const Expanded(child: Text('동영상 보기')),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ],
    );
  }


  void _editPlace(BuildContext context) async {
    // 현재 플레이스 정보를 가져온 후 수정 화면으로 이동
    try {
      final place = await _placeService.getPlaceById(widget.placeId);
      if (place != null && context.mounted) {
        final result = await Navigator.pushNamed(
          context,
          '/edit-place',
          arguments: place,
        );

        // 수정이 완료되었다면 현재 화면 새로고침
        if (result == true && context.mounted) {
          // StatelessWidget이므로 새로고침을 위해 화면을 다시 빌드하도록 강제
          Navigator.pushReplacementNamed(
            context,
            '/place-detail',
            arguments: widget.placeId,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('플레이스 수정 실패: $e')),
        );
      }
    }
  }

  void _viewOnMap(BuildContext context, PlaceModel place) {
    // TODO: 지도에서 플레이스 위치 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지도 보기 기능은 준비 중입니다.')),
    );
  }

  void _sharePlace(BuildContext context, PlaceModel place) {
    // TODO: 플레이스 공유 기능
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공유 기능은 준비 중입니다.')),
    );
  }

  void _viewPlaceStatistics(BuildContext context, PlaceModel place) {
    Navigator.pushNamed(
      context,
      '/place-statistics',
      arguments: place,
    );
  }

}

