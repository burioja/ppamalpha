import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/place/place_model.dart';
import '../../../core/models/post/post_model.dart';
import '../../../core/services/data/post_service.dart';
import '../../../core/services/auth/firebase_service.dart';

/// 포스트 생성 화면의 상태 및 로직 관리
class PostPlaceProvider with ChangeNotifier {
  final PostService _postService = PostService();
  final FirebaseService _firebaseService = FirebaseService();
  final String? currentUserId;

  PostPlaceProvider({required this.currentUserId});

  // ==================== 상태 변수들 ====================
  
  // 타겟팅
  RangeValues selectedAgeRange = const RangeValues(20, 40);
  String selectedGender = 'all';
  List<String> selectedGenders = ['male', 'female'];
  List<String> selectedInterests = [];
  
  // 미디어
  List<File> selectedImages = [];
  File? selectedAudioFile;
  
  // 기본 설정
  int defaultRadius = 1000;
  DateTime? defaultExpiresAt;
  String? selectedPlaceId;
  bool isCoupon = false;
  String? youtubeUrl;
  String selectedPostType = '일반';
  
  // 추가 옵션
  bool hasExpiration = false;
  bool canTransfer = false;
  bool canForward = true;
  bool canRespond = true;
  
  // 상태
  bool isLoading = false;
  PlaceModel? selectedPlace;
  
  // 단가
  int minPrice = 30;

  // ==================== 초기화 ====================
  
  void initialize() {
    defaultExpiresAt = DateTime.now().add(const Duration(days: 30));
    notifyListeners();
  }

  // ==================== 상태 업데이트 ====================
  
  void setAgeRange(RangeValues range) {
    selectedAgeRange = range;
    notifyListeners();
  }

  void setGender(String gender) {
    selectedGender = gender;
    updateGendersList();
  }

  void updateGendersList() {
    if (selectedGender == 'all') {
      selectedGenders = ['male', 'female'];
    } else {
      selectedGenders = [selectedGender];
    }
    notifyListeners();
  }

  void toggleGender(String gender) {
    if (selectedGenders.contains(gender)) {
      selectedGenders.remove(gender);
    } else {
      selectedGenders.add(gender);
    }
    
    if (selectedGenders.isEmpty) {
      selectedGender = 'all';
      selectedGenders = ['male', 'female'];
    } else if (selectedGenders.length == 2) {
      selectedGender = 'all';
    } else {
      selectedGender = selectedGenders.first;
    }
    notifyListeners();
  }

  void toggleInterest(String interest) {
    if (selectedInterests.contains(interest)) {
      selectedInterests.remove(interest);
    } else {
      selectedInterests.add(interest);
    }
    notifyListeners();
  }

  void setRadius(int radius) {
    defaultRadius = radius;
    notifyListeners();
  }

  void setExpiresAt(DateTime? date) {
    defaultExpiresAt = date;
    notifyListeners();
  }

  void setPlaceId(String? placeId) {
    selectedPlaceId = placeId;
    notifyListeners();
  }

  void setIsCoupon(bool value) {
    isCoupon = value;
    notifyListeners();
  }

  void setYoutubeUrl(String? url) {
    youtubeUrl = url;
    notifyListeners();
  }

  void setPostType(String type) {
    selectedPostType = type;
    notifyListeners();
  }

  void toggleCanForward(bool value) {
    canForward = value;
    notifyListeners();
  }

  void toggleCanRespond(bool value) {
    canRespond = value;
    notifyListeners();
  }

  // ==================== 미디어 관리 ====================
  
  void addImage(File image) {
    selectedImages.add(image);
    notifyListeners();
  }

  void removeImage(int index) {
    selectedImages.removeAt(index);
    notifyListeners();
  }

  void setAudioFile(File? file) {
    selectedAudioFile = file;
    notifyListeners();
  }

  // ==================== 포스트 생성 ====================
  
  Future<bool> createPost({
    required String title,
    required String description,
    required int reward,
  }) async {
    if (currentUserId == null) return false;

    isLoading = true;
    notifyListeners();

    try {
      // 이미지 업로드
      final List<String> imageUrls = [];
      final List<String> thumbnailUrls = [];

      for (final image in selectedImages) {
        final result = await _firebaseService.uploadImageWithThumbnail(
          image,
          'posts/$currentUserId',
        );
        imageUrls.add(result['original']!);
        thumbnailUrls.add(result['thumbnail']!);
      }

      // 오디오 업로드
      String? audioUrl;
      if (selectedAudioFile != null) {
        // TODO: FirebaseService.uploadFile 메서드 구현 필요
        debugPrint('⚠️ 오디오 업로드 기능 미구현');
        // audioUrl = await _firebaseService.uploadFile(selectedAudioFile!.path, 'posts/$currentUserId/audio');
      }

      // PostModel 생성
      final post = PostModel(
        postId: '', // Firestore가 생성
        creatorId: currentUserId!,
        creatorName: 'User', // TODO: 실제 사용자 이름 가져오기
        createdAt: DateTime.now(),
        reward: reward,
        defaultRadius: defaultRadius,
        defaultExpiresAt: defaultExpiresAt ?? DateTime.now().add(const Duration(days: 30)),
        targetAge: [selectedAgeRange.start.toInt(), selectedAgeRange.end.toInt()],
        targetGender: selectedGender,
        targetInterest: selectedInterests,
        targetPurchaseHistory: [],
        mediaType: _getMediaTypes(imageUrls, audioUrl),
        mediaUrl: [...imageUrls, if (audioUrl != null) audioUrl],
        thumbnailUrl: thumbnailUrls,
        title: title,
        description: description,
        canRespond: canRespond,
        canForward: canForward,
        canRequestReward: true,
        canUse: false,
        placeId: selectedPlaceId,
        isCoupon: isCoupon,
        youtubeUrl: youtubeUrl,
      );

      await _postService.createPostFromModel(post);
      
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ 포스트 생성 실패: $e');
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<String> _getMediaTypes(List<String> imageUrls, String? audioUrl) {
    final types = <String>[];
    if (imageUrls.isNotEmpty) types.add('image');
    if (audioUrl != null) types.add('audio');
    if (youtubeUrl != null && youtubeUrl!.isNotEmpty) types.add('video');
    if (types.isEmpty) types.add('text');
    return types;
  }

  /// 초기화
  void reset() {
    selectedAgeRange = const RangeValues(20, 40);
    selectedGender = 'all';
    selectedGenders = ['male', 'female'];
    selectedInterests = [];
    selectedImages = [];
    selectedAudioFile = null;
    defaultRadius = 1000;
    defaultExpiresAt = DateTime.now().add(const Duration(days: 30));
    selectedPlaceId = null;
    isCoupon = false;
    youtubeUrl = null;
    selectedPostType = '일반';
    hasExpiration = false;
    canTransfer = false;
    canForward = true;
    canRespond = true;
    selectedPlace = null;
    notifyListeners();
  }
}

