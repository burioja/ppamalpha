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
      
      // 생성된 포스트의 ID를 반환
      return docRef.id;
    } catch (e) {
      throw Exception('포스트 생성 실패: $e');
    }
  }

  // 조건에 맞는 포스트만 조회
  Future<List<PostModel>> getPostsNearLocationWithConditions({
    required GeoPoint location,
    required double radiusInKm,
    String? userGender,
    int? userAge,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .get();

      List<PostModel> posts = [];
      for (var doc in querySnapshot.docs) {
        final post = PostModel.fromFirestore(doc);
        
        // 거리 확인
        final distance = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          post.location.latitude,
          post.location.longitude,
        );
        
        if (distance <= radiusInKm * 1000) {
          // 조건 확인
          if (_checkPostConditions(post, userGender, userAge)) {
            posts.add(post);
          }
        }
      }

      return posts;
    } catch (e) {
      throw Exception('포스트 조회 실패: $e');
    }
  }

  // 포스트 조건 확인
  bool _checkPostConditions(PostModel post, String? userGender, int? userAge) {
    // 타겟 조건 파싱 (예: "남성/20대")
    final targetParts = post.target.split('/');
    final targetGender = targetParts.isNotEmpty ? targetParts[0] : '상관없음';
    final targetAgeRange = targetParts.length > 1 ? targetParts[1] : '상관없음';
    
    // 성별 조건 확인
    if (targetGender != '상관없음' && userGender != null) {
      if (targetGender != userGender) return false;
    }
    
    // 나이 조건 확인
    if (targetAgeRange != '상관없음' && userAge != null) {
      if (!_isAgeInRange(userAge, targetAgeRange)) return false;
    }
    
    // 나이 범위 조건 확인
    if (userAge != null) {
      if (userAge < post.ageMin || userAge > post.ageMax) return false;
    }
    
    return true;
  }

  // 나이 범위 확인
  bool _isAgeInRange(int userAge, String targetAgeRange) {
    switch (targetAgeRange) {
      case '10대':
        return userAge >= 10 && userAge <= 19;
      case '20대':
        return userAge >= 20 && userAge <= 29;
      case '30대':
        return userAge >= 30 && userAge <= 39;
      case '40대':
        return userAge >= 40 && userAge <= 49;
      case '50대+':
        return userAge >= 50;
      default:
        return true;
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