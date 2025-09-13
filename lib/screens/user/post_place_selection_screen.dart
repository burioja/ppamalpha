import 'package:flutter/material.dart';
import '../../core/models/place/place_model.dart';
import '../../core/services/data/place_service.dart';

class PostPlaceSelectionScreen extends StatefulWidget {
  const PostPlaceSelectionScreen({super.key});

  @override
  State<PostPlaceSelectionScreen> createState() => _PostPlaceSelectionScreenState();
}

class _PostPlaceSelectionScreenState extends State<PostPlaceSelectionScreen> {
  final _placeService = PlaceService();
  List<PlaceModel> _userPlaces = [];
  bool _isLoading = true;
  String? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    _loadUserPlaces();
  }

  Future<void> _loadUserPlaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 현재 로그인한 사용자 ID를 가져와야 함
      // 임시로 하드코딩된 사용자 ID 사용 (실제로는 AuthService에서 가져와야 함)
      const String userId = 'v1W8RxAGO8REFnIIBTt1jMQXDOM2'; // 테스트용
      
      _userPlaces = await _placeService.getPlacesByUser(userId);
    } catch (e) {
      debugPrint('플레이스 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('플레이스 선택'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userPlaces.isEmpty
              ? _buildNoPlacesView()
              : _buildPlacesListView(),
    );
  }

  Widget _buildNoPlacesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_business, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            '플레이스가 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '포스트를 만들려면 먼저 플레이스를 생성해야 합니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _createNewPlace(context),
            icon: const Icon(Icons.add_business),
            label: const Text('플레이스 만들기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesListView() {
    return Column(
      children: [
        // 헤더
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    '포스트를 만들 플레이스를 선택하세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '선택한 플레이스에서 포스트가 생성됩니다',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
        
        // 플레이스 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _userPlaces.length + 1, // +1 for "새로 만들기" 버튼
            itemBuilder: (context, index) {
              if (index == _userPlaces.length) {
                // 새로 만들기 버튼
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Icon(Icons.add_business, color: Colors.green.shade600),
                    ),
                    title: const Text(
                      '새로운 플레이스 만들기',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    subtitle: const Text('새로운 플레이스를 생성합니다'),
                    onTap: () => _createNewPlace(context),
                  ),
                );
              }

              final place = _userPlaces[index];
              final isSelected = _selectedPlaceId == place.id;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                    child: Icon(
                      Icons.place,
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                    ),
                  ),
                  title: Text(
                    place.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.blue.shade800 : null,
                    ),
                  ),
                  subtitle: Text(
                    place.description.isNotEmpty 
                        ? place.description 
                        : '설명 없음',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected 
                      ? Icon(Icons.check_circle, color: Colors.blue.shade600)
                      : null,
                  onTap: () => _selectPlace(place),
                ),
              );
            },
          ),
        ),
        
        // 선택된 플레이스가 있을 때만 계속 버튼 표시
        if (_selectedPlaceId != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _continueToPostCreation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  '포스트 만들기 계속',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _selectPlace(PlaceModel place) {
    setState(() {
      _selectedPlaceId = place.id;
    });
  }

  void _createNewPlace(BuildContext context) async {
    final result = await Navigator.pushNamed(context, '/create-place');
    
    if (result == true) {
      // 플레이스 생성 완료 후 목록 새로고침
      await _loadUserPlaces();
      
      // 새로 생성된 플레이스가 있다면 자동 선택
      if (_userPlaces.isNotEmpty) {
        setState(() {
          _selectedPlaceId = _userPlaces.first.id;
        });
      }
    }
  }

  void _continueToPostCreation() async {
    if (_selectedPlaceId != null) {
      final selectedPlace = _userPlaces.firstWhere(
        (place) => place.id == _selectedPlaceId,
      );
      
      // PostDeployScreen에서 온 경우와 일반적인 경우를 구분
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final fromPostDeploy = args?['fromPostDeploy'] ?? false;
      
      if (fromPostDeploy) {
        // PostDeployScreen에서 온 경우: pushNamed 사용하여 결과 대기
        final result = await Navigator.pushNamed(
          context,
          '/post-place',
          arguments: {
            'place': selectedPlace,
            'fromSelection': true,
            'fromPostDeploy': true,
          },
        );
        
        // 포스트 생성 결과를 PostDeployScreen에 전달
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      } else {
        // 일반적인 경우: pushReplacementNamed 사용
        Navigator.pushReplacementNamed(
          context,
          '/post-place',
          arguments: {
            'place': selectedPlace,
            'fromSelection': true,
          },
        );
      }
    }
  }
}
