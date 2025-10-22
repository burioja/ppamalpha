import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 광고보드 포스트 서비스
/// 
/// **책임**:
/// - 광고보드 포스트 조회 (국가/지역 기반)
/// - 광고보드 포스트 수령
/// - 중복 수령 방지
/// - 수량 관리
class AdBoardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 광고보드 포스트 조회
  /// 
  /// [countryCode]: 사용자 국가 코드 (예: "KR")
  /// [regionCode]: 사용자 행정구역 코드 (예: "KR-11")
  /// 
  /// Returns: 수령 가능한 광고보드 포스트 목록
  Future<List<Map<String, dynamic>>> fetchAdBoardPosts({
    required String countryCode,
    String? regionCode,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // 기본 쿼리: 활성화 + 수량 있음 + 국가 일치
      Query query = _firestore
          .collection('ad_board_posts')
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('countryCodes', arrayContains: countryCode)
          .where('expiresAt', isGreaterThan: Timestamp.now());

      final snapshot = await query.get();
      
      final posts = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // 지역 코드 필터링 (선택적)
        if (regionCode != null && regionCode.isNotEmpty) {
          final regionCodes = List<String>.from(data['regionCodes'] ?? []);
          if (regionCodes.isNotEmpty && !regionCodes.contains(regionCode)) {
            continue;
          }
        }
        
        // 이미 수령했는지 확인
        final alreadyCollected = await _hasCollected(user.uid, doc.id);
        if (alreadyCollected) continue;
        
        posts.add({
          'postId': doc.id,
          ...data,
        });
      }
      
      return posts;
    } catch (e) {
      debugPrint('광고보드 포스트 조회 실패: $e');
      return [];
    }
  }

  /// 광고보드 포스트 수령
  /// 
  /// [postId]: 광고보드 포스트 ID
  /// 
  /// Returns: 성공 여부
  Future<bool> collectAdBoardPost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('로그인이 필요합니다');

      final postRef = _firestore.collection('ad_board_posts').doc(postId);
      final userPostRef = _firestore
          .collection('post_collections')
          .doc(user.uid)
          .collection('received')
          .doc(postId);

      // 트랜잭션으로 수량 차감 + 중복 방지
      await _firestore.runTransaction((tx) async {
        final postSnap = await tx.get(postRef);
        if (!postSnap.exists) {
          throw Exception('해당 광고가 존재하지 않습니다');
        }

        final data = postSnap.data() as Map<String, dynamic>;
        final remaining = data['remainingQuantity'] ?? 0;
        final isActive = data['isActive'] ?? false;

        if (!isActive || remaining <= 0) {
          throw Exception('이미 마감된 광고입니다');
        }

        // 중복 수령 방지
        final userPostSnap = await tx.get(userPostRef);
        if (userPostSnap.exists) {
          throw Exception('이미 수령한 광고입니다');
        }

        // 남은 수량 감소
        tx.update(postRef, {
          'remainingQuantity': remaining - 1,
        });

        // 미확인 포스트로 이동
        tx.set(userPostRef, {
          'postId': postId,
          'collectedAt': FieldValue.serverTimestamp(),
          'status': 'UNCONFIRMED',
          'type': 'AD_BOARD',
          'confirmed': false,
        });
      });

      return true;
    } catch (e) {
      debugPrint('광고보드 포스트 수령 실패: $e');
      rethrow;
    }
  }

  /// 사용자가 이미 수령했는지 확인
  Future<bool> _hasCollected(String userId, String postId) async {
    try {
      final doc = await _firestore
          .collection('post_collections')
          .doc(userId)
          .collection('received')
          .doc(postId)
          .get();
      
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// 수령 가능한 광고보드 포스트 개수 조회
  Future<int> getReceivableCount({
    required String countryCode,
    String? regionCode,
  }) async {
    final posts = await fetchAdBoardPosts(
      countryCode: countryCode,
      regionCode: regionCode,
    );
    return posts.length;
  }

  /// 광고보드 포스트 개수 스트림 (실시간 업데이트)
  Stream<int> getReceivableCountStream({
    required String countryCode,
    String? regionCode,
  }) {
    try {
      final user = _auth.currentUser;
      if (user == null) return Stream.value(0);

      // 기본 쿼리: 활성화 + 수량 있음 + 국가 일치
      Query query = _firestore
          .collection('ad_board_posts')
          .where('isActive', isEqualTo: true)
          .where('remainingQuantity', isGreaterThan: 0)
          .where('countryCodes', arrayContains: countryCode)
          .where('expiresAt', isGreaterThan: Timestamp.now());

      return query.snapshots().asyncMap((snapshot) async {
        int count = 0;
        
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          // 지역 코드 필터링 (선택적)
          if (regionCode != null && regionCode.isNotEmpty) {
            final regionCodes = List<String>.from(data['regionCodes'] ?? []);
            if (regionCodes.isNotEmpty && !regionCodes.contains(regionCode)) {
              continue;
            }
          }
          
          // 이미 수령했는지 확인
          final alreadyCollected = await _hasCollected(user.uid, doc.id);
          if (!alreadyCollected) {
            count++;
          }
        }
        
        return count;
      });
    } catch (e) {
      debugPrint('광고보드 포스트 개수 스트림 실패: $e');
      return Stream.value(0);
    }
  }
}

