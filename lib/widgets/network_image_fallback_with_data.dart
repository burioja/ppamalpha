import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 썸네일 URL 생성 함수
String _getThumbnailUrl(String originalUrl, {int width = 200, int height = 200, int quality = 85}) {
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(originalUrl)}&w=$width&h=$height&fit=cover&q=$quality';
}

Widget buildNetworkImage(String url) {
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
    errorWidget: (context, url, error) => Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.broken_image,
          size: 24,
          color: Colors.grey.shade500,
        ),
      ),
    ),
  );
}

// 고화질 원본 이미지 로딩 함수 (Fallback 포함) - 데이터 기반
Widget buildHighQualityImageWithData(String url, List<String>? thumbnailUrls, int imageIndex) {
  debugPrint('고화질 원본 이미지 로딩 시도: $url, 인덱스: $imageIndex');
  
  // 먼저 썸네일부터 시도 (더 안정적)
  String? correctThumbnailUrl;
  if (thumbnailUrls != null && imageIndex < thumbnailUrls.length) {
    correctThumbnailUrl = thumbnailUrls[imageIndex];
  }
  
  debugPrint('사용할 썸네일 URL: $correctThumbnailUrl');
  
  // CORS 문제 해결을 위해 웹 프록시 사용
  if (correctThumbnailUrl != null && correctThumbnailUrl.isNotEmpty) {
    return _buildImageWithWebProxy(
      primaryUrl: correctThumbnailUrl, // 썸네일을 primary로
      fallbackUrl: url, // 원본을 fallback으로  
      isPrimary: false, // 썸네일이므로 false
    );
  }
  
  // 썸네일이 없으면 원본만 시도
  return _buildImageWithWebProxy(
    primaryUrl: url,
    fallbackUrl: null,
    isPrimary: true,
  );
}

// 웹 프록시를 사용하는 이미지 빌더 (CORS 문제 해결)
Widget _buildImageWithWebProxy({
  required String primaryUrl,
  String? fallbackUrl,
  required bool isPrimary,
}) {
  final label = isPrimary ? '원본' : '썸네일';
  debugPrint('$label 이미지 로딩 시도: $primaryUrl');
  
  // CORS 문제 해결을 위해 웹 프록시 사용
  final proxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(primaryUrl)}&output=png&w=800&h=800&fit=inside';
  debugPrint('$label 이미지 웹 프록시 사용: $proxyUrl');
  
  return Image.network(
    proxyUrl,
    fit: BoxFit.cover,
    width: double.infinity,
    height: double.infinity,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) {
        return Stack(
          children: [
            child,
            if (!isPrimary) // 썸네일인 경우 표시
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.8),
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
        color: Colors.grey.shade100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
              const SizedBox(height: 8),
              Text('$label 이미지 로딩 중...',
                style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    },
    errorBuilder: (context, error, stackTrace) {
      debugPrint('$label 이미지 로드 실패: $primaryUrl - 에러: $error');
      
      // Fallback URL이 있으면 시도
      if (fallbackUrl != null && fallbackUrl != primaryUrl) {
        final fallbackLabel = isPrimary ? '썸네일' : '원본';
        debugPrint('$fallbackLabel Fallback 시도: $fallbackUrl');
        
        final fallbackProxyUrl = 'https://images.weserv.nl/?url=${Uri.encodeComponent(fallbackUrl)}&output=png&w=800&h=800&fit=inside';
        debugPrint('$fallbackLabel Fallback 웹 프록시 사용: $fallbackProxyUrl');
        
        return Image.network(
          fallbackProxyUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
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
                      child: Text(
                        fallbackLabel,
                        style: const TextStyle(
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
              color: Colors.grey.shade100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text('$fallbackLabel 로딩 중...',
                      style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('$fallbackLabel Fallback도 실패: $fallbackUrl - $error');
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
      
      // Fallback이 없거나 실패한 경우
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.broken_image,
                size: 60,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              Text('$label 이미지를 불러올 수 없습니다'),
            ],
          ),
        ),
      );
    },
  );
}

// 기존 buildHighQualityImage는 하위 호환성을 위해 유지 (매개변수 없이)
Widget buildHighQualityImage(String url) {
  return buildHighQualityImageWithData(url, null, 0);
}