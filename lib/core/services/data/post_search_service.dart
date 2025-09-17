import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post/post_model.dart';
import '../../../utils/s2_tile_utils.dart';

/// 서버 사이드 포스트 검색 서비스
/// S2 타일 기반 필터링으로 성능 최적화
class PostSearchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 포스트 검색 (서버 사이드 필터링)
  /// 
  /// [centerLat] - 중심 위도
  /// [centerLng] - 중심 경도
  /// [radiusKm] - 검색 반경 (km)
  /// [fogLevel] - 포그레벨 (1: Clear, 2: Partial, 3: Dark)
  /// [rewardType] - 리워드 타입 ('normal', 'super', 'all')
  /// [limit] - 최대 결과 수
  /// [after] - 페이지네이션 커서
  /// 
  /// Returns: 검색 결과와 다음 커서
  static Future<PostSearchResult> searchPosts({
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    int? fogLevel,
    String rewardType = 'all',
    int limit = 100,
    String? after,
  }) async {
    try {
      print('🔍 포스트 검색 시작:');
      print('  - 중심: ($centerLat, $centerLng)');
      print('  - 반경: ${radiusKm}km');
      print('  - 포그레벨: $fogLevel');
      print('  - 리워드 타입: $rewardType');
      
      // 1. S2 타일 커버링 계산
      final s2Cells = S2TileUtils.getS2CellsInRadius(
        centerLat, centerLng, radiusKm, 12
      );
      
      print('  - S2 타일 개수: ${s2Cells.length}개');
      
      if (s2Cells.isEmpty) {
        return PostSearchResult(
          posts: [],
          nextCursor: null,
          totalCount: 0,
        );
      }
      
      // 2. 먼저 포스트 존재 여부 확인
      print('  - 포스트 존재 여부 확인 중...');
      final allPostsSnapshot = await _firestore.collection('posts').limit(5).get();
      print('  - 전체 포스트 개수: ${allPostsSnapshot.docs.length}개');
      
      if (allPostsSnapshot.docs.isNotEmpty) {
        final sampleDoc = allPostsSnapshot.docs.first;
        print('  - 샘플 포스트 데이터: ${sampleDoc.data()}');
      }
      
      if (allPostsSnapshot.docs.isEmpty) {
        print('  - 포스트가 없습니다. 포스트를 먼저 생성해야 합니다.');
        return PostSearchResult(
          posts: [],
          nextCursor: null,
          totalCount: 0,
        );
      }
      
      // 3. 간단한 쿼리로 포스트 조회
      final allPosts = <PostModel>[];
      
      try {
        print('  - 간단한 쿼리로 포스트 조회 중...');
        
        // 가장 간단한 쿼리부터 시도
        Query simpleQuery = _firestore
            .collection('posts')
            .where('isActive', isEqualTo: true);
        
        final simpleSnapshot = await simpleQuery.limit(limit).get();
        print('  - 간단한 쿼리 결과: ${simpleSnapshot.docs.length}개');
        
        if (simpleSnapshot.docs.isNotEmpty) {
          final sampleDoc = simpleSnapshot.docs.first;
          print('  - 샘플 포스트: ${sampleDoc.data()}');
        }
        
        // 포스트 변환
        for (final doc in simpleSnapshot.docs) {
          try {
            final post = PostModel.fromFirestore(doc);
            allPosts.add(post);
            print('  - 포스트 추가: ${post.title} at (${post.location.latitude}, ${post.location.longitude})');
          } catch (e) {
            print('  - 포스트 변환 실패: $e');
          }
        }
        
      } catch (e) {
        print('  - 간단한 쿼리 실패: $e');
      }
      
      // 4. 거리 기반 정밀 필터링
      final filteredPosts = allPosts.where((post) {
        final distance = S2TileUtils.calculateDistance(
          centerLat, centerLng,
          post.location.latitude, post.location.longitude,
        );
        return distance <= radiusKm;
      }).toList();
      
      // 5. 정렬 (거리순, 생성일순)
      filteredPosts.sort((a, b) {
        final distanceA = S2TileUtils.calculateDistance(
          centerLat, centerLng,
          a.location.latitude, a.location.longitude,
        );
        final distanceB = S2TileUtils.calculateDistance(
          centerLat, centerLng,
          b.location.latitude, b.location.longitude,
        );
        
        if (distanceA != distanceB) {
          return distanceA.compareTo(distanceB);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      
      // 6. 제한 적용
      final limitedPosts = filteredPosts.take(limit).toList();
      
      print('  - 최종 결과: ${limitedPosts.length}개');
      
      return PostSearchResult(
        posts: limitedPosts,
        nextCursor: limitedPosts.length >= limit ? 'next_${limitedPosts.length}' : null,
        totalCount: filteredPosts.length,
      );
      
    } catch (e) {
      print('❌ 포스트 검색 실패: $e');
      return PostSearchResult(
        posts: [],
        nextCursor: null,
        totalCount: 0,
      );
    }
  }
  
  /// 배치별 포스트 쿼리
  static Future<List<PostModel>> _queryPostsBatch({
    required List<String> s2Cells,
    required int? fogLevel,
    required String rewardType,
    required int limit,
  }) async {
    try {
      // 기본 필터
      Query query = _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('expiresAt', isGreaterThan: Timestamp.now());
      
      // S2 타일 필터
      query = query.where('s2_12', whereIn: s2Cells);
      
      // 포그레벨 필터
      if (fogLevel != null) {
        query = query.where('fogLevel', isEqualTo: fogLevel);
      }
      
      // 리워드 타입 필터
      if (rewardType != 'all') {
        query = query.where('rewardType', isEqualTo: rewardType);
      }
      
      // 쿼리 실행
      final snapshot = await query.limit(limit).get();
      
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
          
    } catch (e) {
      print('❌ 배치 쿼리 실패: $e');
      return [];
    }
  }
  
  /// 포스트 생성 시 S2 타일 ID 자동 설정
  static Future<void> updatePostS2Tiles(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final location = data['location'] as GeoPoint;
      
      // S2 타일 ID 계산
      final s2_10 = S2TileUtils.latLngToS2CellId(
        location.latitude, location.longitude, 10
      );
      final s2_12 = S2TileUtils.latLngToS2CellId(
        location.latitude, location.longitude, 12
      );
      
      // 포그레벨 계산 (간단한 구현)
      final fogLevel = _calculateFogLevel(location);
      
      // 업데이트
      await _firestore.collection('posts').doc(postId).update({
        's2_10': s2_10,
        's2_12': s2_12,
        'fogLevel': fogLevel,
        'rewardType': data['reward'] != null && data['reward'] >= 1000 ? 'super' : 'normal',
        'tileId_fog1': fogLevel == 1 ? s2_10 : null,
      });
      
      print('✅ 포스트 S2 타일 업데이트 완료: $postId');
      
    } catch (e) {
      print('❌ 포스트 S2 타일 업데이트 실패: $e');
    }
  }
  
  /// 폴백 쿼리 (인덱스 없이 작동)
  static Future<List<PostModel>> _queryPostsFallback({
    required int? fogLevel,
    required String rewardType,
    required int limit,
  }) async {
    try {
      print('  - 폴백 쿼리 실행 중...');
      
      // 1. 먼저 모든 포스트 조회 (디버깅용)
      final allPostsSnapshot = await _firestore.collection('posts').limit(10).get();
      print('  - 전체 포스트 개수: ${allPostsSnapshot.docs.length}개');
      
      if (allPostsSnapshot.docs.isNotEmpty) {
        final samplePost = allPostsSnapshot.docs.first;
        print('  - 샘플 포스트: ${samplePost.data()}');
      }
      
      // 2. 기본 필터만 사용
      Query query = _firestore
          .collection('posts')
          .where('isActive', isEqualTo: true)
          .where('isCollected', isEqualTo: false)
          .where('expiresAt', isGreaterThan: Timestamp.now());
      
      // 리워드 타입 필터
      if (rewardType != 'all') {
        query = query.where('rewardType', isEqualTo: rewardType);
      }
      
      // 쿼리 실행
      final snapshot = await query.limit(limit).get();
      
      print('  - 폴백 쿼리 결과: ${snapshot.docs.length}개 문서');
      
      return snapshot.docs
          .map((doc) => PostModel.fromFirestore(doc))
          .toList();
          
    } catch (e) {
      print('❌ 폴백 쿼리 실패: $e');
      return [];
    }
  }
  
  /// 포그레벨 계산 (간단한 구현)
  static int _calculateFogLevel(GeoPoint location) {
    // 실제로는 사용자의 방문 기록을 기반으로 계산
    // 여기서는 간단히 1로 설정
    return 1;
  }
}

/// 포스트 검색 결과
class PostSearchResult {
  final List<PostModel> posts;
  final String? nextCursor;
  final int totalCount;
  
  PostSearchResult({
    required this.posts,
    required this.nextCursor,
    required this.totalCount,
  });
}
