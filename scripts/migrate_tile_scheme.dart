import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

/// 타일 스킴 마이그레이션 스크립트
/// 
/// 기존 Web Mercator XYZ 스킴 데이터를 1km 근사 그리드 스킴으로 마이그레이션
/// 
/// 사용법:
/// dart scripts/migrate_tile_scheme.dart
/// 
/// 주의사항:
/// - Firebase 프로젝트가 설정되어 있어야 함
/// - 마이그레이션 전에 백업 권장
/// - 테스트 환경에서 먼저 실행 권장

class TileSchemeMigrator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 1km 근사 그리드 상수
  static const double _km1TileSize = 0.009;
  
  /// Web Mercator XYZ를 1km 근사 그리드로 변환
  static String _xyzToKm1TileId(int x, int y, int z) {
    // 타일 중심점 계산
    final lat = _tileYToLatitude(y, z);
    final lng = _tileXToLongitude(x, z);
    
    // 1km 그리드 인덱스 계산
    final tileLat = (lat / _km1TileSize).floor();
    final tileLng = (lng / _km1TileSize).floor();
    
    return 'tile_${tileLat}_${tileLng}';
  }
  
  /// Web Mercator 변환 함수들
  static double _tileXToLongitude(int tileX, int zoomLevel) {
    return tileX / pow(2.0, zoomLevel) * 360.0 - 180.0;
  }
  
  static double _tileYToLatitude(int tileY, int zoomLevel) {
    final n = pi - 2.0 * pi * tileY / pow(2.0, zoomLevel);
    final latitude = 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
    return latitude.clamp(-85.0511, 85.0511);
  }
  
  /// 사용자별 타일 데이터 마이그레이션
  static Future<void> migrateUserTiles(String userId) async {
    print('🔄 사용자 $userId 타일 마이그레이션 시작...');
    
    try {
      // 기존 visited_tiles 컬렉션 조회
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('visited_tiles')
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('📭 마이그레이션할 데이터가 없습니다.');
        return;
      }
      
      print('📊 발견된 타일 문서: ${snapshot.docs.length}개');
      
      final batch = _firestore.batch();
      int migratedCount = 0;
      int skippedCount = 0;
      
      for (final doc in snapshot.docs) {
        final docId = doc.id;
        final data = doc.data();
        
        // 이미 1km 그리드 형식인지 확인
        if (docId.startsWith('tile_')) {
          skippedCount++;
          continue;
        }
        
        // Web Mercator XYZ 형식인지 확인 (x_y_z)
        final parts = docId.split('_');
        if (parts.length != 3) {
          print('⚠️ 알 수 없는 타일 ID 형식: $docId');
          skippedCount++;
          continue;
        }
        
        final x = int.tryParse(parts[0]);
        final y = int.tryParse(parts[1]);
        final z = int.tryParse(parts[2]);
        
        if (x == null || y == null || z == null) {
          print('⚠️ 잘못된 타일 ID 형식: $docId');
          skippedCount++;
          continue;
        }
        
        // 1km 그리드 타일 ID로 변환
        final newTileId = _xyzToKm1TileId(x, y, z);
        
        // 새 문서 참조 생성
        final newDocRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('visited_tiles')
            .doc(newTileId);
        
        // 기존 데이터에 스킴 정보 추가
        final newData = Map<String, dynamic>.from(data);
        newData['originalScheme'] = 'xyz_$z';
        newData['originalTileId'] = docId;
        newData['migratedAt'] = FieldValue.serverTimestamp();
        
        // 배치에 추가
        batch.set(newDocRef, newData, SetOptions(merge: true));
        migratedCount++;
        
        print('✅ $docId → $newTileId');
      }
      
      // 배치 실행
      await batch.commit();
      
      print('🎉 마이그레이션 완료!');
      print('  - 마이그레이션됨: $migratedCount개');
      print('  - 건너뜀: $skippedCount개');
      
    } catch (e) {
      print('❌ 마이그레이션 실패: $e');
      rethrow;
    }
  }
  
  /// 모든 사용자 타일 마이그레이션
  static Future<void> migrateAllUsers() async {
    print('🔄 모든 사용자 타일 마이그레이션 시작...');
    
    try {
      // 모든 사용자 조회
      final usersSnapshot = await _firestore.collection('users').get();
      
      if (usersSnapshot.docs.isEmpty) {
        print('📭 마이그레이션할 사용자가 없습니다.');
        return;
      }
      
      print('👥 발견된 사용자: ${usersSnapshot.docs.length}명');
      
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        print('\n--- 사용자: $userId ---');
        await migrateUserTiles(userId);
      }
      
      print('\n🎉 전체 마이그레이션 완료!');
      
    } catch (e) {
      print('❌ 전체 마이그레이션 실패: $e');
      rethrow;
    }
  }
  
  /// 마이그레이션 통계 조회
  static Future<void> showMigrationStats() async {
    print('📊 마이그레이션 통계 조회...');
    
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      int totalUsers = 0;
      int totalTiles = 0;
      int xyzTiles = 0;
      int km1Tiles = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        totalUsers++;
        final tilesSnapshot = await _firestore
            .collection('users')
            .doc(userDoc.id)
            .collection('visited_tiles')
            .get();
        
        totalTiles += tilesSnapshot.docs.length;
        
        for (final tileDoc in tilesSnapshot.docs) {
          final tileId = tileDoc.id;
          if (tileId.startsWith('tile_')) {
            km1Tiles++;
          } else if (tileId.contains('_') && tileId.split('_').length == 3) {
            xyzTiles++;
          }
        }
      }
      
      print('📈 통계:');
      print('  - 총 사용자: $totalUsers명');
      print('  - 총 타일: $totalTiles개');
      print('  - 1km 그리드: $km1Tiles개');
      print('  - XYZ 형식: $xyzTiles개');
      
    } catch (e) {
      print('❌ 통계 조회 실패: $e');
    }
  }
}

/// 메인 함수
Future<void> main(List<String> args) async {
  try {
    // Firebase 초기화 (Firebase CLI 또는 환경변수 필요)
    print('🔥 Firebase 초기화 중...');
    
    if (args.isEmpty) {
      print('사용법:');
      print('  dart scripts/migrate_tile_scheme.dart stats     # 통계 조회');
      print('  dart scripts/migrate_tile_scheme.dart migrate   # 마이그레이션 실행');
      print('  dart scripts/migrate_tile_scheme.dart user <userId>  # 특정 사용자만');
      return;
    }
    
    final command = args[0];
    
    switch (command) {
      case 'stats':
        await TileSchemeMigrator.showMigrationStats();
        break;
        
      case 'migrate':
        print('⚠️ 주의: 이 작업은 되돌릴 수 없습니다!');
        print('계속하려면 "yes"를 입력하세요:');
        final input = stdin.readLineSync();
        if (input?.toLowerCase() == 'yes') {
          await TileSchemeMigrator.migrateAllUsers();
        } else {
          print('❌ 마이그레이션이 취소되었습니다.');
        }
        break;
        
      case 'user':
        if (args.length < 2) {
          print('❌ 사용자 ID를 입력하세요: dart scripts/migrate_tile_scheme.dart user <userId>');
          return;
        }
        final userId = args[1];
        await TileSchemeMigrator.migrateUserTiles(userId);
        break;
        
      default:
        print('❌ 알 수 없는 명령어: $command');
    }
    
  } catch (e) {
    print('❌ 오류 발생: $e');
    exit(1);
  }
}
