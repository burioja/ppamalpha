import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post/post_model.dart';
import '../../models/post/post_instance_model.dart';

/// 포스트 Firebase Datasource
/// 
/// **책임**: Firebase SDK 직접 호출만 담당
/// **원칙**: 순수 CRUD만, 비즈니스 로직 없음
abstract class PostsFirebaseDataSource {
  Stream<List<PostModel>> streamPosts({String? userId});
  Future<PostModel?> getById(String postId);
  Future<String> create(Map<String, dynamic> data);
  Future<void> update(String postId, Map<String, dynamic> data);
  Future<void> delete(String postId);
  Stream<List<PostInstanceModel>> streamInstances(String postId);
  Future<void> runTransaction(Future<void> Function(Transaction) transactionHandler);
}

/// 포스트 Firebase Datasource 구현
class PostsFirebaseDataSourceImpl implements PostsFirebaseDataSource {
  final FirebaseFirestore _firestore;

  PostsFirebaseDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<PostModel>> streamPosts({String? userId}) {
    Query query = _firestore.collection('posts');
    
    if (userId != null) {
      query = query.where('creatorId', isEqualTo: userId);
    }
    
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<PostModel?> getById(String postId) async {
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();
      
      if (!doc.exists) return null;
      return PostModel.fromFirestore(doc);
    } catch (e) {
      print('❌ Datasource: 포스트 조회 실패: $e');
      rethrow;
    }
  }

  @override
  Future<String> create(Map<String, dynamic> data) async {
    try {
      final docRef = await _firestore
          .collection('posts')
          .add(data);
      
      return docRef.id;
    } catch (e) {
      print('❌ Datasource: 포스트 생성 실패: $e');
      rethrow;
    }
  }
  
  /// PostModel을 바로 생성 (헬퍼)
  Future<String> createFromModel(PostModel post) async {
    return await create(post.toFirestore());
  }

  @override
  Future<void> update(String postId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .update(data);
    } catch (e) {
      print('❌ Datasource: 포스트 업데이트 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> delete(String postId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .delete();
    } catch (e) {
      print('❌ Datasource: 포스트 삭제 실패: $e');
      rethrow;
    }
  }

  @override
  Stream<List<PostInstanceModel>> streamInstances(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('instances')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PostInstanceModel.fromFirestore(doc))
          .toList();
    });
  }

  @override
  Future<void> runTransaction(
    Future<void> Function(Transaction) transactionHandler,
  ) async {
    try {
      await _firestore.runTransaction(transactionHandler);
    } catch (e) {
      print('❌ Datasource: 트랜잭션 실패: $e');
      rethrow;
    }
  }

  /// Firebase 컬렉션 참조 헬퍼
  CollectionReference<Map<String, dynamic>> get postsCollection {
    return _firestore.collection('posts');
  }

  CollectionReference<Map<String, dynamic>> get markersCollection {
    return _firestore.collection('markers');
  }

  DocumentReference<Map<String, dynamic>> postDoc(String postId) {
    return _firestore.collection('posts').doc(postId);
  }

  DocumentReference<Map<String, dynamic>> markerDoc(String markerId) {
    return _firestore.collection('markers').doc(markerId);
  }
}

