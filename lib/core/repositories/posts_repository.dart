import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post/post_model.dart';
import '../models/post/post_instance_model.dart';

import '../datasources/firebase/posts_firebase_ds.dart';

/// 포스트 데이터 저장소
/// 
/// **책임**: 포스트 데이터 접근 로직
/// **TODO**: Datasource 완전 전환 필요
class PostsRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PostsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==================== 조회 (Read) ====================

  /// 포스트 템플릿 스트리밍
  /// 
  /// [userId]: 사용자 ID (내 포스트 필터용, null이면 전체)
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

  /// 단일 포스트 조회
  Future<PostModel?> getPostById(String postId) async {
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .get();
      
      if (!doc.exists) return null;
      return PostModel.fromFirestore(doc);
    } catch (e) {
      print('❌ 포스트 조회 실패: $e');
      return null;
    }
  }

  /// 포스트 인스턴스 스트리밍 (배포된 마커)
  Stream<List<PostInstanceModel>> streamPostInstances(String postId) {
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

  // ==================== 생성 (Create) ====================

  /// 포스트 템플릿 생성
  Future<String> createPost(PostModel post) async {
    try {
      final docRef = await _firestore
          .collection('posts')
          .add(post.toFirestore());
      
      return docRef.id;
    } catch (e) {
      print('❌ 포스트 생성 실패: $e');
      rethrow;
    }
  }

  /// 포스트 배포 (마커 생성)
  /// 
  /// 트랜잭션으로 처리:
  /// 1. 포스트 템플릿 확인
  /// 2. 마커 인스턴스 생성
  /// 3. 포인트 차감 (옵션)
  Future<String> deployPost({
    required String postId,
    required Map<String, dynamic> instanceData,
    bool deductPoints = false,
    int? pointCost,
  }) async {
    try {
      String? instanceId;

      await _firestore.runTransaction((transaction) async {
        // 1. 포스트 템플릿 확인
        final postDoc = await transaction.get(
          _firestore.collection('posts').doc(postId),
        );
        
        if (!postDoc.exists) {
          throw Exception('포스트를 찾을 수 없습니다');
        }

        // 2. 마커 인스턴스 생성
        final markerRef = _firestore.collection('markers').doc();
        transaction.set(markerRef, instanceData);
        instanceId = markerRef.id;

        // 3. 포인트 차감 (옵션)
        if (deductPoints && pointCost != null) {
          final user = _auth.currentUser;
          if (user != null) {
            final pointsRef = _firestore
                .collection('users')
                .doc(user.uid)
                .collection('points')
                .doc('current');
            
            transaction.update(pointsRef, {
              'totalPoints': FieldValue.increment(-pointCost),
            });
          }
        }
      });

      return instanceId ?? '';
    } catch (e) {
      print('❌ 포스트 배포 실패: $e');
      rethrow;
    }
  }

  // ==================== 수령 (Collect) ====================

  /// 포스트 수령 (트랜잭션)
  /// 
  /// 1. 마커 수량 감소
  /// 2. 수령 기록 생성
  /// 3. 포인트 이동 (옵션)
  Future<bool> collectPost({
    required String markerId,
    required String userId,
    int? rewardPoints,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. 마커 확인 및 수량 감소
        final markerRef = _firestore.collection('markers').doc(markerId);
        final markerDoc = await transaction.get(markerRef);
        
        if (!markerDoc.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }
        
        final quantity = markerDoc.data()?['quantity'] ?? 0;
        if (quantity <= 0) {
          throw Exception('수량이 부족합니다');
        }
        
        transaction.update(markerRef, {
          'quantity': quantity - 1,
        });

        // 2. 수령 기록
        final collectionRef = _firestore
            .collection('markers')
            .doc(markerId)
            .collection('collections')
            .doc();
        
        transaction.set(collectionRef, {
          'userId': userId,
          'collectedAt': FieldValue.serverTimestamp(),
          'reward': rewardPoints,
        });

        // 3. 포인트 이동 (옵션)
        if (rewardPoints != null && rewardPoints > 0) {
          final userPointsRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('points')
              .doc('current');
          
          transaction.update(userPointsRef, {
            'totalPoints': FieldValue.increment(rewardPoints),
          });
        }
      });

      return true;
    } catch (e) {
      print('❌ 포스트 수령 실패: $e');
      return false;
    }
  }

  /// 포스트 확정 (confirm)
  /// 
  /// 수집자가 확정하면 포인트가 최종 이동
  Future<bool> confirmPost({
    required String markerId,
    required String collectionId,
  }) async {
    try {
      await _firestore
          .collection('markers')
          .doc(markerId)
          .collection('collections')
          .doc(collectionId)
          .update({
        'confirmedAt': FieldValue.serverTimestamp(),
        'status': 'confirmed',
      });

      return true;
    } catch (e) {
      print('❌ 포스트 확정 실패: $e');
      return false;
    }
  }

  // ==================== 업데이트 (Update) ====================

  /// 포스트 템플릿 업데이트
  Future<bool> updatePost(
    String postId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .update(data);
      
      return true;
    } catch (e) {
      print('❌ 포스트 업데이트 실패: $e');
      return false;
    }
  }

  // ==================== 삭제 (Delete) ====================

  /// 포스트 템플릿 삭제
  Future<bool> deletePost(String postId) async {
    try {
      await _firestore
          .collection('posts')
          .doc(postId)
          .delete();
      
      return true;
    } catch (e) {
      print('❌ 포스트 삭제 실패: $e');
      return false;
    }
  }

  // ==================== 통계 ====================

  /// 포스트 수령 횟수 조회
  Future<int> getCollectionCount(String markerId) async {
    try {
      final snapshot = await _firestore
          .collection('markers')
          .doc(markerId)
          .collection('collections')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ 수령 횟수 조회 실패: $e');
      return 0;
    }
  }

  /// 사용자의 수령 내역 조회
  Stream<List<Map<String, dynamic>>> streamUserCollections(String userId) {
    return _firestore
        .collectionGroup('collections')
        .where('userId', isEqualTo: userId)
        .orderBy('collectedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }
}

