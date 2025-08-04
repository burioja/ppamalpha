import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class TrackConnectionScreen extends StatefulWidget {
  final String type; // 'track' ?�는 'connection'
  
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
    final title = widget.type == 'track' ? '?�로?�하???�크?�레?�스' : '?�로??;
    
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
                  // ?�이???�로고침
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
                  Text('?�류가 발생?�습?�다: ${snapshot.error}'),
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
                        ? 'Track???�레?�스가 ?�습?�다.' 
                        : 'Connection???�습?�다.',
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
              childAspectRatio: 2.5, // 가�??�로 비율 조정
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
      // print �� ���ŵ�
      return [];
    }

    // print �� ���ŵ�

    try {
      if (widget.type == 'track') {
        // ?�용?��? Track???�레?�스 목록 가?�오�?
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        // print �� ���ŵ�
        
        final List<Map<String, dynamic>> workplaces = [];
        for (final doc in followingSnapshot.docs) {
          final workplaceData = doc.data();
          final workplaceId = doc.id;
          final trackMode = workplaceData['mode'] ?? 'work'; // ?�랙 모드 가?�오�?
          
          // print �� ���ŵ�
          
          // ?�레?�스 ?�세 ?�보 가?�오�?
          try {
            final workplaceDoc = await _firestore
                .collection('places')
                .doc(workplaceId)
                .get();
            
            if (workplaceDoc.exists) {
              final workplaceInfo = workplaceDoc.data()!;
              // print �� ���ŵ�
              workplaces.add({
                'workplaceId': workplaceId,
                'nickname': workplaceInfo['name'] ?? '?�레?�스',
                'authority': 'workplace', // ?�크?�레?�스 ?�시
                'profileImageUrl': workplaceInfo['profileImageUrl'] ?? '',
                'trackMode': trackMode, // ?�랙 모드 추�?
              });
            } else {
              // print �� ���ŵ�
            }
          } catch (e) {
            // print �� ���ŵ�
          }
        }
        
        // print �� ���ŵ�
        return workplaces;
      } else {
        // Connection: ?��? ?�랙?�고 ?�는 ?�레?�스???�른 ?�용?�들 목록
        final List<Map<String, dynamic>> connections = [];
        
        // 1. ?��? ?�랙?�고 ?�는 ?�레?�스 목록 가?�오�?
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        // print �� ���ŵ�
        
        for (final followingDoc in followingSnapshot.docs) {
          final placeId = followingDoc.id;
          
          // 2. ???�레?�스???�한 ?�른 ?�용?�들 가?�오�?
          final membersSnapshot = await _firestore
              .collection('places')
              .doc(placeId)
              .collection('members')
              .get();
          
          // print �� ���ŵ�
          
          for (final memberDoc in membersSnapshot.docs) {
            final memberUserId = memberDoc.id;
            
            // ?��? ?�닌 ?�용?�만 추�?
            if (memberUserId != currentUserId) {
              // ?�용???�세 ?�보 가?�오�?
              try {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(memberUserId)
                    .get();
                
                if (userDoc.exists) {
                  final userData = userDoc.data()!;
                  
                  // ?�로??구조?�서 ?�네??가?�오�?
                  String nickname = '?�네??;
                  if (userData['profile'] != null && 
                      userData['profile']['info'] != null) {
                    nickname = userData['profile']['info']['nickname'] ?? '?�네??;
                  } else {
                    nickname = userData['nickname'] ?? '?�네??;
                  }
                  
                  // ?�용?�의 ??�� ?�보 가?�오�?
                  String authority = '직원';
                  try {
                    final memberData = memberDoc.data();
                    authority = memberData['roleId'] ?? '직원';
                  } catch (e) {
                    // print �� ���ŵ�
                  }
                  
                  // ?�레?�스 ?�보??가?�오�?
                  String placeName = '?�레?�스';
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
                    // print �� ���ŵ�
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
                // print �� ���ŵ�
              }
            }
          }
        }
        
        // 중복 ?�거 (같�? ?�용?��? ?�러 ?�레?�스???�할 ???�음)
        final uniqueConnections = <String, Map<String, dynamic>>{};
        for (final connection in connections) {
          final userId = connection['userId'];
          if (!uniqueConnections.containsKey(userId)) {
            uniqueConnections[userId] = connection;
          }
        }
        
        // print �� ���ŵ�
        return uniqueConnections.values.toList();
      }
    } catch (e) {
      // print �� ���ŵ�
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
          
          // ?�로??구조?�서 ?�네??가?�오�?
          String nickname = '?�네??;
          if (userData['profile'] != null && 
              userData['profile']['info'] != null) {
            nickname = userData['profile']['info']['nickname'] ?? '?�네??;
          } else {
            nickname = userData['nickname'] ?? '?�네??;
          }
          
          // ?�용?�의 ??�� ?�보 가?�오�?(기본�? 직원)
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
            // print �� ���ŵ�
          }
          
          userDetails.add({
            'userId': userId,
            'nickname': nickname,
            'authority': authority,
            'profileImageUrl': userData['profileImageUrl'] ?? '',
          });
        }
      } catch (e) {
        // print �� ���ŵ�
      }
    }
    
    return userDetails;
  }

  // ?�면 ?�기???�른 ????결정
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 모바??기�? ?�비 (??400px)
    if (screenWidth < 600) {
      return 2; // 모바?? 2??
    } else if (screenWidth < 900) {
      return 3; // ?�블�? 3??
    } else {
      return 4; // ?�스?�톱: 4??
    }
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final userId = userData['userId'] ?? '';
    final nickname = userData['nickname'] ?? '?�네??;
    final authority = userData['authority'] ?? 'Authority';
    final profileImageUrl = userData['profileImageUrl'] ?? '';
    final trackMode = userData['trackMode'] ?? 'work'; // ?�랙 모드 가?�오�?
    final placeName = userData['placeName'] ?? ''; // ?�레?�스 ?�름

    // 권한 ?�벨???�른 ?�상�??�스???�정
    Color authorityColor;
    String authorityText;
    
    if (widget.type == 'track') {
      // Track??경우 모드�??�시
      authorityColor = trackMode == 'work' ? Colors.blue : Colors.green;
      authorityText = trackMode == 'work' ? '?�크' : '?�이??;
    } else {
      // Connection??경우 ?�용????�� ?�시
      switch (authority.toLowerCase()) {
        case 'owner':
        case '?�유??:
        case '?�장':
        case '?�??:
        case '캡틴':
          authorityColor = Colors.red.shade700;
          authorityText = '?�유??;
          break;
        case 'manager':
        case '관리자':
        case '매니?�':
        case '보조캡틴':
          authorityColor = Colors.orange.shade700;
          authorityText = '관리자';
          break;
        case 'employee':
        case '직원':
        case '?�태??:
          authorityColor = Colors.blue.shade700;
          authorityText = '직원';
          break;
        case 'customer':
        case '고객':
        case '?�님':
        case '?�원':
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
            // ?�쪽: ?�로???��?지
            CircleAvatar(
              radius: 20,
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
            
            // ?�른�? ?�네?�과 권한
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ?�단: ?�네??
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
                  
                  // 중간: ?�레?�스 ?�름 (커넥?�인 경우�?
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
                  
                  // ?�단: Authority ?�는 모드 ?�보
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
                          // ?�랙??경우 모드 ?�이콘과 ?�스??
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
