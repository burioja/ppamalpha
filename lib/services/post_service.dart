import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/post_model.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 포스트 생성
  Future<String> createPost({
    required String userId,
    required String content,
    required GeoPoint location,
    required String address,
    int price = 0,
    int amount = 0,
    int period = 24,
    String periodUnit = 'Hour',
    String function = 'Using',
    String target = '상관없음',
    int ageMin = 20,
    int ageMax = 30,
  }) async {
    try {
      final post = PostModel(
        id: '',
        userId: userId,
        content: content,
        location: location,
        address: address,
        price: price,
        amount: amount,
        period: period,
        periodUnit: periodUnit,
        function: function,
        target: target,
        ageMin: ageMin,
        ageMax: ageMax,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('posts').add(post.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('포스트 생성 실패: $e');
    }
  }

  // 현재 위치의 포스트 조회
  Future<List<PostModel>> getPostsNearLocation({
    required GeoPoint location,
    required double radiusInKm,
  }) async {
    try {
      // 간단한 구현: 모든 포스트를 가져와서 클라이언트에서 필터링
      // 실제 프로덕션에서는 Firestore의 지리적 쿼리를 사용해야 함
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();

      List<PostModel> posts = [];
      for (var doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        final distance = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          post.location.latitude,
          post.location.longitude,
        );
        
        if (distance <= radiusInKm * 1000) {
          posts.add(post);
        }
      }

      return posts;
    } catch (e) {
      throw Exception('포스트 조회 실패: $e');
    }
  }

  // 포스트 회수
  Future<void> collectPost({
    required String postId,
    required String userId,
  }) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isCollected': true,
        'collectedBy': userId,
        'collectedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('포스트 회수 실패: $e');
    }
  }

  // 사용자가 회수한 포스트 조회
  Future<List<PostModel>> getCollectedPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('collectedBy', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('회수한 포스트 조회 실패: $e');
    }
  }

  // 사용자가 생성한 포스트 조회
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('사용자 포스트 조회 실패: $e');
    }
  }

  // 포스트 삭제 (비활성화)
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('포스트 삭제 실패: $e');
    }
  }
} 