import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseMigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Í∏∞Ï°¥ workplaces ?∞Ïù¥??Íµ¨Ï°∞ ?ïÏù∏
  Future<void> inspectWorkplacesStructure() async {
    try {
      // print πÆ ¡¶∞≈µ 
      
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      if (workplacesSnapshot.docs.isEmpty) {
        // print πÆ ¡¶∞≈µ 
        return;
      }
      
      // Ï≤?Î≤àÏß∏ Î¨∏ÏÑú??Íµ¨Ï°∞ ?ïÏù∏
      final firstDoc = workplacesSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      // print πÆ ¡¶∞≈µ 
      // print πÆ ¡¶∞≈µ 
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      // Î™®Îì† Î¨∏ÏÑú??Ï£ºÏöî ?ÑÎìú???ïÏù∏
      // print πÆ ¡¶∞≈µ 
      for (var doc in workplacesSnapshot.docs) {
        final data = doc.data();
        // print πÆ ¡¶∞≈µ 
        // print πÆ ¡¶∞≈µ 
        // print πÆ ¡¶∞≈µ 
        // print πÆ ¡¶∞≈µ 
        // print πÆ ¡¶∞≈µ 
        print('  - Í∏∞Ì? ?ÑÎìú?? ${data.keys.where((key) => !['id', 'groupdata1', 'groupdata2', 'groupdata3'].contains(key)).toList()}');
        // print πÆ ¡¶∞≈µ 
      }
      
      // print πÆ ¡¶∞≈µ 
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
    }
  }

  // Í∏∞Ï°¥ users ?∞Ïù¥??Íµ¨Ï°∞ ?ïÏù∏
  Future<void> inspectUsersStructure() async {
    try {
      // print πÆ ¡¶∞≈µ 
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      if (usersSnapshot.docs.isEmpty) {
        // print πÆ ¡¶∞≈µ 
        return;
      }
      
      // Ï≤?Î≤àÏß∏ Î¨∏ÏÑú??Íµ¨Ï°∞ ?ïÏù∏
      final firstDoc = usersSnapshot.docs.first;
      final firstDocData = firstDoc.data();
      
      // print πÆ ¡¶∞≈µ 
      // print πÆ ¡¶∞≈µ 
      firstDocData.forEach((key, value) {
        print('  $key: $value (${value.runtimeType})');
      });
      
      // print πÆ ¡¶∞≈µ 
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
    }
  }

  // PRD Íµ¨Ï°∞??ÎßûÎäî users Ïª¨Î†â???ÖÎç∞?¥Ìä∏
  Future<void> updateUsersStructure() async {
    try {
      // print πÆ ¡¶∞≈µ 
      
      // Í∏∞Ï°¥ users Ïª¨Î†â?òÏùò Î™®Îì† Î¨∏ÏÑú Í∞Ä?∏Ïò§Í∏?
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var doc in usersSnapshot.docs) {
        final userData = doc.data();
        final userId = doc.id;
        
        // Í∏∞Ï°¥ ?∞Ïù¥??Î≥¥Ï°¥
        final originalData = Map<String, dynamic>.from(userData);
        
        // PRD Íµ¨Ï°∞??ÎßûÎäî ?àÎ°ú???∞Ïù¥??Íµ¨Ï°∞
        final newUserData = {
          'profile': {
            'info': {
              'nickname': userData['nickname'] ?? '?âÎÑ§??,
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
          // Í∏∞Ï°¥ ?∞Ïù¥??Î≥¥Ï°¥ (Î∞±ÏóÖ??
          'originalData': originalData,
        };
        
        // Í∏∞Ï°¥ ?∞Ïù¥?∞Î? ?àÎ°ú??Íµ¨Ï°∞Î°??ÖÎç∞?¥Ìä∏
        await _firestore.collection('users').doc(userId).set(newUserData, SetOptions(merge: true));
        // print πÆ ¡¶∞≈µ 
      }
      
      // print πÆ ¡¶∞≈µ 
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
    }
  }

  // PRD Íµ¨Ï°∞??ÎßûÎäî places Ïª¨Î†â???ùÏÑ±
  Future<void> createPlacesStructure() async {
    try {
      // print πÆ ¡¶∞≈µ 
      
      // Í∏∞Ï°¥ workplaces ?∞Ïù¥?∞Î? placesÎ°?ÎßàÏù¥Í∑∏Î†à?¥ÏÖò
      final workplacesSnapshot = await _firestore.collection('workplaces').get();
      
      for (var doc in workplacesSnapshot.docs) {
        final workplaceData = doc.data();
        final workplaceId = doc.id;
        
        // PRD Íµ¨Ï°∞??ÎßûÎäî places ?∞Ïù¥??(mode ?ÑÎìú ?úÍ±∞)
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
          // Í∏∞Ï°¥ ?∞Ïù¥??Î≥¥Ï°¥ (Î∞±ÏóÖ??
          'originalData': {
            'groupdata1': workplaceData['groupdata1'],
            'groupdata2': workplaceData['groupdata2'],
            'groupdata3': workplaceData['groupdata3'],
          },
        };
        
        // places Ïª¨Î†â?òÏóê Ï∂îÍ?
        await _firestore.collection('places').doc(workplaceId).set(placeData);
        // print πÆ ¡¶∞≈µ 
        
        // Í∏∞Î≥∏ ??ï† ?ùÏÑ±
        await _firestore
            .collection('places')
            .doc(workplaceId)
            .collection('roles')
            .doc('owner')
            .set({
          'name': '?åÏú†??,
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
          'name': 'Í¥ÄÎ¶¨Ïûê',
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
          'name': 'ÏßÅÏõê',
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
          'name': 'Í≥†Í∞ù',
          'permissions': ['view'],
          'level': 4,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      // print πÆ ¡¶∞≈µ 
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
    }
  }

  // ?¨Ïö©???åÎ†à?¥Ïä§ Í¥ÄÍ≥??ùÏÑ±
  Future<void> createUserPlaceRelationships() async {
    try {
      // print πÆ ¡¶∞≈µ 
      
      final usersSnapshot = await _firestore.collection('users').get();
      
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        
        // Í∏∞Ï°¥ workPlaces ?∞Ïù¥???ïÏù∏
        if (userData['workPlaces'] != null) {
          final workPlaces = userData['workPlaces'] as List<dynamic>;
          
          for (var workplace in workPlaces) {
            if (workplace is Map<String, dynamic>) {
              final workplaceId = workplace['workplaceinput'] ?? '';
              final workplaceAdd = workplace['workplaceadd'] ?? '';
              
              if (workplaceId.isNotEmpty) {
                // ?åÎ†à?¥Ïä§Í∞Ä Ï°¥Ïû¨?òÎäîÏßÄ ?ïÏù∏
                final placeDoc = await _firestore.collection('places').doc(workplaceId).get();
                
                if (placeDoc.exists) {
                  // ?¨Ïö©?êÍ? ?±Î°ù??Î™®Îìú Í≤∞Ï†ï (Í∏∞Î≥∏Í∞? work)
                  // Í∏∞Ï°¥ workPlaces???åÌÅ¨Î™®Îìú?êÏÑú ?±Î°ù??Í≤ÉÏúºÎ°?Í∞ÑÏ£º
                  String mode = 'work';
                  
                  // ?¨Ïö©?êÏùò places ?úÎ∏åÏª¨Î†â?òÏóê Ï∂îÍ?
                  await _firestore
                      .collection('users')
                      .doc(userId)
                      .collection('places')
                      .doc(workplaceId)
                      .set({
                    'mode': mode,
                    'roleId': 'employee', // Í∏∞Î≥∏Í∞?
                    'roleName': 'ÏßÅÏõê',
                    'joinedAt': FieldValue.serverTimestamp(),
                    'status': 'active',
                    'permissions': ['schedule'],
                    'workplaceAdd': workplaceAdd, // ÏßÄ???ïÎ≥¥ Î≥¥Ï°¥
                  });
                  
                  // ?åÎ†à?¥Ïä§??members ?úÎ∏åÏª¨Î†â?òÏóê Ï∂îÍ?
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
                    'workplaceAdd': workplaceAdd, // ÏßÄ???ïÎ≥¥ Î≥¥Ï°¥
                  });
                  
                  print('?¨Ïö©??$userId - ?åÎ†à?¥Ïä§ $workplaceId Í¥ÄÍ≥??ùÏÑ± ?ÑÎ£å (mode: $mode, ÏßÄ?? $workplaceAdd)');
                } else {
                  // print πÆ ¡¶∞≈µ 
                }
              }
            }
          }
        }
      }
      
      // print πÆ ¡¶∞≈µ 
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
    }
  }

  // ?ÑÏ≤¥ ÎßàÏù¥Í∑∏Î†à?¥ÏÖò ?§Ìñâ
  Future<void> runMigration() async {
    // print πÆ ¡¶∞≈µ 
    
    await updateUsersStructure();
    await createPlacesStructure();
    await createUserPlaceRelationships();
    
    // print πÆ ¡¶∞≈µ 
  }

  // ?∞Ïù¥??Íµ¨Ï°∞ ?ïÏù∏Îß??§Ìñâ
  Future<void> inspectDataStructure() async {
    // print πÆ ¡¶∞≈µ 
    
    await inspectWorkplacesStructure();
    await inspectUsersStructure();
    
    // print πÆ ¡¶∞≈µ 
  }
} 
