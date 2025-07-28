// lib/widgets/user_status_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class WorkplaceData {
  final List<String> data; // {groupdata1, groupdata2, groupdata3, workplaceinput + workplaceadd}
  final Color color;       // 그룹별 고정 색상
  final String mode;       // work 또는 life
  final String placeId;    // 플레이스 ID

  WorkplaceData(this.data, this.color, {this.mode = 'work', this.placeId = ''});
}

// 랜덤 색상 생성 함수
Color generateRandomColor() {
  Random random = Random();
  return Color.fromARGB(
    255,
    50 + random.nextInt(206),
    50 + random.nextInt(206),
    50 + random.nextInt(206),
  );
}

// 모드별 플레이스 가져오기
Future<List<List<WorkplaceData>>> fetchUserWorkplacesByMode(String mode) async {
  List<List<WorkplaceData>> workplacesList = [];
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // 기본 개인 플레이스 제공
      if (mode == 'life') {
        workplacesList.add([WorkplaceData(['개인'], Colors.blue.shade300, mode: 'life', placeId: 'personal')]);
      } else {
        workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work')]);
      }
      return workplacesList;
    }

    // 기존 데이터 구조와 새로운 구조 모두 확인
    List<WorkplaceData> modeWorkplaces = [];

    // 1. 새로운 PRD 구조에서 사용자 플레이스 가져오기 (플레이스 서브컬렉션)
    try {
      final userPlacesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('places')
          .where('mode', isEqualTo: mode)
          .get();

      print('사용자 플레이스 서브컬렉션에서 ${userPlacesSnapshot.docs.length}개 플레이스 발견');

      for (var placeDoc in userPlacesSnapshot.docs) {
        final placeData = placeDoc.data();
        final placeId = placeDoc.id;
        final roleName = placeData['roleName'] ?? '직원';
        final workplaceAdd = placeData['workplaceAdd'] ?? '';

        // 플레이스 상세 정보 가져오기
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
          print('플레이스 추가: $placeName (역할: $roleName)');
        }
      }
    } catch (e) {
      print('새로운 구조에서 플레이스 로드 실패: $e');
    }

    // 2. 트랙된 플레이스 가져오기 (user_tracks에서 모드별 필터링)
    try {
      final trackSnapshot = await FirebaseFirestore.instance
          .collection('user_tracks')
          .doc(user.uid)
          .collection('following')
          .get();

      print('user_tracks에서 ${trackSnapshot.docs.length}개 트랙 발견');

      for (var trackDoc in trackSnapshot.docs) {
        final trackData = trackDoc.data();
        final placeId = trackDoc.id;
        final trackMode = trackData['mode'] ?? 'work';

        // 현재 모드와 일치하는 트랙된 플레이스만 추가
        if (trackMode == mode) {
          // 이미 플레이스 서브컬렉션에 있는지 확인
          bool alreadyAdded = modeWorkplaces.any((workplace) => workplace.placeId == placeId);
          
          if (!alreadyAdded) {
            // 플레이스 상세 정보 가져오기
            final placeDetailDoc = await FirebaseFirestore.instance
                .collection('places')
                .doc(placeId)
                .get();

            if (placeDetailDoc.exists) {
              final placeDetail = placeDetailDoc.data()!;
              final placeName = placeDetail['name'] ?? placeId;

              List<String> data = ['트래커', placeName];
              Color groupColor = generateRandomColor();

              modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: placeId));
              print('트랙된 플레이스 추가: $placeName');
            }
          }
        }
      }
    } catch (e) {
      print('트랙된 플레이스 로드 실패: $e');
    }

    // 3. 기존 데이터 구조에서도 확인 (하위 호환성)
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
        print('기존 구조에서 플레이스 로드 실패: $e');
      }
    }

    if (modeWorkplaces.isEmpty) {
      // 기본 개인 플레이스 제공
      if (mode == 'life') {
        modeWorkplaces.add(WorkplaceData(['개인'], Colors.blue.shade300, mode: 'life', placeId: 'personal'));
      } else {
        modeWorkplaces.add(WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work'));
      }
    }

    print('최종 플레이스 개수: ${modeWorkplaces.length}');
    workplacesList.add(modeWorkplaces);
    return workplacesList;
  } catch (e) {
    print('플레이스 로드 오류: $e');
    return [];
  }
}

// Track 플레이스 개수 가져오기
Future<int> getTrackCount(String mode) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final trackSnapshot = await FirebaseFirestore.instance
        .collection('user_tracks')
        .doc(user.uid)
        .collection('following')
        .get();

    print('Track 개수 계산 - 문서 개수: ${trackSnapshot.docs.length}');
    for (var doc in trackSnapshot.docs) {
      print('Track 문서 ID: ${doc.id}, 데이터: ${doc.data()}');
    }

    // 모든 Track한 플레이스 개수 반환 (모드 필터링 제거)
    return trackSnapshot.docs.length;
  } catch (e) {
    print('Track 개수 로드 오류: $e');
    return 0;
  }
}

// 기본 개인 플레이스 생성
Future<void> createDefaultPersonalPlace() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 이미 개인 플레이스가 있는지 확인
    final existingPersonalDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('places')
        .doc('personal')
        .get();

    if (!existingPersonalDoc.exists) {
      // 개인 플레이스 생성
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

      // places 컬렉션에도 개인 플레이스 생성
      await FirebaseFirestore.instance
          .collection('places')
          .doc('personal')
          .set({
        'name': '개인',
        'description': '개인 활동 공간',
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'originalData': {
          'groupdata1': '개인',
          'groupdata2': '개인',
          'groupdata3': '개인',
        },
      });

      // places/members에도 추가
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

      print('기본 개인 플레이스가 생성되었습니다.');
    }
  } catch (e) {
    print('기본 개인 플레이스 생성 오류: $e');
  }
}