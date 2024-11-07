// lib/widgets/user_status_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class WorkplaceData {
  final List<String> data; // {groupdata1, groupdata2, groupdata3, workplaceinput + workplaceadd}
  final Color color;       // 그룹별 고정 색상

  WorkplaceData(this.data, this.color);
}

Future<List<List<WorkplaceData>>> fetchUserWorkplaces() async {
  List<List<WorkplaceData>> workplacesList = [];
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300)]);
      return workplacesList;
    }

    QuerySnapshot userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: user.email)
        .get();

    if (userQuery.docs.isEmpty) {
      workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300)]);
      return workplacesList;
    }

    DocumentSnapshot userDoc = userQuery.docs.first;
    List<dynamic>? workPlaces = userDoc['workPlaces'] as List<dynamic>?;

    if (workPlaces == null || workPlaces.isEmpty) {
      workplacesList.add([WorkplaceData(['Customer'], Colors.grey.shade300)]);
      return workplacesList;
    }

    Color generateRandomColor() {
      Random random = Random();
      return Color.fromARGB(
        255,
        50 + random.nextInt(206), // 밝은 색상 범위에서 랜덤 색상 생성
        50 + random.nextInt(206),
        50 + random.nextInt(206),
      );
    }

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

        // 각 그룹을 List에 추가
        workplacesList.add([WorkplaceData(data, groupColor)]);
      }
    }
    return workplacesList;
  } catch (e) {
    return [[WorkplaceData(['데이터 로드 오류: $e'], Colors.red)]];
  }
}
