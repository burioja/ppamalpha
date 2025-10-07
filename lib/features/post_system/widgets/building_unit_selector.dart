import 'package:flutter/material.dart';

class BuildingUnitSelector extends StatefulWidget {
  final String buildingName;
  final Function(String) onUnitSelected;

  const BuildingUnitSelector({
    super.key,
    required this.buildingName,
    required this.onUnitSelected,
  });

  @override
  State<BuildingUnitSelector> createState() => _BuildingUnitSelectorState();
}

class _BuildingUnitSelectorState extends State<BuildingUnitSelector> {
  String? _selectedUnit;
  List<String> _buildingUnits = [];

  @override
  void initState() {
    super.initState();
    _parseBuildingUnits();
  }

  /// 건물명에서 동 정보를 파싱합니다
  void _parseBuildingUnits() {
    final buildingName = widget.buildingName;
    
    // 집합건물 패턴들
    final patterns = [
      RegExp(r'(\d+동)', caseSensitive: false), // "1동", "2동" 등
      RegExp(r'동(\d+)', caseSensitive: false), // "동1", "동2" 등
      RegExp(r'(\d+호)', caseSensitive: false), // "1호", "2호" 등 (빌딩)
    ];

    Set<String> units = {'전체 건물'}; // 기본 옵션

    // 각 패턴으로 검색
    for (final pattern in patterns) {
      final matches = pattern.allMatches(buildingName);
      for (final match in matches) {
        units.add(match.group(0)!);
      }
    }

    // 아파트/빌딩 이름에서 숫자 추출
    final numberPattern = RegExp(r'(\d+)');
    final numbers = numberPattern.allMatches(buildingName);
    
    for (final match in numbers) {
      final number = match.group(1)!;
      if (int.tryParse(number) != null && int.parse(number) <= 20) {
        // 20개 이하의 숫자는 동으로 간주
        units.add('${number}동');
      }
    }

    setState(() {
      _buildingUnits = units.toList()..sort();
      _selectedUnit = _buildingUnits.first; // 첫 번째 옵션 선택
    });

    // 첫 번째 옵션으로 초기화 (다음 프레임에서 실행)
    if (_buildingUnits.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnitSelected(_buildingUnits.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_buildingUnits.length <= 1) {
      // 동 선택이 불필요한 경우
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.apartment, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '건물 단위 선택',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUnit,
              isExpanded: true,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
              items: _buildingUnits.map((unit) {
                return DropdownMenuItem<String>(
                  value: unit,
                  child: Text(unit),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedUnit = newValue;
                  });
                  widget.onUnitSelected(newValue);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
