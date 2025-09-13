import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

class PriceCalculator extends StatefulWidget {
  final List<dynamic> images;
  final dynamic sound;
  final TextEditingController priceController;
  final String? Function(String?)? validator;
  final VoidCallback? onPriceCalculated; // 콜백 추가

  const PriceCalculator({
    super.key,
    required this.images,
    required this.sound,
    required this.priceController,
    this.validator,
    this.onPriceCalculated,
  });

  @override
 State<PriceCalculator> createState() => _PriceCalculatorState();
}

class _PriceCalculatorState extends State<PriceCalculator> {
  static const double _basePricePer100KB = 100.0; // 100KB당 100원 기준
  double _minimumPrice = 0.0;
  double _totalSizeKB = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateMinimumPrice();
  }

  @override
  void didUpdateWidget(PriceCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 더 적극적으로 변화 감지 - 배열 내용 변화도 감지
    if (_hasMediaChanged(oldWidget)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateMinimumPrice();
        _updatePriceControllerIfNeeded();
      });
    }
  }

  bool _hasMediaChanged(PriceCalculator oldWidget) {
    // 배열 길이가 다르면 변경됨
    if (oldWidget.images.length != widget.images.length || 
        oldWidget.sound != widget.sound) {
      return true;
    }
    
    // 배열 내용이 다르면 변경됨 (참조 비교)
    for (int i = 0; i < widget.images.length; i++) {
      if (oldWidget.images[i] != widget.images[i]) {
        return true;
      }
    }
    
    return false;
  }

  // 외부에서 강제로 계산을 트리거할 수 있는 공개 메서드
  void forceRecalculate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMinimumPrice();
      _updatePriceControllerIfNeeded();
    });
  }

  void _updatePriceControllerIfNeeded() {
    // 현재 입력된 가격이 최소 가격보다 낮으면 최소 가격으로 업데이트
    final currentPrice = double.tryParse(widget.priceController.text) ?? 0;
    if (_minimumPrice > 0 && currentPrice < _minimumPrice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.priceController.text = _minimumPrice.toInt().toString();
      });
    }
  }

  void _calculateMinimumPrice() {
    _totalSizeKB = 0.0;
    
    // 이미지 크기 계산
    for (dynamic image in widget.images) {
      if (image is File) {
        _totalSizeKB += image.lengthSync() / 1024;
      } else if (image is Uint8List) {
        _totalSizeKB += image.length / 1024;
      } else if (image is String && image.startsWith('data:image/')) {
        // data URL의 경우 base64 디코딩 후 크기 계산
        try {
          final base64Data = image.split(',')[1];
          final bytes = base64Decode(base64Data);
          _totalSizeKB += bytes.length / 1024;
        } catch (e) {
          // 디코딩 실패 시 기본값 사용
          _totalSizeKB += 100; // 기본 100KB
        }
      }
    }
    
    // 사운드 크기 계산
    if (widget.sound != null) {
      if (widget.sound is File) {
        _totalSizeKB += widget.sound.lengthSync() / 1024;
      } else if (widget.sound is Uint8List) {
        _totalSizeKB += widget.sound.length / 1024;
      }
    }
    
    // 최소 단가 계산 (100KB당 100원)
    _minimumPrice = (_totalSizeKB / 100.0) * _basePricePer100KB;
    
    setState(() {});
    
    // 계산 완료 콜백 호출
    if (widget.onPriceCalculated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onPriceCalculated!();
      });
    }
  }

  String? _validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return '단가를 입력해주세요';
    }
    
    final double? price = double.tryParse(value);
    if (price == null) {
      return '올바른 숫자를 입력해주세요';
    }
    
    if (price < 0) {
      return '단가는 0 이상이어야 합니다';
    }
    
    // 미디어가 있는 경우 최소 단가 검증
    if (_totalSizeKB > 0 && price < _minimumPrice) {
      return '최소 단가는 ${_minimumPrice.toInt()}원 이상이어야 합니다';
    }
    
    // 사용자 정의 validator가 있는 경우 호출
    if (widget.validator != null) {
      return widget.validator!(value);
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '단가',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.priceController,
          decoration: InputDecoration(
            labelText: '단가 (원)',
            border: const OutlineInputBorder(),
            suffixText: '원',
            helperText: _totalSizeKB > 0 
                ? '최소 단가: ${_minimumPrice.toInt()}원 (${_totalSizeKB.toStringAsFixed(1)}KB 기준)'
                : '미디어가 없어 제한이 없습니다',
          ),
          keyboardType: TextInputType.number,
          validator: _validatePrice,
        ),
        if (_totalSizeKB > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '총 미디어 크기: ${_totalSizeKB.toStringAsFixed(1)}KB (100KB당 ${_basePricePer100KB.toInt()}원)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
