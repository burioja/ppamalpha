// lib/widgets/user_status_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class WorkplaceData {
  final List<String> data; // {groupdata1, groupdata2, groupdata3, workplaceinput + workplaceadd}
  final Color color;       // 그룹�?고정 ?�상
  final String mode;       // work ?�는 life
  final String placeId;    // ?�레?�스 ID

  WorkplaceData(this.data, this.color, {this.mode = 'work', this.placeId = ''});
}

// ?�덤 ?�상 ?�성 ?�수
Color generateRandomColor() {
  Random random = Random();
  return Color.fromARGB(
    255,
    50 + random.nextInt(206),
    50 + random.nextInt(206),
    50 + random.nextInt(206),
  );
}

// 모드�??�레?�스 가?�오�?
Future<List<List<WorkplaceData>>> fetchUserWorkplacesByMode(String mode) async {
  List<List<WorkplaceData>> workplacesList = [];
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // 기본 개인 ?�레?�스 ?�공
      if (mode == 'life') {
        workplacesList.add([WorkplaceData(['개인'], Colors.blue.shade300, mode: 'life', placeId: 'personal')]);
      } else {
        workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work')]);
      }
      return workplacesList;
    }

    // 기존 ?�이??구조?� ?�로??구조 모두 ?�인
    List<WorkplaceData> modeWorkplaces = [];

    // 1. ?�로??PRD 구조?�서 ?�용???�레?�스 가?�오�?(?�레?�스 ?�브컬렉??
    try {
      final userPlacesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .where('mode', isEqualTo: mode)
          .get();

      // print �� ���ŵ�

      for (var placeDoc in userPlacesSnapshot.docs) {
        final placeData = placeDoc.data();
        final placeId = placeDoc.id;
        final roleName = placeData['roleName'] ?? '직원';
        final workplaceAdd = placeData['workplaceAdd'] ?? '';

        // ?�레?�스 ?�세 ?�보 가?�오�?
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
          print('?�레?�스 추�?: $placeName (??��: $roleName)');
        }
      }
    } catch (e) {
      // print �� ���ŵ�
    }

    // 2. ?�랙???�레?�스 가?�오�?(user_tracks?�서 모드�??�터�?
    try {
      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      // print �� ���ŵ�

      for (var trackDoc in trackSnapshot.docs) {
        final trackData = trackDoc.data();
        final placeId = trackDoc.id;
        final trackMode = trackData['mode'] ?? 'work';

        // ?�재 모드?� ?�치?�는 ?�랙???�레?�스�?추�?
        if (trackMode == mode) {
          // ?��? ?�레?�스 ?�브컬렉?�에 ?�는지 ?�인
          bool alreadyAdded = modeWorkplaces.any((workplace) => workplace.placeId == placeId);
          
          if (!alreadyAdded) {
            // ?�레?�스 ?�세 ?�보 가?�오�?
            final placeDetailDoc = await FirebaseFirestore.instance
                .collection('places')
                .doc(placeId)
                .get();

            if (placeDetailDoc.exists) {
              final placeDetail = placeDetailDoc.data()!;
              final placeName = placeDetail['name'] ?? placeId;

              List<String> data = ['?�래�?, placeName];
              Color groupColor = generateRandomColor();

              modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: placeId));
              // print �� ���ŵ�
            }
          }
        }
      }
    } catch (e) {
      // print �� ���ŵ�
    }

    // 3. 기존 ?�이??구조?�서???�인 (?�위 ?�환??
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
        // print �� ���ŵ�
      }
    }

    if (modeWorkplaces.isEmpty) {
      // 기본 개인 ?�레?�스 ?�공
      if (mode == 'life') {
        modeWorkplaces.add(WorkplaceData(['개인'], Colors.blue.shade300, mode: 'life', placeId: 'personal'));
      } else {
        modeWorkplaces.add(WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work'));
      }
    }

    // print �� ���ŵ�
    workplacesList.add(modeWorkplaces);
    return workplacesList;
  } catch (e) {
    // print �� ���ŵ�
    return [];
  }
}

// Track ?�레?�스 개수 가?�오�?
Future<int> getTrackCount(String mode) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final trackSnapshot = await FirebaseFirestore.instance
        .collection('user_tracks')
        .doc(user.uid)
        .collection('following')
        .get();

    // print �� ���ŵ�
    for (var doc in trackSnapshot.docs) {
      print('Track 문서 ID: ${doc.id}, ?�이?? ${doc.data()}');
    }

    // 모든 Track???�레?�스 개수 반환 (모드 ?�터�??�거)
    return trackSnapshot.docs.length;
  } catch (e) {
    // print �� ���ŵ�
    return 0;
  }
}

// 기본 개인 ?�레?�스 ?�성
Future<void> createDefaultPersonalPlace() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ?��? 개인 ?�레?�스가 ?�는지 ?�인
    final existingPersonalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('places')
        .doc('personal')
        .get();

    if (!existingPersonalDoc.exists) {
      // 개인 ?�레?�스 ?�성
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .doc('personal')
          .set({
        'mode': 'life',
        'roleId': 'personal',
        'roleName': '개인',
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'permissions': ['personal_schedule', 'personal_settings'],
      });

      // places 컬렉?�에??개인 ?�레?�스 ?�성
      await FirebaseFirestore.instance
          .collection('places')
          .doc('personal')
          .set({
        'name': '개인',
        'description': '개인 ?�동 공간',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'originalData': {
          'groupdata1': '개인',
          'groupdata2': '개인',
          'groupdata3': '개인',
        },
      });

      // places/members?�도 추�?
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

      // print �� ���ŵ�
    }
  } catch (e) {
    // print �� ���ŵ�
  }
}
