import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../providers/create_place_provider.dart';
import '../constants/place_categories.dart';
import '../../../screens/auth/address_search_screen.dart';

class CreatePlaceScreen extends StatefulWidget {
  const CreatePlaceScreen({super.key});

  @override
  State<CreatePlaceScreen> createState() => _CreatePlaceScreenState();
}

class _CreatePlaceScreenState extends State<CreatePlaceScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // 폼 컨트롤러들
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _couponPasswordController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _faxController = TextEditingController();
  final TextEditingController _parkingFeeController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _areaSizeController = TextEditingController();
  final TextEditingController _reservationUrlController = TextEditingController();
  final TextEditingController _reservationPhoneController = TextEditingController();
  final TextEditingController _virtualTourUrlController = TextEditingController();
  final TextEditingController _closureReasonController = TextEditingController();

  GeoPoint? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _couponPasswordController.dispose();
    _mobileController.dispose();
    _faxController.dispose();
    _parkingFeeController.dispose();
    _websiteController.dispose();
    _floorController.dispose();
    _buildingNameController.dispose();
    _landmarkController.dispose();
    _areaSizeController.dispose();
    _reservationUrlController.dispose();
    _reservationPhoneController.dispose();
    _virtualTourUrlController.dispose();
    _closureReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatePlaceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('플레이스 등록'),
            backgroundColor: Colors.blue[600],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(provider),
                        const SizedBox(height: 24),
                        _buildCategorySection(provider),
                        const SizedBox(height: 24),
                        _buildAddressSection(provider),
                        const SizedBox(height: 24),
                        _buildContactSection(provider),
                        const SizedBox(height: 24),
                        _buildImagesSection(provider),
                        const SizedBox(height: 24),
                        _buildFacilitiesSection(provider),
                        const SizedBox(height: 24),
                        _buildSubmitButton(provider),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBasicInfoSection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '기본 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '플레이스 이름',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '플레이스 이름을 입력해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '카테고리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: provider.selectedCategory,
              decoration: const InputDecoration(
                labelText: '메인 카테고리',
                border: OutlineInputBorder(),
              ),
              items: PlaceCategories.categoryOptions.keys.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) => provider.setCategory(value),
            ),
            if (provider.selectedCategory != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: provider.selectedSubCategory,
                decoration: const InputDecoration(
                  labelText: '서브 카테고리',
                  border: OutlineInputBorder(),
                ),
                items: PlaceCategories.categoryOptions[provider.selectedCategory]!
                    .map((subCategory) {
                  return DropdownMenuItem(
                    value: subCategory,
                    child: Text(subCategory),
                  );
                }).toList(),
                onChanged: (value) => provider.setSubCategory(value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '주소',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: '주소',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _pickAddress,
                ),
              ),
              readOnly: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '주소를 선택해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailAddressController,
              decoration: const InputDecoration(
                labelText: '상세 주소',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '연락처',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '전화번호',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagesSection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '이미지',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(provider),
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.selectedImages.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: provider.coverImageIndex == index
                                    ? Colors.blue
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: _buildImagePreview(provider.selectedImages[index]),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => provider.removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              const Text('이미지를 추가해주세요 (최대 5장)'),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(dynamic image) {
    if (image is String && image.startsWith('data:image/')) {
      final bytes = base64Decode(image.split(',')[1]);
      return Image.memory(bytes, fit: BoxFit.cover);
    } else if (image is String) {
      return Image.network(image, fit: BoxFit.cover);
    }
    return const Icon(Icons.image);
  }

  Widget _buildFacilitiesSection(CreatePlaceProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '시설 및 편의시설',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlaceCategories.facilityOptions.map((facility) {
                final isSelected = provider.selectedFacilities.contains(facility);
                return FilterChip(
                  label: Text(facility),
                  selected: isSelected,
                  onSelected: (_) => provider.toggleFacility(facility),
                  selectedColor: Colors.blue[100],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(CreatePlaceProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: provider.isLoading ? null : () => _submitPlace(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '플레이스 등록',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _pickAddress() async {
    final result = await Navigator.pushNamed(
      context,
      '/address-search',
      arguments: {'returnAddress': true},
    );

    if (result != null && result is Map) {
      setState(() {
        _addressController.text = result['address'] ?? '';
        _selectedLocation = result['location'] as GeoPoint?;
      });
    }
  }

  Future<void> _pickImage(CreatePlaceProvider provider) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (provider.selectedImages.length >= 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('최대 5장까지만 업로드할 수 있습니다.')),
            );
          }
          return;
        }

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final base64String = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64String';
          provider.addImage(dataUrl, image.name);
        } else {
          provider.addImage(image.path, image.name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택 실패: $e')),
        );
      }
    }
  }

  Future<void> _submitPlace(CreatePlaceProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (provider.selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요.')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 선택해주세요.')),
      );
      return;
    }

    final success = await provider.createPlace(
      name: _nameController.text,
      description: _descriptionController.text,
      address: _addressController.text,
      detailAddress: _detailAddressController.text,
      location: _selectedLocation!,
      phone: _phoneController.text.isEmpty ? null : _phoneController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      couponPassword: _couponPasswordController.text.isEmpty ? null : _couponPasswordController.text,
      mobile: _mobileController.text.isEmpty ? null : _mobileController.text,
      fax: _faxController.text.isEmpty ? null : _faxController.text,
      website: _websiteController.text.isEmpty ? null : _websiteController.text,
      parkingFee: _parkingFeeController.text.isEmpty ? null : _parkingFeeController.text,
      floor: _floorController.text.isEmpty ? null : _floorController.text,
      buildingName: _buildingNameController.text.isEmpty ? null : _buildingNameController.text,
      landmark: _landmarkController.text.isEmpty ? null : _landmarkController.text,
      areaSize: _areaSizeController.text.isEmpty ? null : _areaSizeController.text,
      reservationUrl: _reservationUrlController.text.isEmpty ? null : _reservationUrlController.text,
      reservationPhone: _reservationPhoneController.text.isEmpty ? null : _reservationPhoneController.text,
      virtualTourUrl: _virtualTourUrlController.text.isEmpty ? null : _virtualTourUrlController.text,
      closureReason: _closureReasonController.text.isEmpty ? null : _closureReasonController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('플레이스가 성공적으로 등록되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('플레이스 등록에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
