import 'package:flutter/material.dart';
import '../../core/services/location/nominatim_service.dart';

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchAddress() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await NominatimService.searchAddress(_searchController.text.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주소 검색 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<String?> _showDetailAddressDialog(BuildContext context) async {
    final TextEditingController detailController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('상세주소 입력'),
          content: TextField(
            controller: detailController,
            decoration: const InputDecoration(
              hintText: '동/호수 등 상세주소를 입력하세요',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, detailController.text.trim()),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '주소를 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchAddress(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _searchAddress,
                  child: _isSearching 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('검색'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            title: Text(result['display_name'] ?? ''),
                            subtitle: Text(
                              '${result['lat']}, ${result['lon']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            onTap: () async {
                              // 상세주소 입력 다이얼로그 표시
                              final detailAddress = await _showDetailAddressDialog(context);
                              if (context.mounted) {
                                // 주소와 상세주소를 함께 반환
                                Navigator.pop(context, {
                                  'address': result['display_name'] ?? '',
                                  'detailAddress': detailAddress ?? '',
                                  'lat': result['lat'],
                                  'lon': result['lon'],
                                  'raw': result,
                                });
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
