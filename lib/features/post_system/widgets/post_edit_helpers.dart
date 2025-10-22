import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../../../core/models/post/post_model.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/data/place_service.dart';
import '../../../core/services/auth/firebase_service.dart';
import '../../../core/services/storage/storage_service.dart';
import '../../../core/utils/logger.dart';

/// 포스트 편집 화면의 헬퍼 함수들
class PostEditHelpers {
  // 포스트 데이터 로드
  static Future<PostModel?> loadPost(String postId) async {
    try {
      final postService = PostService();
      final post = await postService.getPostById(postId);
      
      if (post != null) {
        Logger.info('📝 Post loaded: ${post.title}');
        Logger.info('🖼️ Media count: ${post.mediaUrl.length}');
        
        if (post.mediaUrl.isNotEmpty) {
          for (int i = 0; i < post.mediaUrl.length; i++) {
            final imageUrl = post.mediaUrl[i];
            final preview = imageUrl.length > 100 
                ? '${imageUrl.substring(0, 100)}...' 
                : imageUrl;
            Logger.info('  Image[$i]: $preview');
          }
        }
      }
      
      return post;
    } catch (e) {
      Logger.error('포스트 로드 실패: $e');
      return null;
    }
  }

  // 플레이스 데이터 로드
  static Future<PlaceModel?> loadPlace(String placeId) async {
    try {
      final placeService = PlaceService();
      final place = await placeService.getPlaceById(placeId);
      
      if (place != null) {
        Logger.info('📍 Place loaded: ${place.name}');
      }
      
      return place;
    } catch (e) {
      Logger.error('플레이스 로드 실패: $e');
      return null;
    }
  }

  // 포스트 데이터 업데이트
  static Future<bool> updatePost(String postId, Map<String, dynamic> data) async {
    try {
      final postService = PostService();
      await postService.updatePost(postId, data);
      Logger.info('포스트 업데이트 성공: $postId');
      return true;
    } catch (e) {
      Logger.error('포스트 업데이트 실패: $e');
      return false;
    }
  }

  // 이미지 업로드
  static Future<String?> uploadImage(Uint8List imageData, String fileName) async {
    try {
      final storageService = StorageService();
      final imageUrl = await storageService.uploadImageBytesWithThumbnail(
        imageData,
        'posts',
        fileName,
      );
      Logger.info('이미지 업로드 성공: $fileName');
      return imageUrl;
    } catch (e) {
      Logger.error('이미지 업로드 실패: $e');
      return null;
    }
  }

  // 이미지 삭제
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final storageService = StorageService();
      await storageService.deleteImage(imageUrl);
      Logger.info('이미지 삭제 성공: $imageUrl');
      return true;
    } catch (e) {
      Logger.error('이미지 삭제 실패: $e');
      return false;
    }
  }

  // 포스트 상태 업데이트
  static Future<bool> updatePostStatus(String postId, PostStatus status) async {
    try {
      final postService = PostService();
      await postService.updatePostStatus(postId, status);
      Logger.info('포스트 상태 업데이트 성공: $postId -> $status');
      return true;
    } catch (e) {
      Logger.error('포스트 상태 업데이트 실패: $e');
      return false;
    }
  }

  // 포스트 삭제
  static Future<bool> deletePost(String postId) async {
    try {
      final postService = PostService();
      // TODO: deletePost 메소드 구현 필요
      // await postService.deletePost(postId);
      
      // 임시로 상태만 DELETED로 변경
      await postService.updatePostStatus(postId, PostStatus.DELETED);
      Logger.info('포스트 삭제 성공: $postId');
      return true;
    } catch (e) {
      Logger.error('포스트 삭제 실패: $e');
      return false;
    }
  }

  // 포스트 검증
  static String? validatePost({
    required String title,
    required String content,
    required String reward,
    required List<String> imageUrls,
    required String placeId,
  }) {
    if (title.trim().isEmpty) {
      return '제목을 입력해주세요.';
    }
    
    if (content.trim().isEmpty) {
      return '내용을 입력해주세요.';
    }
    
    if (reward.trim().isEmpty) {
      return '보상을 입력해주세요.';
    }
    
    if (imageUrls.isEmpty) {
      return '최소 1개의 이미지를 업로드해주세요.';
    }
    
    if (placeId.isEmpty) {
      return '플레이스를 선택해주세요.';
    }
    
    return null;
  }

  // 포스트 데이터 생성
  static Map<String, dynamic> buildPostData({
    required String title,
    required String content,
    required String reward,
    required List<String> imageUrls,
    required String placeId,
    required List<String> selectedGenders,
    required RangeValues selectedAgeRange,
    required int selectedPeriod,
    required String selectedFunction,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    String? youtubeUrl,
  }) {
    return {
      'title': title.trim(),
      'content': content.trim(),
      'reward': reward.trim(),
      'imageUrls': imageUrls,
      'placeId': placeId,
      'targetGenders': selectedGenders,
      'targetAgeRange': {
        'min': selectedAgeRange.start.round(),
        'max': selectedAgeRange.end.round(),
      },
      'period': selectedPeriod,
      'function': selectedFunction,
      'canRespond': canRespond,
      'canForward': canForward,
      'canRequestReward': canRequestReward,
      'youtubeUrl': youtubeUrl?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // 포스트 미리보기 데이터 생성
  static Map<String, dynamic> buildPreviewData({
    required String title,
    required String content,
    required String reward,
    required List<String> imageUrls,
    required String placeName,
    required List<String> selectedGenders,
    required RangeValues selectedAgeRange,
    required int selectedPeriod,
    required String selectedFunction,
    required bool canRespond,
    required bool canForward,
    required bool canRequestReward,
    String? youtubeUrl,
  }) {
    return {
      'title': title,
      'content': content,
      'reward': reward,
      'imageCount': imageUrls.length,
      'placeName': placeName,
      'targetGenders': selectedGenders.join(', '),
      'targetAgeRange': '${selectedAgeRange.start.round()}세 - ${selectedAgeRange.end.round()}세',
      'period': '${selectedPeriod}일',
      'function': selectedFunction,
      'canRespond': canRespond ? '가능' : '불가능',
      'canForward': canForward ? '가능' : '불가능',
      'canRequestReward': canRequestReward ? '가능' : '불가능',
      'youtubeUrl': youtubeUrl ?? '없음',
    };
  }

  // 성별 선택 포맷팅
  static String formatGenderSelection(List<String> genders) {
    if (genders.isEmpty) {
      return '성별 제한 없음';
    }
    
    final List<String> formattedGenders = [];
    for (final gender in genders) {
      switch (gender) {
        case 'male':
          formattedGenders.add('남성');
          break;
        case 'female':
          formattedGenders.add('여성');
          break;
        case 'other':
          formattedGenders.add('기타');
          break;
      }
    }
    
    return formattedGenders.join(', ');
  }

  // 나이 범위 포맷팅
  static String formatAgeRange(RangeValues ageRange) {
    return '${ageRange.start.round()}세 - ${ageRange.end.round()}세';
  }

  // 기간 포맷팅
  static String formatPeriod(int period) {
    return '${period}일';
  }

  // 기능 포맷팅
  static String formatFunction(String function) {
    switch (function) {
      case 'Using':
        return '사용';
      case 'Selling':
        return '판매';
      case 'Buying':
        return '구매';
      case 'Sharing':
        return '공유';
      default:
        return function;
    }
  }

  // 응답 가능 여부 포맷팅
  static String formatCanRespond(bool canRespond) {
    return canRespond ? '가능' : '불가능';
  }

  // 전달 가능 여부 포맷팅
  static String formatCanForward(bool canForward) {
    return canForward ? '가능' : '불가능';
  }

  // 보상 요청 가능 여부 포맷팅
  static String formatCanRequestReward(bool canRequestReward) {
    return canRequestReward ? '가능' : '불가능';
  }

  // YouTube URL 포맷팅
  static String formatYoutubeUrl(String? youtubeUrl) {
    if (youtubeUrl == null || youtubeUrl.trim().isEmpty) {
      return '없음';
    }
    return youtubeUrl.trim();
  }

  // 이미지 URL 유효성 검사
  static bool isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // 이미지 로딩 에러 처리
  static Widget buildImageErrorWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }

  // 이미지 로딩 위젯
  static Widget buildImageLoadingWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 빈 이미지 위젯
  static Widget buildEmptyImageWidget() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }

  // 포스트 상태 포맷팅
  static String formatPostStatus(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return '초안';
      case PostStatus.DEPLOYED:
        return '배포됨';
      case PostStatus.RECALLED:
        return '회수됨';
      case PostStatus.DELETED:
        return '삭제됨';
      case PostStatus.EXPIRED:
        return '만료됨';
    }
  }

  // 포스트 상태 색상
  static Color getPostStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return Colors.orange;
      case PostStatus.DEPLOYED:
        return Colors.green;
      case PostStatus.RECALLED:
        return Colors.red;
      case PostStatus.DELETED:
        return Colors.grey;
      case PostStatus.EXPIRED:
        return Colors.grey[600]!;
    }
  }

  // 포스트 상태 아이콘
  static IconData getPostStatusIcon(PostStatus status) {
    switch (status) {
      case PostStatus.DRAFT:
        return Icons.edit;
      case PostStatus.DEPLOYED:
        return Icons.publish;
      case PostStatus.RECALLED:
        return Icons.undo;
      case PostStatus.DELETED:
        return Icons.delete;
      case PostStatus.EXPIRED:
        return Icons.schedule;
    }
  }

  // 포스트 생성일 포맷팅
  static String formatCreatedAt(DateTime? createdAt) {
    if (createdAt == null) {
      return '생성일 정보 없음';
    }
    return '${createdAt.year}년 ${createdAt.month}월 ${createdAt.day}일';
  }

  // 포스트 업데이트일 포맷팅
  static String formatUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) {
      return '업데이트일 정보 없음';
    }
    return '${updatedAt.year}년 ${updatedAt.month}월 ${updatedAt.day}일';
  }

  // 포스트 소유자 ID 포맷팅
  static String formatOwnerId(String? ownerId) {
    if (ownerId == null || ownerId.isEmpty) {
      return '소유자 정보 없음';
    }
    return ownerId;
  }

  // 포스트 플레이스 ID 포맷팅
  static String formatPlaceId(String? placeId) {
    if (placeId == null || placeId.isEmpty) {
      return '플레이스 정보 없음';
    }
    return placeId;
  }

  // 포스트 위치 정보 포맷팅
  static String formatLocation(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return '위치 정보 없음';
    }
    return '위도: ${latitude.toStringAsFixed(6)}, 경도: ${longitude.toStringAsFixed(6)}';
  }

  // 포스트 수집 수 포맷팅
  static String formatCollectionCount(int? collectionCount) {
    if (collectionCount == null || collectionCount == 0) {
      return '수집 없음';
    }
    return '수집 ${collectionCount}개';
  }

  // 포스트 조회 수 포맷팅
  static String formatViewCount(int? viewCount) {
    if (viewCount == null || viewCount == 0) {
      return '조회 없음';
    }
    return '조회 ${viewCount}회';
  }

  // 포스트 응답 수 포맷팅
  static String formatResponseCount(int? responseCount) {
    if (responseCount == null || responseCount == 0) {
      return '응답 없음';
    }
    return '응답 ${responseCount}개';
  }

  // 포스트 전달 수 포맷팅
  static String formatForwardCount(int? forwardCount) {
    if (forwardCount == null || forwardCount == 0) {
      return '전달 없음';
    }
    return '전달 ${forwardCount}개';
  }

  // 포스트 보상 요청 수 포맷팅
  static String formatRewardRequestCount(int? rewardRequestCount) {
    if (rewardRequestCount == null || rewardRequestCount == 0) {
      return '보상 요청 없음';
    }
    return '보상 요청 ${rewardRequestCount}개';
  }

  // 포스트 보상 지급 수 포맷팅
  static String formatRewardPaidCount(int? rewardPaidCount) {
    if (rewardPaidCount == null || rewardPaidCount == 0) {
      return '보상 지급 없음';
    }
    return '보상 지급 ${rewardPaidCount}개';
  }

  // 포스트 보상 총액 포맷팅
  static String formatTotalRewardAmount(double? totalRewardAmount) {
    if (totalRewardAmount == null || totalRewardAmount == 0) {
      return '보상 총액 없음';
    }
    return '보상 총액 ${totalRewardAmount.toStringAsFixed(0)}원';
  }

  // 포스트 보상 평균 포맷팅
  static String formatAverageReward(double? averageReward) {
    if (averageReward == null || averageReward == 0) {
      return '보상 평균 없음';
    }
    return '보상 평균 ${averageReward.toStringAsFixed(0)}원';
  }

  // 포스트 보상 최대 포맷팅
  static String formatMaxReward(double? maxReward) {
    if (maxReward == null || maxReward == 0) {
      return '보상 최대 없음';
    }
    return '보상 최대 ${maxReward.toStringAsFixed(0)}원';
  }

  // 포스트 보상 최소 포맷팅
  static String formatMinReward(double? minReward) {
    if (minReward == null || minReward == 0) {
      return '보상 최소 없음';
    }
    return '보상 최소 ${minReward.toStringAsFixed(0)}원';
  }

  // 포스트 보상 중간값 포맷팅
  static String formatMedianReward(double? medianReward) {
    if (medianReward == null || medianReward == 0) {
      return '보상 중간값 없음';
    }
    return '보상 중간값 ${medianReward.toStringAsFixed(0)}원';
  }

  // 포스트 보상 표준편차 포맷팅
  static String formatRewardStandardDeviation(double? standardDeviation) {
    if (standardDeviation == null || standardDeviation == 0) {
      return '보상 표준편차 없음';
    }
    return '보상 표준편차 ${standardDeviation.toStringAsFixed(0)}원';
  }

  // 포스트 보상 분산 포맷팅
  static String formatRewardVariance(double? variance) {
    if (variance == null || variance == 0) {
      return '보상 분산 없음';
    }
    return '보상 분산 ${variance.toStringAsFixed(0)}원²';
  }

  // 포스트 보상 범위 포맷팅
  static String formatRewardRange(double? minReward, double? maxReward) {
    if (minReward == null || maxReward == null || minReward == 0 || maxReward == 0) {
      return '보상 범위 없음';
    }
    return '보상 범위 ${minReward.toStringAsFixed(0)}원 - ${maxReward.toStringAsFixed(0)}원';
  }

  // 포스트 보상 사분위수 포맷팅
  static String formatRewardQuartiles({
    double? q1,
    double? q2,
    double? q3,
  }) {
    if (q1 == null || q2 == null || q3 == null) {
      return '보상 사분위수 없음';
    }
    return 'Q1: ${q1.toStringAsFixed(0)}원, Q2: ${q2.toStringAsFixed(0)}원, Q3: ${q3.toStringAsFixed(0)}원';
  }

  // 포스트 보상 백분위수 포맷팅
  static String formatRewardPercentiles({
    double? p10,
    double? p25,
    double? p50,
    double? p75,
    double? p90,
  }) {
    if (p10 == null || p25 == null || p50 == null || p75 == null || p90 == null) {
      return '보상 백분위수 없음';
    }
    return 'P10: ${p10.toStringAsFixed(0)}원, P25: ${p25.toStringAsFixed(0)}원, P50: ${p50.toStringAsFixed(0)}원, P75: ${p75.toStringAsFixed(0)}원, P90: ${p90.toStringAsFixed(0)}원';
  }

  // 포스트 보상 히스토그램 포맷팅
  static String formatRewardHistogram(Map<String, int>? histogram) {
    if (histogram == null || histogram.isEmpty) {
      return '보상 히스토그램 없음';
    }
    
    final List<String> histogramEntries = [];
    histogram.forEach((key, value) {
      histogramEntries.add('$key: $value개');
    });
    
    return histogramEntries.join(', ');
  }

  // 포스트 보상 분포 포맷팅
  static String formatRewardDistribution(Map<String, double>? distribution) {
    if (distribution == null || distribution.isEmpty) {
      return '보상 분포 없음';
    }
    
    final List<String> distributionEntries = [];
    distribution.forEach((key, value) {
      distributionEntries.add('$key: ${value.toStringAsFixed(1)}%');
    });
    
    return distributionEntries.join(', ');
  }

  // 포스트 보상 트렌드 포맷팅
  static String formatRewardTrend(List<double>? trend) {
    if (trend == null || trend.isEmpty) {
      return '보상 트렌드 없음';
    }
    
    final List<String> trendEntries = [];
    for (int i = 0; i < trend.length; i++) {
      trendEntries.add('${i + 1}일: ${trend[i].toStringAsFixed(0)}원');
    }
    
    return trendEntries.join(', ');
  }

  // 포스트 보상 예측 포맷팅
  static String formatRewardPrediction({
    double? predictedReward,
    double? confidence,
    String? predictionMethod,
  }) {
    if (predictedReward == null) {
      return '보상 예측 없음';
    }
    
    final List<String> predictionEntries = [];
    predictionEntries.add('예측 보상: ${predictedReward.toStringAsFixed(0)}원');
    
    if (confidence != null) {
      predictionEntries.add('신뢰도: ${(confidence * 100).toStringAsFixed(1)}%');
    }
    
    if (predictionMethod != null) {
      predictionEntries.add('예측 방법: $predictionMethod');
    }
    
    return predictionEntries.join(', ');
  }

  // 포스트 보상 분석 포맷팅
  static String formatRewardAnalysis({
    double? averageReward,
    double? medianReward,
    double? standardDeviation,
    double? variance,
    double? minReward,
    double? maxReward,
    double? range,
    double? coefficientOfVariation,
  }) {
    final List<String> analysisEntries = [];
    
    if (averageReward != null) {
      analysisEntries.add('평균: ${averageReward.toStringAsFixed(0)}원');
    }
    
    if (medianReward != null) {
      analysisEntries.add('중간값: ${medianReward.toStringAsFixed(0)}원');
    }
    
    if (standardDeviation != null) {
      analysisEntries.add('표준편차: ${standardDeviation.toStringAsFixed(0)}원');
    }
    
    if (variance != null) {
      analysisEntries.add('분산: ${variance.toStringAsFixed(0)}원²');
    }
    
    if (minReward != null) {
      analysisEntries.add('최소: ${minReward.toStringAsFixed(0)}원');
    }
    
    if (maxReward != null) {
      analysisEntries.add('최대: ${maxReward.toStringAsFixed(0)}원');
    }
    
    if (range != null) {
      analysisEntries.add('범위: ${range.toStringAsFixed(0)}원');
    }
    
    if (coefficientOfVariation != null) {
      analysisEntries.add('변동계수: ${coefficientOfVariation.toStringAsFixed(2)}');
    }
    
    return analysisEntries.isEmpty ? '보상 분석 없음' : analysisEntries.join(', ');
  }
}