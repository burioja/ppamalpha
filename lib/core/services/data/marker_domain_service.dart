import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../../models/marker/marker_model.dart';
import '../../models/post/post_model.dart';
import '../../models/user/user_model.dart';
import '../../../utils/tile_utils.dart';
import '../../constants/app_constants.dart';

/// 마커 도메인 서비스
/// 
/// **책임**: 순수 도메인 로직 (거리 계산, 권한 체크, 유효성 검증)
/// **원칙**: Firebase는 최소한만, Repository로 이관 권장
class MarkerDomainService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 사용자 타입에 따른 마커 표시 거리 계산
  static int getMarkerDisplayRadius(UserType userType, bool isSuperPost) {
    if (isSuperPost) {
      return AppConsts.superPostRadius5km;  // 슈퍼포스트는 항상 5km
    }
    
    switch (userType) {
      case UserType.normal:
        return AppConsts.normalUserRadius1km;  // 일반사용자 1km
      case UserType.superSite:
        return AppConsts.superSiteUserRadius3km;  // 수퍼사이트 3km
    }
  }

  /// 사용자 타입에 따른 2단계 영역 거리 계산 (30일 방문 경로)
  static int getSecondLevelRadius(UserType userType) {
    switch (userType) {
      case UserType.normal:
        return AppConsts.normalUserRadius2km;  // 일반사용자 1km
      case UserType.superSite:
        return AppConsts.superSiteUserRadius2km;  // 수퍼사이트 3km
    }
  }

  /// 마커 배포 가능 여부 확인 (1단계 영역에서만 가능)
  static bool canDeployMarker(UserType userType, LatLng userLocation, LatLng deployLocation) {
    final radius = getMarkerDisplayRadius(userType, false);  // 일반 포스트 기준
    final distance = calculateDistance(userLocation, deployLocation);
    return distance <= radius;
  }

  /// 마커 수집 가능 여부 확인 (현위치 200m 이내)
  static bool canCollectMarker(LatLng userLocation, LatLng markerLocation) {
    final distance = calculateDistance(userLocation, markerLocation);
    return distance <= AppConsts.markerCollectRadius;
  }

  /// 두 좌표 간의 거리 계산 (미터 단위)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }

  /// 🚀 포스트 템플릿에서 마커 배포 (트랜잭션 처리 강화)
  static Future<String> deployPostAsMarker({
    required String postId,
    required LatLng deployLocation,
    required int quantity,
    int? customRadius, // 커스텀 반경 (지정하지 않으면 템플릿 기본값 사용)
    DateTime? customExpiresAt, // 커스텀 만료일 (지정하지 않으면 템플릿 기본값 사용)
    String? s2_10,
    String? s2_12,
    int? fogLevel,
  }) async {
    String? markerId;

    try {
      print('🚀 포스트 템플릿에서 마커 배포 시작: postId=$postId, location=${deployLocation.latitude},${deployLocation.longitude}');

      // 먼저 포스트 정보를 가져와서 포인트 차감 계산
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('포스트 템플릿을 찾을 수 없습니다: $postId');
      }

      final post = PostModel.fromFirestore(postDoc);
      final totalCost = (post.reward ?? 0) * quantity; // 총 차감할 포인트 = 보상 × 수량

      print('💰 포스트 배포 비용 계산: 보상=${post.reward ?? 0}, 수량=$quantity, 총비용=$totalCost');

      // 포인트 차감 비활성화 (수집 시에만 차감)
      print('📝 배포는 무료입니다. 포인트 차감은 수집 시에만 이루어집니다.');

      // 🔍 포스트 배포자의 인증 상태를 마커에 전달
      final isVerified = post.isVerified;
      print('✅ 배포자 인증 상태: $isVerified (postId: ${post.postId})');
      print('✅ 쿠폰 여부: ${post.isCoupon}');
      print('✅ 생성자 ID: ${post.creatorId}');

      // 트랜잭션으로 마커 생성과 포스트 상태 변경을 원자적으로 처리
      await _firestore.runTransaction((transaction) async {
        // 1. 포스트 템플릿 정보는 이미 위에서 가져왔으므로 바로 사용

        // 2. 배포 설정 (템플릿 기본값 + 커스텀 값)
        final deployRadius = customRadius ?? post.defaultRadius;
        final deployExpiresAt = customExpiresAt ?? post.defaultExpiresAt;

        // 3. 타일 ID 계산
        final tileId = TileUtils.getKm1TileId(deployLocation.latitude, deployLocation.longitude);

        // 4. 마커 데이터 생성
        // ✅ 해결책 5: 클라이언트에서 즉시 필드 설정 (서버 타임스탬프 지연 방지)
        final now = DateTime.now().toUtc();
        final markerData = <String, dynamic>{
          'postId': postId,
          'title': post.title,
          'location': GeoPoint(deployLocation.latitude, deployLocation.longitude),
          'totalQuantity': quantity,
          'remainingQuantity': quantity,
          'collectedQuantity': 0,
          'collectionRate': 0.0,
          'creatorId': post.creatorId,
          'createdAt': Timestamp.fromDate(now),  // ✅ 클라이언트 타임스탬프 (즉시 쿼리 가능)
          'createdAtServer': FieldValue.serverTimestamp(),  // 서버 타임스탬프 (보조용)
          'expiresAt': Timestamp.fromDate(deployExpiresAt),
          'isActive': true,
          'collectedBy': [],
          'tileId': tileId,  // ✅ 클라이언트에서 계산 (즉시 쿼리 가능)
          'quantity': quantity, // 호환성 유지
        };

        // reward 및 파생 필드 추가
        final r = post.reward;
        if (r != null) {
          markerData['reward'] = r;
          final isSuperMarker = r >= AppConsts.superRewardThreshold;
          markerData['isSuperMarker'] = isSuperMarker;
        }

        // S2 타일 ID 추가
        if (s2_10 != null) markerData['s2_10'] = s2_10;
        if (s2_12 != null) markerData['s2_12'] = s2_12;
        if (fogLevel != null) markerData['fogLevel'] = fogLevel;

        // 배포자 인증 상태 저장 (서버사이드 필터링용)
        markerData['isVerified'] = isVerified;
        print('🔍 [MARKER_DEPLOY] isVerified 저장: $isVerified');
        
        // 쿠폰 여부 저장 (서버사이드 필터링용)
        markerData['isCoupon'] = post.isCoupon;
        print('🔍 [MARKER_DEPLOY] isCoupon 저장: ${post.isCoupon}');
        
        print('🔍 [MARKER_DEPLOY] creatorId 저장: ${post.creatorId}');

        // 5. 마커 생성 (트랜잭션 내에서)
        final markerRef = _firestore.collection('markers').doc();
        markerId = markerRef.id;
        transaction.set(markerRef, markerData);

        // 6. 포스트 상태를 DEPLOYED로 변경 및 통계 업데이트 (트랜잭션 내에서)
        transaction.update(postDoc.reference, {
          'status': PostStatus.DEPLOYED.value,
          'updatedAt': FieldValue.serverTimestamp(),
          'totalDeployments': FieldValue.increment(1),
          'totalDeployed': FieldValue.increment(quantity),
          'lastDeployedAt': FieldValue.serverTimestamp(),
        });

        print('✅ 트랜잭션 내에서 마커 생성 및 포스트 상태 변경 완료: markerId=$markerId');
      });

      print('✅ 포스트 템플릿 배포 완료: postId=$postId, markerId=$markerId');
      return markerId!;
    } catch (e) {
      print('❌ 포스트 템플릿 배포 실패: $e');
      // 마커가 생성되었지만 트랜잭션이 실패한 경우를 대비한 정리 로직
      if (markerId != null) {
        try {
          await _firestore.collection('markers').doc(markerId!).delete();
          print('🧹 실패한 마커 정리 완료: $markerId');
        } catch (cleanupError) {
          print('⚠️ 마커 정리 실패: $cleanupError');
        }
      }
      rethrow;
    }
  }

  /// 마커 생성 (포스트 ID와 연결) - 통계 집계 포함
  static Future<String> createMarker({
    required String postId,
    required String title,
    required LatLng position,
    required int quantity,
    required String creatorId,
    required DateTime expiresAt,
    int? reward, // ✅ 추가 (옵셔널로 두면 기존 호출부도 안전)
    String? s2_10, // S2 level 10 추가
    String? s2_12, // S2 level 12 추가
    int? fogLevel, // 포그 레벨 추가
  }) async {
    try {
      print('🚀 마커 생성 시작:');
      print('📋 Post ID: $postId');
      print('📝 제목: $title');
      print('📍 위치: ${position.latitude}, ${position.longitude}');
      print('📦 수량: $quantity');
      print('👤 생성자: $creatorId');
      print('⏰ 만료일: $expiresAt');
      print('💰 보상: ${reward ?? 0}');

      // 포인트 차감 로직 비활성화 (수집 시에만 차감하도록 변경)
      final totalCost = (reward ?? 0) * quantity; // 총 배포 비용 계산 (참고용)
      print('💰 마커 생성 비용 정보: 보상=${reward ?? 0}, 수량=$quantity, 총예상비용=$totalCost');
      print('📝 포인트 차감은 수집 시에만 이루어집니다 (배포는 무료)');

      // 🔍 Post 정보 조회하여 isVerified, isCoupon 가져오기
      bool isVerified = false;
      bool isCoupon = false;
      try {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          final postData = postDoc.data();
          isVerified = postData?['isVerified'] as bool? ?? false;
          isCoupon = postData?['isCoupon'] as bool? ?? false;
          print('✅ Post 정보 조회: isVerified=$isVerified, isCoupon=$isCoupon');
        }
      } catch (e) {
        print('⚠️ Post 정보 조회 실패: $e (기본값 사용)');
      }

      // 타일 ID 계산
      final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);

      final markerData = <String, dynamic>{
        'postId': postId,
        'title': title,
        'location': GeoPoint(position.latitude, position.longitude),
        'totalQuantity': quantity, // 총 배포 수량
        'remainingQuantity': quantity, // 남은 수량
        'collectedQuantity': 0, // 수집된 수량
        'collectionRate': 0.0, // 수집률
        'creatorId': creatorId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'createdAtServer': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isActive': true,
        'collectedBy': [], // 수령한 사용자 목록 초기화
        'tileId': tileId, // 타일 ID 저장
        // 호환성을 위해 기존 quantity 필드도 유지
        'quantity': quantity,
      };

      // ✅ reward를 markerData에 안전하게 포함 (nullable non-promotion 회피)
      final r = reward;
      if (r != null) {
        markerData['reward'] = r;
      }

      // ✅ 파생 필드 저장 (쿼리 최적화용)
      final isSuperMarker = (r ?? 0) >= AppConsts.superRewardThreshold;
      markerData['isSuperMarker'] = isSuperMarker;

      // 🚀 S2 타일 ID 추가
      if (s2_10 != null) {
        markerData['s2_10'] = s2_10;
      }
      if (s2_12 != null) {
        markerData['s2_12'] = s2_12;
      }
      if (fogLevel != null) {
        markerData['fogLevel'] = fogLevel;
      }

      // 배포자 인증 상태 및 쿠폰 여부 저장 (서버사이드 필터링용)
      markerData['isVerified'] = isVerified;
      markerData['isCoupon'] = isCoupon;

      // ✅ 즉시 쿼리 통과/표시를 위한 기본값 보정 (필요 시 이미 있으면 유지)
      markerData.putIfAbsent('createdAt', () => Timestamp.fromDate(DateTime.now()));
      markerData.putIfAbsent('expiresAt', () => Timestamp.fromDate(DateTime.now().add(const Duration(hours: 24))));
      markerData.putIfAbsent('isActive', () => true);

      final batch = _firestore.batch();

      // ✅ 마커 생성 (수동 doc id 생성 → set)
      final markerRef = _firestore.collection('markers').doc();
      batch.set(markerRef, markerData);
      print('📌 마커 문서 ID: ${markerRef.id}');

      // ✅ 포스트 통계 및 상태 업데이트
      final postRef = _firestore.collection('posts').doc(postId);
      // 주의: posts 문서가 없을 수 있으면 update 대신 merge set 권장
      batch.set(postRef, {
        'totalDeployments': FieldValue.increment(1),
        'totalDeployed': FieldValue.increment(quantity),
        'lastDeployedAt': FieldValue.serverTimestamp(),
        'status': 'deployed', // 포스트 상태를 DEPLOYED로 변경 (소문자로 통일)
        'deployedAt': FieldValue.serverTimestamp(), // 배포 시간 기록
      }, SetOptions(merge: true));

      await batch.commit();

      print('✅ 마커 생성 및 통계 업데이트 완료 | markerId=${markerRef.id} | postId=$postId | title=$title | reward=${r ?? 0}원');
      print('📊 포스트 상태 DEPLOYED로 변경됨 | postId=$postId');
      return markerRef.id;
    } catch (e) {
      print('❌ 마커 생성 실패: $e');
      rethrow;
    }
  }

  /// 반경 내 마커 조회
  static Stream<List<MarkerModel>> getMarkersInRadius({
    required LatLng center,
    required double radiusKm,
  }) {
    return _firestore
        .collection('markers')
        .where('isActive', isEqualTo: true)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) {
      final markers = <MarkerModel>[];
      
      for (final doc in snapshot.docs) {
        try {
          final marker = MarkerModel.fromFirestore(doc);
          
          // 거리 계산
          final distance = calculateDistance(
            LatLng(center.latitude, center.longitude),
            LatLng(marker.position.latitude, marker.position.longitude),
          );
          
          // 반경 내에 있고 수량이 0보다 큰 마커만 포함 (remainingQuantity 기준)
          if (distance <= radiusKm && marker.remainingQuantity > 0) {
            markers.add(marker);
          }
        } catch (e) {
          print('❌ 마커 파싱 실패: $e');
        }
      }
      
      // 거리순으로 정렬
      markers.sort((a, b) {
        final distanceA = calculateDistance(
          LatLng(center.latitude, center.longitude),
          LatLng(a.position.latitude, a.position.longitude),
        );
        final distanceB = calculateDistance(
          LatLng(center.latitude, center.longitude),
          LatLng(b.position.latitude, b.position.longitude),
        );
        return distanceA.compareTo(distanceB);
      });
      
      print('📍 반경 ${radiusKm}km 내 마커 ${markers.length}개 발견');
      return markers;
    });
  }

  /// 마커에서 포스트 수령 - 통계 집계 포함
  static Future<bool> collectPostFromMarker({
    required String markerId,
    required String userId,
  }) async {
    try {
      final docRef = _firestore.collection('markers').doc(markerId);

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }

        final data = doc.data()!;
        final remainingQuantity = data['remainingQuantity'] ?? data['quantity'] ?? 0;
        final collectedQuantity = data['collectedQuantity'] ?? 0;
        final totalQuantity = data['totalQuantity'] ?? data['quantity'] ?? 0;
        final collectedBy = List<String>.from(data['collectedBy'] ?? []);
        final postId = data['postId'];

        if (collectedBy.contains(userId)) {
          throw Exception('이미 수령한 포스트입니다');
        }

        if (remainingQuantity <= 0) {
          throw Exception('수량이 부족합니다');
        }

        final newRemainingQuantity = remainingQuantity - 1;
        final newCollectedQuantity = collectedQuantity + 1;
        final newCollectionRate = totalQuantity > 0 ? newCollectedQuantity / totalQuantity : 0.0;
        collectedBy.add(userId);

        // 마커 수량 업데이트
        final markerUpdate = {
          'remainingQuantity': newRemainingQuantity,
          'collectedQuantity': newCollectedQuantity,
          'collectionRate': newCollectionRate,
          'collectedBy': collectedBy,
          'quantity': newRemainingQuantity, // 호환성 유지
        };

        if (newRemainingQuantity <= 0) {
          markerUpdate['isActive'] = false;
        }

        transaction.update(docRef, markerUpdate);

        // 포스트 통계 업데이트 (이미 PostInstanceService에서 처리하지만 직접 수령 시에도 업데이트)
        if (postId != null) {
          final postRef = _firestore.collection('posts').doc(postId);
          transaction.update(postRef, {
            'totalCollected': FieldValue.increment(1),
            'lastCollectedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      print('✅ 마커에서 포스트 수령 완료: $markerId, 사용자: $userId');
      return true;
    } catch (e) {
      print('❌ 마커에서 포스트 수령 실패: $e');
      return false;
    }
  }

  /// 마커 수량 감소 (수령 시)
  static Future<bool> decreaseMarkerQuantity(String markerId) async {
    try {
      final docRef = _firestore.collection('markers').doc(markerId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) {
          throw Exception('마커를 찾을 수 없습니다');
        }
        
        final currentQuantity = doc.data()?['quantity'] ?? 0;
        
        if (currentQuantity <= 0) {
          throw Exception('수량이 부족합니다');
        }
        
        final newQuantity = currentQuantity - 1;
        
        if (newQuantity <= 0) {
          // 수량이 0이 되면 마커 비활성화
          transaction.update(docRef, {
            'quantity': 0,
            'isActive': false,
          });
        } else {
          // 수량만 감소
          transaction.update(docRef, {
            'quantity': newQuantity,
          });
        }
      });
      
      print('✅ 마커 수량 감소 완료: $markerId');
      return true;
    } catch (e) {
      print('❌ 마커 수량 감소 실패: $e');
      return false;
    }
  }

  /// 마커 삭제
  static Future<void> deleteMarker(String markerId) async {
    try {
      await _firestore.collection('markers').doc(markerId).delete();
      print('✅ 마커 삭제 완료: $markerId');
    } catch (e) {
      print('❌ 마커 삭제 실패: $e');
      rethrow;
    }
  }

  /// 🚀 위치 기반 마커 조회 (포그 레벨 고려)
  static Future<List<MarkerModel>> getMarkersInArea({
    required LatLng center,
    required double radiusKm,
    int? fogLevel,
    bool? superOnly,
    String? currentUserId, // 현재 사용자 ID 추가
  }) async {
    try {
      Query query = _firestore
          .collection('markers')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.now());

      // 포그 레벨 필터링
      if (fogLevel != null) {
        query = query.where('fogLevel', isEqualTo: fogLevel);
      }

      // 슈퍼마커만 조회
      if (superOnly == true) {
        query = query.where('isSuperMarker', isEqualTo: true);
      }

      final querySnapshot = await query.get();
      final markers = <MarkerModel>[];

      for (final doc in querySnapshot.docs) {
        try {
          final marker = MarkerModel.fromFirestore(doc);

          // 거리 계산
          final distance = calculateDistance(
            LatLng(center.latitude, center.longitude),
            LatLng(marker.position.latitude, marker.position.longitude),
          );

          // 반경 내에 있고 수량이 0보다 큰 마커만 포함
          if (distance <= radiusKm && marker.remainingQuantity > 0) {
            // 현재 사용자가 이미 수령한 마커는 제외 (단, 내가 배포한 마커는 예외)
            if (currentUserId != null) {
              final data = doc.data() as Map<String, dynamic>?;
              final creatorId = data?['creatorId'] as String?;
              if (creatorId != currentUserId) {
                final collectedBy = List<String>.from(data?['collectedBy'] ?? []);
                if (collectedBy.contains(currentUserId)) {
                  print('🚫 이미 수령한 마커 제외: ${marker.markerId}');
                  continue;
                }
              }
            }
            
            markers.add(marker);
          }
        } catch (e) {
          print('❌ 마커 파싱 실패: $e');
        }
      }

      // 거리순으로 정렬
      markers.sort((a, b) {
        final distanceA = calculateDistance(
          LatLng(center.latitude, center.longitude),
          LatLng(a.position.latitude, a.position.longitude),
        );
        final distanceB = calculateDistance(
          LatLng(center.latitude, center.longitude),
          LatLng(b.position.latitude, b.position.longitude),
        );
        return distanceA.compareTo(distanceB);
      });

      print('📍 반경 ${radiusKm}km 내 마커 ${markers.length}개 발견 (fogLevel: $fogLevel)');
      return markers;
    } catch (e) {
      print('❌ 위치 기반 마커 조회 실패: $e');
      return [];
    }
  }

  /// 🚀 실시간 마커 스트림 (포그 레벨 고려)
  static Stream<List<MarkerModel>> getMarkersInAreaStream({
    required LatLng center,
    required double radiusKm,
    int? fogLevel,
    bool? superOnly,
    String? currentUserId, // 현재 사용자 ID 추가
  }) {
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      return await getMarkersInArea(
        center: center,
        radiusKm: radiusKm,
        fogLevel: fogLevel,
        superOnly: superOnly,
        currentUserId: currentUserId,
      );
    });
  }
}
