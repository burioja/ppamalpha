import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class WorkplaceData {
  final List<String> data;
  final Color color;
  final String mode;
  final String placeId;

  WorkplaceData(this.data, this.color, {required this.mode, required this.placeId});
}

class UserStatusWidget extends StatefulWidget {
  final String mode;
  final Function(String) onWorkplaceSelected;

  const UserStatusWidget({
    super.key,
    required this.mode,
    required this.onWorkplaceSelected,
  });

  @override
  State<UserStatusWidget> createState() => _UserStatusWidgetState();
}

class _UserStatusWidgetState extends State<UserStatusWidget> {
  List<List<WorkplaceData>> workplacesList = [];
  int trackCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkplaces();
    _loadTrackCount();
  }

  Future<void> _loadWorkplaces() async {
    try {
      final workplaces = await getWorkplaces(widget.mode);
      setState(() {
        workplacesList = workplaces;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('작업장 로드 오류: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadTrackCount() async {
    try {
      final count = await getTrackCount(widget.mode);
      setState(() {
        trackCount = count;
      });
    } catch (e) {
      debugPrint('트랙 카운트 로드 오류: $e');
    }
  }

  Color generateRandomColor() {
    final random = Random();
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      0.8,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 트랙 카운트 표시
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '트랙: $trackCount개',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Icon(
                widget.mode == 'work' ? Icons.work : Icons.home,
                color: widget.mode == 'work' ? Colors.orange : Colors.blue,
              ),
            ],
          ),
        ),
        
        // 작업장 목록
        Expanded(
          child: ListView.builder(
            itemCount: workplacesList.length,
            itemBuilder: (context, index) {
              final workplaces = workplacesList[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      '그룹 ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ...workplaces.map((workplace) => _buildWorkplaceItem(workplace)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWorkplaceItem(WorkplaceData workplace) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: workplace.color,
          child: Text(
            workplace.data.isNotEmpty ? workplace.data[0][0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          workplace.data.isNotEmpty ? workplace.data[0] : 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          workplace.data.length > 1 ? workplace.data[1] : '',
          style: TextStyle(color: Colors.grey[600]),
        ),
        onTap: () => widget.onWorkplaceSelected(workplace.placeId),
        trailing: Icon(
          widget.mode == 'work' ? Icons.work : Icons.home,
          color: widget.mode == 'work' ? Colors.orange : Colors.blue,
        ),
      ),
    );
  }
}

// 작업장 데이터 가져오기
Future<List<List<WorkplaceData>>> getWorkplaces(String mode) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    List<List<WorkplaceData>> workplacesList = [];
    List<WorkplaceData> modeWorkplaces = [];

    // 1. 사용자 프로필에서 작업장 정보 가져오기
    try {
      DocumentSnapshot userProfileDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();

      if (userProfileDoc.exists) {
        final userData = userProfileDoc.data() as Map<String, dynamic>;
        final places = userData['places'] as List<dynamic>? ?? [];

        for (var place in places) {
          final placeData = place as Map<String, dynamic>;
          final placeMode = placeData['mode'] as String? ?? '';
          final placeId = placeData['placeId'] as String? ?? '';

          if (placeMode == mode) {
            DocumentSnapshot placeDetailDoc = await FirebaseFirestore.instance
                .collection('places')
                .doc(placeId)
                .get();

            if (placeDetailDoc.exists) {
              final placeDetail = placeDetailDoc.data()!;
              final placeDetailData = placeDetail as Map<String, dynamic>;
              final placeName = placeDetailData['name'] ?? placeId;

              List<String> data = ['개인', placeName];
              Color groupColor = generateRandomColor();

              modeWorkplaces.add(WorkplaceData(data, groupColor, mode: mode, placeId: placeId));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('프로필 작업장 로드 오류: $e');
    }

    // 2. 기존 데이터 구조에서 확인 (하위 호환성)
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
        debugPrint('기존 작업장 로드 오류: $e');
      }
    }

    if (modeWorkplaces.isEmpty) {
      // 기본 개인 프로필 제공
      if (mode == 'life') {
        modeWorkplaces.add(WorkplaceData(['개인'], Colors.blue.shade300, mode: 'life', placeId: 'personal'));
      } else {
        modeWorkplaces.add(WorkplaceData(['Customer'], Colors.grey.shade300, mode: 'work', placeId: 'customer'));
      }
    }

    workplacesList.add(modeWorkplaces);
    return workplacesList;
  } catch (e) {
    debugPrint('작업장 로드 오류: $e');
    return [];
  }
}

// Track 프로필 개수 가져오기
Future<int> getTrackCount(String mode) async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final trackSnapshot = await FirebaseFirestore.instance
        .collection('user_tracks')
        .doc(user.uid)
        .collection('following')
        .get();

    debugPrint('트랙 문서 개수: ${trackSnapshot.docs.length}');
    for (var doc in trackSnapshot.docs) {
      debugPrint('Track 문서 ID: ${doc.id}, 데이터: ${doc.data()}');
    }

    // 모든 Track의 프로필 개수 반환 (모드 구분 없이)
    return trackSnapshot.docs.length;
  } catch (e) {
    debugPrint('트랙 카운트 로드 오류: $e');
    return 0;
  }
}

Color generateRandomColor() {
  final random = Random();
  return Color.fromRGBO(
    random.nextInt(256),
    random.nextInt(256),
    random.nextInt(256),
    0.8,
  );
} 