import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 기존 workplaces 데이터 구조 확인
  Future<void> inspectWorkplacesStructure() async {
    try {
      print('=== Workplaces 데이터 구조 확인 시작 ===');
      
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      if (workplacesSnapshot.docs.isEmpty) {
        print('workplaces 컬렉션이 비어있습니다.');
        return;
      }
      
      // 첫 번째 문서의 구조 확인
      final firstDoc = workplacesSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      print('첫 번째 workplace 문서 ID: ${firstDoc.id}');
      print('첫 번째 workplace 문서 필드들:');
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      // 모든 문서의 주요 필드들 확인
      print('\n모든 workplaces 문서의 주요 필드들:');
      for (var doc in workplacesSnapshot.docs) {
        final data = doc.data();
        print('문서 ID: ${doc.id}');
        print('  - id: ${data['id']}');
        print('  - groupdata1: ${data['groupdata1']}');
        print('  - groupdata2: ${data['groupdata2']}');
        print('  - groupdata3: ${data['groupdata3']}');
        print('  - 기타 필드들: ${data.keys.where((key) => !['id', 'groupdata1', 'groupdata2', 'groupdata3'].contains(key)).toList()}');
        print('---');
      }
      
      print('=== Workplaces 데이터 구조 확인 완료 ===');
    } catch (e) {
      print('Workplaces 구조 확인 오류: $e');
    }
  }

  // 기존 users 데이터 구조 확인
  Future<void> inspectUsersStructure() async {
    try {
      print('=== Users 데이터 구조 확인 시작 ===');
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      if (usersSnapshot.docs.isEmpty) {
        print('users 컬렉션이 비어있습니다.');
        return;
      }
      
      // 첫 번째 문서의 구조 확인
      final firstDoc = usersSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      print('첫 번째 user 문서 ID: ${firstDoc.id}');
      print('첫 번째 user 문서 필드들:');
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      print('=== Users 데이터 구조 확인 완료 ===');
    } catch (e) {
      print('Users 구조 확인 오류: $e');
    }
  }

  // PRD 구조에 맞는 users 컬렉션 업데이트
  Future<void> updateUsersStructure() async {
    try {
      print('=== Users 컬렉션 구조 업데이트 시작 ===');
      
      // 기존 users 컬렉션의 모든 문서 가져오기
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final userId = doc.id;
        
        // 기존 데이터 보존
        final originalData = Map<String, dynamic>.from(userData);
        
        // PRD 구조에 맞는 새로운 데이터 구조
        final newUserData = {
          'profile': {
            'info': {
              'nickname': userData['nickname'] ?? '닉네임',
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
        print('사용자 $userId 업데이트 완료');
      }
      
      print('=== Users 컬렉션 구조 업데이트 완료 ===');
    } catch (e) {
      print('Users 컬렉션 업데이트 오류: $e');
    }
  }

  // PRD 구조에 맞는 places 컬렉션 생성
  Future<void> createPlacesStructure() async {
    try {
      print('=== Places 컬렉션 구조 생성 시작 ===');
      
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
        print('플레이스 $workplaceId 생성 완료');
        
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
        
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('customer')
            .set({
          'name': '고객',
          'permissions': ['view'],
          'level': 4,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('=== Places 컬렉션 구조 생성 완료 ===');
    } catch (e) {
      print('Places 컬렉션 생성 오류: $e');
    }
  }

  // 사용자-플레이스 관계 생성
  Future<void> createUserPlaceRelationships() async {
    try {
      print('=== 사용자-플레이스 관계 생성 시작 ===');
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        
        // 기존 workPlaces 데이터 확인
        if (userData['workPlaces'] != null) {
          final workPlaces = userData['workPlaces'] as List<dynamic>;
          
          for (var workplace in workPlaces) {
            if (workplace is Map<String, dynamic>) {
              final workplaceId = workplace['workplaceinput'] ?? '';
              final workplaceAdd = workplace['workplaceadd'] ?? '';
              
              if (workplaceId.isNotEmpty) {
                // 플레이스가 존재하는지 확인
                final placeDoc = await _firestore.collection('places').doc(workplaceId).get();
                
                if (placeDoc.exists) {
                  // 사용자가 등록한 모드 결정 (기본값: work)
                  // 기존 workPlaces는 워크모드에서 등록된 것으로 간주
                  String mode = 'work';
                  
                  // 사용자의 places 서브컬렉션에 추가
                  await _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('places')
                      .doc(workplaceId)
                      .set({
                    'mode': mode,
                    'roleId': 'employee', // 기본값
                    'roleName': '직원',
                    'joinedAt': FieldValue.serverTimestamp(),
                    'status': 'active',
                    'permissions': ['schedule'],
                    'workplaceAdd': workplaceAdd, // 지점 정보 보존
                  });
                  
                  // 플레이스의 members 서브컬렉션에 추가
                  await _firestore
                      .collection('places')
                      .doc(workplaceId)
                      .collection('members')
                      .doc(userId)
                      .set({
                    'roleId': 'employee',
                    'joinedAt': FieldValue.serverTimestamp(),
                    'status': 'active',
                    'permissions': ['schedule'],
                    'workplaceAdd': workplaceAdd, // 지점 정보 보존
                  });
                  
                  print('사용자 $userId - 플레이스 $workplaceId 관계 생성 완료 (mode: $mode, 지점: $workplaceAdd)');
                } else {
                  print('경고: 플레이스 $workplaceId가 존재하지 않습니다.');
                }
              }
            }
          }
        }
      }
      
      print('=== 사용자-플레이스 관계 생성 완료 ===');
    } catch (e) {
      print('사용자-플레이스 관계 생성 오류: $e');
    }
  }

  // 전체 마이그레이션 실행
  Future<void> runMigration() async {
    print('=== 데이터베이스 마이그레이션 시작 ===');
    
    await updateUsersStructure();
    await createPlacesStructure();
    await createUserPlaceRelationships();
    
    print('=== 데이터베이스 마이그레이션 완료 ===');
  }

  // 데이터 구조 확인만 실행
  Future<void> inspectDataStructure() async {
    print('=== 데이터베이스 구조 확인 시작 ===');
    
    await inspectWorkplacesStructure();
    await inspectUsersStructure();
    
    print('=== 데이터베이스 구조 확인 완료 ===');
  }
} 