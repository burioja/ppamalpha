import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../routes/app_routes.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../place_system/screens/place_detail_screen.dart';
import '../../post_system/screens/post_detail_screen.dart';

enum SearchFilter { all, store, myPosts, receivedPosts }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  SearchFilter _currentFilter = SearchFilter.all;
  String _searchQuery = '';
  bool _isSearching = false;

  // Search results
  List<PlaceModel> _places = [];
  List<PostModel> _myPosts = [];
  List<PostModel> _receivedPosts = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Search places (stores)
  Future<List<PlaceModel>> _searchPlaces(String query) async {
    if (_currentUserId == null || query.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('places')
          .where('createdBy', isEqualTo: _currentUserId)
          .get();

      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .where((place) =>
              place.name.toLowerCase().contains(query.toLowerCase()) ||
              (place.description.toLowerCase().contains(query.toLowerCase())))
          .toList();
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  // Search my posts
  Future<List<PostModel>> _searchMyPosts(String query) async {
    if (_currentUserId == null || query.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('posts')
          .where('creatorId', isEqualTo: _currentUserId)  // ✅ creatorId로 수정
          .get();

      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .where((post) =>
              post.title.toLowerCase().contains(query.toLowerCase()) ||
              (post.description?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();
    } catch (e) {
      debugPrint('Error searching my posts: $e');
      return [];
    }
  }

  // Search received posts
  Future<List<PostModel>> _searchReceivedPosts(String query) async {
    if (_currentUserId == null || query.isEmpty) return [];

    try {
      // Get collected posts from post_collections
      final collectionSnapshot = await _firestore
          .collection('post_collections')
          .where('collectorId', isEqualTo: _currentUserId)
          .get();

      if (collectionSnapshot.docs.isEmpty) return [];

      final postIds = collectionSnapshot.docs.map((doc) => doc.data()['postId'] as String).toList();

      // Get post details
      final List<PostModel> posts = [];
      for (String postId in postIds) {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final post = PostModel.fromFirestore(postDoc);
          if (post.title.toLowerCase().contains(query.toLowerCase()) ||
              (post.description?.toLowerCase().contains(query.toLowerCase()) ?? false)) {
            posts.add(post);
          }
        }
      }

      return posts;
    } catch (e) {
      debugPrint('Error searching received posts: $e');
      return [];
    }
  }

  // Perform search
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _places = [];
        _myPosts = [];
        _receivedPosts = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      // Search based on filter
      if (_currentFilter == SearchFilter.all) {
        final results = await Future.wait([
          _searchPlaces(query),
          _searchMyPosts(query),
          _searchReceivedPosts(query),
        ]);

        setState(() {
          _places = results[0] as List<PlaceModel>;
          _myPosts = results[1] as List<PostModel>;
          _receivedPosts = results[2] as List<PostModel>;
        });
      } else if (_currentFilter == SearchFilter.store) {
        final places = await _searchPlaces(query);
        setState(() {
          _places = places;
          _myPosts = [];
          _receivedPosts = [];
        });
      } else if (_currentFilter == SearchFilter.myPosts) {
        final posts = await _searchMyPosts(query);
        setState(() {
          _places = [];
          _myPosts = posts;
          _receivedPosts = [];
        });
      } else if (_currentFilter == SearchFilter.receivedPosts) {
        final posts = await _searchReceivedPosts(query);
        setState(() {
          _places = [];
          _myPosts = [];
          _receivedPosts = posts;
        });
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('검색'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: '내 플레이스',
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.myPlaces);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '검색어를 입력하세요',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
              onSubmitted: _performSearch,
              onChanged: (value) {
                if (value.isEmpty) {
                  _performSearch('');
                }
              },
            ),
          ),

          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('전체', SearchFilter.all),
                const SizedBox(width: 8),
                _buildFilterChip('스토어', SearchFilter.store),
                const SizedBox(width: 8),
                _buildFilterChip('내 포스트', SearchFilter.myPosts),
                const SizedBox(width: 8),
                _buildFilterChip('받은 포스트', SearchFilter.receivedPosts),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search results
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SearchFilter filter) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = filter;
        });
        if (_searchController.text.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '검색어를 입력하세요',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final hasResults = _places.isNotEmpty || _myPosts.isNotEmpty || _receivedPosts.isNotEmpty;

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '"$_searchQuery"에 대한 검색 결과가 없습니다',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Places (Stores) section
        if (_places.isNotEmpty) ...[
          _buildSectionHeader('스토어', _places.length),
          ..._places.map((place) => _buildPlaceCard(place)),
          const SizedBox(height: 24),
        ],

        // My Posts section
        if (_myPosts.isNotEmpty) ...[
          _buildSectionHeader('내 포스트', _myPosts.length),
          ..._myPosts.map((post) => _buildPostCard(post, isMyPost: true)),
          const SizedBox(height: 24),
        ],

        // Received Posts section
        if (_receivedPosts.isNotEmpty) ...[
          _buildSectionHeader('받은 포스트', _receivedPosts.length),
          ..._receivedPosts.map((post) => _buildPostCard(post, isMyPost: false)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count개',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(PlaceModel place) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.store, color: Colors.blue),
        ),
        title: Text(
          place.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          place.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaceDetailScreen(placeId: place.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(PostModel post, {required bool isMyPost}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMyPost
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Icon(
            Icons.article,
            color: isMyPost ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          post.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.description != null)
              Text(
                post.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.stars,
                  size: 16,
                  color: Colors.amber.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.reward}P',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailScreen(
                post: post,
                isEditable: isMyPost,
              ),
            ),
          );
        },
      ),
    );
  }
}