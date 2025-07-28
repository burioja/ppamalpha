import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class TrackConnectionScreen extends StatefulWidget {
  final String type; // 'track' 또는 'connection'
  
  const TrackConnectionScreen({
    super.key,
    required this.type,
  });

  @override
  State<TrackConnectionScreen> createState() => _TrackConnectionScreenState();
}

class _TrackConnectionScreenState extends State<TrackConnectionScreen> {
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'track' ? '팔로잉하는 워크플레이스' : '팔로워';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (widget.type == 'track')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  // 데이터 새로고침
                });
              },
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getUserList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('오류가 발생했습니다: ${snapshot.error}'),
                ],
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.type == 'track' ? Icons.track_changes : Icons.people,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.type == 'track' 
                        ? 'Track한 플레이스가 없습니다.' 
                        : 'Connection이 없습니다.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getCrossAxisCount(context),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5, // 가로:세로 비율 조정
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index];
              return _buildUserCard(userData);
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUserList() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('사용자 ID가 null입니다.');
      return [];
    }

    print('Track/Connection 데이터 로드 시작 - 사용자 ID: $currentUserId');

    try {
      if (widget.type == 'track') {
        // 사용자가 Track한 플레이스 목록 가져오기
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        print('Track 데이터 로드 - 문서 개수: ${followingSnapshot.docs.length}');
        
        final List<Map<String, dynamic>> workplaces = [];
        for (final doc in followingSnapshot.docs) {
          final workplaceData = doc.data();
          final workplaceId = doc.id;
          final trackMode = workplaceData['mode'] ?? 'work'; // 트랙 모드 가져오기
          
          print('Track 플레이스 ID: $workplaceId, 모드: $trackMode, 데이터: $workplaceData');
          
          // 플레이스 상세 정보 가져오기
          try {
            final workplaceDoc = await _firestore
                .collection('places')
                .doc(workplaceId)
                .get();
            
            if (workplaceDoc.exists) {
              final workplaceInfo = workplaceDoc.data()!;
              print('플레이스 정보 찾음: ${workplaceInfo['name']}');
              workplaces.add({
                'workplaceId': workplaceId,
                'nickname': workplaceInfo['name'] ?? '플레이스',
                'authority': 'workplace', // 워크플레이스 표시
                'profileImageUrl': workplaceInfo['profileImageUrl'] ?? '',
                'trackMode': trackMode, // 트랙 모드 추가
              });
            } else {
              print('플레이스 정보 없음: $workplaceId');
            }
          } catch (e) {
            print('플레이스 정보 가져오기 실패: $e');
          }
        }
        
        print('최종 Track 플레이스 개수: ${workplaces.length}');
        return workplaces;
      } else {
        // Connection: 내가 트랙하고 있는 플레이스의 다른 사용자들 목록
        final List<Map<String, dynamic>> connections = [];
        
        // 1. 내가 트랙하고 있는 플레이스 목록 가져오기
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        print('내가 트랙하는 플레이스 개수: ${followingSnapshot.docs.length}');
        
        for (final followingDoc in followingSnapshot.docs) {
          final placeId = followingDoc.id;
          
          // 2. 이 플레이스에 속한 다른 사용자들 가져오기
          final membersSnapshot = await _firestore
              .collection('places')
              .doc(placeId)
              .collection('members')
              .get();
          
          print('플레이스 $placeId의 멤버 수: ${membersSnapshot.docs.length}');
          
          for (final memberDoc in membersSnapshot.docs) {
            final memberUserId = memberDoc.id;
            
            // 내가 아닌 사용자만 추가
            if (memberUserId != currentUserId) {
              // 사용자 상세 정보 가져오기
              try {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(memberUserId)
                    .get();
                
                if (userDoc.exists) {
                  final userData = userDoc.data()!;
                  
                  // 새로운 구조에서 닉네임 가져오기
                  String nickname = '닉네임';
                  if (userData['profile'] != null && 
                      userData['profile']['info'] != null) {
                    nickname = userData['profile']['info']['nickname'] ?? '닉네임';
                  } else {
                    nickname = userData['nickname'] ?? '닉네임';
                  }
                  
                  // 사용자의 역할 정보 가져오기
                  String authority = '직원';
                  try {
                    final memberData = memberDoc.data();
                    authority = memberData['roleId'] ?? '직원';
                  } catch (e) {
                    print('멤버 역할 정보 가져오기 실패: $e');
                  }
                  
                  // 플레이스 정보도 가져오기
                  String placeName = '플레이스';
                  try {
                    final placeDoc = await _firestore
                        .collection('places')
                        .doc(placeId)
                        .get();
                    
                    if (placeDoc.exists) {
                      final placeData = placeDoc.data()!;
                      placeName = placeData['name'] ?? placeId;
                    }
                  } catch (e) {
                    print('플레이스 정보 가져오기 실패: $e');
                  }
                  
                  connections.add({
                    'userId': memberUserId,
                    'nickname': nickname,
                    'authority': authority,
                    'profileImageUrl': userData['profileImageUrl'] ?? '',
                    'placeName': placeName,
                    'placeId': placeId,
                  });
                }
              } catch (e) {
                print('사용자 정보 가져오기 실패: $e');
              }
            }
          }
        }
        
        // 중복 제거 (같은 사용자가 여러 플레이스에 속할 수 있음)
        final uniqueConnections = <String, Map<String, dynamic>>{};
        for (final connection in connections) {
          final userId = connection['userId'];
          if (!uniqueConnections.containsKey(userId)) {
            uniqueConnections[userId] = connection;
          }
        }
        
        print('최종 커넥션 개수: ${uniqueConnections.length}');
        return uniqueConnections.values.toList();
      }
    } catch (e) {
      print('사용자 목록 가져오기 실패: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getUserDetails(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    final List<Map<String, dynamic>> userDetails = [];
    
    for (final userId in userIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          
          // 새로운 구조에서 닉네임 가져오기
          String nickname = '닉네임';
          if (userData['profile'] != null && 
              userData['profile']['info'] != null) {
            nickname = userData['profile']['info']['nickname'] ?? '닉네임';
          } else {
            nickname = userData['nickname'] ?? '닉네임';
          }
          
          // 사용자의 역할 정보 가져오기 (기본값: 직원)
          String authority = '직원';
          try {
            final userPlacesSnapshot = await _firestore
                .collection('users')
                .doc(userId)
                .collection('places')
                .limit(1)
                .get();
            
            if (userPlacesSnapshot.docs.isNotEmpty) {
              final userPlaceData = userPlacesSnapshot.docs.first.data();
              authority = userPlaceData['roleName'] ?? '직원';
            }
          } catch (e) {
            print('사용자 역할 정보 가져오기 실패: $e');
          }
          
          userDetails.add({
            'userId': userId,
            'nickname': nickname,
            'authority': authority,
            'profileImageUrl': userData['profileImageUrl'] ?? '',
          });
        }
      } catch (e) {
        print('사용자 정보 가져오기 실패: $e');
      }
    }
    
    return userDetails;
  }

  // 화면 크기에 따른 열 수 결정
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 모바일 기준 너비 (약 400px)
    if (screenWidth < 600) {
      return 2; // 모바일: 2열
    } else if (screenWidth < 900) {
      return 3; // 태블릿: 3열
    } else {
      return 4; // 데스크톱: 4열
    }
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final userId = userData['userId'] ?? '';
    final nickname = userData['nickname'] ?? '닉네임';
    final authority = userData['authority'] ?? 'Authority';
    final profileImageUrl = userData['profileImageUrl'] ?? '';
    final trackMode = userData['trackMode'] ?? 'work'; // 트랙 모드 가져오기
    final placeName = userData['placeName'] ?? ''; // 플레이스 이름

    // 권한 레벨에 따른 색상과 텍스트 설정
    Color authorityColor;
    String authorityText;
    
    if (widget.type == 'track') {
      // Track의 경우 모드만 표시
      authorityColor = trackMode == 'work' ? Colors.blue : Colors.green;
      authorityText = trackMode == 'work' ? '워크' : '라이프';
    } else {
      // Connection의 경우 사용자 역할 표시
      switch (authority.toLowerCase()) {
        case 'owner':
        case '소유자':
        case '사장':
        case '대표':
        case '캡틴':
          authorityColor = Colors.red.shade700;
          authorityText = '소유자';
          break;
        case 'manager':
        case '관리자':
        case '매니저':
        case '보조캡틴':
          authorityColor = Colors.orange.shade700;
          authorityText = '관리자';
          break;
        case 'employee':
        case '직원':
        case '스태프':
          authorityColor = Colors.blue.shade700;
          authorityText = '직원';
          break;
        case 'customer':
        case '고객':
        case '손님':
        case '회원':
          authorityColor = Colors.green.shade700;
          authorityText = '고객';
          break;
        default:
          authorityColor = Colors.grey.shade700;
          authorityText = authority;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // 왼쪽: 프로필 이미지
            CircleAvatar(
              radius: 20,
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
            
            // 오른쪽: 닉네임과 권한
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 상단: 닉네임
                  Text(
                    nickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  
                  // 중간: 플레이스 이름 (커넥션인 경우만)
                  if (widget.type == 'connection' && placeName.isNotEmpty) ...[
                    Text(
                      placeName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                  ],
                  
                  // 하단: Authority 또는 모드 정보
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: authorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: authorityColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.type == 'track') ...[
                          // 트랙의 경우 모드 아이콘과 텍스트
                          Icon(
                            trackMode == 'work' ? Icons.work : Icons.home,
                            size: 10,
                            color: authorityColor,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          authorityText,
                          style: TextStyle(
                            color: authorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 