import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../utils/web/web_dom_stub.dart'
    if (dart.library.html) '../../../utils/web/web_dom.dart';

/// 포스트 상세 화면의 이미지 관련 위젯들
class PostDetailImageWidgets {
  final PostModel post;
  final FirebaseService firebaseService;

  PostDetailImageWidgets({
    required this.post,
    required this.firebaseService,
  });

  // 메인 포스트 이미지 위젯
  Widget buildMainPostImage(
    BuildContext context,
    String Function(String, int) findOriginalImageUrl,
    Future<String?> Function(String, FirebaseService) resolveImageUrlConditionally,
  ) {
    print('\n========== [_buildMainPostImage] 시작 ==========');
    
    // 첫 번째 이미지 찾기 (원본 이미지 사용)
    final firstImageIndex = post.mediaType.indexOf('image');
    if (firstImageIndex == -1 || firstImageIndex >= post.mediaUrl.length) {
      print('이미지 없음: firstImageIndex=$firstImageIndex, mediaUrl.length=${post.mediaUrl.length}');
      return const SizedBox.shrink(); // 이미지가 없으면 표시하지 않음
    }

    // 원본 이미지 URL 찾기: mediaUrl에서 원본 이미지를 찾거나 원본 URL 생성
    String imageUrl = post.mediaUrl[firstImageIndex].toString();
    
    // 상세 디버그 로그 추가
    print('=== [MainPostImage] 데이터 구조 분석 ===');
    print('[MainPostImage] firstImageIndex: $firstImageIndex');
    print('[MainPostImage] 기본 이미지 URL: $imageUrl');
    print('[MainPostImage] mediaType: ${post.mediaType}');
    print('[MainPostImage] mediaUrl 길이: ${post.mediaUrl.length}');
    for (int i = 0; i < post.mediaUrl.length; i++) {
      print('[MainPostImage] mediaUrl[$i]: ${post.mediaUrl[i]}');
    }
    print('[MainPostImage] thumbnailUrl 길이: ${post.thumbnailUrl.length}');
    for (int i = 0; i < post.thumbnailUrl.length; i++) {
      print('[MainPostImage] thumbnailUrl[$i]: ${post.thumbnailUrl[i]}');
    }
    print('[MainPostImage] URL 패턴 분석:');
    print('  - HTTP/HTTPS: ${imageUrl.startsWith('http')}');
    print('  - Data URL: ${imageUrl.startsWith('data:image/')}');
    print('  - Contains /thumbnails/: ${imageUrl.contains('/thumbnails/')}');
    print('  - Contains %2Fthumbnails%2F: ${imageUrl.contains('%2Fthumbnails%2F')}');
    print('  - Contains /original/: ${imageUrl.contains('/original/')}');
    print('  - Contains %2Foriginal%2F: ${imageUrl.contains('%2Foriginal%2F')}');
    
    // 원본 이미지 URL 찾기 로직
    String originalImageUrl = findOriginalImageUrl(imageUrl, firstImageIndex);
    print('[MainPostImage] 최종 원본 URL: $originalImageUrl');

    return Container(
      width: double.infinity,
      height: 300, // 대형 이미지 크기
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<String?>(
          future: resolveImageUrlConditionally(originalImageUrl, firebaseService),
          builder: (context, snapshot) {
            final effectiveUrl = snapshot.data ?? originalImageUrl;
            print('[MainPostImage] resolveImageUrl 결과: $effectiveUrl');
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // 상세화면에서는 원본 이미지 우선 사용, 실패 시 썸네일 사용
            return buildReliableImage(effectiveUrl, 0);
          },
        ),
      ),
    );
  }

  // 안정적인 이미지 위젯 (원본 우선, 실패 시 썸네일 사용)
  Widget buildReliableImage(String url, int imageIndex) {
    print('=== [_buildReliableImage] 시작 ===');
    print('URL: $url');
    print('이미지 인덱스: $imageIndex');

    // 1. Data URL (base64) 처리
    if (url.startsWith('data:image/')) {
      print('타입: Data URL - 직접 base64 디코딩');
      try {
        final base64Data = url.split(',').last;
        final bytes = base64Decode(base64Data);
        return Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                print('Data URL 이미지 로딩 실패: $error');
                return buildImageErrorPlaceholder('Data 이미지를 불러올 수 없습니다');
              },
            ),
          ),
        );
      } catch (e) {
        print('Data URL 처리 실패: $e');
        return buildImageErrorPlaceholder('이미지 데이터가 손상되었습니다');
      }
    }

    // 2. HTTP URL 처리 - 다단계 fallback 사용
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Container(
        width: double.infinity,
        height: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: buildNetworkImageWithFallback(url, imageIndex),
        ),
      );
    }

    // 3. 지원되지 않는 형식
    print('지원되지 않는 URL 형식: $url');
    return buildImageErrorPlaceholder('지원되지 않는 이미지 형식');
  }

  // 네트워크 이미지 다단계 fallback
  Widget buildNetworkImageWithFallback(String primaryUrl, int imageIndex) {
    print('네트워크 이미지 로딩 시도: $primaryUrl');

    return Image.network(
      primaryUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;

        return Container(
          color: Colors.grey.shade100,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
                const SizedBox(height: 8),
                Text('고화질 이미지 로딩 중...', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('1차 이미지 로딩 실패: $primaryUrl - $error');

        // Fallback 1: 썸네일 URL 시도
        if (imageIndex < post.thumbnailUrl.length) {
          final thumbnailUrl = post.thumbnailUrl[imageIndex];
          print('Fallback 1: 썸네일 URL 시도 - $thumbnailUrl');

          return Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error2, stackTrace2) {
              print('2차 썸네일 로딩 실패: $thumbnailUrl - $error2');

              // Fallback 2: 웹 프록시 사용
              final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(primaryUrl)}&w=800&h=600&fit=cover&q=85';
              print('Fallback 2: 웹 프록시 시도 - $proxyUrl');

              return Image.network(
                proxyUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error3, stackTrace3) {
                  print('3차 프록시 로딩 실패: $proxyUrl - $error3');
                  return buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
                },
              );
            },
          );
        }

        // Fallback: 프록시 직접 시도
        final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(primaryUrl)}&w=800&h=600&fit=cover&q=85';
        print('직접 프록시 시도: $proxyUrl');

        return Image.network(
          proxyUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error2, stackTrace2) {
            print('프록시도 실패: $error2');
            return buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
          },
        );
      },
    );
  }

  // 고화질 원본 이미지 위젯 (상단 메인 플라이어용)
  Widget buildHighQualityOriginalImage(String url) {
    print('=== [_buildHighQualityOriginalImage] 시작 ===');
    print('로딩할 URL: $url');
    
    // Data URL 처리
    if (url.startsWith('data:image/')) {
      print('타입: Data URL - base64 이미지 사용');
      try {
        final base64Data = url.split(',').last;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (e) {
        print('에러: Data URL 처리 실패 - $e');
        return buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
      }
    }
    
    // HTTP URL 처리 - 고화질 원본 이미지 직접 로드
    if (url.startsWith('http://') || url.startsWith('https://')) {
      print('타입: HTTP URL - 네트워크 이미지 로딩');
      print('  - 원본 경로 포함: ${url.contains('/original/')}');
      print('  - 썸네일 경로 포함: ${url.contains('/thumbnails/')}');
      
      return Image.network(
        url, // 원본 URL 직접 사용 (썸네일 변환 없이)
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('이미지 로딩 완료: $url');
            return child;
          }
          final progress = loadingProgress.expectedTotalBytes != null
              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
              : null;
          print('이미지 로딩 중: ${(progress ?? 0 * 100).toStringAsFixed(1)}%');
          return Container(
            color: Colors.grey.shade200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('고화질 원본 로딩 중...', 
                    style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('에러: 고화질 이미지 로드 실패');
          print('  URL: $url');
          print('  에러: $error');
          print('  스택트레이스: $stackTrace');
          return buildImageErrorPlaceholderWithFallback(url);
        },
      );
    }
    
    // 지원되지 않는 URL 형식
    print('에러: 지원되지 않는 URL 형식 - $url');
    return buildImageErrorPlaceholder('지원되지 않는 이미지 형식');
  }

  // 이미지 에러 플레이스홀더 (Fallback 로직 포함)
  Widget buildImageErrorPlaceholderWithFallback(String failedUrl) {
    print('=== [_buildImageErrorPlaceholderWithFallback] Fallback 시도 ===');
    print('실패한 URL: $failedUrl');
    
    // 원본 이미지 실패 시 썸네일로 대체 시도
    if (failedUrl.contains('/original/') || failedUrl.contains('%2Foriginal%2F')) {
      final thumbnailUrl = failedUrl
        .replaceAll('/original/', '/thumbnails/')
        .replaceAll('%2Foriginal%2F', '%2Fthumbnails%2F');
      print('Fallback: 썸네일 URL로 시도 - $thumbnailUrl');
      
      return Image.network(
        thumbnailUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('Fallback 성공: 썸네일 로딩 완료');
            return Stack(
              children: [
                child,
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '썸네일',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('썸네일 로딩 중...',
                    style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Fallback 실패: 썸네일도 로드 실패');
          return buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
        },
      );
    }
    
    // Fallback도 실패한 경우 기본 에러 플레이스홀더
    return buildImageErrorPlaceholder('이미지를 불러올 수 없습니다');
  }

  // 기본 이미지 에러 플레이스홀더
  Widget buildImageErrorPlaceholder(String message) {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: 60,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 사용자 친화적인 미디어 접근 버튼들
  Widget buildMediaAccessButtons(
    BuildContext context,
    void Function(List<int>) showImageGallery,
    Future<void> Function(String) openExternalUrl,
  ) {
    final List<Widget> buttons = [];
    
    // 이미지 보기 버튼들
    final imageIndices = <int>[];
    for (int i = 0; i < post.mediaType.length; i++) {
      if (post.mediaType[i] == 'image') {
        imageIndices.add(i);
      }
    }
    
    if (imageIndices.length > 1) {
      // 첫 번째 이미지는 이미 위에 대형으로 표시되므로, 추가 이미지들만 버튼으로 제공
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => showImageGallery(imageIndices),
          icon: const Icon(Icons.photo_library, color: Colors.white),
          label: Text(
            '모든 이미지 보기 (${imageIndices.length}장)',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }
    
    // 오디오 재생 버튼들
    for (int i = 0; i < post.mediaType.length; i++) {
      if (post.mediaType[i] == 'audio') {
        final audioUrl = post.mediaUrl[i].toString();
        buttons.add(
          OutlinedButton.icon(
            onPressed: () async {
              final resolvedUrl = await firebaseService.resolveImageUrl(audioUrl);
              if (resolvedUrl != null) {
                await openExternalUrl(resolvedUrl);
              }
            },
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            label: const Text(
              '오디오 재생',
              style: TextStyle(color: Colors.green),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        );
      }
    }
    
    return buttons.isEmpty 
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 12,
          runSpacing: 8,
          children: buttons,
        );
  }
}

// 원본 이미지 URL 찾기 헬퍼 함수
String findOriginalImageUrl(PostModel post, String baseUrl, int imageIndex) {
  print('=== [_findOriginalImageUrl] 분석 시작 ===');
  print('baseUrl: $baseUrl');
  print('imageIndex: $imageIndex');
  
  // 1. 우선: baseUrl(mediaUrl)이 이미 원본 URL인지 확인
  if (baseUrl.contains('/original/') || baseUrl.contains('%2Foriginal%2F')) {
    print('기본 mediaUrl이 이미 원본 URL임: $baseUrl');
    return baseUrl; // 이미 원본 URL이므로 그대로 사용
  }
  
  // 2. mediaUrl이 썸네일이면 원본 URL로 변경
  if (baseUrl.contains('/thumbnails/') || baseUrl.contains('%2Fthumbnails%2F')) {
    final originalUrl = baseUrl
      .replaceAll('/thumbnails/', '/original/')
      .replaceAll('%2Fthumbnails%2F', '%2Foriginal%2F');
    print('mediaUrl이 썸네일이므로 원본 URL로 변경: $originalUrl');
    return originalUrl;
  }
  
  // 3. thumbnailUrl 배열에서 원본 URL 생성 시도 (마지막 수단)
  if (post.thumbnailUrl.isNotEmpty && imageIndex < post.thumbnailUrl.length) {
    final thumbnailUrl = post.thumbnailUrl[imageIndex];
    if (thumbnailUrl.contains('/thumbnails/') || thumbnailUrl.contains('%2Fthumbnails%2F')) {
      final originalUrl = thumbnailUrl
        .replaceAll('/thumbnails/', '/original/')
        .replaceAll('%2Fthumbnails%2F', '%2Foriginal%2F');
      print('마지막 수단: thumbnailUrl에서 원본 URL 생성: $originalUrl');
      return originalUrl;
    }
  }
  
  // 4. 모두 실패한 경우 기본 URL 사용
  print('기본 URL 그대로 사용: $baseUrl');
  return baseUrl;
}

// 조건부 URL 해석 헬퍼 함수
Future<String?> resolveImageUrlConditionally(String url, FirebaseService service) async {
  print('=== [_resolveImageUrlConditionally] 분석 ===');
  print('입력 URL: $url');
  
  // HTTP/HTTPS URL이면 그대로 사용 (이중 처리 방지)
  if (url.startsWith('http://') || url.startsWith('https://')) {
    print('HTTP URL이므로 resolveImageUrl 생략');
    return url;
  }
  
  // Data URL이면 그대로 사용
  if (url.startsWith('data:image/')) {
    print('Data URL이므로 resolveImageUrl 생략');
    return url;
  }
  
  // 그 외의 경우만 Firebase 해석 사용
  print('Firebase resolveImageUrl 사용');
  final resolved = await service.resolveImageUrl(url);
  print('해석 결과: $resolved');
  return resolved;
}


