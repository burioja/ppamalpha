import 'package:flutter/material.dart';

class RangeSliderWithInput extends StatefulWidget {
  final String label;
  final RangeValues initialValues;
  final double min;
  final double max;
  final int divisions;
  final String? Function(RangeValues)? validator;
  final ValueChanged<RangeValues>? onChanged;
  final String Function(double) labelBuilder;

  const RangeSliderWithInput({
    super.key,
    required this.label,
    required this.initialValues,
    required this.min,
    required this.max,
    this.divisions = 0,
    this.validator,
    this.onChanged,
    required this.labelBuilder,
  });

  @override
  State<RangeSliderWithInput> createState() => _RangeSliderWithInputState();
}

class _RangeSliderWithInputState extends State<RangeSliderWithInput> {
  late RangeValues _values;
  late TextEditingController _startController;
  late TextEditingController _endController;

  @override
  void initState() {
    super.initState();
    _values = widget.initialValues;
    _startController = TextEditingController(text: widget.labelBuilder(_values.start).toString());
    _endController = TextEditingController(text: widget.labelBuilder(_values.end).toString());
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _updateSlider(RangeValues newValues) {
    setState(() {
      _values = newValues;
      _startController.text = widget.labelBuilder(newValues.start);
      _endController.text = widget.labelBuilder(newValues.end);
    });
    widget.onChanged?.call(newValues);
  }

  void _updateFromText(String value, bool isStart) {
    // "세" 문자를 제거하고 숫자만 파싱
    final cleanValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final double? parsedValue = double.tryParse(cleanValue);
    if (parsedValue != null && parsedValue >= widget.min && parsedValue <= widget.max) {
      RangeValues newValues;
      if (isStart) {
        newValues = RangeValues(
          parsedValue,
          parsedValue > _values.end ? parsedValue : _values.end,
        );
      } else {
        newValues = RangeValues(
          parsedValue < _values.start ? parsedValue : _values.start,
          parsedValue,
        );
      }
      _updateSlider(newValues);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _startController,
                decoration: const InputDecoration(
                  labelText: '시작',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _updateFromText(value, true),
                validator: (value) {
                  if (value == null || value.isEmpty) return '값을 입력해주세요';
                  // "세" 문자를 제거하고 숫자만 파싱
                  final cleanValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
                  final double? parsedValue = double.tryParse(cleanValue);
                  if (parsedValue == null || parsedValue < widget.min || parsedValue > widget.max) {
                    return '${widget.min}~${widget.max} 사이의 값을 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _endController,
                decoration: const InputDecoration(
                  labelText: '끝',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _updateFromText(value, false),
                validator: (value) {
                  if (value == null || value.isEmpty) return '값을 입력해주세요';
                  // "세" 문자를 제거하고 숫자만 파싱
                  final cleanValue = value.replaceAll(RegExp(r'[^0-9.]'), '');
                  final double? parsedValue = double.tryParse(cleanValue);
                  if (parsedValue == null || parsedValue < widget.min || parsedValue > widget.max) {
                    return '${widget.min}~${widget.max} 사이의 값을 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        RangeSlider(
          values: _values,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          labels: RangeLabels(
            widget.labelBuilder(_values.start),
            widget.labelBuilder(_values.end),
          ),
          onChanged: _updateSlider,
        ),
      ],
    );
  }
}
