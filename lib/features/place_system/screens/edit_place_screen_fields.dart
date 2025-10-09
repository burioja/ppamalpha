import 'package:flutter/material.dart';

// Phase 1, 2, 3 입력 폼 섹션들을 위한 Helper Widgets

class EditPlaceFieldsHelper {
  // ========== Phase 1 입력 폼 ==========

  // 주차 정보 입력 섹션
  static Widget buildParkingSection({
    required String? selectedParkingType,
    required int? parkingCapacity,
    required TextEditingController parkingFeeController,
    required bool hasValetParking,
    required Function(String?) onParkingTypeChanged,
    required Function(int?) onCapacityChanged,
    required Function(bool) onValetParkingChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '주차 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedParkingType,
          decoration: const InputDecoration(
            labelText: '주차 형태',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_parking),
          ),
          items: const [
            DropdownMenuItem(value: 'self', child: Text('자체 주차장')),
            DropdownMenuItem(value: 'valet', child: Text('발레파킹')),
            DropdownMenuItem(value: 'nearby', child: Text('인근 주차장 이용')),
            DropdownMenuItem(value: 'none', child: Text('주차 불가')),
          ],
          onChanged: onParkingTypeChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: parkingCapacity?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '주차 가능 대수',
                  border: OutlineInputBorder(),
                  hintText: '예: 20',
                  prefixIcon: Icon(Icons.pin_drop),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  onCapacityChanged(int.tryParse(value));
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: parkingFeeController,
                decoration: const InputDecoration(
                  labelText: '주차 요금',
                  border: OutlineInputBorder(),
                  hintText: '예: 시간당 2000원',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: hasValetParking,
          onChanged: (value) => onValetParkingChanged(value ?? false),
          title: const Text('발레파킹 제공'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  // 편의시설 선택 섹션
  static Widget buildFacilitiesSection({
    required List<String> selectedFacilities,
    required Function(String, bool) onFacilityChanged,
  }) {
    final facilities = {
      'wifi': 'Wi-Fi',
      'wheelchair': '휠체어 이용 가능',
      'kids_zone': '키즈존',
      'pet_friendly': '반려동물 동반 가능',
      'smoking_area': '흡연 구역',
      'restroom': '화장실',
      'elevator': '엘리베이터',
      'ac': '에어컨',
      'heating': '난방',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '편의시설',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: facilities.entries.map((entry) {
            final isSelected = selectedFacilities.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) => onFacilityChanged(entry.key, selected),
              selectedColor: Colors.blue.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  // 결제 수단 선택 섹션
  static Widget buildPaymentMethodsSection({
    required List<String> selectedPaymentMethods,
    required Function(String, bool) onPaymentMethodChanged,
  }) {
    final paymentMethods = {
      'card': '카드',
      'cash': '현금',
      'mobile_pay': '모바일 결제',
      'cryptocurrency': '암호화폐',
      'account_transfer': '계좌이체',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 수단',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: paymentMethods.entries.map((entry) {
            final isSelected = selectedPaymentMethods.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) => onPaymentMethodChanged(entry.key, selected),
              selectedColor: Colors.green.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  // 요일별 운영시간 입력 섹션
  static Widget buildOperatingHoursDetailSection({
    required Map<String, dynamic> operatingHours,
    required Function() onEditOperatingHours,
  }) {
    final days = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '요일별 운영시간',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: onEditOperatingHours,
              icon: const Icon(Icons.edit),
              label: const Text('편집'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (operatingHours.isEmpty)
          const Text('운영시간이 설정되지 않았습니다', style: TextStyle(color: Colors.grey))
        else
          ...days.map((day) {
            final hours = operatingHours[day];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    hours ?? '휴무',
                    style: TextStyle(
                      color: hours == null ? Colors.red : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 운영시간 상세 섹션 (24시간, 정기휴무, 브레이크타임)
  static Widget buildOperatingHoursSection({
    required bool isOpen24Hours,
    required List<String> regularHolidays,
    required Map<String, String> breakTimes,
    required Function(bool) on24HoursChanged,
    required Function() onAddHoliday,
    required Function(int) onRemoveHoliday,
    required Function() onAddBreakTime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '운영시간 추가 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: isOpen24Hours,
          onChanged: (value) => on24HoursChanged(value ?? false),
          title: const Text('24시간 운영'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('정기 휴무일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            TextButton.icon(
              onPressed: onAddHoliday,
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ],
        ),
        if (regularHolidays.isEmpty)
          const Text('정기 휴무일이 없습니다', style: TextStyle(color: Colors.grey))
        else
          ...regularHolidays.asMap().entries.map((entry) {
            return ListTile(
              title: Text(entry.value),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => onRemoveHoliday(entry.key),
              ),
            );
          }),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('브레이크타임', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            TextButton.icon(
              onPressed: onAddBreakTime,
              icon: const Icon(Icons.add),
              label: const Text('추가'),
            ),
          ],
        ),
        if (breakTimes.isEmpty)
          const Text('브레이크타임이 없습니다', style: TextStyle(color: Colors.grey))
        else
          ...breakTimes.entries.map((entry) {
            return ListTile(
              title: Text('${entry.key}: ${entry.value}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  breakTimes.remove(entry.key);
                },
              ),
            );
          }),
      ],
    );
  }

  // ========== Phase 2 입력 폼 ==========

  // 접근성 선택 섹션
  static Widget buildAccessibilitySection({
    required List<String> selectedAccessibility,
    required Function(String, bool) onAccessibilityChanged,
  }) {
    final accessibilityOptions = {
      'wheelchair_ramp': '휠체어 경사로',
      'wheelchair_restroom': '장애인 화장실',
      'elevator_wheelchair': '휠체어 이용 가능 엘리베이터',
      'braille_blocks': '점자 블록',
      'sign_language': '수어 서비스',
      'parking_disabled': '장애인 주차구역',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '접근성',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: accessibilityOptions.entries.map((entry) {
            final isSelected = selectedAccessibility.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) => onAccessibilityChanged(entry.key, selected),
              selectedColor: Colors.teal.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  // 가격대 및 규모 섹션
  static Widget buildPriceAndCapacitySection({
    required String? selectedPriceRange,
    required int? capacity,
    required TextEditingController areaSizeController,
    required Function(String?) onPriceRangeChanged,
    required Function(int?) onCapacityChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '가격대 및 규모',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedPriceRange,
          decoration: const InputDecoration(
            labelText: '가격대',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          items: const [
            DropdownMenuItem(value: 'budget', child: Text('저렴 (₩)')),
            DropdownMenuItem(value: 'moderate', child: Text('보통 (₩₩)')),
            DropdownMenuItem(value: 'expensive', child: Text('비쌈 (₩₩₩)')),
            DropdownMenuItem(value: 'luxury', child: Text('고급 (₩₩₩₩)')),
          ],
          onChanged: onPriceRangeChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: capacity?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: '수용 인원',
                  border: OutlineInputBorder(),
                  hintText: '예: 50',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => onCapacityChanged(int.tryParse(value)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: areaSizeController,
                decoration: const InputDecoration(
                  labelText: '면적',
                  border: OutlineInputBorder(),
                  hintText: '예: 100㎡',
                  prefixIcon: Icon(Icons.straighten),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 상세 위치 정보 섹션
  static Widget buildLocationDetailsSection({
    required TextEditingController floorController,
    required TextEditingController buildingNameController,
    required TextEditingController landmarkController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '상세 위치 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: floorController,
          decoration: const InputDecoration(
            labelText: '층수',
            border: OutlineInputBorder(),
            hintText: '예: 3층',
            prefixIcon: Icon(Icons.stairs),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: buildingNameController,
          decoration: const InputDecoration(
            labelText: '건물명',
            border: OutlineInputBorder(),
            hintText: '예: 역삼빌딩',
            prefixIcon: Icon(Icons.business),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: landmarkController,
          decoration: const InputDecoration(
            labelText: '주변 랜드마크',
            border: OutlineInputBorder(),
            hintText: '예: 강남역 2번 출구 근처',
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
      ],
    );
  }

  // ========== Phase 3 입력 폼 ==========

  // 예약 시스템 섹션
  static Widget buildReservationSection({
    required bool hasReservation,
    required TextEditingController reservationUrlController,
    required TextEditingController reservationPhoneController,
    required Function(bool) onReservationChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '예약 시스템',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: hasReservation,
          onChanged: (value) => onReservationChanged(value ?? false),
          title: const Text('예약 시스템 제공'),
          contentPadding: EdgeInsets.zero,
        ),
        if (hasReservation) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: reservationUrlController,
            decoration: const InputDecoration(
              labelText: '예약 URL',
              border: OutlineInputBorder(),
              hintText: 'https://booking.example.com',
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: reservationPhoneController,
            decoration: const InputDecoration(
              labelText: '예약 전화번호',
              border: OutlineInputBorder(),
              hintText: '02-1234-5678',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
        ],
      ],
    );
  }

  // 임시 휴업 섹션
  static Widget buildClosureSection({
    required bool isTemporarilyClosed,
    required DateTime? reopeningDate,
    required TextEditingController closureReasonController,
    required Function(bool) onClosureChanged,
    required Function() onSelectReopeningDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '임시 휴업',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: isTemporarilyClosed,
          onChanged: (value) => onClosureChanged(value ?? false),
          title: const Text('임시 휴업 중'),
          contentPadding: EdgeInsets.zero,
        ),
        if (isTemporarilyClosed) ...[
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              reopeningDate != null
                  ? '재개업 예정: ${reopeningDate.year}-${reopeningDate.month.toString().padLeft(2, '0')}-${reopeningDate.day.toString().padLeft(2, '0')}'
                  : '재개업 날짜 선택',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: onSelectReopeningDate,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: closureReasonController,
            decoration: const InputDecoration(
              labelText: '휴업 사유',
              border: OutlineInputBorder(),
              hintText: '예: 리모델링 공사',
              prefixIcon: Icon(Icons.info_outline),
            ),
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  // 미디어 섹션
  static Widget buildMediaSection({
    required TextEditingController virtualTourUrlController,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '추가 미디어',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: virtualTourUrlController,
          decoration: const InputDecoration(
            labelText: '가상 투어 URL',
            border: OutlineInputBorder(),
            hintText: 'https://virtualtour.example.com',
            prefixIcon: Icon(Icons.view_in_ar),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '동영상, 내부/외부 이미지는 추후 업로드 기능 추가 예정',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
