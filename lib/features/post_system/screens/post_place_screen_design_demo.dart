import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/place/place_model.dart';
import '../widgets/range_slider_with_input.dart';
import '../widgets/gender_checkbox_group.dart';
import '../widgets/period_slider_with_input.dart';

/// 포스트 작성 화면 디자인 데모
/// 기능은 동작하지 않지만 새로운 디자인을 미리 볼 수 있습니다.
class PostPlaceScreenDesignDemo extends StatefulWidget {
  const PostPlaceScreenDesignDemo({super.key});

  @override
  State<PostPlaceScreenDesignDemo> createState() => _PostPlaceScreenDesignDemoState();
}

class _PostPlaceScreenDesignDemoState extends State<PostPlaceScreenDesignDemo> {
  // 폼 컨트롤러들 (데모용)
  final _titleController = TextEditingController(text: '샘플 포스트 제목');
  final _contentController = TextEditingController(text: '샘플 포스트 내용입니다.');
  final _priceController = TextEditingController(text: '100');
  final _youtubeUrlController = TextEditingController();

  // 선택된 값들 (데모용)
  String _selectedFunction = 'Using';
  int _selectedPeriod = 7;
  List<String> _selectedGenders = ['male', 'female'];
  RangeValues _selectedAgeRange = const RangeValues(20, 30);
  String _selectedPostType = '일반';
  bool _hasExpiration = false;
  bool _canTransfer = false;
  bool _canForward = false;
  bool _canRespond = false;
  String _selectedTargeting = '기본';

  // 데모 이미지
  final List<String> _imageNames = ['sample_image1.jpg', 'sample_image2.jpg'];
  String _soundFileName = '';

  final List<String> _functions = ['Using', 'Selling', 'Buying', 'Sharing'];
  final List<String> _postTypes = ['일반', '쿠폰'];
  final List<String> _targetingOptions = ['기본', '고급', '맞춤형'];

  // 샘플 플레이스
  final PlaceModel _samplePlace = PlaceModel(
    id: 'demo',
    name: '샘플 장소',
    description: '포스트 작성 디자인 데모용 샘플 장소입니다.',
    address: '서울시 강남구 테헤란로',
    location: const GeoPoint(37.5665, 126.9780),
    category: 'Restaurant',
    createdBy: 'demo-user',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _priceController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('포스트 작성 (디자인 프리뷰)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('디자인 데모입니다. 실제 저장은 되지 않습니다.')),
                );
              },
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
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 플레이스 헤더
              _buildPlaceHeader(),
              
              // 메인 컨텐츠
              Padding(
                padding: const EdgeInsets.all(16.0),
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
                                onChanged: (value) => setState(() => _selectedPostType = value!),
                              ),
                            ),
                          ],
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
                  _samplePlace.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _samplePlace.address ?? '',
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
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 14)))).toList(),
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
                Icon(Icons.perm_media_rounded, color: Colors.purple, size: 20),
                const SizedBox(width: 10),
                Text(
                  '미디어',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                // 단가 입력 필드
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: '단가',
                      labelStyle: const TextStyle(fontSize: 11),
                      prefixIcon: const Icon(Icons.monetization_on, size: 16),
                      suffixText: '원',
                      suffixStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF4D4DFF), width: 1.5),
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
                      count: _imageNames.length,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.text_fields,
                      label: '텍스트',
                      count: _contentController.text.isNotEmpty ? 1 : 0,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.audiotrack,
                      label: '사운드',
                      count: _soundFileName.isEmpty ? 0 : 1,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMediaButton(
                      icon: Icons.videocam,
                      label: '영상',
                      count: 0,
                      color: Colors.red,
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
                  Expanded(child: _buildGenderChipCompact('남', 'male', Colors.blue)),
                  const SizedBox(width: 4),
                  Expanded(child: _buildGenderChipCompact('여', 'female', Colors.pink)),
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
                children: [
                  const Icon(Icons.cake, size: 14, color: Colors.black87),
                  const SizedBox(width: 6),
                  const Text('나이', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  '${_selectedAgeRange.start.toInt()}세 ~ ${_selectedAgeRange.end.toInt()}세',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
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

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
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
    );
  }


  Widget _buildOptionsCompact() {
    return Column(
      children: [
        _buildOptionRow('기한 설정', _hasExpiration, (v) => setState(() => _hasExpiration = v), Icons.schedule),
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
}

