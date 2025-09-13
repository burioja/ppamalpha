import 'package:flutter/material.dart';

import '../../core/models/place/place_model.dart';
import '../../core/services/data/place_service.dart';

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
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 플레이스 헤더
                  _buildPlaceHeader(place),
                  
                  const SizedBox(height: 24),
                  
                  // 기본 정보
                  _buildBasicInfo(place),
                  
                  const SizedBox(height: 24),
                  
                  // 연락처 정보
                  if (place.hasContactInfo) ...[
                    _buildContactInfo(place),
                    const SizedBox(height: 24),
                  ],
                  
                  // 운영 시간
                  if (place.hasOperatingHours) ...[
                    _buildOperatingHours(place),
                    const SizedBox(height: 24),
                  ],
                  
                  // 이미지 갤러리
                  if (place.hasImages) ...[
                    _buildImageGallery(place),
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

  Widget _buildActionButtons(BuildContext context, PlaceModel place) {
    return Column(
      children: [
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
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
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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

  void _editPlace(BuildContext context) {
    // TODO: 플레이스 수정 화면으로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('플레이스 수정 기능은 준비 중입니다.')),
    );
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
}

