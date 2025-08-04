import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';

class TrackConnectionScreen extends StatefulWidget {
  final String type; // 'track' ?êÎäî 'connection'
  
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
    final title = widget.type == 'track' ? '?îÎ°ú?âÌïò???åÌÅ¨?åÎ†à?¥Ïä§' : '?îÎ°ú??;
    
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
                  // ?∞Ïù¥???àÎ°úÍ≥†Ïπ®
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
                  Text('?§Î•òÍ∞Ä Î∞úÏÉù?àÏäµ?àÎã§: ${snapshot.error}'),
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
                        ? 'Track???åÎ†à?¥Ïä§Í∞Ä ?ÜÏäµ?àÎã§.' 
                        : 'Connection???ÜÏäµ?àÎã§.',
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
              childAspectRatio: 2.5, // Í∞ÄÎ°??∏Î°ú ÎπÑÏú® Ï°∞Ï†ï
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
      // print πÆ ¡¶∞≈µ 
      return [];
    }

    // print πÆ ¡¶∞≈µ 

    try {
      if (widget.type == 'track') {
        // ?¨Ïö©?êÍ? Track???åÎ†à?¥Ïä§ Î™©Î°ù Í∞Ä?∏Ïò§Í∏?
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        // print πÆ ¡¶∞≈µ 
        
        final List<Map<String, dynamic>> workplaces = [];
        for (final doc in followingSnapshot.docs) {
          final workplaceData = doc.data();
          final workplaceId = doc.id;
          final trackMode = workplaceData['mode'] ?? 'work'; // ?∏Îûô Î™®Îìú Í∞Ä?∏Ïò§Í∏?
          
          // print πÆ ¡¶∞≈µ 
          
          // ?åÎ†à?¥Ïä§ ?ÅÏÑ∏ ?ïÎ≥¥ Í∞Ä?∏Ïò§Í∏?
          try {
            final workplaceDoc = await _firestore
                .collection('places')
                .doc(workplaceId)
                .get();
            
            if (workplaceDoc.exists) {
              final workplaceInfo = workplaceDoc.data()!;
              // print πÆ ¡¶∞≈µ 
              workplaces.add({
                'workplaceId': workplaceId,
                'nickname': workplaceInfo['name'] ?? '?åÎ†à?¥Ïä§',
                'authority': 'workplace', // ?åÌÅ¨?åÎ†à?¥Ïä§ ?úÏãú
                'profileImageUrl': workplaceInfo['profileImageUrl'] ?? '',
                'trackMode': trackMode, // ?∏Îûô Î™®Îìú Ï∂îÍ?
              });
            } else {
              // print πÆ ¡¶∞≈µ 
            }
          } catch (e) {
            // print πÆ ¡¶∞≈µ 
          }
        }
        
        // print πÆ ¡¶∞≈µ 
        return workplaces;
      } else {
        // Connection: ?¥Í? ?∏Îûô?òÍ≥† ?àÎäî ?åÎ†à?¥Ïä§???§Î•∏ ?¨Ïö©?êÎì§ Î™©Î°ù
        final List<Map<String, dynamic>> connections = [];
        
        // 1. ?¥Í? ?∏Îûô?òÍ≥† ?àÎäî ?åÎ†à?¥Ïä§ Î™©Î°ù Í∞Ä?∏Ïò§Í∏?
        final followingSnapshot = await _firestore
            .collection('user_tracks')
            .doc(currentUserId)
            .collection('following')
            .get();
        
        // print πÆ ¡¶∞≈µ 
        
        for (final followingDoc in followingSnapshot.docs) {
          final placeId = followingDoc.id;
          
          // 2. ???åÎ†à?¥Ïä§???çÌïú ?§Î•∏ ?¨Ïö©?êÎì§ Í∞Ä?∏Ïò§Í∏?
          final membersSnapshot = await _firestore
              .collection('places')
              .doc(placeId)
              .collection('members')
              .get();
          
          // print πÆ ¡¶∞≈µ 
          
          for (final memberDoc in membersSnapshot.docs) {
            final memberUserId = memberDoc.id;
            
            // ?¥Í? ?ÑÎãå ?¨Ïö©?êÎßå Ï∂îÍ?
            if (memberUserId != currentUserId) {
              // ?¨Ïö©???ÅÏÑ∏ ?ïÎ≥¥ Í∞Ä?∏Ïò§Í∏?
              try {
                final userDoc = await _firestore
                    .collection('users')
                    .doc(memberUserId)
                    .get();
                
                if (userDoc.exists) {
                  final userData = userDoc.data()!;
                  
                  // ?àÎ°ú??Íµ¨Ï°∞?êÏÑú ?âÎÑ§??Í∞Ä?∏Ïò§Í∏?
                  String nickname = '?âÎÑ§??;
                  if (userData['profile'] != null && 
                      userData['profile']['info'] != null) {
                    nickname = userData['profile']['info']['nickname'] ?? '?âÎÑ§??;
                  } else {
                    nickname = userData['nickname'] ?? '?âÎÑ§??;
                  }
                  
                  // ?¨Ïö©?êÏùò ??ï† ?ïÎ≥¥ Í∞Ä?∏Ïò§Í∏?
                  String authority = 'ÏßÅÏõê';
                  try {
                    final memberData = memberDoc.data();
                    authority = memberData['roleId'] ?? 'ÏßÅÏõê';
                  } catch (e) {
                    // print πÆ ¡¶∞≈µ 
                  }
                  
                  // ?åÎ†à?¥Ïä§ ?ïÎ≥¥??Í∞Ä?∏Ïò§Í∏?
                  String placeName = '?åÎ†à?¥Ïä§';
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
                    // print πÆ ¡¶∞≈µ 
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
                // print πÆ ¡¶∞≈µ 
              }
            }
          }
        }
        
        // Ï§ëÎ≥µ ?úÍ±∞ (Í∞ôÏ? ?¨Ïö©?êÍ? ?¨Îü¨ ?åÎ†à?¥Ïä§???çÌï† ???àÏùå)
        final uniqueConnections = <String, Map<String, dynamic>>{};
        for (final connection in connections) {
          final userId = connection['userId'];
          if (!uniqueConnections.containsKey(userId)) {
            uniqueConnections[userId] = connection;
          }
        }
        
        // print πÆ ¡¶∞≈µ 
        return uniqueConnections.values.toList();
      }
    } catch (e) {
      // print πÆ ¡¶∞≈µ 
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
          
          // ?àÎ°ú??Íµ¨Ï°∞?êÏÑú ?âÎÑ§??Í∞Ä?∏Ïò§Í∏?
          String nickname = '?âÎÑ§??;
          if (userData['profile'] != null && 
              userData['profile']['info'] != null) {
            nickname = userData['profile']['info']['nickname'] ?? '?âÎÑ§??;
          } else {
            nickname = userData['nickname'] ?? '?âÎÑ§??;
          }
          
          // ?¨Ïö©?êÏùò ??ï† ?ïÎ≥¥ Í∞Ä?∏Ïò§Í∏?(Í∏∞Î≥∏Í∞? ÏßÅÏõê)
          String authority = 'ÏßÅÏõê';
          try {
            final userPlacesSnapshot = await _firestore
                .collection('users')
                .doc(userId)
                .collection('places')
                .limit(1)
                .get();
            
            if (userPlacesSnapshot.docs.isNotEmpty) {
              final userPlaceData = userPlacesSnapshot.docs.first.data();
              authority = userPlaceData['roleName'] ?? 'ÏßÅÏõê';
            }
          } catch (e) {
            // print πÆ ¡¶∞≈µ 
          }
          
          userDetails.add({
            'userId': userId,
            'nickname': nickname,
            'authority': authority,
            'profileImageUrl': userData['profileImageUrl'] ?? '',
          });
        }
      } catch (e) {
        // print πÆ ¡¶∞≈µ 
      }
    }
    
    return userDetails;
  }

  // ?îÎ©¥ ?¨Í∏∞???∞Î•∏ ????Í≤∞Ï†ï
  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Î™®Î∞î??Í∏∞Ï? ?àÎπÑ (??400px)
    if (screenWidth < 600) {
      return 2; // Î™®Î∞î?? 2??
    } else if (screenWidth < 900) {
      return 3; // ?úÎ∏îÎ¶? 3??
    } else {
      return 4; // ?∞Ïä§?¨ÌÜ±: 4??
    }
  }

  Widget _buildUserCard(Map<String, dynamic> userData) {
    final userId = userData['userId'] ?? '';
    final nickname = userData['nickname'] ?? '?âÎÑ§??;
    final authority = userData['authority'] ?? 'Authority';
    final profileImageUrl = userData['profileImageUrl'] ?? '';
    final trackMode = userData['trackMode'] ?? 'work'; // ?∏Îûô Î™®Îìú Í∞Ä?∏Ïò§Í∏?
    final placeName = userData['placeName'] ?? ''; // ?åÎ†à?¥Ïä§ ?¥Î¶Ñ

    // Í∂åÌïú ?àÎ≤®???∞Î•∏ ?âÏÉÅÍ≥??çÏä§???§Ï†ï
    Color authorityColor;
    String authorityText;
    
    if (widget.type == 'track') {
      // Track??Í≤ΩÏö∞ Î™®ÎìúÎß??úÏãú
      authorityColor = trackMode == 'work' ? Colors.blue : Colors.green;
      authorityText = trackMode == 'work' ? '?åÌÅ¨' : '?ºÏù¥??;
    } else {
      // Connection??Í≤ΩÏö∞ ?¨Ïö©????ï† ?úÏãú
      switch (authority.toLowerCase()) {
        case 'owner':
        case '?åÏú†??:
        case '?¨Ïû•':
        case '?Ä??:
        case 'Ï∫°Ìã¥':
          authorityColor = Colors.red.shade700;
          authorityText = '?åÏú†??;
          break;
        case 'manager':
        case 'Í¥ÄÎ¶¨Ïûê':
        case 'Îß§Îãà?Ä':
        case 'Î≥¥Ï°∞Ï∫°Ìã¥':
          authorityColor = Colors.orange.shade700;
          authorityText = 'Í¥ÄÎ¶¨Ïûê';
          break;
        case 'employee':
        case 'ÏßÅÏõê':
        case '?§ÌÉú??:
          authorityColor = Colors.blue.shade700;
          authorityText = 'ÏßÅÏõê';
          break;
        case 'customer':
        case 'Í≥†Í∞ù':
        case '?êÎãò':
        case '?åÏõê':
          authorityColor = Colors.green.shade700;
          authorityText = 'Í≥†Í∞ù';
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
            // ?ºÏ™Ω: ?ÑÎ°ú???¥Î?ÏßÄ
            CircleAvatar(
              radius: 20,
              backgroundImage: profileImageUrl.isNotEmpty
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/images/default_profile.png') as ImageProvider,
            ),
            const SizedBox(width: 8),
            
            // ?§Î•∏Ï™? ?âÎÑ§?ÑÍ≥º Í∂åÌïú
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ?ÅÎã®: ?âÎÑ§??
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
                  
                  // Ï§ëÍ∞Ñ: ?åÎ†à?¥Ïä§ ?¥Î¶Ñ (Ïª§ÎÑ•?òÏù∏ Í≤ΩÏö∞Îß?
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
                  
                  // ?òÎã®: Authority ?êÎäî Î™®Îìú ?ïÎ≥¥
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
                          // ?∏Îûô??Í≤ΩÏö∞ Î™®Îìú ?ÑÏù¥ÏΩòÍ≥º ?çÏä§??
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
