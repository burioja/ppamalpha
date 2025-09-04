import 'package:cloud_firestore/cloud_firestore.dart';


class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // 데이터 구조 확인
  Future<void> inspectDataStructure() async {
    try {
      debugPrint('데이터 구조 확인 시작...');
      
      // users 컬렉션 확인
      final usersSnapshot = await _firestore.collection('users').limit(1).get();
      if (usersSnapshot.docs.isNotEmpty) {
        final userData = usersSnapshot.docs.first.data();
        debugPrint('현재 사용자 데이터 구조:');
        debugPrint(userData.keys.toList());
      }
      
      // workplaces 컬렉션 확인
      final workplacesSnapshot = await _firestore.collection('workplaces').limit(1).get();
      if (workplacesSnapshot.docs.isNotEmpty) {
        final workplaceData = workplacesSnapshot.docs.first.data();
        debugPrint('현재 직장 데이터 구조:');
        debugPrint(workplaceData.keys.toList());
      }
      
      debugPrint('데이터 구조 확인 완료');
    } catch (e) {
      debugPrint('데이터 구조 확인 중 오류: $e');
      rethrow;
    }
  }

  // 마이그레이션 실행
  Future<void> runMigration() async {
    try {
      debugPrint('마이그레이션 시작...');
      
      // 1. 사용자 데이터 구조 업데이트
      await updateUserStructure();
      
      // 2. places 컬렉션 생성
      await createPlacesStructure();
      
      debugPrint('마이그레이션 완료');
    } catch (e) {
      debugPrint('마이그레이션 중 오류: $e');
      rethrow;
    }
  }

  // 사용자 데이터 구조를 PRD에 맞게 업데이트
  Future<void> updateUserStructure() async {
    try {
      debugPrint('사용자 데이터 구조 업데이트 시작...');
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var doc in usersSnapshot.docs) {
        final userId = doc.id;
        final userData = doc.data();
        
        final originalData = Map<String, dynamic>.from(userData);
        
        // PRD 구조에 맞는 새로운 사용자 구조
        final newUserData = {
          'profile': {
            'info': {
              'nickname': userData['nickname'] ?? '사용자',
              'email': userData['email'] ?? '',
              'phoneNumber': userData['phoneNumber'] ?? '',
              'address': userData['address'] ?? '',
              'profileImageUrl': userData['profileImageUrl'] ?? '',
              'birthDate': userData['birthDate'] ?? userData['birth'] ?? '',
              'gender': userData['gender'] ?? '',
              'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }
          },
          'settings': {
            'notificationSettings': {},
            'privacySettings': {},
            'workplaceSettings': {},
          },
          // 기존 데이터 보존 (백업용)
          'originalData': originalData,
        };
        
        // 기존 데이터를 새로운 구조로 업데이트
        await _firestore.collection('users').doc(userId).set(newUserData, SetOptions(merge: true));
        debugPrint('사용자 $userId 업데이트 완료');
      }
      
      debugPrint('사용자 데이터 구조 업데이트 완료');
    } catch (e) {
      debugPrint('사용자 데이터 구조 업데이트 중 오류: $e');
      rethrow;
    }
  }

  // PRD 구조에 맞는 places 컬렉션 생성
  Future<void> createPlacesStructure() async {
    try {
      debugPrint('places 컬렉션 생성 시작...');
      
      // 기존 workplaces 데이터를 places로 마이그레이션
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      for (var doc in workplacesSnapshot.docs) {
        final workplaceData = doc.data();
        final workplaceId = doc.id;
        
        // PRD 구조에 맞는 places 데이터 (mode 필드 제거)
        final placeData = {
          'name': workplaceData['id'] ?? workplaceId,
          'description': '${workplaceData['groupdata1'] ?? ''} - ${workplaceData['groupdata2'] ?? ''} - ${workplaceData['groupdata3'] ?? ''}',
          'address': '',
          'contactInfo': {
            'phone': '',
            'email': '',
          },
          'createdBy': 'system',
          'createdAt': FieldValue.serverTimestamp(),
          // 기존 데이터 보존 (백업용)
          'originalData': {
            'groupdata1': workplaceData['groupdata1'],
            'groupdata2': workplaceData['groupdata2'],
            'groupdata3': workplaceData['groupdata3'],
          },
        };
        
        // places 컬렉션에 추가
        await _firestore.collection('places').doc(workplaceId).set(placeData);
        debugPrint('장소 $workplaceId 생성 완료');
        
        // 기본 역할 생성
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('owner')
            .set({
          'name': '소유자',
          'permissions': ['all'],
          'level': 1,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('manager')
            .set({
          'name': '관리자',
          'permissions': ['schedule', 'employee'],
          'level': 2,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('employee')
            .set({
          'name': '직원',
          'permissions': ['schedule'],
          'level': 3,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('장소 $workplaceId 역할 생성 완료');
      }
      
      debugPrint('places 컬렉션 생성 완료');
    } catch (e) {
      debugPrint('places 컬렉션 생성 중 오류: $e');
      rethrow;
    }
  }
} 
