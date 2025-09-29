import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/user_points_model.dart';

class PointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 사용자 포인트 정보 가져오기
  Future<UserPointsModel?> getUserPoints(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_points')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserPointsModel.fromFirestore(doc);
      }

      // 포인트 정보가 없으면 기본값으로 생성 (신규 사용자 10만 포인트 지급)
      final newUserPoints = UserPointsModel(
        userId: userId,
        totalPoints: 100000, // 신규 사용자 10만 포인트 지급
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
      );

      await _createUserPoints(newUserPoints);

      // 포인트 지급 히스토리 기록
      await _addPointsHistory(
        userId: userId,
        amount: 100000,
        type: 'system_grant',
        reason: '가입 축하 포인트 (10만 포인트)',
        relatedId: null,
      );

      return newUserPoints;
    } catch (e) {
      print('사용자 포인트 가져오기 실패: $e');
      return null;
    }
  }

  /// 사용자 포인트 정보 생성
  Future<void> _createUserPoints(UserPointsModel userPoints) async {
    try {
      await _firestore
          .collection('user_points')
          .doc(userPoints.userId)
          .set(userPoints.toFirestore());
    } catch (e) {
      print('사용자 포인트 생성 실패: $e');
    }
  }

  /// 포인트 히스토리 기록 (내부 메서드)
  Future<void> _addPointsHistory({
    required String userId,
    required int amount,
    required String type,
    required String reason,
    String? relatedId,
  }) async {
    try {
      await _firestore
          .collection('user_points')
          .doc(userId)
          .collection('history')
          .add({
        'points': amount,
        'type': type,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'relatedId': relatedId,
      });
    } catch (e) {
      print('포인트 히스토리 기록 실패: $e');
    }
  }

  /// 포인트 추가
  Future<UserPointsModel?> addPoints(String userId, int points, String reason) async {
    try {
      print('💰 addPoints 호출:');
      print('  - 사용자 ID: $userId');
      print('  - 추가할 포인트: $points');
      print('  - 사유: $reason');

      final batch = _firestore.batch();

      // 1. 포인트 정보 업데이트
      final userPointsRef = _firestore
          .collection('user_points')
          .doc(userId);

      print('📝 user_points 문서 업데이트 중...');
      batch.update(userPointsRef, {
        'totalPoints': FieldValue.increment(points),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      // 2. 포인트 히스토리 기록
      final historyRef = _firestore
          .collection('user_points')
          .doc(userId)
          .collection('history')
          .doc();

      print('📝 포인트 히스토리 기록 중...');
      batch.set(historyRef, {
        'points': points,
        'type': 'earned',
        'reason': reason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      // 배치 실행
      print('🚀 Firestore 배치 커밋 중...');
      await batch.commit();
      print('✅ Firestore 배치 커밋 완료');

      // 업데이트된 포인트 정보 반환
      print('🔄 업데이트된 포인트 정보 조회 중...');
      final result = await getUserPoints(userId);
      if (result != null) {
        print('✅ addPoints 성공 - 현재 총 포인트: ${result.totalPoints}');
      } else {
        print('⚠️ getUserPoints 결과가 null');
      }
      return result;
    } catch (e) {
      print('❌ 포인트 추가 실패: $e');
      print('스택 트레이스: $e');
      return null;
    }
  }

  /// 포인트 차감
  Future<UserPointsModel?> deductPoints(String userId, int points, String reason) async {
    try {
      final userPoints = await getUserPoints(userId);
      if (userPoints == null || userPoints.totalPoints < points) {
        throw Exception('포인트가 부족합니다');
      }

      final batch = _firestore.batch();

      // 1. 포인트 정보 업데이트
      final userPointsRef = _firestore
          .collection('user_points')
          .doc(userId);

      batch.update(userPointsRef, {
        'totalPoints': FieldValue.increment(-points),
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      });

      // 2. 포인트 히스토리 기록
      final historyRef = _firestore
          .collection('user_points')
          .doc(userId)
          .collection('history')
          .doc();

      batch.set(historyRef, {
        'points': points,
        'type': 'spent',
        'reason': reason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      // 배치 실행
      await batch.commit();

      // 업데이트된 포인트 정보 반환
      return await getUserPoints(userId);
    } catch (e) {
      print('포인트 차감 실패: $e');
      return null;
    }
  }

  /// 포인트 히스토리 가져오기
  Future<List<Map<String, dynamic>>> getPointsHistory(String userId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('user_points')
          .doc(userId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'points': data['points'] ?? 0,
          'type': data['type'] ?? 'unknown',
          'reason': data['reason'] ?? '알 수 없음',
          'timestamp': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('포인트 히스토리 가져오기 실패: $e');
      return [];
    }
  }

  /// 실시간 포인트 정보 스트림
  Stream<UserPointsModel?> getUserPointsStream(String userId) {
    return _firestore
        .collection('user_points')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserPointsModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// 포인트 랭킹 가져오기
  Future<List<UserPointsModel>> getPointsRanking({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('user_points')
          .orderBy('totalPoints', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserPointsModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('포인트 랭킹 가져오기 실패: $e');
      return [];
    }
  }

  /// 쿠폰 사용 포인트 적립
  Future<UserPointsModel?> addCouponPoints(String userId, int points, String postTitle, String placeId) async {
    return await addPoints(
      userId,
      points,
      '쿠폰 사용 적립 - $postTitle'
    );
  }

  /// 모든 기존 사용자에게 100만 포인트 지급 (관리자용)
  Future<void> grantMillionPointsToAllUsers() async {
    try {
      print('🎯 모든 사용자에게 100만 포인트 지급 시작');

      // 모든 사용자 포인트 문서 조회
      final querySnapshot = await _firestore
          .collection('user_points')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('📝 기존 사용자가 없습니다.');
        return;
      }

      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final currentPoints = data['totalPoints'] ?? 0;

        // 100만 포인트보다 적은 사용자에게만 지급
        if (currentPoints < 1000000) {
          final pointsToAdd = 1000000 - currentPoints;

          // 사용자 포인트 업데이트
          batch.update(doc.reference, {
            'totalPoints': 1000000,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // 히스토리 추가
          final historyRef = doc.reference.collection('history').doc();
          batch.set(historyRef, {
            'points': pointsToAdd,
            'type': 'system_grant',
            'reason': '임시 지급 포인트 (100만 포인트 보장)',
            'timestamp': FieldValue.serverTimestamp(),
            'relatedId': null,
          });

          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('✅ $updateCount명의 사용자에게 포인트 지급 완료');
      } else {
        print('📝 모든 사용자가 이미 100만 포인트 이상 보유하고 있습니다.');
      }

    } catch (e) {
      print('❌ 전체 포인트 지급 실패: $e');
      rethrow;
    }
  }

  /// 포스트 생성 시 포인트 차감 (포스트 생성자)
  Future<bool> deductPostCreationPoints(String creatorId, int totalReward, String postId) async {
    try {
      print('💰 포스트 생성 비용 차감: 생성자=$creatorId, 총비용=$totalReward');

      final userPoints = await getUserPoints(creatorId);
      if (userPoints == null || userPoints.totalPoints < totalReward) {
        print('❌ 포인트 부족: 현재=${userPoints?.totalPoints ?? 0}, 필요=$totalReward');
        return false;
      }

      await deductPoints(
        creatorId,
        totalReward,
        '포스트 생성 비용 차감 (PostID: $postId)',
      );

      print('✅ 포스트 생성 비용 차감 완료');
      return true;

    } catch (e) {
      print('❌ 포스트 생성 비용 차감 실패: $e');
      return false;
    }
  }

  /// 포스트 수집 시 포인트 지급 (수집자에게)
  Future<bool> rewardPostCollection(String collectorId, int reward, String postId, String creatorId) async {
    try {
      print('🎁 포스트 수집 보상 지급 시작:');
      print('  - 수집자 ID: $collectorId');
      print('  - 보상 포인트: $reward');
      print('  - 포스트 ID: $postId');
      print('  - 생성자 ID: $creatorId');

      final result = await addPoints(
        collectorId,
        reward,
        '포스트 수집 보상 (PostID: $postId, 생성자: $creatorId)',
      );

      if (result != null) {
        print('✅ 포스트 수집 보상 지급 완료');
        print('  - 업데이트된 총 포인트: ${result.totalPoints}');
        return true;
      } else {
        print('❌ addPoints 결과가 null');
        return false;
      }

    } catch (e) {
      print('❌ 포스트 수집 보상 지급 실패: $e');
      print('스택 트레이스: $e');
      return false;
    }
  }

  /// 포스트 사용 시 포인트 지급 (주자에게, 옵션)
  Future<bool> rewardPostUsage(String userId, int reward, String postId, {String? placeId}) async {
    try {
      print('🏪 포스트 사용 보상 지급: 사용자=$userId, 보상=$reward');

      String reason = '포스트 사용 보상 (PostID: $postId)';
      if (placeId != null) {
        reason += ' at Place: $placeId';
      }

      await addPoints(userId, reward, reason);

      print('✅ 포스트 사용 보상 지급 완료');
      return true;

    } catch (e) {
      print('❌ 포스트 사용 보상 지급 실패: $e');
      return false;
    }
  }

  /// 사용자의 포인트가 10만 이상인지 확인하고, 부족하면 보충
  Future<void> ensureMinimumPoints(String userId) async {
    try {
      final userPoints = await getUserPoints(userId);
      if (userPoints != null && userPoints.totalPoints < 100000) {
        final pointsToAdd = 100000 - userPoints.totalPoints;
        await addPoints(
          userId,
          pointsToAdd,
          '최소 포인트 보장 (10만 포인트)',
        );
        print('✅ 사용자 $userId에게 $pointsToAdd 포인트 보충 완료');
      }
    } catch (e) {
      print('❌ 최소 포인트 보장 실패: $e');
    }
  }

  /// 특정 사용자에게 포인트 지급 (관리자용)
  Future<void> grantPointsToUser(String userEmail, int points) async {
    try {
      print('🎯 특정 사용자에게 포인트 지급: $userEmail -> $points 포인트');

      // 이메일로 사용자 찾기 (Firebase Auth에서)
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('❌ 사용자를 찾을 수 없습니다: $userEmail');
        return;
      }

      final userDoc = userQuery.docs.first;
      final userId = userDoc.id;

      // 사용자 포인트 정보 확인
      final userPoints = await getUserPoints(userId);
      if (userPoints == null) {
        print('📝 사용자 포인트 정보가 없어 새로 생성합니다: $userEmail');
        // 새로운 포인트 정보 생성
        final newUserPoints = UserPointsModel(
          userId: userId,
          totalPoints: points,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );
        await _createUserPoints(newUserPoints);

        // 포인트 지급 히스토리 기록
        await _addPointsHistory(
          userId: userId,
          amount: points,
          type: 'system_grant',
          reason: '관리자 포인트 지급 ($userEmail)',
          relatedId: null,
        );
      } else {
        print('📝 기존 포인트: ${userPoints.totalPoints}, 추가 지급: $points');
        await addPoints(userId, points, '관리자 포인트 지급 ($userEmail)');
      }

      print('✅ $userEmail에게 $points 포인트 지급 완료');

    } catch (e) {
      print('❌ 포인트 지급 실패: $e');
      rethrow;
    }
  }

  /// 모든 기존 사용자에게 10만 포인트로 조정 (관리자용)
  Future<void> adjustToHundredThousandPoints() async {
    try {
      print('🎯 모든 사용자 포인트를 10만으로 조정 시작');

      // 모든 사용자 포인트 문서 조회
      final querySnapshot = await _firestore
          .collection('user_points')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('📝 사용자가 없습니다.');
        return;
      }

      final batch = _firestore.batch();
      int updateCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final currentPoints = data['totalPoints'] ?? 0;

        // 100만 포인트 이상 보유자를 10만 포인트로 조정
        if (currentPoints >= 1000000) {
          // 사용자 포인트 업데이트
          batch.update(doc.reference, {
            'totalPoints': 100000,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // 히스토리 추가
          final historyRef = doc.reference.collection('history').doc();
          batch.set(historyRef, {
            'points': 100000 - currentPoints, // 음수값
            'type': 'system_adjustment',
            'reason': '포인트 정책 변경 (10만 포인트 조정)',
            'timestamp': FieldValue.serverTimestamp(),
            'relatedId': null,
          });

          updateCount++;
        }
      }

      if (updateCount > 0) {
        await batch.commit();
        print('✅ $updateCount명의 사용자 포인트를 10만으로 조정 완료');
      } else {
        print('📝 조정할 사용자가 없습니다 (모든 사용자가 이미 100만 포인트 미만)');
      }

    } catch (e) {
      print('❌ 포인트 조정 실패: $e');
      rethrow;
    }
  }
}