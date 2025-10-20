import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/location/location_service.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';
import '../widgets/price_calculator.dart';
import '../widgets/post_place_helpers.dart';
import '../widgets/post_place_widgets.dart';
import '../utils/post_price_calculator.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  // 상태 변수들
  RangeValues _selectedAgeRange = const RangeValues(20, 40);
  String _selectedGender = 'all';
  List<String> _selectedGenders = ['male', 'female']; // 디자인 데모 스타일
  List<String> _selectedInterests = [];
  List<File> _selectedImages = [];
  File? _selectedAudioFile;
  int _defaultRadius = 1000;
  DateTime? _defaultExpiresAt;
  String? _selectedPlaceId;
  bool _isCoupon = false;
  String? _youtubeUrl;
  String _selectedPostType = '일반';

  // 추가 옵션들
  bool _hasExpiration = false;
  bool _canTransfer = false;
  bool _canForward = true;
  bool _canRespond = true;

  // 로딩 상태
  bool _isLoading = false;

  // 플레이스 정보
  PlaceModel? _selectedPlace;

  // 단가 관련
  int _minPrice = 30; // 최소 단가 (기본 1MB까지)
  
  final List<String> _postTypes = ['일반', '쿠폰'];

  @override
  void initState() {
    super.initState();
    _defaultExpiresAt = DateTime.now().add(const Duration(days: 30));
    _loadPlaceInfo();
    _rewardController.text = _minPrice.toString(); // 초기 최소 단가 설정
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 롱프레스에서 전달된 location 파라미터 처리
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('location')) {
      // location 파라미터가 있으면 해당 위치로 포스트 생성 준비
      final location = args['location'];
      debugPrint('📍 롱프레스 위치에서 포스트 생성: $location');
    }
  }

  Future<void> _loadPlaceInfo() async {
    // TODO: 선택된 플레이스 정보 로드
    // 임시로 샘플 플레이스 사용
    setState(() {
      _selectedPlace = PlaceModel(
        id: 'sample',
        name: '포스트 생성',
        description: '새로운 포스트를 작성하세요',
        address: '장소를 선택해주세요',
        location: const GeoPoint(37.5665, 126.9780),
        category: 'General',
        createdBy: 'user',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('포스트 작성'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createPost,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('완료'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D4DFF),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? PostPlaceWidgets.buildLoadingWidget()
          : ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 플레이스 헤더
                    if (_selectedPlace != null) _buildPlaceHeader(),
                    
                    // 메인 컨텐츠
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // 기본 정보 섹션 (제목과 타입만)
                            _buildCompactSection(
                              title: '기본 정보',
                              icon: Icons.edit_note_rounded,
                              color: Colors.blue,
                              children: [
                                // 제목과 타입을 같은 줄에 배치 (3.5:1.5 비율)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: _buildCompactTextField(
                                        controller: _titleController,
                      label: '제목',
                                        icon: Icons.title,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: _buildCompactDropdown(
                                        label: '타입',
                                        value: _selectedPostType,
                                        items: _postTypes,
                                        icon: Icons.category_outlined,
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedPostType = value!;
                                            _isCoupon = value == '쿠폰';
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // 설명 필드
                                _buildCompactTextField(
                                  controller: _descriptionController,
                      label: '설명',
                                  icon: Icons.description,
                      maxLines: 3,
                                ),
                              ],
                    ),
                    const SizedBox(height: 16),
                    
                            // 미디어 섹션 (헤더에 단가 포함)
                            _buildMediaSectionWithPrice(),
                    const SizedBox(height: 16),
                    
                            // 타겟팅 (일렬로 컴팩트하게)
                            _buildCompactSection(
                              title: '타겟팅',
                              icon: Icons.people_rounded,
                              color: Colors.orange,
                              children: [
                                _buildTargetingInline(),
                              ],
                            ),
                    const SizedBox(height: 16),
                    
                            // 추가 옵션 (컴팩트)
                            _buildCompactSection(
                              title: '추가 옵션',
                              icon: Icons.tune_rounded,
                              color: Colors.teal,
                              children: [
                                _buildOptionsCompact(),
                              ],
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPlaceHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4D4DFF),
            const Color(0xFF4D4DFF).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D4DFF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
      children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPlace!.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPlace!.address ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 섹션 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
          style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          // 섹션 컨텐츠
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 1.5),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(fontSize: 14)),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildMediaSectionWithPrice() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // 섹션 헤더 (미디어 + 단가)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.1),
                  Colors.purple.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.perm_media_rounded, color: Colors.purple, size: 20),
                const SizedBox(width: 10),
        const Text(
                  '미디어',
          style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const Spacer(),
                // 단가 입력 필드
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _rewardController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    onChanged: (value) {
                      final price = int.tryParse(value) ?? 0;
                      if (price < _minPrice && value.isNotEmpty) {
                        // 최소 단가보다 낮으면 경고 색상
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '단가',
                      labelStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Icons.monetization_on, size: 16),
                      suffixText: '원',
                      suffixStyle: const TextStyle(fontSize: 12),
                      helperText: '최소: $_minPrice원',
                      helperStyle: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: (int.tryParse(_rewardController.text) ?? _minPrice) < _minPrice 
                            ? Colors.red 
                            : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: (int.tryParse(_rewardController.text) ?? _minPrice) < _minPrice 
                            ? Colors.red 
                            : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: (int.tryParse(_rewardController.text) ?? _minPrice) < _minPrice 
                            ? Colors.red 
                            : const Color(0xFF4D4DFF),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 미디어 버튼들 (4개: 이미지, 텍스트, 사운드, 영상)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.image,
                      label: '이미지',
                      count: _selectedImages.length,
                      color: Colors.blue,
                      onTap: _pickImages,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.text_fields,
                      label: '텍스트',
                      count: _descriptionController.text.isNotEmpty ? 1 : 0,
                      color: Colors.green,
                      onTap: () {
                        // 텍스트는 이미 위에 설명 필드가 있음
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.audiotrack,
                      label: '사운드',
                      count: _selectedAudioFile != null ? 1 : 0,
                      color: Colors.orange,
                      onTap: _pickAudioFile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.videocam,
                      label: '영상',
                      count: _youtubeUrlController.text.isNotEmpty ? 1 : 0,
                      color: Colors.red,
                      onTap: _pickYoutubeUrl,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            // 동그라미 숫자 배지 (오른쪽 상단)
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetingInline() {
    return Row(
      children: [
        // 성별 선택
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.people, size: 14, color: Colors.black87),
                  const SizedBox(width: 6),
                  const Text('성별', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedGenders.contains('male')) {
                            _selectedGenders.remove('male');
                          } else {
                            _selectedGenders.add('male');
                          }
                          _updateGenderSelection();
                        });
                      },
                      child: _buildGenderChipCompact('남', 'male', Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedGenders.contains('female')) {
                            _selectedGenders.remove('female');
                          } else {
                            _selectedGenders.add('female');
                          }
                          _updateGenderSelection();
                        });
                      },
                      child: _buildGenderChipCompact('여', 'female', Colors.pink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 나이 범위
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cake, size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      const Text('나이', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(
                    '${_selectedAgeRange.start.toInt()} - ${_selectedAgeRange.end.toInt()}세',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.orange.shade400,
                  inactiveTrackColor: Colors.orange.shade100,
                  thumbColor: Colors.orange,
                  overlayColor: Colors.orange.withOpacity(0.2),
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                ),
                child: RangeSlider(
                  values: _selectedAgeRange,
                  min: 10,
                  max: 80,
                  onChanged: (range) {
            setState(() {
                      _selectedAgeRange = range;
            });
          },
        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderChipCompact(String label, String value, Color color) {
    final isSelected = _selectedGenders.contains(value);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
          style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOptionsCompact() {
    return Column(
      children: [
        _buildOptionRow('기한 설정', _hasExpiration, (v) {
          setState(() => _hasExpiration = v);
          if (v) _selectExpiryDate();
        }, Icons.schedule),
        const Divider(height: 20),
        _buildOptionRow('전달 가능', _canForward, (v) => setState(() => _canForward = v), Icons.forward),
        const Divider(height: 20),
        _buildOptionRow('응답 가능', _canRespond, (v) => setState(() => _canRespond = v), Icons.reply),
        const Divider(height: 20),
        _buildOptionRow('송금 요청', _canTransfer, (v) => setState(() => _canTransfer = v), Icons.attach_money),
      ],
    );
  }

  Widget _buildOptionRow(String label, bool value, Function(bool) onChanged, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: value ? const Color(0xFF4D4DFF) : Colors.grey),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: value ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF4D4DFF),
          ),
        ),
      ],
    );
  }

  // ==================== 단가 계산 ====================
  
  /// 최소 단가 업데이트 및 TextField에 반영
  void _updateMinPrice() {
    final newMinPrice = PostPriceCalculator.calculateMinPriceFromFiles(
      images: _selectedImages,
      audioFile: _selectedAudioFile,
    );
    
    setState(() {
      _minPrice = newMinPrice;
      
      // 현재 입력된 단가가 최소 단가보다 낮으면 자동으로 최소 단가로 설정
      final currentPrice = int.tryParse(_rewardController.text) ?? 0;
      if (currentPrice < _minPrice) {
        _rewardController.text = _minPrice.toString();
      }
    });
    
    // 디버그 정보 출력
    PostPriceCalculator.printCalculationDetails(
      images: _selectedImages,
      audioFile: _selectedAudioFile,
    );
  }

  // ==================== 이벤트 핸들러들 ====================

  void _updateGenderSelection() {
    if (_selectedGenders.isEmpty) {
      _selectedGender = 'all';
    } else if (_selectedGenders.length == 2) {
      _selectedGender = 'all';
    } else if (_selectedGenders.contains('male')) {
      _selectedGender = 'male';
    } else {
      _selectedGender = 'female';
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await PostPlaceHelpers.pickImages();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
        _updateMinPrice(); // 최소 단가 업데이트
        PostPlaceHelpers.showSuccessSnackBar(context, '${images.length}개의 이미지가 추가되었습니다');
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '이미지 선택 실패: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final audioFile = await PostPlaceHelpers.pickAudioFile();
      if (audioFile != null) {
        setState(() {
          _selectedAudioFile = audioFile;
        });
        _updateMinPrice(); // 최소 단가 업데이트
        PostPlaceHelpers.showSuccessSnackBar(context, '오디오 파일이 추가되었습니다');
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '오디오 파일 선택 실패: $e');
    }
  }

  Future<void> _pickYoutubeUrl() async {
    final controller = TextEditingController(text: _youtubeUrlController.text);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('유튜브 URL 입력'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=...',
            prefixIcon: Icon(Icons.videocam),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _youtubeUrlController.text = result;
        _youtubeUrl = result;
      });
      PostPlaceHelpers.showSuccessSnackBar(context, '유튜브 URL이 추가되었습니다');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    _updateMinPrice(); // 최소 단가 업데이트
  }

  void _removeAudioFile() {
    setState(() {
      _selectedAudioFile = null;
    });
    _updateMinPrice(); // 최소 단가 업데이트
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _defaultExpiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (date != null) {
      setState(() {
        _defaultExpiresAt = date;
      });
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 기본 유효성 검사
    if (_titleController.text.trim().isEmpty) {
      PostPlaceHelpers.showErrorSnackBar(context, '제목을 입력해주세요');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      PostPlaceHelpers.showErrorSnackBar(context, '설명을 입력해주세요');
      return;
    }

    if (_rewardController.text.trim().isEmpty) {
      PostPlaceHelpers.showErrorSnackBar(context, '단가를 입력해주세요');
      return;
    }

    // 최소 단가 검증
    final price = int.tryParse(_rewardController.text) ?? 0;
    if (price < _minPrice) {
      PostPlaceHelpers.showErrorSnackBar(context, '단가는 최소 $_minPrice원 이상이어야 합니다');
      return;
    }

    // 확인 다이얼로그
    final confirmed = await PostPlaceHelpers.showConfirmDialog(
      context,
      '포스트 생성',
      '포스트를 생성하시겠습니까?',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('사용자가 로그인되지 않았습니다');
      }

      // 미디어 URL 생성
      final mediaTypes = PostPlaceHelpers.determineMediaTypes(_selectedImages, _selectedAudioFile);
      final mediaUrls = await PostPlaceHelpers.generateMediaUrls(_selectedImages, _selectedAudioFile);
      final thumbnailUrls = await PostPlaceHelpers.generateThumbnailUrls(_selectedImages);

      // 포스트 생성
      final postId = await PostPlaceHelpers.createPost(
        creatorId: currentUser.uid,
        creatorName: currentUser.displayName ?? 'Unknown',
        reward: int.parse(_rewardController.text),
        targetAge: [_selectedAgeRange.start.toInt(), _selectedAgeRange.end.toInt()],
        targetGender: _selectedGender,
        targetInterest: _selectedInterests,
        targetPurchaseHistory: [],
        mediaType: mediaTypes,
        mediaUrl: mediaUrls,
        thumbnailUrl: thumbnailUrls,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        canRespond: _canRespond,
        canForward: _canForward,
        canRequestReward: _canTransfer,
        canUse: true,
        defaultRadius: _defaultRadius,
        defaultExpiresAt: _hasExpiration ? _defaultExpiresAt : null,
        placeId: _selectedPlaceId,
        isCoupon: _isCoupon,
        youtubeUrl: _youtubeUrl,
      );

      if (postId != null) {
        PostPlaceHelpers.showSuccessSnackBar(context, '포스트가 성공적으로 생성되었습니다');
        Navigator.pop(context, true);
      } else {
        throw Exception('포스트 생성에 실패했습니다');
      }
    } catch (e) {
      PostPlaceHelpers.showErrorSnackBar(context, '포스트 생성 실패: $e');
    } finally {
      if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
}
