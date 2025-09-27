import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase 상태를 직접 확인하는 디버그 스크립트
class FirebaseDebugChecker {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 특정 포스트 ID 확인
  Future<void> checkSpecificPost(String postId) async {
    try {
      debugPrint('🔍 Firebase 디버그: postId=$postId 확인 중...');

      // posts 컬렉션 확인
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data()!;
        debugPrint('✅ posts 컬렉션에서 발견:');
        debugPrint('   - title: ${data['title']}');
        debugPrint('   - creatorId: ${data['creatorId']}');
        debugPrint('   - quantity: ${data['quantity']}');
        debugPrint('   - createdAt: ${data['createdAt']}');
      } else {
        debugPrint('❌ posts 컬렉션에서 찾을 수 없음');
      }

      // markers 컬렉션에서 이 postId를 참조하는 마커들 확인
      final markersQuery = await _firestore
          .collection('markers')
          .where('postId', isEqualTo: postId)
          .get();

      debugPrint('📍 이 postId를 참조하는 마커들: ${markersQuery.docs.length}개');
      for (final markerDoc in markersQuery.docs) {
        final markerData = markerDoc.data();
        debugPrint('   - markerId: ${markerDoc.id}');
        debugPrint('   - remainingQuantity: ${markerData['remainingQuantity']}');
        debugPrint('   - totalQuantity: ${markerData['totalQuantity']}');
      }

    } catch (e) {
      debugPrint('❌ Firebase 확인 중 오류: $e');
    }
  }

  /// 전체 컬렉션 상태 요약
  Future<void> checkAllCollections() async {
    final collections = ['posts', 'markers', 'post_collections', 'users', 'user_points'];

    for (final collectionName in collections) {
      try {
        debugPrint('🔍 $collectionName 컬렉션 확인 중...');

        final snapshot = await _firestore.collection(collectionName).limit(5).get();
        debugPrint('   - 문서 개수: ${snapshot.size}개 (최대 5개까지 확인)');

        if (snapshot.docs.isNotEmpty) {
          debugPrint('   - 첫 번째 문서 ID: ${snapshot.docs.first.id}');
          final firstDocData = snapshot.docs.first.data();
          final keys = firstDocData.keys.take(5).join(', ');
          debugPrint('   - 필드들: $keys...');
        }
      } catch (e) {
        debugPrint('   - ❌ 오류: $e');
      }
    }
  }

  /// 최근 생성된 포스트들 확인
  Future<void> checkRecentPosts() async {
    try {
      debugPrint('🔍 최근 생성된 포스트들 확인 중...');

      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      debugPrint('📊 최근 포스트 ${snapshot.docs.length}개:');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        debugPrint('   - ${doc.id}: ${data['title']} (${createdAt?.toString().substring(0, 19)})');
      }
    } catch (e) {
      debugPrint('❌ 최근 포스트 확인 중 오류: $e');
    }
  }
}

/// 전역 함수로 쉽게 호출 가능
Future<void> debugFirebaseCheck() async {
  final checker = FirebaseDebugChecker();

  debugPrint('🚀 Firebase 디버그 체크 시작');

  // 전체 컬렉션 상태
  await checker.checkAllCollections();

  // 최근 포스트들
  await checker.checkRecentPosts();

  // 특정 포스트 확인
  await checker.checkSpecificPost('fsTkJPcxCS2mPyJsIeA7');

  debugPrint('✅ Firebase 디버그 체크 완료');
}