import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firestore 타일 데이터 디버깅 스크립트
/// 
/// 사용법:
/// dart scripts/debug_tile_data.dart

class TileDataDebugger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// 현재 사용자의 타일 데이터 확인
  static Future<void> debugCurrentUserTiles() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ 로그인된 사용자가 없습니다.');
      return;
    }
    
    print('👤 사용자: ${user.uid}');
    print('📧 이메일: ${user.email}');
    
    try {
      // visited_tiles 컬렉션 조회
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .limit(20) // 처음 20개만
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('📭 방문한 타일이 없습니다.');
        return;
      }
      
      print('📊 방문한 타일 (${snapshot.docs.length}개):');
      print('=' * 80);
      
      for (final doc in snapshot.docs) {
        final tileId = doc.id;
        final data = doc.data();
        
        print('🔸 타일 ID: $tileId');
        print('  - lastVisitTime: ${data['lastVisitTime']}');
        print('  - visitCount: ${data['visitCount']}');
        print('  - originalScheme: ${data['originalScheme']}');
        print('  - originalTileId: ${data['originalTileId']}');
        print('  - migratedAt: ${data['migratedAt']}');
        print('  - 전체 데이터: $data');
        print('-' * 40);
      }
      
      // 타일 ID 형식 분석
      print('\n📈 타일 ID 형식 분석:');
      int km1Count = 0;
      int xyzCount = 0;
      int otherCount = 0;
      
      for (final doc in snapshot.docs) {
        final tileId = doc.id;
        if (tileId.startsWith('tile_')) {
          km1Count++;
        } else if (tileId.contains('_') && tileId.split('_').length == 3) {
          xyzCount++;
        } else {
          otherCount++;
        }
      }
      
      print('  - 1km 그리드 형식: $km1Count개');
      print('  - XYZ 형식: $xyzCount개');
      print('  - 기타 형식: $otherCount개');
      
    } catch (e) {
      print('❌ 데이터 조회 실패: $e');
    }
  }
  
  /// 특정 타일 ID의 상세 정보 확인
  static Future<void> debugSpecificTile(String tileId) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ 로그인된 사용자가 없습니다.');
      return;
    }
    
    print('🔍 타일 상세 정보: $tileId');
    
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .doc(tileId)
          .get();
      
      if (!doc.exists) {
        print('❌ 해당 타일이 존재하지 않습니다.');
        return;
      }
      
      final data = doc.data()!;
      print('✅ 타일 데이터:');
      print('  - lastVisitTime: ${data['lastVisitTime']}');
      print('  - visitCount: ${data['visitCount']}');
      print('  - originalScheme: ${data['originalScheme']}');
      print('  - originalTileId: ${data['originalTileId']}');
      print('  - 전체 데이터: $data');
      
    } catch (e) {
      print('❌ 타일 조회 실패: $e');
    }
  }
}

/// 메인 함수
Future<void> main(List<String> args) async {
  try {
    print('🔥 Firebase 초기화 중...');
    
    if (args.isEmpty) {
      await TileDataDebugger.debugCurrentUserTiles();
    } else if (args[0] == 'tile' && args.length > 1) {
      await TileDataDebugger.debugSpecificTile(args[1]);
    } else {
      print('사용법:');
      print('  dart scripts/debug_tile_data.dart           # 현재 사용자 타일 데이터');
      print('  dart scripts/debug_tile_data.dart tile <id> # 특정 타일 상세 정보');
    }
    
  } catch (e) {
    print('❌ 오류 발생: $e');
    exit(1);
  }
}
