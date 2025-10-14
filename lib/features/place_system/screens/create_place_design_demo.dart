import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreatePlaceDesignDemo extends StatefulWidget {
  const CreatePlaceDesignDemo({super.key});

  @override
  State<CreatePlaceDesignDemo> createState() => _CreatePlaceDesignDemoState();
}

class _CreatePlaceDesignDemoState extends State<CreatePlaceDesignDemo>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 폼 컨트롤러들
  final TextEditingController _nameController = TextEditingController(text: '맛있는 카페');
  final TextEditingController _descriptionController = TextEditingController(text: '따뜻한 분위기의 카페입니다.');
  final TextEditingController _addressController = TextEditingController(text: '서울시 강남구 테헤란로');
  final TextEditingController _detailAddressController = TextEditingController(text: '123번길 45');
  final TextEditingController _phoneController = TextEditingController(text: '02-1234-5678');
  final TextEditingController _emailController = TextEditingController(text: 'info@cafe.com');

  String? _selectedCategory = '카페/디저트';
  bool _isActive = true;

  // 카테고리 옵션들
  final Map<String, List<String>> _categoryOptions = {
    '음식점': ['한식', '중식', '일식', '양식', '분식', '치킨', '피자', '버거', '아시안', '뷔페', '해산물', '고기집', '찌개/탕', '국수/면', '죽/백반'],
    '카페/디저트': ['커피전문점', '베이커리', '아이스크림', '디저트카페', '브런치카페', '차/전통차'],
    '소매/쇼핑': ['편의점', '슈퍼마켓', '대형마트', '백화점', '아울렛', '전통시장'],
    '의류/패션': ['의류', '신발', '가방', '액세서리', '안경/선글라스', '시계', '속옷'],
    '뷰티/화장품': ['화장품', '향수', '네일샵', '왁싱샵'],
    '생활용품': ['생활잡화', '문구', '꽃집', '인테리어소품', '애완용품'],
    '전자/가전': ['휴대폰', '컴퓨터', '가전제품', '카메라', '게임'],
    '가구/인테리어': ['가구', '침구', '조명', '커튼/블라인드', '주방용품'],
    '숙박': ['호텔', '모텔', '펜션', '게스트하우스', '리조트', '민박'],
    '문화/여가': ['영화관', '공연장', '박물관', '미술관', '전시관', '도서관', '문화센터'],
    '오락': ['노래방', 'PC방', '게임장', '볼링장', '당구장', '만화카페', 'VR카페'],
    '병원/의료': ['종합병원', '내과', '외과', '치과', '한의원', '소아과', '산부인과', '정형외과', '피부과', '안과', '이비인후과', '약국', '동물병원'],
    '교육': ['학원', '어학원', '컴퓨터학원', '예체능학원', '독서실', '스터디카페', '도서관'],
    '미용/뷰티': ['미용실', '네일샵', '피부관리', '마사지', '스파', '사우나', '찜질방'],
    '운동/스포츠': ['헬스장', '필라테스', '요가', '수영장', '태권도', '골프연습장', '클라이밍', '스쿼시', '배드민턴'],
    '생활서비스': ['세탁소', '수선집', '열쇠', '이사', '택배', '렌터카', '주차장', '세차장'],
    '금융/보험': ['은행', '증권사', '보험사', '대부업체', '환전소'],
    '부동산': ['부동산중개', '공인중개사'],
    '자동차': ['자동차판매', '정비소', '세차장', '주유소', '충전소', '카센터', '타이어'],
    '공공기관': ['주민센터', '우체국', '경찰서', '소방서', '시청', '구청', '도서관', '보건소'],
  };

  final List<String> _selectedImages = [];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: AppBar(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: true,
          title: const Text(
            '배포자 생성',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          flexibleSpace: SafeArea(
            child: Container(
              alignment: Alignment.bottomCenter,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: '기본 정보'),
                  Tab(text: '상세 정보'),
                  Tab(text: '미리보기'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(),
          _buildDetailInfoTab(),
          _buildPreviewTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이것은 디자인 프리뷰입니다'),
              backgroundColor: Colors.blue,
            ),
          );
        },
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('배포자 생성', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // 기본 정보 탭
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // 배포자명 + 카테고리 (같은 행)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 배포자명 (flex: 3)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          const Text(
                            '배포자명',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: '이름',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                
                // 카테고리 (flex: 1)
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              '카테고리',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.orange.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.orange.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.orange.shade200),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: _categoryOptions.keys.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        },
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, size: 20, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 주소 섹션
          _buildCompactFormSection(
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: '주소',
            child: Column(
              children: [
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: '주소 검색',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailAddressController,
                  decoration: InputDecoration(
                    hintText: '상세주소',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // 이미지 추가 섹션
          _buildCompactFormSection(
            icon: Icons.image,
            iconColor: Colors.purple,
            title: '이미지',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1.5, style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    '이미지 추가',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedImages.length}개 선택됨',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 연락처 정보 섹션
          _buildCompactFormSection(
            icon: Icons.contact_phone,
            iconColor: Colors.green,
            title: '연락처 정보',
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: '이메일',
                    labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    hintText: 'example@email.com',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: Icon(Icons.email, size: 18, color: Colors.grey[600]),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '전화번호',
                    labelStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    hintText: '010-1234-5678',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    prefixIcon: Icon(Icons.phone, size: 18, color: Colors.grey[600]),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),

          // 활성 상태 섹션
          _buildCompactFormSection(
            icon: Icons.toggle_on,
            iconColor: Colors.indigo,
            title: '활성 상태',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isActive ? Colors.green.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isActive ? Colors.green.shade200 : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isActive ? Icons.check_circle : Icons.cancel,
                    color: _isActive ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isActive ? '활성' : '비활성',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _isActive ? Colors.green.shade900 : Colors.grey.shade700,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                    activeColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // 상세 정보 탭
  Widget _buildDetailInfoTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // 설명 섹션
          _buildFormSection(
            icon: Icons.description,
            iconColor: Colors.indigo,
            title: '설명',
            child: TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '배포자에 대한 설명을 입력하세요',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 운영 시간 섹션
          _buildFormSection(
            icon: Icons.access_time,
            iconColor: Colors.teal,
            title: '운영 시간',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildTimeRow('월', '09:00', '18:00'),
                  const Divider(height: 16),
                  _buildTimeRow('화', '09:00', '18:00'),
                  const Divider(height: 16),
                  _buildTimeRow('수', '09:00', '18:00'),
                  const Divider(height: 16),
                  _buildTimeRow('목', '09:00', '18:00'),
                  const Divider(height: 16),
                  _buildTimeRow('금', '09:00', '18:00'),
                  const Divider(height: 16),
                  _buildTimeRow('토', '10:00', '17:00'),
                  const Divider(height: 16),
                  _buildTimeRow('일', '휴무', ''),
                ],
              ),
            ),
          ),

          // 편의시설 섹션
          _buildFormSection(
            icon: Icons.local_parking,
            iconColor: Colors.brown,
            title: '편의시설',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFacilityChip('주차', Icons.local_parking),
                _buildFacilityChip('와이파이', Icons.wifi),
                _buildFacilityChip('화장실', Icons.wc),
                _buildFacilityChip('휠체어', Icons.accessible),
                _buildFacilityChip('엘리베이터', Icons.elevator),
                _buildFacilityChip('카드결제', Icons.credit_card),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // 미리보기 탭
  Widget _buildPreviewTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // 배포자 카드 미리보기
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 영역
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          '배포자 이미지',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),

                // 정보 영역
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이름과 상태
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _nameController.text,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isActive ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isActive ? '활성' : '비활성',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 카테고리
                      Row(
                        children: [
                          Icon(Icons.category, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            _selectedCategory ?? '카테고리 없음',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 주소
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _addressController.text,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 전화번호
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            _phoneController.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 설명
                      if (_descriptionController.text.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          _descriptionController.text,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 통계 카드들
          Container(
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '배포된\n포스트',
                    '0',
                    Icons.post_add,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatCard(
                    '총 리워드',
                    '0원',
                    Icons.monetization_on,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // 컴팩트 폼 섹션 빌더
  Widget _buildCompactFormSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // 폼 섹션 빌더 (상세 정보 탭용)
  Widget _buildFormSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // 시간 행 빌더
  Widget _buildTimeRow(String day, String open, String close) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            day,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            close.isEmpty ? open : '$open ~ $close',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  // 편의시설 칩 빌더
  Widget _buildFacilityChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.brown.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 통계 카드 빌더
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

