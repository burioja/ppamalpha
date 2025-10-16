import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// 포스트 수집 관련 헬퍼 클래스
class PostCollectionHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 수집 기록 생성
  static Future<String> createCollectionRecord({
    required String postId,
    required String userId,
    required String creatorId,
    required int reward,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 멱등 ID 생성 (postId_userId)
      final collectionId = '${postId}_$userId';

      final collectionData = {
        'postId': postId,
        'userId': userId,
        'postCreatorId': creatorId,
        'reward': reward,
        'collectedAt': FieldValue.serverTimestamp(),
        'confirmed': false,
        'metadata': metadata ?? {},
      };

      await _firestore
          .collection('post_collections')
          .doc(collectionId)
          .set(collectionData);

      debugPrint('✅ 수집 기록 생성 완료: $collectionId');
      return collectionId;
    } catch (e) {
      debugPrint('❌ 수집 기록 생성 실패: $e');
      rethrow;
    }
  }

  /// 수집 확인 처리
  static Future<void> confirmCollection({
    required String collectionId,
    required String userId,
    required int reward,
  }) async {
    try {
      await _firestore
          .collection('post_collections')
          .doc(collectionId)
          .update({
        'confirmed': true,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 수집 확인 완료: $collectionId');
    } catch (e) {
      debugPrint('❌ 수집 확인 실패: $e');
      rethrow;
    }
  }

  /// 사용자의 수집 기록 조회
  static Future<List<Map<String, dynamic>>> getUserCollections(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('post_collections')
          .where('userId', isEqualTo: userId)
          .orderBy('collectedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();
    } catch (e) {
      debugPrint('❌ 사용자 수집 기록 조회 실패: $e');
      return [];
    }
  }

  /// 포스트의 수집 통계 조회
  static Future<Map<String, dynamic>> getPostCollectionStats(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('post_collections')
          .where('postId', isEqualTo: postId)
          .get();

      final total = snapshot.size;
      final confirmed = snapshot.docs.where((doc) => doc.data()['confirmed'] == true).length;
      final uniqueCollectors = snapshot.docs.map((doc) => doc.data()['userId']).toSet().length;

      return {
        'total': total,
        'confirmed': confirmed,
        'unconfirmed': total - confirmed,
        'uniqueCollectors': uniqueCollectors,
      };
    } catch (e) {
      debugPrint('❌ 포스트 수집 통계 조회 실패: $e');
      return {'total': 0, 'confirmed': 0, 'unconfirmed': 0, 'uniqueCollectors': 0};
    }
  }
}

