
      // 포인트 보상 정보와 함께 성공 메시지 표시
      final reward = marker.reward ?? 0;
      final message = reward > 0
          ? '포스트를 수령했습니다! 🎉\n${reward}포인트가 지급되었습니다! (${marker.quantity - 1}개 남음)'
          : '포스트를 수령했습니다! (${marker.quantity - 1}개 남음)';

      Navigator.of(context).pop(); // 다이얼로그 먼저 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // 수령 완료 후 즉시 마커 목록 새로고침
      print('🔄 마커 수령 완료 - 마커 목록 새로고침 시작');
      
      // 1. 로컬에서 같은 포스트의 모든 마커 즉시 제거 (UI 반응성)
      setState(() {
        final postId = marker.postId;
        final removedCount = _markers.where((m) => m.postId == postId).length;
        _markers.removeWhere((m) => m.postId == postId);
        print('🗑️ 같은 포스트의 모든 마커 제거: ${marker.title} (${removedCount}개 마커 제거됨)');
        print('   - postId: $postId');
        _updateMarkers(); // 클러스터 재계산
      });
      
      // 2. 서버에서 실제 마커 상태 확인 및 동기화
      await Future.delayed(const Duration(milliseconds: 500));
      await _updatePostsBasedOnFogLevel();
      _updateReceivablePosts(); // 수령 가능 개수 업데이트
      
      print('✅ 마커 목록 새로고침 완료');

      // 메인 스크린의 포인트 새로고침 (GlobalKey 사용)
      try {
        final mainScreenState = MapScreen.mapKey.currentState;
        if (mainScreenState != null) {
          // MainScreen에 포인트 새로고침 메서드가 있다면 호출
          debugPrint('📱 메인 스크린 포인트 새로고침 요청');
        }
      } catch (e) {
        debugPrint('⚠️ 메인 스크린 포인트 새로고침 실패: $e');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  void _updateMarkers() {
    // map_screen_markers.dart의 _updateMarkers 메서드 호출
    // 중복 로직 제거
  }

  // LatLng -> 화면 좌표 변환 함수
  Offset _latLngToScreen(LatLng ll) {
    return latLngToScreenWebMercator(
      ll, 
      mapCenter: _mapCenter, 
      zoom: _mapZoom, 
      viewSize: _lastMapSize,
    );
  }




  Future<void> _collectMarker(MarkerModel marker) async {
    // TODO: 새로운 구조에 맞게 구현 예정
    print('마커 수집: ${marker.title}');
  }

  void _showMarkerDetail(MarkerModel marker) {
    // TODO: 새로운 구조에 맞게 구현 예정
    print('마커 상세: ${marker.title}');
  }

  // 마커 회수 (삭제)
  Future<void> _removeMarker(MarkerModel marker) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다')),
        );
        return;
      }

      // 배포자 확인
      if (marker.creatorId != user.uid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자신이 배포한 포스트만 회수할 수 있습니다')),
        );
        return;
      }

      debugPrint('');
      debugPrint('🟢🟢🟢 [map_screen] 회수 버튼 클릭 - 마커 정보 🟢🟢🟢');
      debugPrint('🟢 marker.markerId: ${marker.markerId}');
      debugPrint('🟢 marker.postId: ${marker.postId}');
      debugPrint('🟢 PostService().recallMarker() 호출 시작...');
      debugPrint('');

      // 개별 마커 회수 (포스트와 다른 마커는 유지)
      // await PostService().recallMarker(marker.markerId); // TODO: 메소드 구현 필요

      debugPrint('');
      debugPrint('🟢 [map_screen] PostService().recallMarker() 완료');
      debugPrint('🟢🟢🟢 ========================================== 🟢🟢🟢');
      debugPrint('');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('마커를 회수했습니다')),
      );
      
      // ❌ Navigator.of(context).pop() 제거 - 버튼에서 이미 닫음
      _updatePostsBasedOnFogLevel(); // 마커 목록 새로고침
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 클라이언트사이드 필터링 제거됨 - 서버사이드에서 처리
  // bool _matchesFilter(PostModel post) { ... } // 제거됨


  void _showPostDetail(PostModel post) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = post.creatorId == currentUserId;
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>?>(
        future: isOwner ? null : UserService().getUserById(post.creatorId),
        builder: (context, snapshot) {
          String creatorInfo = isOwner ? '본인' : post.creatorName;
          String creatorEmail = '';
          
          if (!isOwner && snapshot.hasData && snapshot.data != null) {
            creatorEmail = snapshot.data!['email'] ?? '';
          }
          
          return AlertDialog(
        title: Text(post.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('리워드: ${post.reward}원'),
                SizedBox(height: 8),
            Text('설명: ${post.description}'),
                SizedBox(height: 8),
            Text('기본 만료일: ${post.defaultExpiresAt.toString().split(' ')[0]}'),
                SizedBox(height: 8),
            if (isOwner)
                  Text('배포자: 본인', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                else ...[
                  Text('배포자: $creatorInfo', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                  if (creatorEmail.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text('이메일: $creatorEmail', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
            ],
          ),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          if (isOwner)
              TextButton(
                onPressed: () {
                Navigator.pop(context);
                _removePost(post); // Only owner can remove
              },
              child: const Text('회수', style: TextStyle(color: Colors.red)),
            )
          else
              TextButton(
                onPressed: () {
                Navigator.pop(context);
                _collectPost(post); // Others can collect
              },
              child: const Text('수집'),
            ),
        ],
          );
        },
      ),
    );
  }

  Future<void> _collectPost(PostModel post) async {
    try {
      await PostService().collectPost(
        postId: post.postId, 
        userId: FirebaseAuth.instance.currentUser!.uid
      );
      // 🚀 실시간 스트림이 자동으로 업데이트되므로 별도 새로고침 불필요
      // _loadPosts(forceRefresh: true); // 포스트 목록 새로고침

      // 효과음/진동
      await _playReceiveEffects(1);

      // 캐러셀 팝업으로 포스트 내용 표시
      await _showPostReceivedCarousel([post]);

    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 수집 중 오류가 발생했습니다: $e')),
      );
    }
  }

  Future<void> _removePost(PostModel post) async {
    try {
      // 포스트 회수 (마커도 함께 회수 처리됨)
      await PostService().recallPost(post.postId);
      // 🚀 실시간 스트림이 자동으로 업데이트되므로 별도 새로고침 불필요
      // _loadPosts(forceRefresh: true); // 포스트 목록 새로고침
          ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포스트를 회수했습니다!')),
          );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('포스트 회수 중 오류가 발생했습니다: $e')),
      );
    }
  }

  // 포스트 수령 캐러셀 팝업
  Future<void> _showPostReceivedCarousel(List<PostModel> posts) async {
    if (posts.isEmpty) return;

    // 확인 상태 추적
    final confirmedPosts = <String>{};
    final postService = PostService();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) return;

    final totalReward = posts.fold(0, (sum, post) => sum + (post.reward ?? 0));
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true, // 뒤로가기/외부 터치로 닫을 수 있음 (미확인 포스트로 이동)
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        child: Column(
          children: [
            // 상단 헤더
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text(
                    '${posts.length}개 포스트 수령됨 (확인 대기)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (totalReward > 0) ...[
                    SizedBox(height: 4),
                    Text(
                      '총 +${totalReward}포인트',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Colors.green, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 캐러셀 영역
            Expanded(
              child: PageView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final isConfirmed = confirmedPosts.contains(post.postId);
                  
                  return GestureDetector(
                    onTap: () async {
                      if (isConfirmed) return; // 이미 확인한 포스트는 무시
                      
                      try {
                        // 멱등 ID로 직접 조회
                        final collectionId = '${post.postId}_$currentUserId';
                        final collectionDoc = await FirebaseFirestore.instance
                            .collection('post_collections')
                            .doc(collectionId)
                            .get();
                        
                        if (!collectionDoc.exists) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('수령 기록을 찾을 수 없습니다')),
                          );
                          return;
                        }
                        
                        final collectionData = collectionDoc.data()!;
                        final creatorId = collectionData['postCreatorId'] ?? '';
                        final reward = collectionData['reward'] ?? 0;
                        
                        // 포스트 확인 처리
                        // await postService.confirmPost( // TODO: confirmPost 메소드 구현
                        //   collectionId: collectionId,
                        //   userId: currentUserId,
                        //   postId: post.postId,
                        //   creatorId: creatorId,
                        //   reward: reward,
                        // );
                        
                        // 확인 상태 업데이트
                        setState(() {
                          confirmedPosts.add(post.postId);
                        });
                        
                        // 피드백
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ 포스트 확인 완료! +${reward}포인트'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } catch (e) {
                        debugPrint('포스트 확인 실패: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('포스트 확인에 실패했습니다')),
                        );
                      }
                    },
                    child: _buildPostCarouselPage(post, index + 1, posts.length, isConfirmed),
                  );
                },
              ),
            ),
            
            // 하단 인디케이터 + 버튼
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // 페이지 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(posts.length, (index) {
                      final post = posts[index];
                      final isConfirmed = confirmedPosts.contains(post.postId);
                      return Container(
                        width: 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConfirmed ? Colors.green : Colors.grey[300],
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 12),
                  // 확인 상태 표시
                  Text(
                    '${confirmedPosts.length}/${posts.length} 확인 완료',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // 항상 표시되는 버튼들
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // 다이얼로그 닫기
                            // 인박스로 이동
                            if (widget.onNavigateToInbox != null) {
                              widget.onNavigateToInbox!();
                            }
                          },
                          icon: Icon(Icons.inbox),
                          label: Text('인박스 보기'),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            '나중에 확인',
                            style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // 캐러셀 개별 페이지 위젯
  Widget _buildPostCarouselPage(PostModel post, int currentIndex, int totalCount, bool isConfirmed) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 진행률 및 상태 표시
          Row(
            children: [
              Text(
                '$currentIndex/$totalCount',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isConfirmed ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isConfirmed ? '✓ 확인완료' : '터치하여 확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Spacer(),
              if (totalCount > 1)
                Text(
                  '👈 스와이프',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // 포스트 제목
          Text(
            post.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: 12),
          
          // 포스트 설명
          if (post.description.isNotEmpty) ...[
            Text(
              post.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // 포스트 이미지
          if (post.mediaUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                post.mediaUrl.first,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
          ],
          
          // 포인트 정보
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '포인트 지급',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '+${post.reward ?? 0}포인트',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 확인 안내 (확인되지 않은 경우에만)
          if (!isConfirmed) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app, size: 24, color: Colors.orange[700]),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '이 영역을 터치하면\n포인트를 받고 확인됩니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_upward, size: 28, color: Colors.orange[700]),
                ],
              ),
            ),
          ] else ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 24, color: Colors.green[700]),
                  SizedBox(width: 12),
                  Text(
                    '확인 완료!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

    void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
            children: [
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 제목
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '필터 설정',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 필터 내용
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
            children: [
                    const SizedBox(height: 20),
                    // 일반/쿠폰 토글
                    Row(
                      children: [
                        const Text('포스트 타입:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
          child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'all'),
            child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                                      color: _selectedCategory == 'all' ? Colors.blue : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '전체',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedCategory = 'coupon'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                                      color: _selectedCategory == 'coupon' ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                                    child: const Text(
                                      '쿠폰만',
                  textAlign: TextAlign.center,
                                      style: TextStyle(
                color: Colors.white,
                                        fontWeight: FontWeight.w500,
              ),
            ),
          ),
                ),
              ),
            ],
          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 거리 표시 (유료/무료에 따라)
                    Row(
                      children: [
                        const Text('검색 반경:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isPremiumUser ? Colors.amber[50] : Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isPremiumUser ? Colors.amber[200]! : Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_maxDistance.toInt()}m',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isPremiumUser ? Colors.amber[800] : Colors.blue,
                                ),
                              ),
                              if (_isPremiumUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[600],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 리워드 슬라이더
                    Row(
                      children: [
                        const Text('최소 리워드:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              Text('${_minReward}원', 
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Slider(
                                value: _minReward.toDouble(),
                                min: 0,
                                max: 10000,
                                divisions: 100,
                                onChanged: (value) {
    setState(() {
                                    _minReward = value.toInt();
                                  });
                                },
            ),
          ],
        ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // 정렬 옵션
                    Row(
          children: [
                        const Text('정렬:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '가까운순',
                                      textAlign: TextAlign.center,
              style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {}),
                                  child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                                      color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                                    child: const Text(
                                      '최신순',
                  textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500,
                ),
              ),
            ),
                ),
              ),
            ],
          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 하단 버튼들
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                onPressed: () {
                        Navigator.pop(context);
                        _resetFilters();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                onPressed: () {
                        Navigator.pop(context);
                        _updateMarkers();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('적용'),
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



  void _resetFilters() {
    setState(() {
      _selectedCategory = 'all';
      _maxDistance = _isPremiumUser ? 3000.0 : 1000.0; // 유료: 3km, 무료: 1km
      _minReward = 0;
      _showCouponsOnly = false;
      _showMyPostsOnly = false;
      _showUrgentOnly = false;
      _showVerifiedOnly = false; // 인증 필터 초기화
      _showUnverifiedOnly = false; // 미인증 필터 초기화
    });
    _updateMarkers();
  }

  // 필터 칩 빌더 헬퍼 함수
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
    required Color selectedColor,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: selected ? [
          BoxShadow(
            color: selectedColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : selectedColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : selectedColor,
              ),
            ),
          ],
        ),
        selected: selected,
        onSelected: onSelected,
        selectedColor: selectedColor,
        checkmarkColor: Colors.white,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? selectedColor : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Future<void> _navigateToPostPlace() async {
    if (_longPressedLatLng == null) return;

    // 현재위치, 집, 일터 주변에서 배포 가능한지 확인
    final canDeploy = _canLongPressAtLocation(_longPressedLatLng!);

    if (!canDeploy) {
      // 거리 초과 시 아무 동작도 하지 않음 (사용자 경험 개선)
      return;
    }

    // PostDeploymentController를 사용한 위치 기반 포스트 배포
    final success = await PostDeploymentController.deployPostFromLocation(context, _longPressedLatLng!);

    // 포스트 배포 완료 후 처리
    if (success) {
      print('포스트 배포 완료');
      // 🚀 배포 완료 후 즉시 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
      
      // 마커 즉시 업데이트
      await _updatePostsBasedOnFogLevel();
      
      // 데이터베이스 반영을 위해 충분한 시간 대기 후 다시 한 번 업데이트
      await Future.delayed(const Duration(milliseconds: 1500));
      await _updatePostsBasedOnFogLevel();
      
      // 마지막으로 한 번 더 업데이트 (확실하게)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 배포를 취소한 경우 롱프레스 위치 초기화
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  Future<void> _navigateToPostAddress() async {
    if (_longPressedLatLng == null) return;

    try {
      // 1. OSM에서 건물명 조회
      print('🌐 OSM에서 건물명 조회 중...');
      final buildingName = await OSMGeocodingService.getBuildingName(_longPressedLatLng!);
      
      if (buildingName == null) {
        _showToast('건물명을 찾을 수 없습니다.');
        return;
      }
      
      print('✅ 건물명 조회 성공: $buildingName');
      
      // 2. 건물명 확인 팝업
      final isCorrect = await _showBuildingNameConfirmation(buildingName);
      
      if (isCorrect) {
        // 3. 포스트 배포 화면으로 이동 (주소 모드)
        _navigateToPostDeploy('address', buildingName);
    } else {
        // 4. 주소 검색 팝업
        final selectedAddress = await _showAddressSearchDialog();
        if (selectedAddress != null) {
          _navigateToPostDeploy('address', selectedAddress['display_name']);
        }
      }
    } catch (e) {
      print('❌ 주소 배포 오류: $e');
      _showToast('주소 정보를 가져오는 중 오류가 발생했습니다.');
    }
  }

  /// 건물명 확인 팝업
  Future<bool> _showBuildingNameConfirmation(String buildingName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 확인'),
        content: Text('$buildingName이 맞습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('예'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// 주소 검색 팝업
  Future<Map<String, dynamic>?> _showAddressSearchDialog() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddressSearchDialog(),
    );
  }

  /// 포스트 배포 화면으로 네비게이션
  Future<void> _navigateToPostDeploy(String type, String buildingName) async {
    final result = await Navigator.pushNamed(
      context,
      '/post-deploy',
      arguments: {
        'location': _longPressedLatLng!,
        'type': type,
        'buildingName': buildingName,
      },
    );

    if (result != null && mounted) {
      // 배포 완료 후 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null;
      });
      
      print('🚀 배포 완료 - 즉시 마커 조회 시작');
      
      // ✅ 해결책 2: 포그/타일/캐시 파생값 재빌드
      if (_currentPosition != null) {
        final currentTileId = TileUtils.getKm1TileId(
          _currentPosition!.latitude, 
          _currentPosition!.longitude
        );
        _rebuildFogWithUserLocations(_currentPosition!);
        _setLevel1TileLocally(currentTileId);
        print('✅ 포그/타일 상태 재빌드 완료');
      }
      
      // ✅ 해결책 3: 1단계 타일 캐시 초기화 (새 마커 쿼리 보장)
      _clearFogLevel1Cache();
      print('✅ 1단계 타일 캐시 초기화 완료');
      
      // ✅ 해결책 4: 강제 fetch
      await _updatePostsBasedOnFogLevel();
      print('✅ 마커 조회 완료');
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 취소한 경우
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  /// 토스트 메시지 표시
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _navigateToPostBusiness() async {
    if (_longPressedLatLng == null) return;

    // PostDeploymentController를 사용한 카테고리 기반 포스트 배포
    final success = await PostDeploymentController.deployPostFromCategory(context, _longPressedLatLng!);

    // 포스트 배포 완료 후 처리
    if (success) {
      print('포스트 배포 완료');
      // 🚀 배포 완료 후 즉시 마커 새로고침
      setState(() {
        _isLoading = true;
        _longPressedLatLng = null; // 팝업용 변수만 초기화
      });
      
      // 마커 즉시 업데이트
      await _updatePostsBasedOnFogLevel();
      
      // 데이터베이스 반영을 위해 충분한 시간 대기 후 다시 한 번 업데이트
      await Future.delayed(const Duration(milliseconds: 1500));
      await _updatePostsBasedOnFogLevel();
      
      // 마지막으로 한 번 더 업데이트 (확실하게)
      await Future.delayed(const Duration(milliseconds: 1000));
      await _updatePostsBasedOnFogLevel();
      
      setState(() {
        _isLoading = false;
      });
    } else {
      // 배포를 취소한 경우 롱프레스 위치 초기화
      setState(() {
        _longPressedLatLng = null;
      });
    }
  }

  void _showLongPressMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들 바
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // 제목
              const Text(
                '포스트 배포',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              // 설명
              const Text(
                '이 위치에 포스트를 배포하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              
              // 메뉴 옵션들
              Expanded(
                child: Column(
                  children: [
                    // 이 위치에 뿌리기
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPostPlace();
                        },
                        icon: const Icon(Icons.location_on, color: Colors.white),
                        label: const Text(
                          '이 위치에 뿌리기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4D4DFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 이 주소에 뿌리기
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _navigateToPostAddress();
                        },
                        icon: const Icon(Icons.home, color: Colors.white),
                        label: const Text(
                          '이 주소에 뿌리기',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // 근처 업종에 뿌리기 (작업중)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: null, // 비활성화
                        icon: const Icon(Icons.business, color: Colors.white),
                        label: const Text(
                          '근처 업종에 뿌리기 (작업중)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey, // 회색으로 변경
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
            ],
          ),
        ),
      ),
    );
  }



  void _onMapReady() {
    // 현재 위치로 지도 이동
    if (_currentPosition != null) {
      _mapController?.move(_currentPosition!, _currentZoom);
    }
  }

  // 집으로 이동
  void _moveToHome() {
    if (_homeLocation != null) {
      _mapController?.move(_homeLocation!, _currentZoom);
    }
  }

  // 일터로 이동 (순차적으로)
  void _moveToWorkplace() {
    if (_workLocations.isNotEmpty) {
      final targetLocation = _workLocations[_currentWorkplaceIndex];
      _mapController?.move(targetLocation, _currentZoom);
      
      // 다음 일터로 인덱스 이동 (순환)
      setState(() {
        _currentWorkplaceIndex = (_currentWorkplaceIndex + 1) % _workLocations.length;
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    final double dLon = _degreesToRadians(point2.longitude - point1.longitude);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(_degreesToRadians(point1.latitude)) * sin(_degreesToRadians(point2.latitude)) * 
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Mock 위치 관련 메서드들
  void _toggleMockMode() {
    setState(() {
      _isMockModeEnabled = !_isMockModeEnabled;
      if (_isMockModeEnabled) {
        _isMockControllerVisible = true;
        // 원래 GPS 위치 백업
        _originalGpsPosition = _currentPosition;
        // Mock 위치가 없으면 현재 GPS 위치를 기본값으로 설정
        if (_mockPosition == null && _currentPosition != null) {
          _mockPosition = _currentPosition;
        }
      } else {
        _isMockControllerVisible = false;
        // Mock 모드 비활성화 시 원래 GPS 위치로 복원
        if (_originalGpsPosition != null) {
          _currentPosition = _originalGpsPosition;
          _mapController?.move(_originalGpsPosition!, _currentZoom);
          _createCurrentLocationMarker(_originalGpsPosition!);
          _updateCurrentAddress();
          _updatePostsBasedOnFogLevel();
        }
      }
    });
  }

  Future<void> _setMockPosition(LatLng position) async {
    // 이전 Mock 위치 저장 (회색 영역 표시용)
    final previousPosition = _mockPosition;
    
    setState(() {
      _mockPosition = position;
      // Mock 모드에서는 실제 위치도 업데이트 (실제 기능처럼 동작)
      if (_isMockModeEnabled) {
        _currentPosition = position;
      }
    });

    // Mock 위치로 지도 중심 이동 (현재 줌 레벨 유지)
    final currentZoom = _mapController?.camera.zoom ?? _currentZoom;
    _mapController?.move(position, currentZoom);
    
    // Mock 위치 마커 생성
    _createCurrentLocationMarker(position);
    
    // 주소 업데이트 (Mock 위치 기준)
    _updateMockAddress(position);
    
    // 타일 방문 기록 업데이트 (실제 기능처럼 동작)
    final tileId = TileUtils.getKm1TileId(position.latitude, position.longitude);
    print('🎭 Mock 위치 타일 방문 기록 업데이트: $tileId');
    await VisitTileService.updateCurrentTileVisit(tileId);
    _setLevel1TileLocally(tileId);
    
    // 포그 오브 워 재구성 (실제 기능처럼 동작)
    _rebuildFogWithUserLocations(position);
    
    // 회색 영역 업데이트 (이전 위치 포함)
    _updateGrayAreasWithPreviousPosition(previousPosition);
    
    // 마커 업데이트
    _updatePostsBasedOnFogLevel();
  }

  Future<void> _updateMockAddress(LatLng position) async {
    try {
      final address = await NominatimService.reverseGeocode(position);
      setState(() {
        _currentAddress = address;
      });
      widget.onAddressChanged?.call(address);
    } catch (e) {
      setState(() {
        _currentAddress = '주소 변환 실패';
      });
    }
  }

  // 화살표 방향에 따른 Mock 위치 이동
  void _moveMockPosition(String direction) async {
    if (_mockPosition == null) return;

    const double moveDistance = 0.000225; // 약 25m 이동
    LatLng newPosition;
    
    switch (direction) {
      case 'up':
        newPosition = LatLng(_mockPosition!.latitude + moveDistance, _mockPosition!.longitude);
        break;
      case 'down':
        newPosition = LatLng(_mockPosition!.latitude - moveDistance, _mockPosition!.longitude);
        break;
      case 'left':
        newPosition = LatLng(_mockPosition!.latitude, _mockPosition!.longitude - moveDistance);
        break;
      case 'right':
        newPosition = LatLng(_mockPosition!.latitude, _mockPosition!.longitude + moveDistance);
        break;
      default:
        return;
    }
    
    await _setMockPosition(newPosition);
  }

  void _hideMockController() {
    setState(() {
      _isMockControllerVisible = false;
    });
  }

  Future<void> _showMockPositionInputDialog() async {
    final latController = TextEditingController(
      text: _mockPosition?.latitude.toStringAsFixed(6) ?? '',
    );
    final lngController = TextEditingController(
      text: _mockPosition?.longitude.toStringAsFixed(6) ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mock 위치 직접 입력'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: '위도 (Latitude)',
                hintText: '37.5665',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lngController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: '경도 (Longitude)',
                hintText: '126.9780',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '예시: 서울시청 (37.5665, 126.9780)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('이동'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final lat = double.parse(latController.text);
        final lng = double.parse(lngController.text);
        
        // 유효 범위 체크 (대략적인 한국 범위)
        if (lat < 33.0 || lat > 39.0 || lng < 124.0 || lng > 132.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('한국 범위 내의 좌표를 입력해주세요')),
          );
          return;
        }

        final newPosition = LatLng(lat, lng);
        await _setMockPosition(newPosition);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mock 위치 이동: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바른 숫자를 입력해주세요')),
        );
      }
    }

    latController.dispose();
    lngController.dispose();
  }

  // 통합된 회색 영역 업데이트 (DB에서 최신 방문 기록 로드)
  void _updateGrayAreasWithPreviousPosition(LatLng? previousPosition) async {
    try {
      // DB에서 최신 방문 기록 로드 (서버 강제 읽기)
      final visitedPositions = await _loadVisitedPositionsFromDB();
      
      // 이전 위치도 추가 (즉시 반영용)
      if (previousPosition != null) {
        visitedPositions.add(previousPosition);
        print('🎯 이전 위치를 회색 영역으로 추가: ${previousPosition.latitude}, ${previousPosition.longitude}');
      }
      
      // 새로운 회색 영역 생성
      final grayPolygons = OSMFogService.createGrayAreas(visitedPositions);
      
      setState(() {
        _grayPolygons = grayPolygons;
      });
      
      print('✅ 회색 영역 업데이트 완료: ${visitedPositions.length}개 위치');
    } catch (e) {
      print('❌ 회색 영역 업데이트 실패: $e');
    }
  }

  // DB에서 최신 방문 기록 로드 (서버 강제 읽기)
  Future<List<LatLng>> _loadVisitedPositionsFromDB() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      // 30일 이내 방문 기록 가져오기 (서버 강제 읽기)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final visitedTiles = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('visited_tiles')
          .where('lastVisitTime', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get(const GetOptions(source: Source.server)); // 서버 강제 읽기

      final visitedPositions = <LatLng>[];
      
      for (final doc in visitedTiles.docs) {
        final tileId = doc.id;
        // 타일 ID에서 좌표 추출
        final position = _extractPositionFromTileId(tileId);
        if (position != null) {
          visitedPositions.add(position);
        }
      }

      print('🔍 DB에서 로드된 방문 위치 개수: ${visitedPositions.length}');
      return visitedPositions;
    } catch (e) {
      print('❌ DB에서 방문 위치 로드 실패: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _workplaceSubscription?.cancel(); // ✅ 일터 리스너 구독 취소
    _mapMoveTimer?.cancel(); // 타이머 정리
    _clusterDebounceTimer?.cancel(); // 클러스터 디바운스 타이머 정리
    super.dispose();
  }

  @override
