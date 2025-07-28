import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'track_connection_screen.dart';
import 'store_detail_screen.dart';
import '../services/track_service.dart';

class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _followingPlaces = [];
  bool _isLoading = false;
  String _currentMode = 'work'; // 현재 모드 (기본값: work)

  @override
  void initState() {
    super.initState();
    _loadFollowingPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 팔로잉 중인 플레이스 목록 로드
  Future<void> _loadFollowingPlaces() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final followingSnapshot = await _firestore
          .collection('user_tracks')
          .doc(currentUserId)
          .collection('following')
          .get();

      setState(() {
        _followingPlaces = followingSnapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      print('팔로잉 플레이스 로드 오류: $e');
    }
  }

  // 검색어 토큰화 (공백으로 분리)
  List<String> _tokenizeQuery(String query) {
    return query.toLowerCase().trim().split(' ').where((token) => token.isNotEmpty).toList();
  }

  // 검색 점수 계산
  double _calculateSearchScore(String placeName, String description, List<String> searchTokens) {
    final nameLower = placeName.toLowerCase();
    final descLower = description.toLowerCase();
    double score = 0.0;

    for (final token in searchTokens) {
      // 이름에서 검색
      if (nameLower.contains(token)) {
        score += 10.0; // 이름 매칭은 높은 점수
        
        // 시작 부분 매칭은 추가 점수
        if (nameLower.startsWith(token)) {
          score += 5.0;
        }
      }
      
      // 설명에서 검색
      if (descLower.contains(token)) {
        score += 2.0; // 설명 매칭은 낮은 점수
      }
    }

    // 모든 토큰이 매칭되면 보너스 점수
    final allTokensMatch = searchTokens.every((token) => 
        nameLower.contains(token) || descLower.contains(token));
    if (allTokensMatch) {
      score += 3.0;
    }

    return score;
  }

  // 스토어 검색 (개선된 부분 검색)
  Future<void> _searchStores(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 모든 플레이스를 가져온 후 클라이언트에서 필터링
      final placesSnapshot = await _firestore
          .collection('places')
          .get();

      final results = <Map<String, dynamic>>[];
      final searchTokens = _tokenizeQuery(query);
      
      for (var doc in placesSnapshot.docs) {
        final placeData = doc.data();
        final placeName = (placeData['name'] ?? doc.id).toString();
        final description = (placeData['description'] ?? '').toString();
        
        // 검색 점수 계산
        final searchScore = _calculateSearchScore(placeName, description, searchTokens);
        
        // 점수가 0보다 크면 검색 결과에 포함
        if (searchScore > 0) {
          results.add({
            'placeId': doc.id,
            'name': placeName,
            'description': description,
            'isFollowing': _followingPlaces.contains(doc.id),
            'searchScore': searchScore,
          });
        }
      }

      // 검색 점수 순으로 정렬 (높은 점수가 우선)
      results.sort((a, b) {
        final scoreA = a['searchScore'] ?? 0.0;
        final scoreB = b['searchScore'] ?? 0.0;
        return scoreB.compareTo(scoreA);
      });

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      print('스토어 검색 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 트랙/언트랙 토글
  Future<void> _toggleTrack(String placeId, String placeName) async {
    try {
      final isTracked = await TrackService.isTracked(placeId);
      
      if (isTracked) {
        // 언트랙
        await TrackService.untrackPlace(placeId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$placeName 트랙을 해제했습니다.')),
        );
      } else {
        // 트랙
        await TrackService.trackPlace(placeId, _currentMode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$placeName을 $_currentMode 모드로 트랙했습니다.')),
        );
      }
      
      // 팔로잉 목록 다시 로드
      await _loadFollowingPlaces();
      
      // 검색 결과 업데이트
      setState(() {
        for (var result in _searchResults) {
          if (result['placeId'] == placeId) {
            result['isFollowing'] = !isTracked;
          }
        }
      });
    } catch (e) {
      print('트랙/언트랙 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 모드 변경
  void _changeMode(String mode) {
    setState(() {
      _currentMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토어 검색'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // 모드 선택 버튼
          PopupMenuButton<String>(
            onSelected: _changeMode,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'work',
                child: Row(
                  children: [
                    Icon(Icons.work, color: _currentMode == 'work' ? Colors.blue : Colors.grey),
                    const SizedBox(width: 8),
                    Text('워크 모드', style: TextStyle(
                      color: _currentMode == 'work' ? Colors.blue : Colors.black,
                      fontWeight: _currentMode == 'work' ? FontWeight.bold : FontWeight.normal,
                    )),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'life',
                child: Row(
                  children: [
                    Icon(Icons.home, color: _currentMode == 'life' ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Text('라이프 모드', style: TextStyle(
                      color: _currentMode == 'life' ? Colors.green : Colors.black,
                      fontWeight: _currentMode == 'life' ? FontWeight.bold : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentMode == 'work' ? Icons.work : Icons.home,
                    color: _currentMode == 'work' ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentMode == 'work' ? '워크' : '라이프',
                    style: TextStyle(
                      color: _currentMode == 'work' ? Colors.blue : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '스토어 이름을 검색하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchStores('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _searchStores(value);
              },
            ),
          ),
          
          // 검색 결과
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          '검색 결과가 없습니다.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final store = _searchResults[index];
                          final isFollowing = store['isFollowing'] ?? false;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  store['name'][0],
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: _buildHighlightedText(
                                store['name'],
                                _searchController.text,
                                const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: _buildHighlightedText(
                                store['description'],
                                _searchController.text,
                                const TextStyle(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 트랙/언트랙 버튼
                                  ElevatedButton(
                                    onPressed: () => _toggleTrack(
                                      store['placeId'],
                                      store['name'],
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isFollowing 
                                          ? Colors.grey 
                                          : (_currentMode == 'work' ? Colors.blue : Colors.green),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: Text(
                                      isFollowing ? '언트랙' : '트랙',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // 스토어 상세 버튼
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => StoreDetailScreen(
                                            placeId: store['placeId'],
                                            placeName: store['name'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.arrow_forward_ios),
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // 검색어 하이라이트 텍스트 위젯
  Widget _buildHighlightedText(
    String text,
    String searchQuery,
    TextStyle style, {
    int? maxLines,
    TextOverflow? overflow,
  }) {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final searchTokens = _tokenizeQuery(searchQuery);
    final spans = <TextSpan>[];
    String remainingText = text;

    // 각 검색 토큰에 대해 하이라이트 처리
    for (final token in searchTokens) {
      final tokenLower = token.toLowerCase();
      final textLower = remainingText.toLowerCase();
      final tokenIndex = textLower.indexOf(tokenLower);

      if (tokenIndex != -1) {
        // 토큰 이전 텍스트
        if (tokenIndex > 0) {
          spans.add(TextSpan(
            text: remainingText.substring(0, tokenIndex),
            style: style,
          ));
        }

        // 하이라이트된 토큰
        spans.add(TextSpan(
          text: remainingText.substring(tokenIndex, tokenIndex + token.length),
          style: style.copyWith(
            backgroundColor: Colors.yellow.withOpacity(0.3),
            fontWeight: FontWeight.bold,
          ),
        ));

        // 토큰 이후 텍스트
        remainingText = remainingText.substring(tokenIndex + token.length);
      }
    }

    // 남은 텍스트 추가
    if (remainingText.isNotEmpty) {
      spans.add(TextSpan(
        text: remainingText,
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
} 