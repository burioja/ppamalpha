import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/data/user_service.dart';

class ProfileHeaderCard extends StatefulWidget {
  final String? profileImageUrl;
  final String nickname;
  final String email;
  final VoidCallback? onProfileUpdated;

  const ProfileHeaderCard({
    super.key,
    this.profileImageUrl,
    required this.nickname,
    required this.email,
    this.onProfileUpdated,
  });

  @override
  State<ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends State<ProfileHeaderCard> {
  final ImagePicker _picker = ImagePicker();
  final UserService _userService = UserService();
  bool _isUploading = false;
  String? _currentImageUrl;  // 현재 표시 중인 이미지 URL

  @override
  void initState() {
    super.initState();
    _currentImageUrl = widget.profileImageUrl;
  }

  @override
  void didUpdateWidget(ProfileHeaderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('🔄 ProfileHeaderCard didUpdateWidget 호출');
    debugPrint('🔄 이전 URL: ${oldWidget.profileImageUrl}');
    debugPrint('🔄 새 URL: ${widget.profileImageUrl}');
    debugPrint('🔄 현재 _currentImageUrl: $_currentImageUrl');
    
    // URL이 변경되었거나 현재 URL이 다를 때 업데이트
    if (oldWidget.profileImageUrl != widget.profileImageUrl || 
        _currentImageUrl != widget.profileImageUrl) {
      debugPrint('🔄 URL 변경 감지 또는 불일치 - 업데이트 진행');
      
      // URL 검증 및 업데이트
      if (widget.profileImageUrl != null && widget.profileImageUrl!.isNotEmpty) {
        debugPrint('✅ 유효한 새 URL 감지 - 업데이트 진행');
        setState(() {
          _currentImageUrl = widget.profileImageUrl;
        });
        debugPrint('✅ _currentImageUrl 업데이트 완료: $_currentImageUrl');
      } else {
        debugPrint('⚠️ URL이 null이거나 비어있음 - 기본 아이콘 유지');
        setState(() {
          _currentImageUrl = null;
        });
      }
    } else {
      debugPrint('ℹ️ URL 변경 없음 - 업데이트 건너뜀');
    }
  }

  Future<void> _changeProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // Firebase Storage에 업로드
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('사용자가 로그인되지 않았습니다');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // 플랫폼별 업로드 처리
      UploadTask uploadTask;
      if (kIsWeb) {
        // 웹: XFile의 바이트 데이터 사용
        final bytes = await image.readAsBytes();
        uploadTask = storageRef.putData(bytes);
      } else {
        // 모바일: File 객체 사용
        uploadTask = storageRef.putFile(File(image.path));
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('🖼️ 프로필 이미지 업로드 성공: $downloadUrl');

      // 사용자 프로필 업데이트
      final savedUrl = await _userService.updateUserProfile(profileImageUrl: downloadUrl);
      debugPrint('✅ UserService 업데이트 완료 - 저장된 URL: $savedUrl');

      // Firestore에서 직접 확인
      final verifyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userService.currentUserId)
          .get();
      final verifiedUrl = verifyDoc.data()?['profileImageUrl'];
      debugPrint('🔍 Firestore 직접 확인 - profileImageUrl: $verifiedUrl');

      // 이전 이미지 캐시 제거
      if (widget.profileImageUrl != null) {
        await NetworkImage(widget.profileImageUrl!).evict();
        debugPrint('🗑️ 이전 이미지 캐시 제거 완료');
      }

      // URL 검증
      final finalUrl = verifiedUrl ?? downloadUrl;
      if (finalUrl == null || !finalUrl.contains('token=')) {
        debugPrint('⚠️ 잘못된 URL 감지 - token 누락: $finalUrl');
        throw Exception('Invalid Firebase Storage URL - missing token');
      }

      // 로컬 상태 즉시 업데이트
      if (mounted) {
        setState(() {
          _currentImageUrl = finalUrl;
        });
        debugPrint('💫 로컬 상태 업데이트 완료 - _currentImageUrl: $_currentImageUrl');
      }

      // 상위 위젯에 업데이트 알림
      if (widget.onProfileUpdated != null) {
        debugPrint('📢 onProfileUpdated 콜백 호출');
        widget.onProfileUpdated!();
      } else {
        debugPrint('⚠️ onProfileUpdated 콜백이 null');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('프로필 이미지가 변경되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 프로필 이미지 및 편집 버튼
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                        ? Image.network(
                                _currentImageUrl!,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                // 웹에서는 캐시 크기 제한을 사용하지 않음 (CORS 문제 회피)
                                cacheWidth: kIsWeb ? null : 200,
                                cacheHeight: kIsWeb ? null : 200,
                                // 로딩 중 표시
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                },
                                // 에러 시 기본 아이콘 표시
                                errorBuilder: (context, error, stackTrace) {
                                  debugPrint('❌ 프로필 이미지 로드 에러: $error');
                                  debugPrint('❌ URL 전체: $_currentImageUrl');
                                  debugPrint('❌ 플랫폼: ${kIsWeb ? "웹" : "모바일"}');
                                  // URL 검증
                                  if (_currentImageUrl != null) {
                                    final hasToken = _currentImageUrl!.contains('token=');
                                    debugPrint('❌ Token 포함 여부: $hasToken');
                                  }
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              )
                        : Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.grey[600],
                            ),
                          ),
                  ),
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploading ? null : _changeProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 사용자 정보
            Column(
              children: [
                Text(
                  widget.nickname.isNotEmpty ? widget.nickname : '닉네임 없음',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 프로필 완성도 인디케이터
            _buildProfileCompletionIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCompletionIndicator() {
    // 간단한 프로필 완성도 계산 (이후 확장 가능)
    int completedFields = 0;
    int totalFields = 3;

    if (widget.nickname.isNotEmpty) completedFields++;
    if (widget.email.isNotEmpty) completedFields++;
    if (widget.profileImageUrl != null) completedFields++;

    double completionRate = completedFields / totalFields;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '프로필 완성도',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            Text(
              '${(completionRate * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: completionRate,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}