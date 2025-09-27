import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Firebase 초기화
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      projectId: "ppamproto-439623",
      appId: "1:714872165171:web:1b07188ea5236f196e2446",
      storageBucket: "ppamproto-439623.appspot.com",
      apiKey: "AIzaSyC_e2AeyXkjp4VW3-NbVmZG-V7VONNMqvY",
      authDomain: "ppamproto-439623.firebaseapp.com",
      messagingSenderId: "714872165171",
    ),
  );

  final firestore = FirebaseFirestore.instance;

  print('🚀 Firebase 직접 연결 테스트 시작');
  print('프로젝트 ID: ppamproto-439623');

  try {
    // 1. 전체 컬렉션들 확인
    print('\n📊 주요 컬렉션들 확인 중...');

    final collections = ['posts', 'markers', 'post_collections', 'users', 'user_points'];

    for (final collectionName in collections) {
      try {
        print('\n🔍 $collectionName 컬렉션 확인:');
        final snapshot = await firestore.collection(collectionName).limit(5).get();
        print('   문서 개수: ${snapshot.size}개 (최대 5개 확인)');

        if (snapshot.docs.isNotEmpty) {
          print('   첫 번째 문서 ID: ${snapshot.docs.first.id}');
          final data = snapshot.docs.first.data();
          final keys = data.keys.take(5).join(', ');
          print('   필드들: $keys');
        } else {
          print('   ❌ 빈 컬렉션이거나 존재하지 않음');
        }
      } catch (e) {
        print('   ❌ 오류: $e');
      }
    }

    // 2. 특정 포스트 확인
    print('\n🎯 특정 포스트 확인: fsTkJPcxCS2mPyJsIeA7');
    final postDoc = await firestore.collection('posts').doc('fsTkJPcxCS2mPyJsIeA7').get();

    if (postDoc.exists) {
      print('✅ 포스트 발견!');
      final data = postDoc.data()!;
      print('   제목: ${data['title']}');
      print('   생성자: ${data['creatorId']}');
      print('   수량: ${data['quantity']}');
      print('   생성일: ${data['createdAt']}');
    } else {
      print('❌ 포스트를 찾을 수 없음');
    }

    // 3. 해당 포스트를 참조하는 마커들 확인
    print('\n📍 관련 마커들 확인:');
    final markersQuery = await firestore
        .collection('markers')
        .where('postId', isEqualTo: 'fsTkJPcxCS2mPyJsIeA7')
        .get();

    print('   이 포스트를 참조하는 마커: ${markersQuery.docs.length}개');
    for (final markerDoc in markersQuery.docs) {
      final data = markerDoc.data();
      print('   마커 ID: ${markerDoc.id}');
      print('   남은 수량: ${data['remainingQuantity']}');
      print('   총 수량: ${data['totalQuantity']}');
    }

    // 4. 최근 생성된 포스트들 확인
    print('\n📅 최근 포스트들 확인:');
    final recentPosts = await firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();

    print('   최근 포스트 ${recentPosts.docs.length}개:');
    for (final doc in recentPosts.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      print('   - ${doc.id}: ${data['title']} (${createdAt?.toString().substring(0, 19)})');
    }

  } catch (e) {
    print('❌ Firebase 연결 오류: $e');
  }

  print('\n✅ Firebase 직접 연결 테스트 완료');
}