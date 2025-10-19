import '../../../core/models/post/post_model.dart';

/// 포스트 유효성 검증 서비스
/// 
/// **책임**: 포스트 데이터 유효성 검증
/// **원칙**: 순수 비즈니스 로직만
class PostValidationService {
  // ==================== 유효성 검증 ====================

  /// 포스트 전체 유효성 검증
  /// 
  /// Returns: (isValid, errors)
  static (bool, List<String>) validatePost({
    required String title,
    required String description,
    int? reward,
    int? quantity,
    DateTime? expiresAt,
    String? category,
  }) {
    final errors = <String>[];

    // 제목 검증
    final titleError = validateTitle(title);
    if (titleError != null) errors.add(titleError);

    // 설명 검증
    final descError = validateDescription(description);
    if (descError != null) errors.add(descError);

    // 보상 검증
    if (reward != null) {
      final rewardError = validateReward(reward);
      if (rewardError != null) errors.add(rewardError);
    }

    // 수량 검증
    if (quantity != null) {
      final quantityError = validateQuantity(quantity);
      if (quantityError != null) errors.add(quantityError);
    }

    // 만료일 검증
    if (expiresAt != null) {
      final expiryError = validateExpiryDate(expiresAt);
      if (expiryError != null) errors.add(expiryError);
    }

    // 카테고리 검증
    if (category != null) {
      final categoryError = validateCategory(category);
      if (categoryError != null) errors.add(categoryError);
    }

    return (errors.isEmpty, errors);
  }

  /// 제목 검증
  static String? validateTitle(String title) {
    if (title.trim().isEmpty) {
      return '제목을 입력해주세요';
    }
    
    if (title.length < 2) {
      return '제목은 2자 이상이어야 합니다';
    }
    
    if (title.length > 100) {
      return '제목은 100자 이하여야 합니다';
    }
    
    return null;
  }

  /// 설명 검증
  static String? validateDescription(String description) {
    if (description.trim().isEmpty) {
      return '설명을 입력해주세요';
    }
    
    if (description.length < 10) {
      return '설명은 10자 이상이어야 합니다';
    }
    
    if (description.length > 1000) {
      return '설명은 1000자 이하여야 합니다';
    }
    
    return null;
  }

  /// 보상 검증
  static String? validateReward(int reward) {
    if (reward < 0) {
      return '보상은 0원 이상이어야 합니다';
    }
    
    if (reward > 100000) {
      return '보상은 100,000원 이하여야 합니다';
    }
    
    return null;
  }

  /// 수량 검증
  static String? validateQuantity(int quantity) {
    if (quantity < 1) {
      return '수량은 1개 이상이어야 합니다';
    }
    
    if (quantity > 1000) {
      return '수량은 1,000개 이하여야 합니다';
    }
    
    return null;
  }

  /// 만료일 검증
  static String? validateExpiryDate(DateTime expiresAt) {
    final now = DateTime.now();
    
    if (expiresAt.isBefore(now)) {
      return '만료일은 현재 시간 이후여야 합니다';
    }
    
    final maxDate = now.add(const Duration(days: 365));
    if (expiresAt.isAfter(maxDate)) {
      return '만료일은 1년 이내여야 합니다';
    }
    
    return null;
  }

  /// 카테고리 검증
  static String? validateCategory(String category) {
    const validCategories = [
      'delivery',
      'pickup',
      'service',
      'coupon',
      'stamp',
    ];
    
    if (!validCategories.contains(category)) {
      return '올바른 카테고리를 선택해주세요';
    }
    
    return null;
  }

  /// 성별 필터 검증
  static String? validateGenderFilter(List<String>? genders) {
    if (genders == null || genders.isEmpty) {
      return null; // 선택사항
    }

    const validGenders = ['male', 'female', 'all'];
    
    for (final gender in genders) {
      if (!validGenders.contains(gender)) {
        return '올바른 성별을 선택해주세요';
      }
    }
    
    return null;
  }

  /// 연령 필터 검증
  static String? validateAgeFilter(int? minAge, int? maxAge) {
    if (minAge == null && maxAge == null) {
      return null; // 선택사항
    }

    if (minAge != null && (minAge < 0 || minAge > 100)) {
      return '최소 연령은 0-100 사이여야 합니다';
    }

    if (maxAge != null && (maxAge < 0 || maxAge > 100)) {
      return '최대 연령은 0-100 사이여야 합니다';
    }

    if (minAge != null && maxAge != null && minAge > maxAge) {
      return '최소 연령이 최대 연령보다 클 수 없습니다';
    }

    return null;
  }

  // ==================== 데이터 정규화 ====================

  /// 제목 정규화
  static String normalizeTitle(String title) {
    return title.trim();
  }

  /// 설명 정규화
  static String normalizeDescription(String description) {
    return description.trim();
  }

  /// 카테고리 정규화
  static String normalizeCategory(String category) {
    return category.toLowerCase().trim();
  }

  // ==================== 포스트 타입 검증 ====================

  /// 쿠폰 포스트 여부 확인
  static bool isCouponPost(PostModel post) {
    return post.category == 'coupon' || (post.isCoupon ?? false);
  }

  /// 스탬프 포스트 여부 확인
  static bool isStampPost(PostModel post) {
    return post.category == 'stamp' || (post.isStamp ?? false);
  }

  /// 배달 포스트 여부 확인
  static bool isDeliveryPost(PostModel post) {
    return post.category == 'delivery';
  }

  /// 서비스 포스트 여부 확인
  static bool isServicePost(PostModel post) {
    return post.category == 'service';
  }
}

