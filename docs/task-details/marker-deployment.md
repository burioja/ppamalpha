# 마커 뿌리기 UI/UX 개선

## 📋 과제 개요
**과제 ID**: TASK-003
**제목**: 마커 뿌리기 UI/UX 개선
**우선순위**: ⭐⭐ 중간
**담당자**: TBD
**상태**: 🔄 계획 중

## 🎯 요구사항 분석

### 사용자 요구사항
1. **뿌리기 기능 개선**: 마커 선택 후 리스트 제일 하단에 "뿌리기" 기능
2. **이미지 제한 해제**: 사진 업로드 시 정사각형 제한 해제
3. **UI 개선**: 사용자 경험 향상 및 오류 수정
4. **기능 안정성**: 뿌리기 과정에서 발생하는 오류 해결

### 비즈니스 요구사항
- 직관적이고 편리한 마커 배포 프로세스
- 다양한 이미지 비율 지원으로 컨텐츠 다양성 증대
- 안정적인 마커 배포로 사용자 만족도 향상

## 🔍 현재 상태 분석

### 기존 구현사항
```dart
// lib/features/post_system/screens/post_deploy_screen.dart 분석 결과

✅ 구현 완료:
- PostDeployScreen 기본 구조
- 사용자 포스트 목록 로드
- 위치 기반 마커 배포
- 수량/가격 설정 기능
- 배포 기간 설정

🔄 개선 필요:
- 리스트 하단 "뿌리기" 버튼 추가
- 이미지 업로드 제한 해제
- UI/UX 개선
- 오류 처리 강화
```

### 현재 화면 구조
```
PostDeployScreen
├── 포스트 선택 리스트
├── 수량/가격 입력
├── 기간 설정
└── 배포 버튼 (현재 위치)
```

## ✅ 구현 계획

### Phase 1: 리스트 하단 "뿌리기" 기능 추가
- [ ] 포스트 선택 리스트 디자인 개선
- [ ] 하단 고정 "뿌리기" 버튼 영역 추가
- [ ] 선택된 포스트 정보 요약 표시

### Phase 2: 이미지 업로드 제한 해제
- [ ] 정사각형 제한 관련 코드 식별 및 제거
- [ ] 다양한 비율 이미지 지원
- [ ] 이미지 미리보기 개선

### Phase 3: UI/UX 개선
- [ ] 직관적인 인터페이스 디자인
- [ ] 배포 진행 상태 표시
- [ ] 성공/실패 피드백 개선

### Phase 4: 오류 처리 강화
- [ ] 네트워크 오류 처리
- [ ] 데이터 검증 강화
- [ ] 사용자 친화적 오류 메시지

## 🛠 구현 상세

### 1. 리스트 하단 "뿌리기" 기능

```dart
class _PostDeployScreenState extends State<PostDeployScreen> {
  // ... 기존 코드 ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('마커 뿌리기'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 상단 정보 영역
          _buildLocationInfo(),

          // 포스트 선택 리스트 (확장 가능)
          Expanded(
            child: _buildPostList(),
          ),

          // 하단 고정 뿌리기 영역
          _buildBottomDeploySection(),
        ],
      ),
    );
  }

  Widget _buildPostList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '뿌릴 포스트 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _userPosts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _userPosts.length,
                        itemBuilder: (context, index) {
                          final post = _userPosts[index];
                          return _buildPostCard(post);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post) {
    final isSelected = _selectedPost?.postId == post.postId;

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onPostSelected(post),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 포스트 썸네일
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: post.thumbnailUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              post.thumbnailUrl.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.image, color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.post_add, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 12),

                  // 포스트 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${post.reward}원',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${post.mediaType.join(', ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 선택 표시
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue[400],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDeploySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 선택된 포스트 요약
              if (_selectedPost != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '선택된 포스트: ${_selectedPost!.title}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${_selectedPost!.reward}원',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                ),

              // 배포 설정 (간소화)
              Row(
                children: [
                  // 수량 설정
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: '수량',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 기간 설정
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedDuration,
                      decoration: const InputDecoration(
                        labelText: '기간',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: _durationOptions.map((duration) {
                        return DropdownMenuItem(
                          value: duration,
                          child: Text('${duration}일'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDuration = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 총 비용 및 뿌리기 버튼
              Row(
                children: [
                  // 총 비용 표시
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '총 비용',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            '${_totalPrice.toStringAsFixed(0)}원',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // 뿌리기 버튼
                  SizedBox(
                    width: 120,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _selectedPost != null && !_isDeploying
                          ? _deployPostToLocation
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isDeploying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '뿌리기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2. 이미지 업로드 제한 해제

이미지 업로드 제한을 찾기 위해 관련 파일들을 조사해야 합니다:

```dart
// 이미지 업로드 관련 파일 조사 필요
// 1. 포스트 생성 화면
// 2. 이미지 선택/업로드 서비스
// 3. 이미지 압축/리사이징 로직

// 정사각형 제한 해제 예시:
// 기존: AspectRatio 고정 또는 이미지 크롭
// 개선: 원본 비율 유지 또는 사용자 선택 가능
```

### 3. 배포 진행 상태 표시

```dart
Future<void> _deployPostToLocation() async {
  if (_selectedPost == null) {
    _showErrorMessage('포스트를 선택해주세요.');
    return;
  }

  setState(() {
    _isDeploying = true;
  });

  try {
    // 진행 상태 다이얼로그 표시
    _showDeployProgressDialog();

    // 배포 로직 실행
    final result = await _performDeployment();

    // 성공 피드백
    _showSuccessDialog(result);

  } catch (e) {
    _showErrorDialog(e.toString());
  } finally {
    setState(() {
      _isDeploying = false;
    });
  }
}

void _showDeployProgressDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('마커 뿌리는 중...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '${_selectedPost!.title} 마커를 배포하고 있습니다.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

## 📊 테스트 시나리오

### 시나리오 1: 마커 선택 및 뿌리기
1. PostDeployScreen 진입
2. 포스트 목록에서 하나 선택
3. 하단에 선택된 포스트 정보 표시 확인
4. 수량/기간 설정
5. "뿌리기" 버튼으로 배포 실행

### 시나리오 2: 이미지 업로드 제한 해제
1. 포스트 생성 화면 진입
2. 다양한 비율의 이미지 업로드 테스트
   - 가로형 이미지 (16:9)
   - 세로형 이미지 (9:16)
   - 정사각형 이미지 (1:1)
3. 모든 비율 이미지 업로드 성공 확인

### 시나리오 3: 오류 처리
1. 네트워크 연결 없이 배포 시도
2. 잘못된 데이터로 배포 시도
3. 적절한 오류 메시지 표시 확인

## 📝 체크리스트

### 개발 단계
- [ ] 하단 고정 "뿌리기" 영역 구현
- [ ] 포스트 선택 카드 UI 개선
- [ ] 이미지 업로드 제한 조사 및 해제
- [ ] 배포 진행 상태 표시 구현
- [ ] 오류 처리 강화

### 테스트 단계
- [ ] 다양한 화면 크기에서 UI 테스트
- [ ] 이미지 비율별 업로드 테스트
- [ ] 배포 프로세스 전체 테스트
- [ ] 오류 시나리오 테스트

### 배포 단계
- [ ] 코드 리뷰 완료
- [ ] QA 검증 완료
- [ ] 프로덕션 배포

## 🚨 위험 요소 및 대응 방안

### 위험 요소
1. **UI 복잡성 증가**: 하단 고정 영역으로 인한 레이아웃 복잡성
2. **이미지 처리 성능**: 다양한 비율 이미지 처리로 인한 성능 영향
3. **배포 실패 처리**: 네트워크 오류 등으로 인한 배포 실패

### 대응 방안
1. **레이아웃 최적화**: Flexible, Expanded 위젯 적절한 사용
2. **이미지 최적화**: 적절한 압축 및 캐싱 전략
3. **견고한 오류 처리**: 재시도 메커니즘 및 명확한 피드백

## 📅 일정 계획

| 단계 | 작업 내용 | 예상 소요 시간 | 마감일 |
|------|-----------|---------------|--------|
| 분석 | 현재 상태 분석 완료 | 0.5일 | ✅ 완료 |
| UI 개선 | 하단 뿌리기 영역 구현 | 1일 | TBD |
| 제한 해제 | 이미지 업로드 제한 해제 | 0.5일 | TBD |
| 오류 처리 | 배포 과정 오류 처리 강화 | 0.5일 | TBD |
| 테스트 | 통합 테스트 및 검증 | 0.5일 | TBD |

**총 예상 기간**: 3일

---

*작성일: 2025-09-30*
*최종 수정일: 2025-09-30*