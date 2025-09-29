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
 State<PriceCalculator> createState() => PriceCalculatorState();
}

class PriceCalculatorState extends State<PriceCalculator> {
  static const double _basePricePer100KB = 100.0; // 100KB당 100원 기준
  double _minimumPrice = 0.0;
  double _totalSizeKB = 0.0;

  @override
  void initState() {
    super.initState();
    print('[PriceCalculator] initState 호출됨');
    _calculateMinimumPrice();
  }

  @override
  void didUpdateWidget(PriceCalculator oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[PriceCalculator] didUpdateWidget 호출됨');
    print('[PriceCalculator] 이전 이미지 개수: ${oldWidget.images.length}, 현재 이미지 개수: ${widget.images.length}');
    print('[PriceCalculator] 이전 사운드: ${oldWidget.sound != null}, 현재 사운드: ${widget.sound != null}');

    // 더 적극적으로 변화 감지 - 배열 내용 변화도 감지
    if (_hasMediaChanged(oldWidget)) {
      print('[PriceCalculator] 미디어 변경 감지됨 - 재계산 수행');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateMinimumPrice();
        _updatePriceControllerIfNeeded();
      });
    } else {
      print('[PriceCalculator] 미디어 변경 없음');
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
    print('[PriceCalculator] forceRecalculate 호출됨');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMinimumPrice();
      _updatePriceControllerIfNeeded();
    });
  }

  void _updatePriceControllerIfNeeded() {
    final currentText = widget.priceController.text.trim();
    final currentPrice = double.tryParse(currentText) ?? 0;

    // 미디어가 있고 최소 가격이 0보다 클 때만 업데이트
    if (_minimumPrice > 0) {
      // 1. 가격 필드가 비어있거나 0인 경우 → 최소 가격으로 자동 설정
      // 2. 현재 가격이 최소 가격보다 낮은 경우 → 최소 가격으로 업데이트
      if (currentText.isEmpty || currentPrice == 0 || currentPrice < _minimumPrice) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.priceController.text = _minimumPrice.toInt().toString();
        });
      }
    }
  }

  /// 100원 단위로 올림
  /// 예: 149원 → 200원, 251원 → 300원, 300원 → 300원
  double _roundUpToHundred(double price) {
    if (price <= 0) return 0;
    return ((price / 100).ceil() * 100).toDouble();
  }

  void _calculateMinimumPrice() {
    print('=== [_calculateMinimumPrice] 시작 ===');
    _totalSizeKB = 0.0;

    print('이미지 개수: ${widget.images.length}');

    // 이미지 크기 계산
    for (int i = 0; i < widget.images.length; i++) {
      dynamic image = widget.images[i];
      double imageSizeKB = 0.0;

      print('이미지 $i 타입: ${image.runtimeType}');

      if (image is File) {
        imageSizeKB = image.lengthSync() / 1024;
        print('이미지 $i (File): ${imageSizeKB.toStringAsFixed(2)} KB');
      } else if (image is Uint8List) {
        imageSizeKB = image.length / 1024;
        print('이미지 $i (Uint8List): ${imageSizeKB.toStringAsFixed(2)} KB');
      } else if (image is String && image.startsWith('data:image/')) {
        // data URL의 경우 base64 디코딩 후 크기 계산
        try {
          final base64Data = image.split(',')[1];
          final bytes = base64Decode(base64Data);
          imageSizeKB = bytes.length / 1024;
          print('이미지 $i (Data URL): ${imageSizeKB.toStringAsFixed(2)} KB');
        } catch (e) {
          // 디코딩 실패 시 기본값 사용
          imageSizeKB = 100; // 기본 100KB
          print('이미지 $i (Data URL 디코딩 실패): 기본값 ${imageSizeKB.toStringAsFixed(2)} KB');
        }
      } else if (image is String) {
        // HTTP URL 등 기타 문자열의 경우 추정값 사용
        imageSizeKB = 150; // 기본 150KB
        print('이미지 $i (String URL): 추정값 ${imageSizeKB.toStringAsFixed(2)} KB');
      } else {
        // 알 수 없는 타입의 경우 기본값 사용
        imageSizeKB = 100; // 기본 100KB
        print('이미지 $i (알 수 없는 타입: ${image.runtimeType}): 기본값 ${imageSizeKB.toStringAsFixed(2)} KB');
      }

      _totalSizeKB += imageSizeKB;
    }

    // 사운드 크기 계산
    double soundSizeKB = 0.0;
    if (widget.sound != null) {
      print('사운드 타입: ${widget.sound.runtimeType}');
      if (widget.sound is File) {
        soundSizeKB = widget.sound.lengthSync() / 1024;
        print('사운드 (File): ${soundSizeKB.toStringAsFixed(2)} KB');
      } else if (widget.sound is Uint8List) {
        soundSizeKB = widget.sound.length / 1024;
        print('사운드 (Uint8List): ${soundSizeKB.toStringAsFixed(2)} KB');
      } else {
        print('사운드 (알 수 없는 타입): 0 KB');
      }
      _totalSizeKB += soundSizeKB;
    } else {
      print('사운드 없음');
    }

    print('총 미디어 크기: ${_totalSizeKB.toStringAsFixed(2)} KB');

    // 최소 단가 계산 (100KB당 100원)
    final rawPrice = (_totalSizeKB / 100.0) * _basePricePer100KB;

    // 100원 단위로 올림 적용
    _minimumPrice = _roundUpToHundred(rawPrice);

    print('계산된 원본 가격: ${rawPrice.toStringAsFixed(2)}원');
    print('100원 단위 올림 후 최소 단가: ${_minimumPrice.toStringAsFixed(0)}원');
    print('=== [_calculateMinimumPrice] 완료 ===');

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

    // 100원 단위 검증
    if (price % 100 != 0) {
      final roundedPrice = _roundUpToHundred(price);
      return '단가는 100원 단위여야 합니다 (${roundedPrice.toInt()}원으로 올림됩니다)';
    }

    // 미디어가 있는 경우 최소 단가 검증 (100원 단위 올림 적용된 값)
    if (_totalSizeKB > 0 && price < _minimumPrice) {
      return '최소 단가는 ${_minimumPrice.toInt()}원 이상이어야 합니다\n(미디어 용량 기준, 100원 단위 올림 적용)';
    }

    // 사용자 정의 validator가 있는 경우 호출
    if (widget.validator != null) {
      return widget.validator!(value);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    print('[PriceCalculator] build 호출됨 - 이미지: ${widget.images.length}개, 사운드: ${widget.sound != null}, 총 크기: ${_totalSizeKB}KB, 최소가격: ${_minimumPrice}원');
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
                ? '📷 이미지/🔊 사운드 포함 시 최소 단가: ${_minimumPrice.toInt()}원 (${_totalSizeKB.toStringAsFixed(1)}KB, 100원 단위 올림 적용)'
                : '💡 이미지나 사운드 추가 시 자동으로 최소 단가가 계산됩니다 (100원 단위 올림)',
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
