import 'package:flutter/material.dart';

class PostTargetingWidgets {
  // 타겟팅 섹션 (성별과 나이를 한 줄에 배치)
  static Widget buildTargetingInline({
    required List<String> selectedGenders,
    required RangeValues selectedAgeRange,
    required Function(List<String>) onGenderChanged,
    required Function(RangeValues) onAgeRangeChanged,
  }) {
    return Column(
      children: [
        // 성별과 나이를 한 줄에 배치
        Row(
          children: [
            // 성별 선택
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '성별',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGenderButton(
                          '남',
                          'male',
                          Colors.blue,
                          selectedGenders,
                          onGenderChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGenderButton(
                          '여',
                          'female',
                          Colors.pink,
                          selectedGenders,
                          onGenderChanged,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 나이 선택
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        '나이',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 40, // 성별 버튼과 동일한 높이
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Stack(
                      children: [
                        RangeSlider(
                          values: selectedAgeRange,
                          min: 18,
                          max: 65,
                          divisions: 47,
                          activeColor: Colors.orange,
                          inactiveColor: Colors.grey[300],
                          onChanged: onAgeRangeChanged,
                        ),
                        // 슬라이더 위에 숫자 표시
                        Positioned(
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[600],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${selectedAgeRange.start.round()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[600],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${selectedAgeRange.end.round()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 성별 버튼
  static Widget _buildGenderButton(
    String label,
    String value,
    Color color,
    List<String> selectedGenders,
    Function(List<String>) onChanged,
  ) {
    final isSelected = selectedGenders.contains(value);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isSelected ? color : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? color : color.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            List<String> newGenders = List.from(selectedGenders);
            if (isSelected) {
              newGenders.remove(value);
            } else {
              newGenders.add(value);
            }
            onChanged(newGenders);
          },
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 추가 옵션 섹션
  static Widget buildAdditionalOptions({
    required String selectedFunction,
    required String selectedTargeting,
    required bool hasExpiration,
    required bool canTransfer,
    required bool canForward,
    required bool canRespond,
    required List<String> functions,
    required List<String> targetingOptions,
    required Function(String?) onFunctionChanged,
    required Function(String?) onTargetingChanged,
    required Function(bool?) onExpirationChanged,
    required Function(bool?) onTransferChanged,
    required Function(bool?) onForwardChanged,
    required Function(bool?) onRespondChanged,
  }) {
    return Column(
      children: [
        // 기능 선택
        Row(
          children: [
            Expanded(
              child: _buildCompactDropdown(
                label: '기능',
                value: selectedFunction,
                items: functions,
                icon: Icons.settings,
                onChanged: onFunctionChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 타겟팅 레벨 선택
        Row(
          children: [
            Expanded(
              child: _buildCompactDropdown(
                label: '타겟팅',
                value: selectedTargeting,
                items: targetingOptions,
                icon: Icons.tune,
                onChanged: onTargetingChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 체크박스 옵션들 (2x2 그리드)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3,
          children: [
            _buildCheckboxOption(
              '만료일 설정',
              hasExpiration,
              onExpirationChanged,
            ),
            _buildCheckboxOption(
              '전달 가능',
              canTransfer,
              onTransferChanged,
            ),
            _buildCheckboxOption(
              '전달 가능',
              canForward,
              onForwardChanged,
            ),
            _buildCheckboxOption(
              '응답 가능',
              canRespond,
              onRespondChanged,
            ),
          ],
        ),
      ],
    );
  }

  // 컴팩트 드롭다운
  static Widget _buildCompactDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // 체크박스 옵션 (토글로 변경)
  static Widget _buildCheckboxOption(
    String label,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: value ? Colors.blue[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? Colors.blue[300]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: value ? Colors.blue[700] : Colors.grey[700],
                fontWeight: value ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
