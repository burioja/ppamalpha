import 'package:flutter/material.dart';

class GenderCheckboxGroup extends StatefulWidget {
  final List<String> selectedGenders;
  final ValueChanged<List<String>> onChanged;
  final String? Function(List<String>)? validator;

  const GenderCheckboxGroup({
    Key? key,
    required this.selectedGenders,
    required this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  State<GenderCheckboxGroup> createState() => _GenderCheckboxGroupState();
}

class _GenderCheckboxGroupState extends State<GenderCheckboxGroup> {
  late List<String> _selectedGenders;

  @override
  void initState() {
    super.initState();
    _selectedGenders = List.from(widget.selectedGenders);
  }

  void _toggleGender(String gender) {
    setState(() {
      if (_selectedGenders.contains(gender)) {
        _selectedGenders.remove(gender);
      } else {
        _selectedGenders.add(gender);
      }
      widget.onChanged(_selectedGenders);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별 타겟팅',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('남성'),
                value: _selectedGenders.contains('male'),
                onChanged: (bool? value) => _toggleGender('male'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: CheckboxListTile(
                title: const Text('여성'),
                value: _selectedGenders.contains('female'),
                onChanged: (bool? value) => _toggleGender('female'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        if (widget.validator != null)
          Builder(
            builder: (context) {
              final error = widget.validator!(_selectedGenders);
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
