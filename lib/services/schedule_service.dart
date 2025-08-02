import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 사용자 ID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 안전한 bool 변환 함수
  bool safeBool(dynamic value) {
    print('=== safeBool 디버깅 ===');
    print('입력값: $value (${value.runtimeType})');
    
    if (value is bool) {
      print('bool 타입으로 처리: $value');
      return value;
    }
    if (value is String) {
      final result = value.toLowerCase() == 'true';
      print('String에서 변환: "$value" -> $result');
      return result;
    }
    if (value == null) {
      print('null 값으로 처리: false');
      return false;
    }
    print('기타 타입으로 처리: false');
    return false;
  }

  // 스케줄 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _schedulesCollection {
    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('schedules');
  }

  // 특정 날짜의 스케줄 가져오기 (단순화된 쿼리)
  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByDate(String date) {
    print('=== ScheduleService.getSchedulesByDate 디버깅 ===');
    print('요청 날짜: $date');
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .snapshots()
        .map((snapshot) {
          print('Firebase에서 가져온 문서 수: ${snapshot.docs.length}');
          snapshot.docs.forEach((doc) {
            final data = doc.data();
            print('문서 ID: ${doc.id}');
            print('전체 데이터: $data');
            print('isCompleted: ${data['isCompleted']} (${data['isCompleted'].runtimeType})');
            print('title: ${data['title']} (${data['title'].runtimeType})');
            print('time: ${data['time']} (${data['time'].runtimeType})');
            print('---');
          });
          return snapshot;
        });
  }

  // 오늘의 스케줄 가져오기
  Stream<QuerySnapshot<Map<String, dynamic>>> getTodaySchedules() {
    print('=== ScheduleService.getTodaySchedules 디버깅 ===');
    final today = DateTime.now();
    final dateString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    print('오늘 날짜: $dateString');
    return getSchedulesByDate(dateString);
  }

  // 특정 기간의 스케줄 가져오기 (단순화)
  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByDateRange(String startDate, String endDate) {
    return _schedulesCollection
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThanOrEqualTo: endDate)
        .snapshots();
  }

  // 완료된 스케줄 가져오기 (단순화)
  Stream<QuerySnapshot<Map<String, dynamic>>> getCompletedSchedules(String date) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('isCompleted', isEqualTo: true)
        .snapshots();
  }

  // 미완료 스케줄 가져오기 (단순화)
  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingSchedules(String date) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('isCompleted', isEqualTo: false)
        .snapshots();
  }

  // 개인용 스케줄 가져오기
  Stream<QuerySnapshot<Map<String, dynamic>>> getPersonalSchedules(String date) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('shareScope', isEqualTo: 'personal')
        .snapshots();
  }

  // 팀 공유 스케줄 가져오기
  Stream<QuerySnapshot<Map<String, dynamic>>> getTeamSchedules(String date) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('shareScope', isEqualTo: 'team')
        .snapshots();
  }

  // 공개 스케줄 가져오기
  Stream<QuerySnapshot<Map<String, dynamic>>> getPublicSchedules(String date) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('shareScope', isEqualTo: 'public')
        .snapshots();
  }

  // 공유범위별 스케줄 가져오기
  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedulesByShareScope(String date, String shareScope) {
    return _schedulesCollection
        .where('date', isEqualTo: date)
        .where('shareScope', isEqualTo: shareScope)
        .snapshots();
  }

  // 스케줄 추가
  Future<void> addSchedule({
    required String title,
    required String date,
    required String time,
    String? description,
    int? duration,
    String? location,
    String? category,
    String? priority,
    String? shareScope,
  }) async {
    if (currentUserId == null) throw Exception('사용자가 로그인되지 않았습니다.');

    await _schedulesCollection.add({
      'title': title,
      'date': date,
      'time': time,
      'description': description ?? '',
      'duration': duration ?? 60,
      'location': location ?? '',
      'category': category ?? 'personal',
      'priority': priority ?? 'medium',
      'shareScope': shareScope ?? 'personal', // 개인용, 팀 공유, 공개
      'isCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 스케줄 수정
  Future<void> updateSchedule({
    required String scheduleId,
    String? title,
    String? date,
    String? time,
    String? description,
    int? duration,
    String? location,
    String? category,
    String? priority,
    bool? isCompleted,
    String? shareScope,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 디버깅을 위한 데이터 출력
      print('ScheduleService - 업데이트할 필드들:');
      print('title: $title (${title.runtimeType})');
      print('time: $time (${time.runtimeType})');
      print('description: $description (${description.runtimeType})');
      print('duration: $duration (${duration.runtimeType})');
      print('location: $location (${location.runtimeType})');
      print('category: $category (${category.runtimeType})');
      print('priority: $priority (${priority.runtimeType})');
      print('isCompleted: $isCompleted (${isCompleted.runtimeType})');

      // 각 필드를 안전하게 추가
      if (title != null && title.isNotEmpty) {
        updates['title'] = title.toString();
      }
      if (date != null && date.isNotEmpty) {
        updates['date'] = date.toString();
      }
      if (time != null && time.isNotEmpty) {
        updates['time'] = time.toString();
      }
      if (description != null) {
        updates['description'] = description.toString();
      }
      if (duration != null) {
        updates['duration'] = duration;
      }
      if (location != null) {
        updates['location'] = location.toString();
      }
      if (category != null && category.isNotEmpty) {
        updates['category'] = category.toString();
      }
      if (priority != null && priority.isNotEmpty) {
        updates['priority'] = priority.toString();
      }
      
      // shareScope 필드 추가
      if (shareScope != null && shareScope.isNotEmpty) {
        updates['shareScope'] = shareScope.toString();
      }
      
      // isCompleted는 bool 타입이므로 명시적으로 처리
      if (isCompleted != null) {
        // bool 타입 확인 및 변환
        if (isCompleted is bool) {
          updates['isCompleted'] = isCompleted;
        } else {
          // 다른 타입인 경우 기본값 사용
          updates['isCompleted'] = false;
        }
        print('isCompleted 최종 값: ${updates['isCompleted']} (${updates['isCompleted'].runtimeType})');
      }

      print('최종 업데이트 데이터: $updates');

      // 각 필드의 타입을 다시 확인
      print('업데이트 데이터 타입 확인:');
      updates.forEach((key, value) {
        print('$key: $value (${value.runtimeType})');
      });

      // Firebase 업데이트 시도
      try {
        await _schedulesCollection.doc(scheduleId).update(updates);
        print('Firebase 업데이트 성공');
      } catch (firebaseError) {
        print('Firebase 업데이트 오류: $firebaseError');
        
        // 기존 문서를 먼저 가져와서 타입 확인
        final docSnapshot = await _schedulesCollection.doc(scheduleId).get();
        if (docSnapshot.exists) {
          final existingData = docSnapshot.data()!;
          print('기존 데이터: $existingData');
          print('기존 isCompleted 타입: ${existingData['isCompleted'].runtimeType}');
          
          // 기존 데이터와 새 데이터를 병합하여 업데이트
          final mergedData = Map<String, dynamic>.from(existingData);
          updates.forEach((key, value) {
            if (key != 'updatedAt') { // updatedAt은 제외
              mergedData[key] = value;
            }
          });
          mergedData['updatedAt'] = FieldValue.serverTimestamp();
          
          print('병합된 데이터: $mergedData');
          await _schedulesCollection.doc(scheduleId).set(mergedData, SetOptions(merge: true));
          print('병합 업데이트 성공');
        }
      }
    } catch (e) {
      print('ScheduleService - 업데이트 오류: $e');
      print('오류 스택 트레이스:');
      print(e.toString());
      rethrow;
    }
  }

  // 스케줄 삭제
  Future<void> deleteSchedule(String scheduleId) async {
    await _schedulesCollection.doc(scheduleId).delete();
  }

  // 스케줄 완료 상태 토글
  Future<void> toggleScheduleCompletion(String scheduleId, bool isCompleted) async {
    await _schedulesCollection.doc(scheduleId).update({
      'isCompleted': isCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 스케줄 통계 가져오기
  Future<Map<String, dynamic>> getScheduleStats(String date) async {
    final snapshot = await _schedulesCollection
        .where('date', isEqualTo: date)
        .get();

    final total = snapshot.docs.length;
    final completed = snapshot.docs.where((doc) => doc.data()['isCompleted'] == true).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
    };
  }
} 