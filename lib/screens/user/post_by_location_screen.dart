import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/post_service.dart';
import '../../services/firebase_service.dart';

class PostByLocationScreen extends StatefulWidget {
  final LatLng location;
  final String? address;

  const PostByLocationScreen({
    Key? key,
    required this.location,
    this.address,
  }) : super(key: key);

  @override
  State<PostByLocationScreen> createState() => _PostByLocationScreenState();
}

class _PostByLocationScreenState extends State<PostByLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isSubmitting = false;

  final _postService = PostService();
  final _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _priceController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
    if (widget.address != null && widget.address!.isNotEmpty) {
      _addressController.text = widget.address!;
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  int get _totalPrice {
    final price = int.tryParse(_priceController.text) ?? 0;
    final amount = int.tryParse(_amountController.text) ?? 0;
    return price * amount;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final userId = _firebaseService.currentUser?.uid ?? '';
      final userName = _firebaseService.currentUser?.displayName ?? '익명';
      // 주소만 사용: 주소를 좌표로 변환
      if (_addressController.text.trim().isEmpty) {
        throw Exception('주소를 입력하세요');
      }
      final List<Location> locs = await locationFromAddress(_addressController.text.trim());
      if (locs.isEmpty) {
        throw Exception('해당 주소의 좌표를 찾을 수 없습니다');
      }
      final GeoPoint location = GeoPoint(locs.first.latitude, locs.first.longitude);

      final flyerId = await _postService.createFlyer(
        creatorId: userId,
        creatorName: userName,
        location: location,
        radius: 1000,
        reward: int.tryParse(_priceController.text) ?? 0,
        targetAge: const [20, 30],
        targetGender: 'all',
        targetInterest: const [],
        targetPurchaseHistory: const [],
        mediaType: const [],
        mediaUrl: const [],
        title: _addressController.text.isNotEmpty
            ? '주소 기반 포스트'
            : '위치 기반 포스트',
        description: _addressController.text.trim(),
        canRespond: true,
        canForward: true,
        canRequestReward: true,
        canUse: true,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      if (mounted) {
        Navigator.pop(context, {
          'location': LatLng(location.latitude, location.longitude),
          'flyerId': flyerId,
          'address': _addressController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('포스트 생성 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('포스트 설정 (위치/주소)'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('배포'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('주소 입력', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '상세 주소',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '주소를 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('입력한 주소', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_addressController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_addressController.text.trim(), style: TextStyle(color: Colors.grey[700])),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text('포스트 선택 (저장된 포스트 로드 예정)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text('저장된 포스트가 없어요. 포스트 만들기로 이동해 주세요.'),
              ),
              const SizedBox(height: 24),

              const Text('가격 및 수량', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: '가격',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '가격을 입력하세요';
                        if (int.tryParse(v) == null) return '숫자만 입력하세요';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: '수량',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '수량을 입력하세요';
                        if (int.tryParse(v) == null) return '숫자만 입력하세요';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('총액: $_totalPrice', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


