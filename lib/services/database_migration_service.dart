import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 기존 workplaces ?�이??구조 ?�인
  Future<void> inspectWorkplacesStructure() async {
    try {
      // print �� ���ŵ�
      
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      if (workplacesSnapshot.docs.isEmpty) {
        // print �� ���ŵ�
        return;
      }
      
      // �?번째 문서??구조 ?�인
      final firstDoc = workplacesSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      // print �� ���ŵ�
      // print �� ���ŵ�
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      // 모든 문서??주요 ?�드???�인
      // print �� ���ŵ�
      for (var doc in workplacesSnapshot.docs) {
        final data = doc.data();
        // print �� ���ŵ�
        // print �� ���ŵ�
        // print �� ���ŵ�
        // print �� ���ŵ�
        // print �� ���ŵ�
        print('  - 기�? ?�드?? ${data.keys.where((key) => !['id', 'groupdata1', 'groupdata2', 'groupdata3'].contains(key)).toList()}');
        // print �� ���ŵ�
      }
      
      // print �� ���ŵ�
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // 기존 users ?�이??구조 ?�인
  Future<void> inspectUsersStructure() async {
    try {
      // print �� ���ŵ�
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      if (usersSnapshot.docs.isEmpty) {
        // print �� ���ŵ�
        return;
      }
      
      // �?번째 문서??구조 ?�인
      final firstDoc = usersSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      // print �� ���ŵ�
      // print �� ���ŵ�
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      // print �� ���ŵ�
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // PRD 구조??맞는 users 컬렉???�데?�트
  Future<void> updateUsersStructure() async {
    try {
      // print �� ���ŵ�
      
      // 기존 users 컬렉?�의 모든 문서 가?�오�?
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final userId = doc.id;
        
        // 기존 ?�이??보존
        final originalData = Map<String, dynamic>.from(userData);
        
        // PRD 구조??맞는 ?�로???�이??구조
        final newUserData = {
          'profile': {
            'info': {
              'nickname': userData['nickname'] ?? '?�네??,
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
          // 기존 ?�이??보존 (백업??
          'originalData': originalData,
        };
        
        // 기존 ?�이?��? ?�로??구조�??�데?�트
        await _firestore.collection('users').doc(userId).set(newUserData, SetOptions(merge: true));
        // print �� ���ŵ�
      }
      
      // print �� ���ŵ�
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // PRD 구조??맞는 places 컬렉???�성
  Future<void> createPlacesStructure() async {
    try {
      // print �� ���ŵ�
      
      // 기존 workplaces ?�이?��? places�?마이그레?�션
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      for (var doc in workplacesSnapshot.docs) {
        final workplaceData = doc.data();
        final workplaceId = doc.id;
        
        // PRD 구조??맞는 places ?�이??(mode ?�드 ?�거)
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
          // 기존 ?�이??보존 (백업??
          'originalData': {
            'groupdata1': workplaceData['groupdata1'],
            'groupdata2': workplaceData['groupdata2'],
            'groupdata3': workplaceData['groupdata3'],
          },
        };
        
        // places 컬렉?�에 추�?
        await _firestore.collection('places').doc(workplaceId).set(placeData);
        // print �� ���ŵ�
        
        // 기본 ??�� ?�성
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('owner')
            .set({
          'name': '?�유??,
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
      
      // print �� ���ŵ�
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // ?�용???�레?�스 관�??�성
  Future<void> createUserPlaceRelationships() async {
    try {
      // print �� ���ŵ�
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        
        // 기존 workPlaces ?�이???�인
        if (userData['workPlaces'] != null) {
          final workPlaces = userData['workPlaces'] as List<dynamic>;
          
          for (var workplace in workPlaces) {
            if (workplace is Map<String, dynamic>) {
              final workplaceId = workplace['workplaceinput'] ?? '';
              final workplaceAdd = workplace['workplaceadd'] ?? '';
              
              if (workplaceId.isNotEmpty) {
                // ?�레?�스가 존재?�는지 ?�인
                final placeDoc = await _firestore.collection('places').doc(workplaceId).get();
                
                if (placeDoc.exists) {
                  // ?�용?��? ?�록??모드 결정 (기본�? work)
                  // 기존 workPlaces???�크모드?�서 ?�록??것으�?간주
                  String mode = 'work';
                  
                  // ?�용?�의 places ?�브컬렉?�에 추�?
                  await _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('places')
                      .doc(workplaceId)
                      .set({
                    'mode': mode,
                    'roleId': 'employee', // 기본�?
                    'roleName': '직원',
                    'joinedAt': FieldValue.serverTimestamp(),
                    'status': 'active',
                    'permissions': ['schedule'],
                    'workplaceAdd': workplaceAdd, // 지???�보 보존
                  });
                  
                  // ?�레?�스??members ?�브컬렉?�에 추�?
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
                    'workplaceAdd': workplaceAdd, // 지???�보 보존
                  });
                  
                  print('?�용??$userId - ?�레?�스 $workplaceId 관�??�성 ?�료 (mode: $mode, 지?? $workplaceAdd)');
                } else {
                  // print �� ���ŵ�
                }
              }
            }
          }
        }
      }
      
      // print �� ���ŵ�
    } catch (e) {
      // print �� ���ŵ�
    }
  }

  // ?�체 마이그레?�션 ?�행
  Future<void> runMigration() async {
    // print �� ���ŵ�
    
    await updateUsersStructure();
    await createPlacesStructure();
    await createUserPlaceRelationships();
    
    // print �� ���ŵ�
  }

  // ?�이??구조 ?�인�??�행
  Future<void> inspectDataStructure() async {
    // print �� ���ŵ�
    
    await inspectWorkplacesStructure();
    await inspectUsersStructure();
    
    // print �� ���ŵ�
  }
} 
