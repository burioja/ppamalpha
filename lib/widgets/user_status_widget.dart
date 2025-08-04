// lib/widgets/user_status_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class WorkplaceData {
  final List<String> data; // {groupdata1, groupdata2, groupdata3, workplaceinput + workplaceadd}
  final Color color;       // ê·¸ë£¹ë³?ê³ ì • ?‰ìƒ
  final String mode;       // work ?ëŠ” life
  final String placeId;    // ?Œë ˆ?´ìŠ¤ ID

  WorkplaceData(this.data, this.color, {this.mode = 'work', this.placeId = ''});
}

// ?œë¤ ?‰ìƒ ?ì„± ?¨ìˆ˜
Color generateRandomColor() {
  Random random = Random();
  return Color.fromARGB(
    255,
    50 + random.nextInt(206),
    50 + random.nextInt(206),
    50 + random.nextInt(206),
  );
}

// ëª¨ë“œë³??Œë ˆ?´ìŠ¤ ê°€?¸ì˜¤ê¸?
Future<List<List<WorkplaceData>>> fetchUserWorkplacesByMode(String mode) async {
  List<List<WorkplaceData>> workplacesList = [];
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ê¸°ë³¸ ê°œì¸ ?Œë ˆ?´ìŠ¤ ?œê³µ
      if (mode == 'life') {
        workplacesList.add([WorkplaceData(['ê°œì¸'], Colors.blue.shade300, mode: 'life', placeId: 'personal')]);
      } else {
        workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work')]);
      }
      return workplacesList;
    }

    // ê¸°ì¡´ ?°ì´??êµ¬ì¡°?€ ?ˆë¡œ??êµ¬ì¡° ëª¨ë‘ ?•ì¸
    List<WorkplaceData> modeWorkplaces = [];

    // 1. ?ˆë¡œ??PRD êµ¬ì¡°?ì„œ ?¬ìš©???Œë ˆ?´ìŠ¤ ê°€?¸ì˜¤ê¸?(?Œë ˆ?´ìŠ¤ ?œë¸Œì»¬ë ‰??
    try {
      final userPlacesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .where('mode', isEqualTo: mode)
          .get();

      // print ¹® Á¦°ÅµÊ

      for (var placeDoc in userPlacesSnapshot.docs) {
        final placeData = placeDoc.data();
        final placeId = placeDoc.id;
        final roleName = placeData['roleName'] ?? 'ì§ì›';
        final workplaceAdd = placeData['workplaceAdd'] ?? '';

        // ?Œë ˆ?´ìŠ¤ ?ì„¸ ?•ë³´ ê°€?¸ì˜¤ê¸?
        final placeDetailDoc = await FirebaseFirestore.instance
            .collection('places')
            .doc(placeId)
            .get();

        if (placeDetailDoc.exists) {
          final placeDetail = placeDetailDoc.data()!;
          final placeName = placeDetail['name'] ?? placeId;
          final displayName = workplaceAdd.isNotEmpty ? '$placeName $workplaceAdd' : placeName;

          List<String> data = [roleName, displayName];
          Color groupColor = generateRandomColor();

          modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: placeId));
          print('?Œë ˆ?´ìŠ¤ ì¶”ê?: $placeName (??• : $roleName)');
        }
      }
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
    }

    // 2. ?¸ë™???Œë ˆ?´ìŠ¤ ê°€?¸ì˜¤ê¸?(user_tracks?ì„œ ëª¨ë“œë³??„í„°ë§?
    try {
      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      // print ¹® Á¦°ÅµÊ

      for (var trackDoc in trackSnapshot.docs) {
        final trackData = trackDoc.data();
        final placeId = trackDoc.id;
        final trackMode = trackData['mode'] ?? 'work';

        // ?„ì¬ ëª¨ë“œ?€ ?¼ì¹˜?˜ëŠ” ?¸ë™???Œë ˆ?´ìŠ¤ë§?ì¶”ê?
        if (trackMode == mode) {
          // ?´ë? ?Œë ˆ?´ìŠ¤ ?œë¸Œì»¬ë ‰?˜ì— ?ˆëŠ”ì§€ ?•ì¸
          bool alreadyAdded = modeWorkplaces.any((workplace) => workplace.placeId == placeId);
          
          if (!alreadyAdded) {
            // ?Œë ˆ?´ìŠ¤ ?ì„¸ ?•ë³´ ê°€?¸ì˜¤ê¸?
            final placeDetailDoc = await FirebaseFirestore.instance
                .collection('places')
                .doc(placeId)
                .get();

            if (placeDetailDoc.exists) {
              final placeDetail = placeDetailDoc.data()!;
              final placeName = placeDetail['name'] ?? placeId;

              List<String> data = ['?¸ë˜ì»?, placeName];
              Color groupColor = generateRandomColor();

              modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: placeId));
              // print ¹® Á¦°ÅµÊ
            }
          }
        }
      }
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
    }

    // 3. ê¸°ì¡´ ?°ì´??êµ¬ì¡°?ì„œ???•ì¸ (?˜ìœ„ ?¸í™˜??
    if (modeWorkplaces.isEmpty) {
      try {
        QuerySnapshot userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: user.email)
            .get();

        if (userQuery.docs.isNotEmpty) {
          DocumentSnapshot userDoc = userQuery.docs.first;
          List<dynamic>? workPlaces = userDoc['workPlaces'] as List<dynamic>?;

          if (workPlaces != null && workPlaces.isNotEmpty) {
            for (var place in workPlaces) {
              String workplaceInput = place['workplaceinput'] ?? '';
              String workplaceAdd = place['workplaceadd'] ?? '';

              DocumentSnapshot workplaceDoc = await FirebaseFirestore.instance
                  .collection('workplaces')
                  .doc(workplaceInput)
                  .get();

              if (workplaceDoc.exists) {
                String groupData1 = workplaceDoc['groupdata1'] ?? '';
                String groupData2 = workplaceDoc['groupdata2'] ?? '';
                String groupData3 = workplaceDoc['groupdata3'] ?? '';

                String workplaceDisplay = workplaceInput + (workplaceAdd.isNotEmpty ? ' $workplaceAdd' : '');
                List<String> data = [groupData1, groupData2, groupData3, workplaceDisplay];

                Color groupColor = generateRandomColor();
                modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: workplaceInput));
              }
            }
          }
        }
      } catch (e) {
        // print ¹® Á¦°ÅµÊ
      }
    }

    if (modeWorkplaces.isEmpty) {
      // ê¸°ë³¸ ê°œì¸ ?Œë ˆ?´ìŠ¤ ?œê³µ
      if (mode == 'life') {
        modeWorkplaces.add(WorkplaceData(['ê°œì¸'], Colors.blue.shade300, mode: 'life', placeId: 'personal'));
      } else {
        modeWorkplaces.add(WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work'));
      }
    }

    // print ¹® Á¦°ÅµÊ
    workplacesList.add(modeWorkplaces);
    return workplacesList;
  } catch (e) {
    // print ¹® Á¦°ÅµÊ
    return [];
  }
}

// Track ?Œë ˆ?´ìŠ¤ ê°œìˆ˜ ê°€?¸ì˜¤ê¸?
Future<int> getTrackCount(String mode) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final trackSnapshot = await FirebaseFirestore.instance
        .collection('user_tracks')
        .doc(user.uid)
        .collection('following')
        .get();

    // print ¹® Á¦°ÅµÊ
    for (var doc in trackSnapshot.docs) {
      print('Track ë¬¸ì„œ ID: ${doc.id}, ?°ì´?? ${doc.data()}');
    }

    // ëª¨ë“  Track???Œë ˆ?´ìŠ¤ ê°œìˆ˜ ë°˜í™˜ (ëª¨ë“œ ?„í„°ë§??œê±°)
    return trackSnapshot.docs.length;
  } catch (e) {
    // print ¹® Á¦°ÅµÊ
    return 0;
  }
}

// ê¸°ë³¸ ê°œì¸ ?Œë ˆ?´ìŠ¤ ?ì„±
Future<void> createDefaultPersonalPlace() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ?´ë? ê°œì¸ ?Œë ˆ?´ìŠ¤ê°€ ?ˆëŠ”ì§€ ?•ì¸
    final existingPersonalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('places')
        .doc('personal')
        .get();

    if (!existingPersonalDoc.exists) {
      // ê°œì¸ ?Œë ˆ?´ìŠ¤ ?ì„±
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc('personal')
          .set({
        'mode': 'life',
        'roleId': 'personal',
        'roleName': 'ê°œì¸',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'permissions': ['personal_schedule', 'personal_settings'],
      });

      // places ì»¬ë ‰?˜ì—??ê°œì¸ ?Œë ˆ?´ìŠ¤ ?ì„±
      await FirebaseFirestore.instance
          .collection('places')
          .doc('personal')
          .set({
        'name': 'ê°œì¸',
        'description': 'ê°œì¸ ?œë™ ê³µê°„',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'originalData': {
          'groupdata1': 'ê°œì¸',
          'groupdata2': 'ê°œì¸',
          'groupdata3': 'ê°œì¸',
        },
      });

      // places/members?ë„ ì¶”ê?
      await FirebaseFirestore.instance
          .collection('places')
          .doc('personal')
          .collection('members')
          .doc(user.uid)
          .set({
        'roleId': 'personal',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // print ¹® Á¦°ÅµÊ
    }
  } catch (e) {
    // print ¹® Á¦°ÅµÊ
  }
}
