import 'package:flutter/material.dart';

class PeriodSliderWithInput extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int>? onChanged;
  final String? Function(int)? validator;

  const PeriodSliderWithInput({
    Key? key,
    required this.initialValue,
    this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  State<PeriodSliderWithInput> createState() => _PeriodSliderWithInputState();
}

class _PeriodSliderWithInputState extends State<PeriodSliderWithInput> {
  late double _value;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.toDouble();
    _controller = TextEditingController(text: _value.toInt().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSlider(double newValue) {
    setState(() {
      _value = newValue;
      _controller.text = newValue.toInt().toString();
    });
    widget.onChanged?.call(newValue.toInt());
  }

  void _updateFromText(String value) {
    final int? parsedValue = int.tryParse(value);
    if (parsedValue != null && parsedValue >= 1 && parsedValue <= 30) {
      setState(() {
        _value = parsedValue.toDouble();
      });
      widget.onChanged?.call(parsedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기간',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _value,
                min: 1,
                max: 30,
                divisions: 29,
                label: '${_value.toInt()}일',
                onChanged: _updateSlider,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '일',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: _updateFromText,
                validator: (value) {
                  if (value == null || value.isEmpty) return '값을 입력해주세요';
                  final int? parsedValue = int.tryParse(value);
                  if (parsedValue == null || parsedValue < 1 || parsedValue > 30) {
                    return '1~30 사이의 값을 입력해주세요';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1일', style: TextStyle(color: Colors.grey[600])),
              Text('30일', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}
