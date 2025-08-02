import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle; // 경로 수정

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // JSON 파일을 읽어 Firebase에 업로드f하는 함수
  Future<void> uploadWorkplaces() async {
    try {
      // JSON 파일 읽기
      final String response = await rootBundle.loadString('assets/workplaces.json');
      final data = json.decode(response)['workplaces'];

      // Firestore의 workplaces 컬렉션에 데이터 추가
      for (var workplace in data) {
        final String id = workplace['id'].toString();
        final docRef = _firestore.collection('workplaces').doc(id);

        // ID가 존재하는지 확인
        final docSnapshot = await docRef.get();
        if (!docSnapshot.exists) {
          await docRef.set(workplace);
          print("워크플레이스 '$id'가 Firebase에 추가되었습니다.");
        } else {
          print("워크플레이스 '$id'는 이미 존재합니다. 건너뜁니다.");
        }
      }

      print("JSON 데이터가 Firebase에 성공적으로 업로드되었습니다.");
    } catch (e) {
      print("업로드 중 오류 발생: $e");
    }
  }
}

