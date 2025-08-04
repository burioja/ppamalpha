import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle; // 경로 ?�정

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // JSON ?�일???�어 Firebase???�로?�f?�는 ?�수
  Future<void> uploadWorkplaces() async {
    try {
      // JSON ?�일 ?�기
      final String response = await rootBundle.loadString('assets/workplaces.json');
      final data = json.decode(response)['workplaces'];

      // Firestore??workplaces 컬렉?�에 ?�이??추�?
      for (var workplace in data) {
        final String id = workplace['id'].toString();
        final docRef = _firestore.collection('workplaces').doc(id);

        // ID가 존재?�는지 ?�인
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set(workplace);
          // ?�크?�레?�스 '$id'가 Firebase??추�??�었?�니??
        } else {
          // ?�크?�레?�스 '$id'???��? 존재?�니?? 건너?�니??
        }
      }

      // JSON ?�이?��? Firebase???�공?�으�??�로?�되?�습?�다.
    } catch (e) {
      // ?�로??�??�류 발생: $e
    }
  }
}

