import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 썸네일 URL 생성 함수
String _getThumbnailUrl(String originalUrl, {int width = 200, int height = 200, int quality = 85}) {
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(originalUrl)}&w=$width&h=$height&fit=cover&q=$quality';
}

Widget buildNetworkImage(String url) {
  debugPrint('썸네일 이미지 로딩 시도: $url');
  
  // 썸네일 URL 생성
  final thumbnailUrl = _getThumbnailUrl(url);
  
  return CachedNetworkImage(
    imageUrl: thumbnailUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    memCacheHeight: 200,
    memCacheWidth: 200,
    placeholder: (context, url) => Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image,
          size: 24,
          color: Colors.grey.shade400,
        ),
      ),
    ),
    errorWidget: (context, url, error) {
      debugPrint('썸네일 이미지 로드 실패: $url - 에러: $error');
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Icon(
            Icons.broken_image,
            size: 24,
            color: Colors.grey.shade500,
          ),
        ),
      );
    },
  );
}

// 고화질 원본 이미지 로딩 함수 (Fallback 포함)
Widget buildHighQualityImage(String url) {
  debugPrint('고화질 원본 이미지 로딩 시도: $url');
  
  // 원본 이미지를 직접 로딩 (썸네일 변환 없이)
  return CachedNetworkImage(
    imageUrl: url, // 원본 URL 직접 사용
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    memCacheHeight: 800, // 고화질 캐시
    memCacheWidth: 800,
    placeholder: (context, url) => Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('고화질 이미지 로딩 중...'),
          ],
        ),
      ),
    ),
    errorWidget: (context, url, error) {
      debugPrint('고화질 이미지 로드 실패: $url - 에러: $error');
      debugPrint('썸네일로 Fallback 시도...');
      
      // Fallback: 원본 실패 시 올바른 썸네일 URL 사용 (매개변수 필요)
      debugPrint('원본 이미지 실패, Fallback 시도 - 하지만 thumbnailUrls 정보 없음');
      
      // 기본 경로 변환으로 시도 (토큰 문제 가능)
      String? thumbnailUrl;
      if (url.contains('%2Foriginal%2F')) {
        thumbnailUrl = url.replaceAll('%2Foriginal%2F', '%2Fthumbnails%2F');
      } else if (url.contains('/original/')) {
        thumbnailUrl = url.replaceAll('/original/', '/thumbnails/');
      }
      
      if (thumbnailUrl != null && thumbnailUrl != url) {
        debugPrint('기본 경로 변환 시도 (토큰 불일치 위험): $thumbnailUrl');
        return CachedNetworkImage(
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          memCacheHeight: 400,
          memCacheWidth: 400,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade100,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('Fallback 썸네일도 실패: $thumbnailUrl - $error');
            return Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text('이미지를 불러올 수 없습니다'),
                  ],
                ),
              ),
            );
          },
        );
      }
      
      // 기본 오류 표시
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 60,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text('고화질 이미지를 불러올 수 없습니다'),
            ],
          ),
        ),
      );
    },
  );
}

// Fallback URL 생성 함수 - 올바른 썸네일 토큰 사용
String? _buildThumbnailFallbackUrl(String originalUrl, List<String>? thumbnailUrls, int imageIndex) {
  debugPrint('Fallback URL 생성 시도 - 원본: $originalUrl, 인덱스: $imageIndex');
  
  // 1. 우선: thumbnailUrls 배열에서 해당 인덱스의 올바른 썸네일 URL 사용
  if (thumbnailUrls != null && imageIndex < thumbnailUrls.length) {
    final correctThumbnailUrl = thumbnailUrls[imageIndex];
    if (correctThumbnailUrl.isNotEmpty) {
      debugPrint('올바른 썸네일 URL 사용: $correctThumbnailUrl');
      return correctThumbnailUrl;
    }
  }
  
  // 2. Fallback: URL 경로 변환 (토큰은 틀릴 수 있음)
  if (originalUrl.contains('%2Foriginal%2F')) {
    final converted = originalUrl.replaceAll('%2Foriginal%2F', '%2Fthumbnails%2F');
    debugPrint('URL 경로 변환 (토큰 불일치 가능): $converted');
    return converted;
  }
  if (originalUrl.contains('/original/')) {
    final converted = originalUrl.replaceAll('/original/', '/thumbnails/');
    debugPrint('URL 경로 변환 (토큰 불일치 가능): $converted');
    return converted;
  }
  
  debugPrint('Fallback URL 생성 불가');
  return null;
}