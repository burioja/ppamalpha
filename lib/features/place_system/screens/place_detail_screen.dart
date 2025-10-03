import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../../../widgets/network_image_fallback_with_data.dart';

class PlaceDetailScreen extends StatelessWidget {
  final String placeId;
  final PlaceService _placeService = PlaceService();

  PlaceDetailScreen({super.key, required this.placeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이스 상세'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editPlace(context),
          ),
        ],
      ),
      body: FutureBuilder<PlaceModel?>(
        future: _placeService.getPlaceById(placeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
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
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.place, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('플레이스를 찾을 수 없습니다.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          } else {
            final place = snapshot.data!;
            debugPrint('📸 PlaceDetailScreen - Place ID: ${place.id}');
            debugPrint('📸 PlaceDetailScreen - imageUrls: ${place.imageUrls}');
            debugPrint('📸 PlaceDetailScreen - hasImages: ${place.hasImages}');
            debugPrint('📸 PlaceDetailScreen - imageUrls.length: ${place.imageUrls.length}');

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단 이미지 그리드 (3-4개 우선 표시)
                  if (place.hasImages) ...[
                    _buildImageGridHeader(place),
                    const SizedBox(height: 16),
                  ] else ...[
                    // 이미지가 없을 때 표시
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            '등록된 이미지가 없습니다',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 플레이스 헤더 (간소화)
                  _buildSimplePlaceHeader(place),

                  const SizedBox(height: 20),

                  // 간결한 기본 정보
                  _buildCompactInfo(place),

                  const SizedBox(height: 24),

                  // 지도
                  if (place.location != null) ...[
                    _buildPlaceMap(place),
                    const SizedBox(height: 24),
                  ],

                  // 액션 버튼들
                  _buildActionButtons(context, place),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  // 상단 이미지 그리드 (3-4개 이미지)
  Widget _buildImageGridHeader(PlaceModel place) {
    final images = place.imageUrls.take(4).toList(); // 최대 4개만 표시

    return Container(
      height: 200,
      width: double.infinity,
      child: images.length == 1
          ? _buildSingleImage(images[0], place, 0)
          : images.length == 2
              ? _buildDoubleImages(images, place)
              : images.length == 3
                  ? _buildTripleImages(images, place)
                  : _buildQuadImages(images, place),
    );
  }

  Widget _buildSingleImage(String imageUrl, PlaceModel place, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: buildHighQualityImageWithData(
        imageUrl,
        place.thumbnailUrls.isNotEmpty ? place.thumbnailUrls : null,
        index,
      ),
    );
  }

  Widget _buildDoubleImages(List<String> images, PlaceModel place) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: buildHighQualityImageWithData(images[0], place.thumbnailUrls, 0),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: buildHighQualityImageWithData(images[1], place.thumbnailUrls, 1),
          ),
        ),
      ],
    );
  }

  Widget _buildTripleImages(List<String> images, PlaceModel place) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: buildHighQualityImageWithData(images[0], place.thumbnailUrls, 0),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[1], place.thumbnailUrls, 1),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[2], place.thumbnailUrls, 2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadImages(List<String> images, PlaceModel place) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[0], place.thumbnailUrls, 0),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[1], place.thumbnailUrls, 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[2], place.thumbnailUrls, 2),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(16)),
                  child: buildHighQualityImageWithData(images[3], place.thumbnailUrls, 3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 간소화된 플레이스 헤더
  Widget _buildSimplePlaceHeader(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (place.category != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              place.fullCategoryPath,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 간결한 정보 카드
  Widget _buildCompactInfo(PlaceModel place) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 기본 설명
          if (place.description != null && place.description!.isNotEmpty) ...[
            Text(
              place.description!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 위치 정보
          _buildInfoRow(Icons.location_on, '위치', place.formattedAddress ?? '위치 정보 없음'),

          // 연락처
          if (place.phoneNumber != null && place.phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, '전화번호', place.phoneNumber!),
          ],

          // 웹사이트
          if (place.website != null && place.website!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.web, '웹사이트', place.website!),
          ],

          // 운영시간
          if (place.hasOperatingHours) ...[
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, '운영시간', _getOperatingHoursSummary(place)),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.blue.shade600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getOperatingHoursSummary(PlaceModel place) {
    // 간단한 운영시간 요약 (예: "월-금 09:00-18:00")
    if (place.operatingHours == null || place.operatingHours!.isEmpty) {
      return '운영시간 정보 없음';
    }

    // 첫 번째 요일의 운영시간을 표시
    final firstDay = place.operatingHours!.keys.first;
    final hours = place.operatingHours![firstDay];
    if (hours != null) {
      return '$firstDay ${hours['hour']?.toString().padLeft(2, '0')}:${hours['minute']?.toString().padLeft(2, '0')} 등';
    }
    return '운영시간 정보 없음';
  }

  Widget _buildPlaceHeader(PlaceModel place) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(place.category),
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (place.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.fullCategoryPath,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            place.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '기본 정보',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (place.address != null) ...[
                _buildInfoRow(Icons.location_on, '주소', place.address!),
                const SizedBox(height: 12),
              ],
              _buildInfoRow(Icons.calendar_today, '생성일', _formatDate(place.createdAt)),
              if (place.updatedAt != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(Icons.update, '수정일', _formatDate(place.updatedAt!)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '연락처 정보',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              if (place.contactInfo?['phone'] != null) ...[
                _buildInfoRow(Icons.phone, '전화번호', place.contactInfo!['phone']!),
                const SizedBox(height: 12),
              ],
              if (place.contactInfo?['email'] != null) ...[
                _buildInfoRow(Icons.email, '이메일', place.contactInfo!['email']!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatingHours(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운영 시간',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: place.operatingHours!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '${entry.value['hour']?.toString().padLeft(2, '0')}:${entry.value['minute']?.toString().padLeft(2, '0')}',
                      ),
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

  Widget _buildImageGallery(PlaceModel place) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이미지',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: place.imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/place-image-viewer',
                    arguments: {
                      'images': place.imageUrls,
                      'index': index,
                    },
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      place.imageUrls[index],
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
          height: 250, // 지도 높이
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ppam.alpha',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        place.location!.latitude,
                        place.location!.longitude,
                      ),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.place,
                        size: 40,
                        color: Colors.red,
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


  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case '요식업':
        return Icons.restaurant;
      case '배움':
        return Icons.school;
      case '생활':
        return Icons.home;
      case '쇼핑':
        return Icons.shopping_bag;
      case '엔터테인먼트':
        return Icons.movie;
      case '정치':
        return Icons.account_balance;
      default:
        return Icons.place;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _editPlace(BuildContext context) async {
    // 현재 플레이스 정보를 가져온 후 수정 화면으로 이동
    try {
      final place = await _placeService.getPlaceById(placeId);
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
            arguments: placeId,
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

