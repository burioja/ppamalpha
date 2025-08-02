import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

class AddressSearchWidget extends StatefulWidget {
  final Function(String) onAddressSelected;
  final TextEditingController controller;
  final InputDecoration? decoration;

  const AddressSearchWidget({
    super.key,
    required this.onAddressSelected,
    required this.controller,
    this.decoration,
  });

  @override
  _AddressSearchWidgetState createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget> {
  List<Location> _suggestedLocations = [];

  Future<void> _searchAddress(String query) async {
    try {
      List<Location> locations = await locationFromAddress(query);
      setState(() {
        _suggestedLocations = locations;
      });
    } catch (e) {
      print('주소 검색 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          decoration: widget.decoration ??
              const InputDecoration(
                labelText: '주소 검색',
              ),
          onChanged: _searchAddress,
        ),
        const SizedBox(height: 9),
        Expanded(
          child: ListView.builder(
            itemCount: _suggestedLocations.length,
            itemBuilder: (context, index) {
              final location = _suggestedLocations[index];
              return ListTile(
                title: Text('위도: ${location.latitude}, 경도: ${location.longitude}'),
                onTap: () {
                  widget.onAddressSelected('${location.latitude},${location.longitude}');
                  widget.controller.clear();
                  setState(() {
                    _suggestedLocations.clear();
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
